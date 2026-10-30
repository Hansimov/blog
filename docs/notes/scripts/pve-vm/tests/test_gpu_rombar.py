"""Offline Bash policy tests. Never run qm, QEMU, VFIO, or real PCI checks.

Run on Linux/WSL: python3 -m unittest discover -s tests -p 'test_gpu_rombar.py'
An in-memory runner may supply SCRIPT_SOURCES to test without installing files.
"""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


if "SCRIPT_SOURCES" not in globals():
    root = Path(__file__).resolve().parents[2]
    SCRIPT_SOURCES = {
        name: (root / directory / name).read_text(encoding="utf-8")
        for directory, name in (
            ("pve-vm", "qm_gpus.sh"),
            ("pve-vm", "start_vm101.sh"),
            ("pve-ubuntu", "pve_ubuntu.sh"),
        )
    }

BASH = os.environ.get("PVE_TEST_BASH") or shutil.which("bash")
if os.name == "nt" and not os.environ.get("PVE_TEST_BASH") and shutil.which("git"):
    git_bash = Path(shutil.which("git")).resolve().parents[1] / "bin" / "bash.exe"
    if git_bash.is_file():
        BASH = str(git_bash)


def function(script, name):
    match = re.search(rf"(?ms)^{re.escape(name)}\(\) \{{\n.*?^\}}", SCRIPT_SOURCES[script])
    if match is None:
        raise AssertionError(f"Function not found: {script}:{name}")
    return match.group(0) + "\n"


