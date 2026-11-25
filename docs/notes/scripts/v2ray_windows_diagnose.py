"""Compare a Windows V2Ray plain-TCP VMess exit directly and via the live HTTP proxy on 11111."""
import argparse
from contextlib import contextmanager, suppress
from copy import deepcopy
import ctypes
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time


class ProbeError(Exception):
    pass


class ProbeParser(argparse.ArgumentParser):
    def error(self, message):
        # argparse normally repeats the rejected command-line token, which may be a private path.
        super().error("Invalid arguments. Use --help for the required directory and supported options.")


class TcpInfo(ctypes.Structure):
    # Windows SDK mstcpip.h TCP_INFO_v0, requested with SIO_TCP_INFO.
    u32, u64, u8 = ctypes.c_uint32, ctypes.c_uint64, ctypes.c_ubyte
    _fields_ = [
        ("state", u32), ("mss", u32), ("age_ms", u64), ("timestamps", u8),
        ("rtt_us", u32), ("min_rtt_us", u32), ("in_flight", u32), ("cwnd", u32),
        ("snd_wnd", u32), ("rcv_wnd", u32), ("rcv_buf", u32), ("bytes_out", u64),
        ("bytes_in", u64), ("reordered", u32), ("retrans_bytes", u32),
        ("fast_retrans", u32), ("duplicate_acks", u32), ("rto_episodes", u32), ("syn_retrans", u8),
    ]


def tcp_info(sock):
    version, size, info = ctypes.c_uint32(0), ctypes.c_uint32(), TcpInfo()
    result = ctypes.windll.ws2_32.WSAIoctl(
        ctypes.c_size_t(sock.fileno()), ctypes.c_uint32(0xD8000027),
        ctypes.byref(version), 4, ctypes.byref(info), ctypes.sizeof(info),
        ctypes.byref(size), None, None,
    )
    if result or size.value != ctypes.sizeof(info):
        raise ProbeError("Windows could not read TCP_INFO_v0 for the upstream connection.")
    return info


def pump(source, destination):
    try:
        while data := source.recv(65536):
            destination.sendall(data)
    except OSError:
        pass
    finally:
        with suppress(OSError):
            destination.shutdown(socket.SHUT_WR)


def measure_direct(listener, upstream, done, stats):
    """Relay the encrypted VMess TCP bytes and observe only the physical upstream socket."""
    try:
        listener.settimeout(0.2)
        while not done.is_set():
            try:
                local, _ = listener.accept()
                break
            except TimeoutError:
                continue
        else:
            return
        with local, socket.create_connection(upstream, timeout=8) as remote:
            remote.settimeout(None)
            workers = []
            for source, destination in ((local, remote), (remote, local)):
                worker = threading.Thread(target=pump, args=(source, destination), daemon=True)
                worker.start()
                workers.append(worker)
            try:
                while True:
                    try:
                        info = tcp_info(remote)
                    except ProbeError:
                        # The upload is still a valid observation when counters are unavailable.
                        stats["measurement_error"] = "TCP_INFO_v0 unavailable"
                        done.wait()
                        break
                    stats.update(bytes_out=info.bytes_out, retrans_bytes=info.retrans_bytes,
                                 rto_episodes=info.rto_episodes, mss=info.mss)
                    if info.bytes_out:
                        stats["min_sampled_cwnd"] = min(stats.get("min_sampled_cwnd", info.cwnd), info.cwnd)
                    if done.wait(0.1):
                        break
            finally:
                for sock in (local, remote):
                    with suppress(OSError):
                        sock.shutdown(socket.SHUT_RDWR)
                for worker in workers:
                    worker.join(1)
    except OSError as error:
        stats["connection_error"] = type(error).__name__


def loopback_listener():
    sock = socket.socket()
    try:
        sock.bind(("127.0.0.1", 0))
        sock.listen()
        return sock
    except BaseException:
        sock.close()
        raise


@contextmanager
def outbounds_for(mode, outbound):
    target = deepcopy(outbound)
    target.pop("proxySettings", None)
    target["tag"] = "final"
    if mode == "relay":
        target["proxySettings"] = {"tag": "via-11111"}
        front = {"protocol": "http", "tag": "via-11111", "settings": {
            "servers": [{"address": "127.0.0.1", "port": 11111}]}}
        yield [target, front], None
        return
    server = target["settings"]["vnext"][0]
    upstream = (server["address"], server["port"])
    done, stats = threading.Event(), {}
    with loopback_listener() as listener:
        server.update(address="127.0.0.1", port=listener.getsockname()[1])
        thread = threading.Thread(target=measure_direct, args=(listener, upstream, done, stats), daemon=True)
        thread.start()
        try:
            yield [target], stats
        finally:
            done.set()
            thread.join(10)


@contextmanager
def proxy(exe, outbounds):
    with loopback_listener() as reservation:
        port = reservation.getsockname()[1]
    config = {"log": {"loglevel": "none"}, "outbounds": outbounds,
              "inbounds": [{"protocol": "http", "listen": "127.0.0.1", "port": port, "settings": {}}]}
    # 5.7.0 prefers config.json alongside the executable even with a different cwd.
    # The copy is alone in a temporary directory. The private configuration travels only over stdin.
    env = {k: v for k, v in os.environ.items()
           if k.lower() not in {"v2ray.location.config", "v2ray_location_config",
                                "v2ray.location.confdir", "v2ray_location_confdir"}}
    with subprocess.Popen([exe, "run", "-format", "json"], cwd=exe.parent, env=env, stdin=subprocess.PIPE,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                          creationflags=subprocess.CREATE_NO_WINDOW) as process:
        try:
            with process.stdin as pipe:
                pipe.write(json.dumps(config).encode())
            for _ in range(80):
                if process.poll() is not None:
                    raise ProbeError("The isolated V2Ray process exited during startup.")
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                        break
                except OSError:
                    time.sleep(0.05)
            else:
                raise ProbeError("The isolated V2Ray listener did not start.")
            yield port
        finally:
            if process.poll() is None:
                process.terminate()


