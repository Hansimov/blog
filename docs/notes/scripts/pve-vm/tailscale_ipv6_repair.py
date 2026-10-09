#!/usr/bin/env python3
"""Diagnose stale SLAAC prefixes on one Linux interface; default is read-only.

Public output uses P1/P2 labels, never real IPs. Repair requires two failed
source-bound IPv6 checks, a healthy alternative, and fresh advertisements from
the current default router. Refreshes only NetworkManager's IPv6 automatic state;
no interface bounce, IPv4 edit, firewall edit, or permanent prefix pinning.
"""
import argparse
import concurrent.futures
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import socket
import stat
import struct
import subprocess
import time


class Refuse(RuntimeError):
    """Only fixed, non-private messages may be used here."""


def command(argv, timeout=10):
    return subprocess.run(argv, capture_output=True, text=True, timeout=timeout,
                          stdin=subprocess.DEVNULL)


def read_json(argv):
    result = command(argv)
    if result.returncode:
        raise Refuse("Network inspection failed; command output suppressed.")
    return json.loads(result.stdout)


def prefix(address):
    return str(ipaddress.ip_network(
        f"{address['local']}/{address['prefixlen']}", strict=False))


def addresses(interface):
    rows = read_json(["ip", "-j", "address", "show", "dev", interface])
    if len(rows) != 1:
        raise Refuse("Expected exactly one interface.")
    return [a for a in rows[0].get("addr_info", [])
            if a["family"] == "inet6" and a.get("scope") == "global"
            and not a.get("tentative") and not a.get("dadfailed")
            and ipaddress.ip_address(a["local"]) in ipaddress.ip_network("2000::/3")]


def route(interface):
    rows = read_json(["ip", "-j", "-6", "route", "show", "default"])
    # Ambiguous/multi-router and policy-routed networks need manual diagnosis.
    if len(rows) != 1 or rows[0].get("dev") != interface or not rows[0].get("gateway"):
        raise Refuse("Need one IPv6 default router on the selected interface.")
    selected = read_json(["ip", "-j", "-6", "route", "get", "2606:4700:4700::1111"])[0]
    if selected.get("dev") != interface:
        raise Refuse("IPv6 policy routing selects another interface.")
    return rows[0]["gateway"], selected.get("prefsrc", selected.get("src"))


def parse_ra(packet):
    """Return currently preferred /64 autoconfiguration prefixes, or refuse."""
    if len(packet) < 16 or packet[0:2] != b"\x86\x00" or not any(packet[6:8]):
        raise Refuse("Invalid or non-default router advertisement.")
    result = set()
    offset = 16
    while offset < len(packet):
        if offset + 2 > len(packet):
            raise Refuse("Truncated router advertisement.")
        kind, units = packet[offset:offset + 2]
        length = units * 8
        if not length or offset + length > len(packet):
            raise Refuse("Invalid router advertisement option.")
        option = packet[offset:offset + length]
        if kind == 3:
            if length != 32:
                raise Refuse("Invalid prefix information option.")
            valid, preferred = struct.unpack("!II", option[4:12])
            if option[2] == 64 and option[3] & 0x40 and 0 < preferred <= valid:
                result.add(str(ipaddress.IPv6Network(
                    (int.from_bytes(option[16:32], "big"), 64))))
        offset += length
    if not result:
        raise Refuse("No preferred SLAAC /64 prefix advertised; no automatic repair.")
    return result


def advertised_prefixes(interface, gateway):
    index = socket.if_nametoindex(interface)
    rows = read_json(["ip", "-j", "-6", "address", "show", "dev", interface])
    links = [a["local"] for a in rows[0]["addr_info"] if a.get("scope") == "link"]
    if not links:
        raise Refuse("Interface has no link-local address.")
    with socket.socket(socket.AF_INET6, socket.SOCK_RAW, socket.IPPROTO_ICMPV6) as sock:
        sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_IF, index)
        sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_HOPS, 255)
        sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_RECVHOPLIMIT, 1)
        sock.bind((links[0], 0, 0, index))
        sock.sendto(struct.pack("!BBHI", 133, 0, 0, 0), ("ff02::2", 0, 0, index))
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            sock.settimeout(max(0.01, deadline - time.monotonic()))
            try:
                packet, ancillary, _, source = sock.recvmsg(4096, 128)
            except socket.timeout:
                break
            hop = next((struct.unpack("i", data)[0] for level, kind, data in ancillary
                        if level == socket.IPPROTO_IPV6 and kind == socket.IPV6_HOPLIMIT), None)
            if (packet[:1] == b"\x86" and hop == 255
                    and ipaddress.ip_address(source[0].split("%")[0])
                    == ipaddress.ip_address(gateway.split("%")[0])):
                return parse_ra(packet)
    raise Refuse("No verified advertisement from the default router; left unchanged.")


