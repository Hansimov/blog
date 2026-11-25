"""The A/B comparison must still force a direct route after production switches to relay."""
from copy import deepcopy
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import v2ray_windows_diagnose as diag


class OutboundsTests(unittest.TestCase):
    def test_compare_same_final_from_already_relayed_config(self):
        original = {
            "protocol": "vmess",
            "settings": {"vnext": [{"address": "203.0.113.1", "port": 443,
                                    "users": [{"id": "fixture"}]}]},
            "proxySettings": {"tag": "production-relay"},
        }
        before = deepcopy(original)
        with patch.object(diag, "measure_direct") as measure:
            with diag.outbounds_for("direct", original) as (direct, _):
                target, = direct
                self.assertNotIn("proxySettings", target)
                local = target["settings"]["vnext"][0]
                self.assertEqual(local["address"], "127.0.0.1")
                self.assertEqual(local["users"], original["settings"]["vnext"][0]["users"])
            self.assertEqual(measure.call_args.args[1], ("203.0.113.1", 443))
        with diag.outbounds_for("relay", original) as (relay, _):
            target, via = relay
            self.assertEqual(target["settings"], original["settings"])
            self.assertEqual(target["proxySettings"]["tag"], via["tag"])
            self.assertEqual(via["settings"]["servers"], [{"address": "127.0.0.1", "port": 11111}])
        self.assertEqual(original, before)

    def test_early_http_200_does_not_pass_an_incomplete_upload(self):
        payload = b"example"
        for reported, expected in [(2, False), (len(payload), True)]:
            with self.subTest(reported=reported):
                timing = f"200 200 0.2 0.3 0.4 {reported}".encode()
                result = subprocess.CompletedProcess([], 0, timing)
                with patch.object(diag.subprocess, "run", return_value=result), patch("builtins.print"):
                    self.assertEqual(diag.upload(11119, payload, 5), expected)

    def test_private_output_from_curl_is_not_printed(self):
        result = subprocess.CompletedProcess([], 1, b"200 200 sensitive-value 0.3 0.4 7", b"sensitive-error")
        output = StringIO()
        with patch.object(diag.subprocess, "run", return_value=result), redirect_stdout(output):
            with self.assertRaises(diag.ProbeError) as failure:
                diag.upload(11119, b"example", 5)
        self.assertNotIn("sensitive", str(failure.exception) + output.getvalue())

    def test_command_line_and_process_errors_hide_private_values(self):
        private = "sensitive-test-value"
        output = StringIO()
        with patch.object(sys, "argv", ["tool", "--dir", ".", "--rounds", private]), redirect_stderr(output):
            with self.assertRaises(SystemExit):
                diag.run_cli()
        error = subprocess.CalledProcessError(1, [private], stderr=private)
        with patch.object(diag, "main", side_effect=error), redirect_stderr(output):
            self.assertEqual(diag.run_cli(), 1)
        self.assertNotIn(private, output.getvalue())


if __name__ == "__main__":
    unittest.main()
