#!/usr/bin/env python3
"""Compare IPv4 STUN from unused UDP source ports without exposing addresses.

Requires a Tailscale CLI with netcheck --bind-port and --format=json support.
Does not stop tailscaled, change configuration, or modify firewall rules.
An occupied port is skipped: this cannot probe the daemon's active socket.
"""

import argparse
import ipaddress
import json
import socket
import subprocess


def public_ipv4_endpoint(value):
    """Validate the endpoint without returning or logging its address."""
    if not isinstance(value, str):
        return False
    try:
        host, port = value.rsplit(":", 1)
        addr = ipaddress.ip_address(host)
        return addr.version == 4 and addr.is_global and 0 < int(port) <= 65535
    except (ValueError, TypeError):
        return False


def probe(port):
    result = {"source_port": port}
    if port:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                sock.bind(("0.0.0.0", port))
        except OSError:
            return {**result, "status": "port_unavailable"}
    try:
        completed = subprocess.run(
            ["tailscale", "netcheck", "--format=json", "--bind-address", "0.0.0.0",
             "--bind-port", str(port)],
            capture_output=True, text=True, timeout=15, check=False,
        )
        if completed.returncode:
            return {**result, "status": "command_failed"}
        report = json.loads(completed.stdout)
        if not isinstance(report, dict) or not isinstance(report.get("UDP"), bool):
            return {**result, "status": "invalid_report"}
        endpoint = public_ipv4_endpoint(report.get("GlobalV4"))
        # IPv4=true alone is insufficient: fallback probes may set it even
        # when no UDP/STUN round trip succeeded. Never print raw netcheck logs.
        result.update(
            status="stun_ok" if report["UDP"] and endpoint else "no_public_ipv4_stun",
            udp_reply=report["UDP"],
            public_ipv4_endpoint=endpoint,
            ipv4_flag=report.get("IPv4") is True,
        )
        return result
    except subprocess.TimeoutExpired:
        return {**result, "status": "command_timeout"}
    except FileNotFoundError:
        return {**result, "status": "tailscale_not_found"}
    except (OSError, ValueError):
        return {**result, "status": "probe_error"}


def port_number(value):
    try:
        port = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError("Use 0 or an unprivileged UDP port") from None
    if port != 0 and not 1024 <= port <= 65535:
        raise argparse.ArgumentTypeError("Use 0 or a UDP port in 1024..65535")
    return port


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ports", type=port_number, nargs="+", default=[0],
                        help="Up to four unused source ports; 0 asks the OS to choose")
    parser.add_argument("--repeats", type=int, choices=range(1, 4), default=2)
    args = parser.parse_args(argv)
    ports = list(dict.fromkeys(args.ports))
    if len(ports) > 4:
        parser.error("At most four source ports may be compared")
    failed = False
    for round_number in range(1, args.repeats + 1):
        for port in ports:
            result = probe(port)
            print(json.dumps({"round": round_number, **result}), flush=True)
            failed |= result["status"] not in ("stun_ok", "no_public_ipv4_stun")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