def netcheck(address=None):
    argv = ["tailscale", "netcheck", "--format=json"]
    if address:
        argv += ["--bind-address", address]
    # Avoid inheriting a shell HTTP proxy and mistaking its path for this host's.
    env = {k: v for k, v in os.environ.items()
           if k.lower() not in ("http_proxy", "https_proxy", "all_proxy")}
    result = subprocess.run(argv, capture_output=True, text=True, timeout=30,
                            stdin=subprocess.DEVNULL, env=env)
    if result.returncode:
        raise Refuse("netcheck could not run; this is not evidence of a dead prefix.")
    report = json.loads(result.stdout)
    if not isinstance(report.get("IPv6"), bool):
        raise Refuse("Unsupported netcheck output; no automatic repair.")
    return report["IPv6"] is True and report.get("UDP") is True


def inspect(interface, maintain=False):
    initial = addresses(interface)
    gateway, source = route(interface)
    prefixes = sorted({prefix(a) for a in initial})
    labels = {p: f"P{i}" for i, p in enumerate(prefixes, 1)}
    advertised = advertised_prefixes(interface, gateway)
    selected = next((prefix(a) for a in initial if a["local"] == source), None)
    if maintain and selected in advertised:
        print("Default IPv6 source belongs to a currently advertised prefix; no refresh needed.")
        return None
    active = {p: [a for a in initial if prefix(a) == p
                  and a.get("preferred_life_time", 0) > 0] for p in prefixes}

    def check(items):
        # Only active prefixes can be repair candidates. Already deprecated ones
        # are not revived just for a test. Prefer a temporary source if available.
        if not items:
            return []
        representative = sorted(items, key=lambda a: not a.get("temporary", False))[0]
        return [netcheck(representative["local"]) for _ in range(2)]

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        checks = dict(zip(prefixes, pool.map(check, [active[p] for p in prefixes])))
    for p in prefixes:
        print(f"{labels[p]}: addresses={sum(prefix(a) == p for a in initial)} "
              f"preferred={len(active[p])} advertised={p in advertised} "
              f"IPv6_checks={checks[p]}", flush=True)
    print(f"Default source prefix: {labels.get(selected, 'unknown')}", flush=True)
    return initial, gateway, selected, advertised, labels, checks


def identity():
    return {"boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
            "machine_id": Path("/etc/machine-id").read_text().strip()}


def save_backup(directory, interface, items, profile):
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    metadata = directory.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0:
        raise Refuse("Backup directory must be a real, root-owned directory.")
    directory.chmod(0o700)
    data = dict(identity(), version=2, interface=interface, saved_at=time.time(),
                addresses_before=items, profile=profile, ipv6_method="auto")
    path = directory / f"ipv6-{time.time_ns()}.json"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        json.dump(data, stream, indent=2)
        stream.flush()
        os.fsync(stream.fileno())
    print(f"Private backup (contains real addresses): {path}", flush=True)
    return path, data


def nm_method(interface, method):
    if command(["nmcli", "--wait", "10", "device", "modify", interface,
                "ipv6.method", method], timeout=15).returncode:
        raise Refuse("NetworkManager IPv6 update failed; private output suppressed.")


def restore(interface, data):
    if (data.get("version") != 2 or data.get("interface") != interface
            or data.get("ipv6_method") != "auto"
            or any(data.get(k) != v for k, v in identity().items())):
        raise Refuse("Backup must belong to this interface, machine, and current boot.")
    # Restoration means resume auto-configuration, NOT re-add stale addresses.
    nm_method(interface, "auto")
    print("IPv6 automatic configuration restored; stale addresses were not re-created.", flush=True)


def ipv4_snapshot(interface):
    rows = read_json(["ip", "-j", "-4", "address", "show", "dev", interface])
    ips = sorted((a["local"], a["prefixlen"]) for a in rows[0].get("addr_info", []))
    defaults = read_json(["ip", "-j", "-4", "route", "show", "default"])
    routes = sorted((r.get("dev", ""), r.get("gateway", ""), r.get("metric", 0)) for r in defaults)
    return ips, routes