def read_outbound(folder):
    def read(filename):
        return json.loads((folder / filename).read_text(encoding="utf-8-sig"))

    front = read("config.json")
    final = read("config_vmiss.json")["outbounds"][0]
    stream = final.get("streamSettings", {})
    if (final.get("protocol") != "vmess" or len(final["settings"]["vnext"]) != 1
            or stream.get("network", "tcp") != "tcp" or stream.get("security", "none") != "none"
            or stream.get("sockopt") or final.get("sendThrough") or final.get("mux", {}).get("enabled")):
        raise ProbeError("The probe supports one plain TCP VMess upstream without mux or socket overrides.")
    front_out = front["outbounds"][0]
    if (front_out.get("protocol") != "vmess" or front_out.get("proxySettings")
            or front.get("routing", {}).get("rules") != [
                {"type": "field", "ip": ["geoip:private"], "outboundTag": "direct"}]
            or not any(i.get("protocol") == "http" and i.get("port") == 11111 for i in front["inbounds"])):
        raise ProbeError("Expected the live 11111 config to proxy public IPs with only a private-IP bypass.")
    server = final["settings"]["vnext"][0]
    front_server = front_out["settings"]["vnext"][0]
    if not ipaddress.ip_address(server["address"]).is_global or front_server["address"] == server["address"]:
        raise ProbeError("Expected a distinct public final upstream IP.")
    return final


def upload(port, payload, timeout):
    result = subprocess.run([
        "curl.exe", "--disable", "--silent", "--http1.1", "--noproxy", "",
        "--proxy", f"http://127.0.0.1:{port}", "--max-time", str(timeout),
        "--header", "Expect:", "--header", "Content-Type: application/octet-stream",
        "--data-binary", "@-", "--output", "NUL", "--write-out",
        "%{http_connect} %{http_code} %{time_appconnect} %{time_starttransfer} %{time_total} %{size_upload}",
        "https://speed.cloudflare.com/__up",
    ], input=payload, capture_output=True, timeout=timeout + 5)
    seconds = rb"([0-9]{1,3}(?:\.[0-9]{1,6})?)"
    report = re.fullmatch(rb"([0-9]{3}) ([0-9]{3}) " + b" ".join([seconds] * 3) + rb" ([0-9]{1,8})",
                          result.stdout.strip())
    if report is None:
        raise ProbeError("curl could not report request timings.")
    connect, http, tls, first, total, uploaded = (value.decode("ascii") for value in report.groups())
    print(f"CONNECT={connect} HTTP={http} curl={result.returncode} TLS={tls}s "
          f"first={first}s total={total}s curl_upload_bytes={uploaded}", flush=True)
    return result.returncode == 0 and connect == http == "200" and uploaded == str(len(payload))


def main():
    cli = ProbeParser(prog="v2ray_windows_diagnose.py", description=__doc__, epilog=(
        "Uses config.json (live 11111) and config_vmiss.json (final upstream). "
        "Each route receives one synthetic 2,400,000-byte POST per round. Requires Windows 10+ and V2Ray 5.x."))
    cli.add_argument("--dir", type=Path, required=True, metavar="DIR", help="directory with V2Ray and its configs")
    cli.add_argument("--rounds", type=int, choices=range(1, 5), default=1, help="alternate which route goes first")
    cli.add_argument("--timeout", type=int, default=30, help="seconds per upload (default 30)")
    args = cli.parse_args()
    if sys.platform != "win32" or not 1 <= args.timeout <= 180:
        raise ProbeError("Requires Windows and a timeout of 1 to 180 seconds.")
    final = read_outbound(args.dir)
    with socket.create_connection(("127.0.0.1", 11111), timeout=2):
        pass
    payload = os.urandom(2_400_000)
    with tempfile.TemporaryDirectory(prefix="v2ray-upload-") as temp:
        exe = Path(shutil.copy2(args.dir / "v2ray.exe", temp))
        passed = True
        for i in range(args.rounds):
            for mode in (("direct", "relay") if i % 2 == 0 else ("relay", "direct")):
                print(f"round={i + 1} {mode} ", end="", flush=True)
                with outbounds_for(mode, final) as (outbounds, stats), proxy(exe, outbounds) as port:
                    ok = upload(port, payload, args.timeout)
                if stats is not None:
                    print("  TCP to final upstream:", json.dumps(stats, sort_keys=True), flush=True)
                passed = passed and ok
    return 0 if passed else 1


def run_cli():
    # Python's default thread traceback prints absolute source paths and the raw exception.
    previous_hook = threading.excepthook
    threading.excepthook = lambda _: print("A probe worker stopped unexpectedly.", file=sys.stderr)
    try:
        return main()
    except KeyboardInterrupt:
        print("Probe interrupted.", file=sys.stderr)
        return 130
    except ProbeError as error:
        print(error, file=sys.stderr)
    except Exception:
        # Config, process, socket and filesystem exceptions can contain private values.
        print("Could not complete the probe. Check the local installation and proxy configuration.",
              file=sys.stderr)
    finally:
        threading.excepthook = previous_hook
    return 1


if __name__ == "__main__":
    sys.exit(run_cli())
