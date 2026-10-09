"""Linux offline tests. All networking, services, and address mutations mocked."""
import contextlib
import copy
import importlib.util
import io
import ipaddress
import json
from pathlib import Path
import stat
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "tailscale_ipv6_repair.py"
spec = importlib.util.spec_from_file_location("ipv6_repair", SOURCE)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

OLD = "2001:db8:1::/64"
GOOD = "2001:db8:2::/64"
GATEWAY = "fe80::1"
IFACE = "eth0"
IDENTITY = {"boot_id": "test-boot", "machine_id": "test-machine"}


def address(value):
    return {"family": "inet6", "scope": "global", "local": value, "prefixlen": 64,
            "dynamic": True, "mngtmpaddr": True, "preferred_life_time": 300,
            "valid_life_time": 600}


def advertisement(prefix=GOOD, preferred=100, flags=0xC0):
    head = struct.pack("!BBHBBHII", 134, 0, 0, 64, 0, 1800, 0, 0)
    option = struct.pack("!BBBBIII", 3, 4, 64, flags, 200, preferred, 0)
    option += ipaddress.ip_network(prefix).network_address.packed
    return head + option


class RAtests(unittest.TestCase):
    def test_extracts_preferred_slaac_prefix(self):
        self.assertEqual(mod.parse_ra(advertisement()), {GOOD})

    def test_zero_preferred_is_not_a_healthy_prefix(self):
        with self.assertRaises(mod.Refuse):
            mod.parse_ra(advertisement(preferred=0))

    def test_non_autonomous_prefix_is_not_eligible(self):
        with self.assertRaises(mod.Refuse):
            mod.parse_ra(advertisement(flags=0x80))

    def test_invalid_lengths_fail_closed(self):
        for packet in (b"", advertisement()[:-1], advertisement()[:16] + b"\x03\x00"):
            with self.subTest(packet_length=len(packet)), self.assertRaises(mod.Refuse):
                mod.parse_ra(packet)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.old = address("2001:db8:1::123")
        self.good = address("2001:db8:2::123")
        self.evidence = ([self.old, self.good], GATEWAY, OLD, {GOOD},
                         {OLD: "P1", GOOD: "P2"}, {OLD: [False, False], GOOD: [True, True]})
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.ra = self.stack.enter_context(patch.object(mod, "advertised_prefixes", return_value={GOOD}))
        self.stack.enter_context(patch.object(mod, "addresses", return_value=[self.old, self.good]))
        self.route = self.stack.enter_context(patch.object(mod, "route", return_value=(GATEWAY, self.old["local"])))
        self.refresh = self.stack.enter_context(patch.object(mod, "refresh_nm"))

    def invoke(self):
        mod.repair(IFACE, "P1", Path("/unused"), self.evidence)

    def test_proven_stale_default_can_refresh(self):
        self.invoke()
        self.refresh.assert_called_once_with(IFACE, OLD, {GOOD}, Path("/unused"))

    def test_one_successful_old_probe_blocks_repair(self):
        self.evidence[5][OLD] = [False, True]
        with self.assertRaises(mod.Refuse): self.invoke()
        self.refresh.assert_not_called()

    def test_missing_healthy_alternative_blocks_repair(self):
        self.evidence[5][GOOD] = [True, False]
        with self.assertRaises(mod.Refuse): self.invoke()
        self.refresh.assert_not_called()

    def test_still_advertised_old_prefix_blocks_repair(self):
        self.evidence[3].add(OLD)
        with self.assertRaises(mod.Refuse): self.invoke()
        self.refresh.assert_not_called()

    def test_second_ra_change_blocks_repair(self):
        self.ra.return_value = {GOOD, OLD}
        with self.assertRaises(mod.Refuse): self.invoke()
        self.refresh.assert_not_called()

    def test_source_change_during_probe_blocks_repair(self):
        self.route.return_value = (GATEWAY, self.good["local"])
        with self.assertRaises(mod.Refuse): self.invoke()
        self.refresh.assert_not_called()

    def test_static_address_is_never_changed(self):
        self.old["dynamic"] = False
        with self.assertRaises(mod.Refuse): self.invoke()
        self.refresh.assert_not_called()

    def test_healthy_maintenance_is_a_noop_without_netcheck(self):
        self.route.return_value = (GATEWAY, self.good["local"])
        with patch.object(mod, "netcheck") as check:
            self.assertIsNone(mod.inspect(IFACE, maintain=True))
        check.assert_not_called()
        self.refresh.assert_not_called()

    def test_diagnostic_output_contains_labels_not_addresses(self):
        output = io.StringIO()
        with patch.object(mod, "netcheck", side_effect=lambda a: a == self.good["local"]), \
                contextlib.redirect_stdout(output):
            mod.inspect(IFACE)
        self.assertIn("P1:", output.getvalue())
        self.assertNotIn("2001:", output.getvalue())
        self.refresh.assert_not_called()


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.cmd = self.stack.enter_context(patch.object(mod, "command", return_value=
            subprocess.CompletedProcess([], 0, "auto\n", "")))
        self.method = self.stack.enter_context(patch.object(mod, "nm_method"))
        self.backup = self.stack.enter_context(patch.object(mod, "save_backup"))
        self.stack.enter_context(patch.object(mod, "addresses", return_value=[address("2001:db8:2::123")]))
        self.v4 = self.stack.enter_context(patch.object(mod, "ipv4_snapshot", return_value=([("192.0.2.2", 24)], ["test-route"])))
        self.check = self.stack.enter_context(patch.object(mod, "netcheck", return_value=True))
        self.stack.enter_context(patch.object(mod, "route", return_value=(GATEWAY, "2001:db8:2::123")))

    def invoke(self):
        mod.refresh_nm(IFACE, OLD, {GOOD}, Path("/unused"))

    def test_success_resumes_auto_and_cancels_recovery(self):
        self.invoke()
        self.assertEqual([c.args[1] for c in self.method.call_args_list], ["disabled", "auto"])
        self.assertEqual(self.cmd.call_args_list[-1].args[0][:2], ["systemctl", "stop"])
        self.backup.assert_called_once()

    def test_failure_to_disable_still_restores_auto(self):
        self.method.side_effect = [mod.Refuse("synthetic failure"), None]
        with self.assertRaisesRegex(mod.Refuse, "recovery remains armed"):
            self.invoke()
        self.assertEqual([c.args[1] for c in self.method.call_args_list], ["disabled", "auto"])
        self.assertFalse(any(c.args[0][0] == "systemctl" for c in self.cmd.call_args_list))

    def test_interrupt_still_restores_auto(self):
        self.method.side_effect = [KeyboardInterrupt(), None]
        with self.assertRaises(mod.Refuse): self.invoke()
        self.assertEqual(self.method.call_count, 2)

    def test_failed_validation_keeps_independent_recovery(self):
        self.check.return_value = False
        with self.assertRaises(mod.Refuse): self.invoke()
        self.assertFalse(any(c.args[0][0] == "systemctl" for c in self.cmd.call_args_list))

    def test_ipv4_change_is_detected(self):
        self.v4.side_effect = [(["before"], ["route"]), (["changed"], ["route"])]
        with self.assertRaises(mod.Refuse): self.invoke()
        self.check.assert_not_called()

    def test_missing_ipv4_management_blocks_refresh(self):
        self.v4.return_value = ([], [])
        with self.assertRaises(mod.Refuse): self.invoke()
        self.method.assert_not_called()

    def test_failure_to_arm_recovery_prevents_mutation(self):
        self.cmd.side_effect = [subprocess.CompletedProcess([], 0, "profile\n"),
                               subprocess.CompletedProcess([], 0, "auto\n"),
                               subprocess.CompletedProcess([], 1, "", "private")]
        with self.assertRaises(mod.Refuse): self.invoke()
        self.method.assert_not_called()


