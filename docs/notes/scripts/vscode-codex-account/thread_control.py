"""Release one idle thread over the owning window's existing app-server connection."""
import json
import threading
import time
import uuid


class ThreadControl:
    def __init__(self, stdin):
        self.stdin = stdin
        self.lock = threading.Lock()
        self.pending = {}  # Editor request ID -> thread it can act on.
        self.target = None
        self.interrupted = False
        self.unsubscribing = False
        self.id_prefix = "vscodex-release-" + uuid.uuid4().hex + ":"
        self.reply_id = None
        self.reply = None
        self.ready = threading.Event()

    def write(self, line):
        with self.lock:
            self.stdin.write(line)
            self.stdin.flush()

    def from_editor(self, line):
        """Return a local error only for a request racing this exact unsubscribe."""
        try:
            msg = json.loads(line)
        except ValueError:
            msg = None
        with self.lock:
            if isinstance(msg, dict) and "id" in msg and "method" in msg:
                params = msg.get("params")
                tid = params.get("threadId") if isinstance(params, dict) else None
                if isinstance(tid, str) and msg["method"] not in ("thread/read", "thread/turns/list"):
                    if tid == self.target:
                        if self.unsubscribing:
                            return {"id": msg["id"], "error": {"code": -32000,
                                    "message": "Thread is being released. Retry in the destination window."}}
                        self.interrupted = True
                    self.pending[msg["id"]] = tid
            self.stdin.write(line)
            self.stdin.flush()

    def from_native(self, line):
        """Consume private replies; leave native notifications on the editor stream."""
        # Native success replies put the ID before the result. A resume can carry
        # megabytes of history that the bridge only needs to forward, byte for byte.
        if (self.pending and self.target is None and len(line) >= 65536
                and line.startswith(b'{"id":') and line.endswith((b"}\n", b"}\r\n"))):
            end = line.find(b',"result":', 6, 512)
            if end >= 0:
                try:
                    rid = json.loads(line[6:end])  # Decode escaped/UTF-8 string IDs exactly as in the request.
                except ValueError:
                    rid = None
                if type(rid) in (int, str) and not (isinstance(rid, str) and rid.startswith(self.id_prefix)):
                    with self.lock:
                        if self.target is None and rid in self.pending:
                            del self.pending[rid]
                            return False
        if not self.pending and self.target is None and self.id_prefix.encode() not in line:
            return False
        try:
            msg = json.loads(line)
        except ValueError:
            return False
        if not isinstance(msg, dict):
            return False
        with self.lock:
            if "method" in msg:
                params = msg.get("params") or {}
                if (self.target and isinstance(params, dict) and params.get("threadId") == self.target
                        and msg["method"] in ("turn/started", "thread/status/changed")):
                    self.interrupted = True
                return False
            rid = msg.get("id")
            if isinstance(rid, str) and rid.startswith(self.id_prefix):
                if rid == self.reply_id:
                    self.reply = msg.get("result")
                    self.ready.set()
                return True  # Also consume late replies after a timeout.
            self.pending.pop(rid, None)
            return False

    def _request(self, method, params, deadline):
        with self.lock:
            if time.monotonic() >= deadline:
                raise TimeoutError()
            if self.interrupted or self.target in self.pending.values():
                return "busy", None
            self.unsubscribing = method == "thread/unsubscribe"
            self.ready.clear()
            self.reply = None
            self.reply_id = self.id_prefix + uuid.uuid4().hex
            message = {"id": self.reply_id, "method": method, "params": params}
            self.stdin.write(json.dumps(message).encode() + b"\n")
            self.stdin.flush()
        if not self.ready.wait(max(0, deadline - time.monotonic())):
            raise TimeoutError()
        return ("ok", self.reply) if isinstance(self.reply, dict) else ("error", None)

    def release(self, thread_id, deadline):
        with self.lock:
            if self.target is not None or thread_id in self.pending.values():
                return "busy"
            self.target = thread_id
            self.interrupted = self.unsubscribing = False
        try:
            status, reply = self._request("thread/read", {"threadId": thread_id, "includeTurns": False}, deadline)
            if status != "ok":
                return status
            thread = reply.get("thread")
            if not isinstance(thread, dict) or thread.get("id") != thread_id:
                return "error"
            runtime = thread.get("status")
            if not isinstance(runtime, dict):
                return "error"
            state = runtime.get("type")
            if state == "notLoaded":
                return "not_loaded"
            if state != "idle" or runtime.get("activeFlags"):
                return "busy"
            status, reply = self._request("thread/unsubscribe", {"threadId": thread_id}, deadline)
            if status != "ok":
                return status
            return {"unsubscribed": "released", "notSubscribed": "not_loaded",
                    "notLoaded": "not_loaded"}.get(reply.get("status"), "error")
        except TimeoutError:
            return "timeout"
        except (OSError, ValueError):
            return "error"
        finally:
            with self.lock:
                self.target = self.reply_id = self.reply = None
                self.unsubscribing = False

    def close_input(self):
        with self.lock:
            self.stdin.close()
            self.ready.set()
