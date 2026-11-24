import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import unittest


INSTALLER = Path(__file__).resolve().parents[1] / "install-linux.sh"


@unittest.skipUnless(sys.platform.startswith("linux"), "Remote SSH Linux launcher")
class LinuxLauncherTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.bin = self.root / "local bin"
        self.command = self.bin / "vscodex-app-server"
        self.env = {"HOME": str(self.root), "PATH": str(self.bin) + os.pathsep + os.defpath}

    def manage(self, action, **updates):
        return subprocess.run(["bash", str(INSTALLER), action, str(self.bin)],
                              capture_output=True, env={**self.env, **updates})

    def bundle(self, version):
        arch, directory = {"x86_64": ("x64", "linux-x86_64"),
                           "aarch64": ("arm64", "linux-aarch64")}[platform.machine()]
        extension = self.root / "extensions" / f"openai.chatgpt-{version}-linux-{arch}"
        folder = extension / "bin" / directory
        folder.mkdir(parents=True)
        (extension / "package.json").write_text(json.dumps({
            "name": "chatgpt", "publisher": "OpenAI", "version": version}))
        binary = folder / "codex"
        binary.write_text("#!/usr/bin/env python3\nimport json, os, sys\n"
                          "print(json.dumps([sys.argv, os.getenv('wss_proxy'), os.getenv('no_proxy')]))\n")
        binary.chmod(0o700)
        return folder

    def test_uses_appended_bundle_preserves_arguments_and_proxy_on_upgrade(self):
        self.assertEqual(self.manage("install", VSCODEX_LINUX_NO_PROXY="example.test").returncode, 0)
        self.assertEqual(self.manage("install").returncode, 0)
        self.assertEqual(self.manage("check").returncode, 0)
        earlier, current = self.bundle("1.0.0"), self.bundle("2.0.0")
        env = {**self.env, "PATH": os.pathsep.join([self.env["PATH"], str(earlier), str(current)]),
               "HTTPS_PROXY": "http://127.0.0.1:3128", "NO_PROXY": "local.test"}
        args = ["app-server", "value with spaces", "", '"quote"']
        result = subprocess.run([str(self.command), *args], env=env, capture_output=True, check=True)
        argv, proxy, bypass = json.loads(result.stdout)
        self.assertEqual(argv, [str(current / "codex"), *args])
        self.assertEqual(proxy, env["HTTPS_PROXY"])
        self.assertTrue({"example.test", "local.test"} <= set(bypass.split(",")))
        self.assertEqual(self.manage("uninstall").returncode, 0)
        self.assertFalse(self.command.exists())

    def test_rejects_unrelated_runtime_and_preserves_unmanaged_command(self):
        self.assertEqual(self.manage("install").returncode, 0)
        folder = self.bundle("1.0.0")
        env = {**self.env, "PATH": self.env["PATH"] + os.pathsep + str(folder)}
        (folder / "codex").unlink()
        (folder / "codex").symlink_to("/bin/true")
        self.assertNotEqual(subprocess.run([self.command], env=env, capture_output=True).returncode, 0)
        self.assertNotEqual(subprocess.run([self.command], env=self.env, capture_output=True).returncode, 0)
        self.command.write_text("existing user command\n")
        self.assertNotEqual(self.manage("install").returncode, 0)
        self.assertNotEqual(self.manage("uninstall").returncode, 0)
        self.assertEqual(self.command.read_text(), "existing user command\n")


if __name__ == "__main__":
    unittest.main()
