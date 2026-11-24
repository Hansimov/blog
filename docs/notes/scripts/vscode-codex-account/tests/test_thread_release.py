import json
from pathlib import Path
import queue
import sys
import threading
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from thread_control import ThreadControl


def line(message):
    return json.dumps(message).encode() + b"\n"


class NativeInput(queue.Queue):
    def write(self, data):
        self.put(data)

    def flush(self):
        pass


class ThreadReleaseTest(unittest.TestCase):
    def setUp(self):
        self.native = NativeInput()
        self.control = ThreadControl(self.native)

    def expecting(self, method):
        request = json.loads(self.native.get(timeout=2))
        self.assertEqual(request["method"], method)
        self.assertEqual(request["params"]["threadId"], "target")
        return request

    def start_release(self, timeout=3):
        finished = queue.Queue()

        def release():
            try:
                finished.put(self.control.release("target", time.monotonic() + timeout))
            except Exception as exc:
                finished.put(exc)

        threading.Thread(target=release, daemon=True).start()
        return finished, self.expecting("thread/read")

    def read_reply(self, request, status):
        result = {"thread": {"id": "target", "status": status}}
        self.assertTrue(self.control.from_native(line({"id": request["id"], "result": result})))

    def test_malformed_or_busy_status_never_unsubscribes(self):
        for status in (None, "invalid", {}, {"type": "unknown"}, {"type": "active", "activeFlags": []},
                       {"type": "active", "activeFlags": ["waitingOnApproval"]},
                       {"type": "idle", "activeFlags": ["waitingOnUserInput"]}):
            with self.subTest(status=status):
                finished, request = self.start_release()
                self.read_reply(request, status)
                self.assertIn(finished.get(timeout=2), ("busy", "error"))
                self.assertTrue(self.native.empty())
        for malformed in ({"result": {}}, {"result": {"thread": "bad"}},
                          {"result": {"thread": {"id": "other", "status": {"type": "idle"}}}},
                          {"error": {"code": -1, "message": "simulated native error"}}):
            with self.subTest(reply=malformed):
                finished, request = self.start_release()
                self.assertTrue(self.control.from_native(line({"id": request["id"], **malformed})))
                self.assertEqual(finished.get(timeout=2), "error")
                self.assertTrue(self.native.empty())

    def test_pending_turn_start_and_concurrent_turn_start_win_over_release(self):
        start = line({"id": "start", "method": "turn/start", "params": {"threadId": "target"}})
        done = line({"id": "start", "result": {}})
        self.assertIsNone(self.control.from_editor(start))
        self.assertEqual(self.native.get(timeout=2), start)
        self.assertEqual(self.control.release("target", time.monotonic() + 1), "busy")
        self.assertFalse(self.control.from_native(done))
        finished, request = self.start_release()
        self.assertIsNone(self.control.from_editor(start))
        self.assertEqual(self.native.get(timeout=2), start)
        self.assertFalse(self.control.from_native(done))
        self.read_reply(request, {"type": "idle"})
        self.assertEqual(finished.get(timeout=2), "busy")
        self.assertTrue(self.native.empty())

    def test_concurrent_native_activity_wins_over_stale_idle_reply(self):
        for notice in (
            {"method": "turn/started", "params": {"threadId": "target", "turn": {"id": "turn"}}},
            {"method": "thread/status/changed", "params": {
                "threadId": "target", "status": {"type": "active", "activeFlags": []}}},
        ):
            with self.subTest(method=notice["method"]):
                finished, request = self.start_release()
                self.assertFalse(self.control.from_native(line(notice)))
                self.read_reply(request, {"type": "idle"})
                self.assertEqual(finished.get(timeout=2), "busy")
                self.assertTrue(self.native.empty())

    def test_unsubscribe_preserves_other_threads_and_forwards_official_notifications(self):
        finished, request = self.start_release()
        self.read_reply(request, {"type": "idle"})
        unsubscribe = self.expecting("thread/unsubscribe")
        race = self.control.from_editor(line({"id": "race", "method": "turn/start", "params": {"threadId": "target"}}))
        self.assertEqual(race["id"], "race")
        self.assertIn("error", race)
        other = line({"id": 9, "method": "turn/start", "params": {"threadId": "other"}})
        self.assertIsNone(self.control.from_editor(other))
        self.assertEqual(self.native.get(timeout=2), other)
        for message in ({"id": 9, "result": {"turn": {"id": "other-turn"}}},
                        {"method": "turn/started", "params": {"threadId": "other"}},
                        {"method": "thread/closed", "params": {"threadId": "target"}}):
            self.assertFalse(self.control.from_native(line(message)))
        self.assertTrue(self.control.from_native(line({"id": unsubscribe["id"], "result": {"status": "unsubscribed"}})))
        self.assertEqual(finished.get(timeout=2), "released")
        self.assertTrue(self.native.empty())

    def test_timed_out_private_reply_is_not_forwarded_or_applied(self):
        expired, previous = self.start_release(timeout=0.25)
        self.assertEqual(expired.get(timeout=2), "timeout")
        current, request = self.start_release()
        self.read_reply(previous, {"type": "idle"})
        self.assertTrue(self.native.empty())
        self.read_reply(request, {"type": "notLoaded"})
        self.assertEqual(current.get(timeout=2), "not_loaded")
        self.read_reply(previous, {"type": "idle"})
        self.assertTrue(self.native.empty())


if __name__ == "__main__":
    unittest.main()
