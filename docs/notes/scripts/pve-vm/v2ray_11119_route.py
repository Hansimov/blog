#!/usr/bin/env python3
"""Switch an existing V2Ray 4.x TCP outbound between direct and local relay.

Run inside the VM. Reads the existing private config; no upstream credentials
are embedded here. Candidate probes use a separate loopback listener and the
service's Unix account. Failed changes restore the previous config and service.
"""
import argparse
import copy
import concurrent.futures
import datetime
import fcntl
import grp
import json
import os
from pathlib import Path
import pwd
import socket
import stat
import subprocess
import tempfile
import time


RELAY_TAG = "via-local-v2ray-http-11111"
CHECKS = (
    ("https://www.google.com/generate_204", "204"),
    ("https://www.cloudflare.com/cdn-cgi/trace", "200"),
)


def command(argv, timeout=35):
    return subprocess.run(argv, capture_output=True, text=True, timeout=timeout,
                          stdin=subprocess.DEVNULL)


def service_account(service):
    user = command(["systemctl", "show", service, "-p", "User", "--value"]).stdout.strip()
    group = command(["systemctl", "show", service, "-p", "Group", "--value"]).stdout.strip()
    account = pwd.getpwnam(user or "root")
    gid = grp.getgrnam(group).gr_gid if group else account.pw_gid
    return account.pw_uid, gid


def primary(config, tag):
    outbounds = config.get("outbounds", [])
    matches = [item for item in outbounds if item.get("tag") == tag] if tag else outbounds[:1]
    if len(matches) != 1 or matches[0].get("protocol") not in (
            "vmess", "vless", "trojan", "shadowsocks"):
        raise RuntimeError("Select exactly one existing remote proxy outbound with --outbound-tag.")
    stream = matches[0].get("streamSettings", {})
    if stream.get("sockopt", {}).get("dialerProxy"):
        raise RuntimeError("dialerProxy is configured; this V2Ray 4.x helper cannot change it.")
    return matches[0]


def candidate(config, mode, tag):
    result = copy.deepcopy(config)
    target = primary(result, tag)
    if mode == "direct":
        target.pop("proxySettings", None)
        return result
    stream = target.get("streamSettings", {})
    if stream.get("network", "tcp") != "tcp" or stream.get("security", "none") != "none":
        raise RuntimeError("Relay mode supports raw TCP only; retain transport settings on newer cores separately.")
    relay = {"tag": RELAY_TAG, "protocol": "http", "settings": {
        "servers": [{"address": "127.0.0.1", "port": 11111}]}}
    existing = [item for item in result["outbounds"] if item.get("tag") == RELAY_TAG]
    if existing and (len(existing) != 1 or existing[0] != relay):
        raise RuntimeError("Existing relay tag has different settings; refusing to overwrite it.")
    if not existing:
        result["outbounds"].append(relay)
    target["proxySettings"] = {"tag": RELAY_TAG}
    return result


def check_http(port, url, expected):
    result = command(["curl", "--silent", "--show-error", "--noproxy", "",
                      "--proxy", f"http://127.0.0.1:{port}", "--connect-timeout", "10",
                      "--max-time", "20", "--output", "/dev/null", "--write-out",
                      "%{http_code} %{time_total}", url], timeout=24)
    code = result.stdout.split()[0] if result.stdout.split() else "000"
    ok = result.returncode == 0 and code == expected
    print(f"{'OK' if ok else 'FAIL'} {url}: {result.stdout.strip()} curl={result.returncode}", flush=True)
    return ok


def check_proxy(port):
    # Two rounds avoid accepting a single successful request on a flaky route.
    results = []
    for _ in range(2):
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(CHECKS)) as pool:
            futures = [pool.submit(check_http, port, url, status) for url, status in CHECKS]
            results.extend(job.result() for job in futures)
    return all(results)


def validate(binary, path):
    # Matches the existing V2Ray 4.x systemd ExecStart, without upgrading it.
    result = command([binary, "-test", "-config", str(path)])
    if result.returncode:
        raise RuntimeError("V2Ray configuration validation failed (private config output suppressed).")


def probe(config, args, uid, gid, directory):
    probe_config = copy.deepcopy(config)
    target = primary(probe_config, args.outbound_tag)
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    # Make the selected remote outbound the default and force probe requests to it;
    # production split-routing rules must not create a false successful direct test.
    probe_config["outbounds"].remove(target)
    probe_config["outbounds"].insert(0, target)
    probe_config["inbounds"] = [{"listen": "127.0.0.1", "port": port,
                                  "protocol": "http", "settings": {}}]
    probe_config["routing"] = {"domainStrategy": "AsIs", "rules": []}
    probe_config["log"] = {"loglevel": "warning"}
    for key in ("api", "reverse", "observatory", "burstObservatory"):
        probe_config.pop(key, None)
    path = directory / "probe.json"
    path.write_text(json.dumps(probe_config), encoding="utf-8")
    os.chown(path, 0, gid)
    path.chmod(0o640)
    validate(args.binary, path)
    with (directory / "probe.log").open("wb") as log:
        process = subprocess.Popen([args.binary, "-config", str(path)],
                                   stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                                   cwd="/", user=uid, group=gid, extra_groups=[])
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError("Isolated V2Ray probe exited before becoming ready.")
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                        break
                except OSError:
                    time.sleep(0.1)
            else:
                raise RuntimeError("Isolated V2Ray probe listener did not become ready.")
            return check_proxy(port) and process.poll() is None
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)