class BackupTests(unittest.TestCase):
    def test_backup_is_private_and_restore_does_not_recreate_addresses(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(mod, "identity", return_value=IDENTITY), \
                contextlib.redirect_stdout(io.StringIO()):
            path, data = mod.save_backup(Path(directory), IFACE, [address("2001:db8:1::123")], "test-profile")
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(json.loads(path.read_text()), data)
            with patch.object(mod, "nm_method") as method:
                mod.restore(IFACE, data)
            method.assert_called_once_with(IFACE, "auto")

    def test_other_boot_backup_cannot_restore(self):
        data = dict(IDENTITY, version=2, interface=IFACE, ipv6_method="auto")
        with patch.object(mod, "identity", return_value=dict(IDENTITY, boot_id="another")), \
                patch.object(mod, "nm_method") as method:
            with self.assertRaises(mod.Refuse): mod.restore(IFACE, data)
        method.assert_not_called()

    def test_netcheck_command_failure_is_not_dead_prefix_evidence(self):
        with patch.object(mod.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "private")):
            with self.assertRaises(mod.Refuse): mod.netcheck("2001:db8:1::123")

    def test_netcheck_removes_proxy_environment(self):
        with patch.dict(mod.os.environ, {"HTTP_PROXY": "http://example.invalid", "https_proxy": "private"}), \
                patch.object(mod.subprocess, "run", return_value=subprocess.CompletedProcess([], 0,
                    '{"IPv6": true, "UDP": true}', "")) as run:
            self.assertTrue(mod.netcheck("2001:db8:2::123"))
        self.assertFalse(any(k.lower() in ("http_proxy", "https_proxy", "all_proxy")
                             for k in run.call_args.kwargs["env"]))


if __name__ == "__main__":
    unittest.main()
