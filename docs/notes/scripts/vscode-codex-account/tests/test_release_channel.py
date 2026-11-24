import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import release_channel as channel


class ReleaseChannelTests(unittest.TestCase):
    def test_cross_process_target_and_unmanaged_owner(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.assertEqual(channel.request_release(root, os.getpid(), str(uuid.uuid4())), "unmanaged")
            thread_id = str(uuid.uuid4())
            module = str(Path(channel.__file__).parent)
            script = (
                "import sys,os;sys.path.insert(0,sys.argv[1]);import release_channel as c\n"
                "with c.serve_releases(sys.argv[2], os.getpid(),"
                " lambda thread, deadline: 'busy' if thread==sys.argv[3] else 'not_loaded'):\n"
                " print('ready',flush=True);input()\n"
            )
            proc = subprocess.Popen([sys.executable, "-I", "-c", script, module, temp, thread_id],
                                    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            try:
                self.assertEqual(proc.stdout.readline().strip(), "ready")
                self.assertEqual(channel.request_release(root, proc.pid, thread_id), "busy")
                self.assertEqual(channel.request_release(root, proc.pid, str(uuid.uuid4())), "not_loaded")
                # Even a matching old directory name cannot route to another process.
                stale = channel._mailbox(root, proc.pid).with_name(f"{os.getpid()}-old-generation")
                stale.mkdir()
                self.assertEqual(channel.request_release(root, os.getpid(), thread_id), "unmanaged")
                proc.communicate("\n", timeout=3)
                self.assertEqual(channel.request_release(root, proc.pid, thread_id), "unmanaged")
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.communicate()

    def test_expired_queued_request_is_not_executed(self):
        release_first = threading.Event()
        first_started = threading.Event()
        first, second = str(uuid.uuid4()), str(uuid.uuid4())
        handled = []

        def handle(thread_id, deadline):
            handled.append(thread_id)
            if thread_id == first:
                first_started.set()
                release_first.wait(max(0, deadline - time.monotonic()))
            return "released"

        with tempfile.TemporaryDirectory() as temp, channel.serve_releases(temp, os.getpid(), handle):
            result = []
            client = threading.Thread(target=lambda: result.append(channel.request_release(temp, os.getpid(), first)))
            client.start()
            try:
                self.assertTrue(first_started.wait(2))
                self.assertEqual(channel.request_release(temp, os.getpid(), second, timeout=0.15), "timeout")
            finally:
                release_first.set()
                client.join(timeout=2)
            self.assertEqual(result, ["released"])
            self.assertEqual(handled, [first])
            with self.assertRaises(ValueError):
                channel.request_release(temp, os.getpid(), "../../other")


if __name__ == "__main__":
    unittest.main()
