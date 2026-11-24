import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "nt", "Windows installer and launcher")
class RemoteSshWindowsTest(unittest.TestCase):
    def test_short_command_keeps_windows_account_backend_and_rejects_conflicts(self):
        sys.path.insert(0, str(SOURCE))
        self.addCleanup(sys.path.remove, str(SOURCE))
        import account

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            roaming = root / "Roaming"
            local = root / "Local"
            bin_dir = roaming / "npm"
            bin_dir.mkdir(parents=True)
            system = Path(os.environ["SystemRoot"]) / "System32"
            ps = system / "WindowsPowerShell/v1.0/powershell.exe"
            store = local / "vscode-codex-account"
            settings = roaming / "Code/User/settings.json"
            settings.parent.mkdir(parents=True)
            settings.write_text('{"editor.fontSize": 12}', encoding="utf-8")
            home = root / "home"
            # A fresh PATH with our fixture npm directory prevents any user PATH registry edit.
            env = dict(os.environ, APPDATA=str(roaming), LOCALAPPDATA=str(local), CODEX_HOME=str(home))
            env["PATH"] = os.pathsep.join(map(str, (bin_dir, Path(sys.executable).parent, system, ps.parent)))
            install = [str(ps), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SOURCE / "install.ps1")]

            cmd = bin_dir / "vscodex-app-server.exe"
            cmd.write_bytes(b"unrelated executable")
            result = subprocess.run([*install, "-RemoteSsh"], env=env, capture_output=True, timeout=45)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(cmd.read_bytes(), b"unrelated executable")
            self.assertNotIn("chatgpt.cliExecutable", json.loads(settings.read_bytes()))
            cmd.unlink()

            for args in ([*install, "-RemoteSsh"], install):
                result = subprocess.run(args, env=env, capture_output=True, timeout=45)
                self.assertEqual(result.returncode, 0, result.stderr)
                config = json.loads(settings.read_bytes())
                self.assertEqual(config["chatgpt.cliExecutable"], "vscodex-app-server")
                self.assertEqual(config["editor.fontSize"], 12)

            with patch.object(account, "ROOT", store):
                target = account.installed_launcher(config)
                self.assertEqual(target, store / (store / "path-launcher-target").read_text(encoding="utf-8"))
                self.assertEqual(account.installed_launcher({account.EXECUTABLE: str(target)}), target)

            bundled = root / "openai.chatgpt-1.0.0-win32-x64/bin/windows-x86_64/codex.exe"
            bundled.parent.mkdir(parents=True)
            bundled.touch()
            (bundled.parents[2] / "package.json").write_text("{}", encoding="utf-8")
            env["PATH"] += os.pathsep + str(bundled.parent)
            env["CODEX_INTERNAL_ORIGINATOR_OVERRIDE"] = "codex_vscode"
            shell_cmd = [str(system / "cmd.exe"), "/d", "/c", "vscodex-app-server"]
            result = subprocess.run([*shell_cmd, "--vscodex-bundled-path"], env=env,
                                    capture_output=True, check=True, timeout=10)
            self.assertEqual(Path(result.stdout.decode("utf-8").strip()), bundled)

            # Exercise the stdio app-server entry point with an isolated stand-in for the broker.
            (store / "backend.py").write_text(
                "import sys\ngot = sys.stdin.buffer.read()\nsys.stdout.buffer.write(got)\nsys.exit(3)\n",
                encoding="utf-8")
            message = b'{"id":1,"method":"initialize"}\n'
            result = subprocess.run([*shell_cmd, "app-server"], input=message, env=env,
                                    capture_output=True, timeout=10)
            self.assertEqual(result.stdout, message)
            self.assertEqual(result.returncode, 3)

            (store / "path-launcher-target").write_text("../foreign.exe", encoding="utf-8")
            with patch.object(account, "ROOT", store), self.assertRaises(ValueError):
                account.installed_launcher(config)
            result = subprocess.run([*shell_cmd, "--vscodex-bundled-path"], env=env,
                                    capture_output=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
