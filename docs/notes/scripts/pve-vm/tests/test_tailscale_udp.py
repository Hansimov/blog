"""Offline tests: no real STUN, socket binding, or service changes."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "tailscale_udp_probe.py"
spec = importlib.util.spec_from_file_location("udp_probe", SOURCE)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.sock = self.stack.enter_context(patch.object(mod.socket, "socket"))
        self.run = self.stack.enter_context(patch.object(mod.subprocess, "run"))

    def report(self, value):
        self.run.return_value = subprocess.CompletedProcess([], 0, json.dumps(value), "private log")

    def test_success_is_allowlisted_and_does_not_print_endpoint(self):
        self.report({"UDP": True, "IPv4": True, "GlobalV4": "8.8.8.8:12345", "Secret": "private"})
        result = mod.probe(41643)
        self.assertEqual(result["status"], "stun_ok")
        self.assertNotIn("8.8.8.8", json.dumps(result))
        self.assertNotIn("private", json.dumps(result))
        argv = self.run.call_args.args[0]
        self.assertEqual(argv[-2:], ["--bind-port", "41643"])

    def test_ipv4_flag_without_udp_reply_is_not_success(self):
        self.report({"UDP": False, "IPv4": True, "GlobalV4": ""})
        self.assertEqual(mod.probe(0)["status"], "no_public_ipv4_stun")

    def test_private_or_invalid_endpoint_is_not_public(self):
        for endpoint in ("192.0.2.1:12345", "192.168.1.1:12345", "[2001:db8::1]:12345",
                         "8.8.8.8:70000", "8.8.8.8:0", "malformed", None, {}):
            with self.subTest(endpoint=endpoint):
                self.assertFalse(mod.public_ipv4_endpoint(endpoint))

    def test_busy_port_is_not_probed_or_released(self):
        self.sock.return_value.__enter__.return_value.bind.side_effect = OSError("private address")
        self.assertEqual(mod.probe(41641)["status"], "port_unavailable")
        self.run.assert_not_called()

    def test_failure_messages_never_include_raw_output(self):
        self.run.return_value = subprocess.CompletedProcess([], 1, "private address", "secret")
        self.assertEqual(mod.probe(0), {"source_port": 0, "status": "command_failed"})
        self.run.side_effect = subprocess.TimeoutExpired(["private address"], 15, output="secret")
        self.assertEqual(mod.probe(0), {"source_port": 0, "status": "command_timeout"})

    def test_invalid_report_does_not_raise(self):
        for value in ([], None, {"UDP": "true"}, {}):
            self.report(value)
            self.assertEqual(mod.probe(0)["status"], "invalid_report")
        self.run.return_value = subprocess.CompletedProcess([], 0, "invalid json private", "")
        self.assertEqual(mod.probe(0)["status"], "probe_error")

    def test_cli_interleaves_rounds_and_deduplicates_ports(self):
        with patch.object(mod, "probe", return_value={"status": "stun_ok"}) as probe:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(mod.main(["--ports", "41641", "41643", "41641"]), 0)
            self.assertEqual([c.args[0] for c in probe.call_args_list], [41641, 41643, 41641, 41643])
            self.assertEqual(len(output.getvalue().splitlines()), 4)

    def test_port_input_bounds(self):
        for value in ("-1", "1", "65536", "not-a-port"):
            with self.assertRaises(mod.argparse.ArgumentTypeError):
                mod.port_number(value)
        self.assertEqual(mod.port_number("0"), 0)
        self.assertEqual(mod.port_number("41642"), 41642)


if __name__ == "__main__":
    unittest.main()
