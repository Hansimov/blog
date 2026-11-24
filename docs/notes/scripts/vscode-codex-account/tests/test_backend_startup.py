from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import backend


class BackendStartupTest(unittest.TestCase):
    def test_stdio_handshake_finishes_while_history_is_blocked(self):
        # Use real pipes and child processes for both the original passthrough
        # and the selected-account proxy. All homes and credentials are fixtures.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            shared = root / "shared"
            shared.mkdir()
            (root / "shared-home").write_text(str(shared), encoding="utf-8")
            native = root / "native.py"
            native.write_text(
                "import json, os, sys\n"
                "for line in sys.stdin:\n"
                "    req = json.loads(line)\n"
                "    result = {'method': req['method'], 'home': os.environ['CODEX_HOME']}\n"
                "    print(json.dumps({'id': req['id'], 'result': result}), flush=True)\n",
                encoding="utf-8")
            harness = (
                "import pathlib, sys, threading\n"
                "sys.path.insert(0, sys.argv.pop(1))\n"
                "import backend\n"
                "root = pathlib.Path(sys.argv.pop(1))\n"
                "backend.account.ROOT = root\n"
                "backend.account.ACCOUNTS = root / 'accounts'\n"
                "def blocked(*args):\n"
                "    (root / 'import-started').touch()\n"
                "    threading.Event().wait()\n"
                "backend.history.import_accounts = blocked\n"
                "backend.login_tokens = lambda *_: {'accessToken': 'synthetic', 'chatgptAccountId': 'test'}\n"
                "sys.exit(backend.main())\n")
            request = {"id": 17, "method": "initialize", "params": {"clientInfo": {"name": "test"}}}
            expected = {"id": 17, "result": {"method": "initialize", "home": str(shared)}}
            for slot in ("original", "example"):
                with self.subTest(slot=slot):
                    result = subprocess.run(
                        [sys.executable, "-I", "-c", harness, str(Path(backend.__file__).parent),
                         str(root), sys.executable, slot, "-I", str(native), "app-server"],
                        input=json.dumps(request) + "\n", capture_output=True, text=True,
                        env=dict(os.environ, LOCALAPPDATA=folder, APPDATA=folder), timeout=10)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual([json.loads(line) for line in result.stdout.splitlines()], [expected])
                    self.assertTrue((root / "import-started").is_file())
                    (root / "import-started").unlink()

    def test_failed_optional_import_does_not_write_to_protocol_or_leak_details(self):
        for kind in (OSError, ValueError, sqlite3.OperationalError):
            with self.subTest(kind=kind):
                stdout, stderr = io.StringIO(), io.StringIO()
                with patch.object(backend.history, "import_accounts", side_effect=kind("private detail")), \
                        redirect_stdout(stdout), redirect_stderr(stderr):
                    backend.run_history_import(Path("unused"), lambda home: {})
                self.assertEqual(stdout.getvalue(), "")
                self.assertTrue(stderr.getvalue().strip())
                self.assertNotIn("private detail", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