def atomic_write(path, data, metadata):
    fd, temporary = tempfile.mkstemp(prefix=".v2ray-route-", suffix=".json", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
            os.fchown(output.fileno(), metadata.st_uid, metadata.st_gid)
            os.fchmod(output.fileno(), stat.S_IMODE(metadata.st_mode))
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def restart(service):
    if command(["systemctl", "restart", service]).returncode:
        raise RuntimeError("Service restart failed.")
    if command(["systemctl", "is-active", "--quiet", service]).returncode:
        raise RuntimeError("Service is not active after restart.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("status", "test-direct", "direct", "relay"))
    parser.add_argument("--config", type=Path, default=Path("/usr/local/etc/v2ray/new.json"))
    parser.add_argument("--service", default="v2ray@new.service")
    parser.add_argument("--binary", default="/usr/local/bin/v2ray")
    parser.add_argument("--outbound-tag", default=None)
    parser.add_argument("--backup-dir", type=Path, default=Path("/var/backups/v2ray-route"))
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error("Run with sudo inside the VM.")
    args.config = args.config.resolve(strict=True)
    with open("/run/lock/v2ray-11119-route.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        raw = args.config.read_bytes()
        metadata = args.config.stat()
        config = json.loads(raw)
        current = primary(config, args.outbound_tag).get("proxySettings", {}).get("tag")
        route = "direct" if not current else ("relay via 127.0.0.1:11111" if current == RELAY_TAG else "other relay")
        print(f"Current route: {route}", flush=True)
        if args.mode == "status":
            print("Service: " + command(["systemctl", "is-active", args.service]).stdout.strip())
            return
        if not any(item.get("protocol") == "http" and item.get("port") == 11119
                   for item in config.get("inbounds", [])):
            raise RuntimeError("Expected HTTP inbound on 11119 is absent.")
        if command(["systemctl", "is-active", "--quiet", args.service]).returncode:
            raise RuntimeError("Start the existing service before testing or switching routes.")
        mode = "direct" if args.mode == "test-direct" else args.mode
        changed = candidate(config, mode, args.outbound_tag)
        uid, gid = service_account(args.service)
        with tempfile.TemporaryDirectory(prefix="v2ray-route-", dir="/run") as temp:
            directory = Path(temp)
            os.chown(directory, 0, gid)
            directory.chmod(0o710)
            print(f"Testing {mode} with an isolated listener as service uid={uid}...", flush=True)
            if not probe(changed, args, uid, gid, directory):
                raise RuntimeError("Candidate route failed; production config and service were left unchanged.")
            if args.mode == "test-direct":
                print("Direct route passed. Use 'direct' to switch production.")
                return
            if config == changed:
                print("Already using the requested route; no restart needed.")
                return
            candidate_path = directory / "candidate.json"
            encoded = (json.dumps(changed, ensure_ascii=False, indent=2) + "\n").encode()
            candidate_path.write_bytes(encoded)
            candidate_path.chmod(0o600)
            validate(args.binary, candidate_path)
            if args.config.read_bytes() != raw:
                raise RuntimeError("Config changed during the probe; rerun against the new version.")
            backup_dir = args.backup_dir
            backup_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
            backup_dir.chmod(0o700)
            stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
            backup = backup_dir / f"{args.config.name}.{stamp}.bak"
            fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as output:
                output.write(raw)
                output.flush()
                os.fsync(output.fileno())
            print(f"Private backup: {backup}", flush=True)
            atomic_write(args.config, encoded, metadata)
            try:
                restart(args.service)
                if not check_proxy(11119):
                    raise RuntimeError("Production HTTP checks failed.")
            except BaseException as problem:
                atomic_write(args.config, raw, metadata)
                restart(args.service)
                restored = check_proxy(11119)
                raise RuntimeError(f"Previous config restored; previous route healthy={restored}.") from problem
            print(f"Switched to {mode}; production HTTPS checks passed.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        # Config parsing and process errors may contain private values: do not dump
        # the config, V2Ray log, subprocess output, or Python exception traceback.
        message = str(error) if isinstance(error, RuntimeError) else type(error).__name__
        raise SystemExit("ERROR: " + message)