@unittest.skipUnless(BASH, "Bash is required; run on Linux/WSL")
class RomPolicyTests(unittest.TestCase):
    def shell(self, body, **env):
        return subprocess.run(
            [BASH, "--noprofile", "--norc", "-s"],
            input="set -Eeuo pipefail\n" + body,
            text=True, capture_output=True, timeout=10,
            env={**os.environ, **env},
        )

    def generated(self, value, installer=False, bdf="0000:01:00"):
        if installer:
            body = function("pve_ubuntu.sh", "gpu_pci_spec") + 'gpu_pci_spec "$VALUE"\n'
        else:
            body = function("qm_gpus.sh", "join_csv") + function("qm_gpus.sh", "value_for_gpu")
            body += 'declare -A current_by_bdf=()\n'
            body += '[[ -z "$VALUE" ]] || current_by_bdf["$BDF"]="$VALUE"\n'
            body += 'value_for_gpu "$BDF"\n'
        result = self.shell(body, VALUE=value, BDF=bdf)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def test_new_card_and_changed_slot_always_disable_rom(self):
        for bdf in ("0000:01:00", "0000:fe:00"):
            with self.subTest(bdf=bdf):
                self.assertEqual(self.generated("", bdf=bdf), f"{bdf},pcie=1,rombar=0")

    def test_old_and_conflicting_values_are_normalized_in_both_scripts(self):
        for installer in (False, True):
            for suffix in ("", ",rombar=1", ",rombar=on", ",rombar=0", ",rombar=off",
                           ",rombar=1,rombar=0", ",rombar=0,rombar=0"):
                with self.subTest(installer=installer, suffix=suffix):
                    actual = self.generated("0000:01:00,pcie=1" + suffix, installer)
                    self.assertEqual(actual, "0000:01:00,pcie=1,rombar=0")

    def test_unrelated_options_and_function_address_are_preserved(self):
        value = "0000:01:00.0,rombar=1,romfile=compute.rom,x-vga=0"
        expected = "0000:01:00.0,romfile=compute.rom,x-vga=0,pcie=1,rombar=0"
        for installer in (False, True):
            self.assertEqual(self.generated(value, installer), expected)

    def test_repeated_normalization_is_idempotent(self):
        for installer in (False, True):
            first = self.generated("0000:01:00,rombar=1", installer)
            self.assertEqual(self.generated(first, installer), first)

    def verify_config(self, value):
        body = function("qm_gpus.sh", "normalize_bdf")
        body += function("qm_gpus.sh", "verify_contiguous_config")
        body += '''
VMID=101
selected_gpus=(0000:01:00)
qm() { printf 'hostpci0: %s\n' "$VALUE"; }
verify_contiguous_config
'''
        return self.shell(body, VALUE=value)

    @unittest.skipIf(os.name == "nt", "Bash /dev/fd process substitution requires Linux/WSL")
    def test_contiguous_legacy_config_still_requires_migration(self):
        for suffix in ("", ",rombar=1", ",rombar=0,rombar=0", ",rombar=0,rombar=1"):
            with self.subTest(suffix=suffix):
                self.assertNotEqual(self.verify_config("0000:01:00,pcie=1" + suffix).returncode, 0)

    @unittest.skipIf(os.name == "nt", "Bash /dev/fd process substitution requires Linux/WSL")
    def test_config_verification_accepts_reordered_options(self):
        for value in ("0000:01:00,pcie=1,rombar=0", "0000:01:00,rombar=0,pcie=1"):
            result = self.verify_config(value)
            self.assertEqual(result.returncode, 0, result.stderr)

    def startup_guard(self, config, command="verify_gpu_rom_policy", config_rc="0"):
        body = function("start_vm101.sh", "verify_gpu_rom_policy")
        body += function("start_vm101.sh", "production_start")
        body += '''
VMID=101
QM_TIMEOUT=1
timeout() { shift; "$@"; }
qm() {
  [[ "$1" == config ]] || { echo unexpected-qm-call >&2; return 99; }
  printf '%s\n' "$MOCK_CONFIG"
  return "$CONFIG_RC"
}
die() { printf '%s\n' "$*" >&2; exit 1; }
'''
        return self.shell(body + command + "\n", MOCK_CONFIG=config, CONFIG_RC=config_rc)

    def test_startup_guard_rejects_unsafe_or_unreadable_config(self):
        for value in ("0000:01:00,pcie=1", "0000:01:00,rombar=1",
                      "0000:01:00,rombar=0,rombar=1", "0000:01:00,rombar=0,rombar=0"):
            with self.subTest(value=value):
                result = self.startup_guard("hostpci0: " + value, "production_start cached 1")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("refusing to start", result.stderr)
                self.assertNotIn("unexpected-qm-call", result.stderr)
        self.assertNotEqual(self.startup_guard("", config_rc="1").returncode, 0)

    def test_startup_guard_checks_every_entry(self):
        good = "hostpci0: 0000:01:00,rombar=0\nhostpci1: 0000:02:00,rombar=0"
        self.assertEqual(self.startup_guard(good).returncode, 0)
        self.assertNotEqual(self.startup_guard(good.replace("02:00,rombar=0", "02:00")).returncode, 0)
        self.assertEqual(self.startup_guard("memory: 1024").returncode, 0)

    def test_installer_start_only_path_cannot_bypass_policy(self):
        body = function("pve_ubuntu.sh", "start_vm")
        # Do not consult a real host's reboot flag during this offline test.
        body = body.replace("[[ -f /run/pve_ubuntu_reboot_required ]]", "false")
        body += '''
yaml_get() { printf '101\n'; }
log() { printf '%s\n' "$*"; }
qm() {
  case "$1" in
    status) echo 'status: stopped' ;;
    config) printf '%s\n' "$MOCK_CONFIG" ;;
    start) echo mock-start ;;
    *) return 99 ;;
  esac
}
start_vm
'''
        for config, accepted in (("hostpci0: 0000:01:00,rombar=0", True),
                                 ("hostpci0: 0000:01:00,rombar=1", False),
                                 ("hostpci0: 0000:01:00", False)):
            result = self.shell(body, MOCK_CONFIG=config)
            self.assertEqual(result.returncode == 0, accepted, result.stderr)
            self.assertEqual("mock-start" in result.stdout, accepted)

    @unittest.skipIf(os.name == "nt", "Fake PCI directory names require Linux/WSL")
    def test_probe_command_disables_rom_for_every_function(self):
        with tempfile.TemporaryDirectory(prefix="gpu-rombar-test-") as tmp:
            root = Path(tmp)
            for bdf in ("0000:01:00.0", "0000:01:00.1", "0000:02:00.0"):
                (root / bdf).mkdir()
            body = function("qm_gpus.sh", "vfio_probe_subset")
            body = body.replace("/sys/bus/pci/devices/", "${FAKE_PCI}/")
            body += '''
VMID=101
vfio_probe_count=0
MAX_VFIO_PROBES=20
VFIO_PROBE_SECONDS=5
PROBE_DIR="$FAKE_PCI"
QEMU_BIN=fake_qemu
log() { :; }
warn() { printf '%s\n' "$*" >&2; }
die() { exit 99; }
gpu_is_healthy() { return 0; }
fake_qemu() { printf '%s\n' "$@" > "$CAPTURE"; return 124; }
timeout() { shift 4; "$@"; }
vfio_probe_subset test 0000:01:00 0000:02:00
'''
            capture = root / "argv.txt"
            result = self.shell(body, FAKE_PCI=root.as_posix(), CAPTURE=capture.as_posix())
            self.assertEqual(result.returncode, 0, result.stderr)
            argv = capture.read_text().splitlines()
            devices = [x for x in argv if x.startswith("vfio-pci,")]
            self.assertEqual(len(devices), 3)
            self.assertTrue(all(x.split(",").count("rombar=0") == 1 for x in devices))


if __name__ == "__main__":
    unittest.main()
