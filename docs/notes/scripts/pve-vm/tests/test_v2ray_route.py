"""Linux-only offline tests; no real proxy, credentials, or service changes.

python3 -m unittest discover -s docs/notes/scripts/pve-vm/tests -v
"""
import contextlib
import builtins
import importlib.util
import io
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "v2ray_11119_route.py"
spec = importlib.util.spec_from_file_location("route", SOURCE)
route = importlib.util.module_from_spec(spec)
spec.loader.exec_module(route)


class RouteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.config_path = self.directory / "new.json"
        self.config = {
            "inbounds": [{"protocol": "http", "listen": "127.0.0.1", "port": 11119}],
            "outbounds": [{"protocol": "vmess", "settings": {"vnext": [{
                "address": "example.invalid", "port": 9991,
                "users": [{"id": "TEST-ONLY-CREDENTIAL"}]}]},
                "proxySettings": {"tag": route.RELAY_TAG}},
                {"tag": "direct", "protocol": "freedom", "settings": {}},
                {"tag": route.RELAY_TAG, "protocol": "http", "settings": {
                    "servers": [{"address": "127.0.0.1", "port": 11111}]}}],
            "routing": {"rules": [{"type": "field", "ip": ["geoip:private"],
                                     "outboundTag": "direct"}]},
        }
        self.original = json.dumps(self.config).encode()
        self.config_path.write_bytes(self.original)
        self.config_path.chmod(0o640)

    def invoke(self, probe=True, http=None, restart_error=None, mode="direct"):
        stack = contextlib.ExitStack()
        self.addCleanup(stack.close)
        stack.enter_context(patch.object(sys, "argv", ["route", mode,
            "--config", str(self.config_path), "--backup-dir", str(self.directory / "backups")]))
        stack.enter_context(patch.object(route.os, "geteuid", return_value=0))
        stack.enter_context(patch.object(route.os, "chown"))
        real_temp = tempfile.TemporaryDirectory
        stack.enter_context(patch.object(route.tempfile, "TemporaryDirectory",
            side_effect=lambda **kwargs: real_temp(prefix="probe-", dir=self.directory)))
        stack.enter_context(patch.object(route, "open", create=True,
            side_effect=lambda path, *a, **kw: builtins.open(
                self.directory / "route.lock" if path == "/run/lock/v2ray-11119-route.lock" else path,
                *a, **kw)))
        stack.enter_context(patch.object(route, "service_account", return_value=(0, 0)))
        stack.enter_context(patch.object(route, "command", return_value=
            subprocess.CompletedProcess([], 0, "active\n", "")))
        stack.enter_context(patch.object(route, "probe", return_value=probe))
        stack.enter_context(patch.object(route, "validate"))
        stack.enter_context(patch.object(route, "check_proxy", side_effect=http or [True]))
        restart = stack.enter_context(patch.object(route, "restart", side_effect=restart_error))
        stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        return restart

    def test_failed_candidate_never_writes_or_restarts(self):
        restart = self.invoke(probe=False)
        with self.assertRaisesRegex(RuntimeError, "Candidate route failed"):
            route.main()
        self.assertEqual(self.config_path.read_bytes(), self.original)
        self.assertFalse((self.directory / "backups").exists())
        restart.assert_not_called()

    def test_success_changes_only_detour_and_keeps_private_backup(self):
        restart = self.invoke()
        route.main()
        expected = json.loads(self.original)
        expected["outbounds"][0].pop("proxySettings")
        self.assertEqual(json.loads(self.config_path.read_bytes()), expected)
        self.assertEqual(stat.S_IMODE(self.config_path.stat().st_mode), 0o640)
        backup, = (self.directory / "backups").glob("*.bak")
        self.assertEqual(backup.read_bytes(), self.original)
        self.assertEqual(stat.S_IMODE(backup.stat().st_mode), 0o600)
        restart.assert_called_once()

    def test_failed_production_check_restores_exact_previous_bytes(self):
        restart = self.invoke(http=[False, True])
        with self.assertRaisesRegex(RuntimeError, "Previous config restored"):
            route.main()
        self.assertEqual(self.config_path.read_bytes(), self.original)
        self.assertEqual(restart.call_count, 2)

    def test_failed_restart_restores_previous_config_and_restarts_again(self):
        restart = self.invoke(restart_error=[RuntimeError("synthetic restart failure"), None])
        with self.assertRaisesRegex(RuntimeError, "Previous config restored"):
            route.main()
        self.assertEqual(self.config_path.read_bytes(), self.original)
        self.assertEqual(restart.call_count, 2)

    def test_unchanged_relay_is_idempotent(self):
        restart = self.invoke(mode="relay")
        route.main()
        self.assertEqual(self.config_path.read_bytes(), self.original)
        restart.assert_not_called()

    def test_relay_refuses_to_discard_existing_transport(self):
        self.config["outbounds"][0]["streamSettings"] = {"network": "ws"}
        with self.assertRaisesRegex(RuntimeError, "raw TCP"):
            route.candidate(self.config, "relay", None)


if __name__ == "__main__":
    unittest.main()