def refresh_nm(interface, target, healthy, backup_dir):
    profile = command(["nmcli", "-g", "GENERAL.CONNECTION", "device", "show", interface])
    if profile.returncode or not profile.stdout.strip():
        raise Refuse("Selected interface must be managed by NetworkManager.")
    method = command(["nmcli", "-g", "ipv6.method", "connection", "show", profile.stdout.strip()])
    if method.returncode or method.stdout.strip() != "auto":
        raise Refuse("Only a NetworkManager profile with ipv6.method=auto is supported.")
    before_v4 = ipv4_snapshot(interface)
    if not before_v4[0] or not before_v4[1]:
        raise Refuse("Need IPv4 management connectivity before refreshing IPv6.")
    save_backup(backup_dir, interface, addresses(interface), profile.stdout.strip())
    unit = f"tailscale-ipv6-recover-{time.time_ns()}"
    # Independent recovery also works if this process is killed or its caller
    # disconnects between disabled and auto. No shell, no embedded credentials.
    if command(["systemd-run", "--quiet", "--collect", "--unit=" + unit,
                "--on-active=90s", "/usr/bin/nmcli", "--wait", "10", "device", "modify",
                interface, "ipv6.method", "auto"]).returncode:
        raise Refuse("Could not arm independent IPv6 recovery; no network changes made.")
    try:
        try:
            nm_method(interface, "disabled")
        finally:
            nm_method(interface, "auto")
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            current = addresses(interface)
            if (any(prefix(a) in healthy and a.get("preferred_life_time", 0) > 0 for a in current)
                    and not any(prefix(a) == target for a in current)):
                break
            time.sleep(1)
        else:
            raise Refuse("IPv6 did not relearn a healthy prefix without the stale prefix.")
        if ipv4_snapshot(interface) != before_v4:
            raise Refuse("IPv4 state changed during repair; investigate using the management channel.")
        if not netcheck():
            raise Refuse("Unbound IPv6 check failed after refresh.")
        _, source = route(interface)
        if not any(a["local"] == source and prefix(a) in healthy for a in addresses(interface)):
            raise Refuse("Default source did not move to a proven healthy prefix.")
    except BaseException:
        raise Refuse("Refresh validation failed; IPv6 auto recovery remains armed. Inspect via IPv4/PVE console.") from None
    if command(["systemctl", "stop", unit + ".timer"]).returncode:
        raise Refuse("Refresh succeeded, but recovery timer could not be canceled (it only restores auto).")
    print("IPv6 state refreshed; stale prefix gone, IPv4 unchanged, netcheck passed. "
          "Persistent connection profile unchanged; verify end-to-end Tailscale ping.", flush=True)


def repair(interface, label, backup_dir, evidence):
    initial, gateway, selected, advertised, labels, checks = evidence
    target = next((p for p, name in labels.items() if name == label), None)
    healthy = {p for p in advertised if checks.get(p) == [True, True]}
    if (target is None or selected != target or target in advertised
            or checks.get(target) != [False, False] or not healthy):
        raise Refuse("Repair requires a failed default prefix absent from RA and a proven healthy advertised alternative.")
    # A second RA and a fresh address snapshot guard against renumbering while
    # the probes were running. Do not apply stale P1/P2 assumptions.
    if advertised_prefixes(interface, gateway) != advertised:
        raise Refuse("Router advertisements changed during diagnosis; rerun.")
    current = addresses(interface)
    new_gateway, new_source = route(interface)
    if (new_gateway != gateway or new_source not in {a["local"] for a in initial if prefix(a) == target}
            or {a["local"] for a in current} != {a["local"] for a in initial}):
        raise Refuse("Network addresses or route changed during diagnosis; rerun.")
    items = [a for a in current if prefix(a) == target and a.get("preferred_life_time", 0) > 0]
    if not items or any(not a.get("dynamic") or a["prefixlen"] != 64 for a in items):
        raise Refuse("Only preferred dynamic SLAAC /64 addresses can be repaired.")
    refresh_nm(interface, target, healthy, backup_dir)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", default="diagnose", choices=("diagnose", "repair", "maintain", "restore"))
    parser.add_argument("--interface", required=True)
    parser.add_argument("--stale-prefix", help="P1/P2 label from a fresh diagnosis; repair revalidates all evidence")
    parser.add_argument("--backup-dir", type=Path, default=Path("/var/backups/tailscale-network"))
    parser.add_argument("--backup", type=Path, help="private backup created by this script, for restore")
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error("Run as root: receiving IPv6 router advertisements requires raw sockets.")
    if (args.mode == "repair") != bool(args.stale_prefix) or (args.mode == "restore") != bool(args.backup):
        parser.error("Use --stale-prefix only with repair, and --backup only with restore.")
    # Ensure a real local interface; subprocess arguments never go through a shell.
    socket.if_nametoindex(args.interface)
    with open("/run/lock/tailscale-ipv6-repair.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.mode == "restore":
            metadata = args.backup.lstat()
            if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0
                    or stat.S_IMODE(metadata.st_mode) & 0o077):
                raise Refuse("Restore requires a root-owned, private regular backup file.")
            restore(args.interface, json.loads(args.backup.read_text()))
            return
        evidence = inspect(args.interface, maintain=args.mode == "maintain")
        if evidence is None:
            return
        if args.mode in ("repair", "maintain"):
            label = args.stale_prefix if args.mode == "repair" else evidence[4].get(evidence[2])
            repair(args.interface, label, args.backup_dir, evidence)
        else:
            print("Diagnosis only; no address/config changes. Labels are local to this snapshot.")


if __name__ == "__main__":
    try:
        main()
    except (Refuse, OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        # Never leak IPs, router identifiers, netcheck logs, or exception tracebacks.
        raise SystemExit("ERROR: " + (str(error) if isinstance(error, Refuse) else type(error).__name__))
