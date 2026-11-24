"""Local release requests for one window. The installer restricts ROOT to the current user and SYSTEM."""
from contextlib import contextmanager
import ctypes
from ctypes import wintypes
import math
import os
from pathlib import Path
import threading
import time
import uuid


RESULTS = {"released", "busy", "not_loaded", "error", "timeout"}
MAX_TIMEOUT = 15
POLL_INTERVAL = 0.20


def _mailbox(root, pid):
    # A PID can be recycled while an old mailbox is still on disk.
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.GetProcessTimes.argtypes = (wintypes.HANDLE,) + (ctypes.POINTER(wintypes.FILETIME),) * 4
    kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
    handle = kernel.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not handle:
        return None
    try:
        created, exited, system, user = (wintypes.FILETIME() for _ in range(4))
        if not kernel.GetProcessTimes(handle, ctypes.byref(created), ctypes.byref(exited),
                                      ctypes.byref(system), ctypes.byref(user)):
            return None
        stamp = (created.dwHighDateTime << 32) + created.dwLowDateTime
        return Path(root) / "release-requests" / f"{pid}-{stamp:x}"
    finally:
        kernel.CloseHandle(handle)


def _publish(path, value):
    # Only the server creates the parent; an exited owner's mailbox must not be recreated.
    temp = path.with_suffix(path.suffix + ".tmp")
    try:
        temp.write_text(value, encoding="ascii")
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def _listen(box, stop, release):
    while not stop.is_set():
        for request in box.glob("*.request"):
            if stop.is_set():
                return
            claimed = request.with_suffix(".working")
            try:
                request.rename(claimed)
                with claimed.open("rb") as stream:
                    data = stream.read(129)
                if len(data) > 128:
                    continue
                thread_id, expiry = data.decode("ascii").split()
                deadline = float(expiry)
                if str(uuid.UUID(thread_id)) != thread_id or not 0 < deadline - time.monotonic() <= MAX_TIMEOUT:
                    continue
                try:
                    result = release(thread_id, deadline)
                except Exception:
                    # Keep other windows' requests available if the backend exits during an RPC.
                    result = "error"
                if time.monotonic() < deadline and not stop.is_set():
                    _publish(request.with_suffix(".reply"), result if result in RESULTS else "error")
            except (OSError, ValueError):
                # The client can time out and remove its request before we claim it.
                continue
            finally:
                claimed.unlink(missing_ok=True)
        stop.wait(POLL_INTERVAL)


@contextmanager
def serve_releases(root, native_pid, on_release):
    """Serve UUID-only requests in the private installation directory during this server's life."""
    box = _mailbox(root, native_pid)
    try:
        if box is not None:
            box.mkdir(parents=True, exist_ok=False)
    except OSError:
        box = None
    if box is None:
        # An unavailable optional control channel must not prevent VS Code from opening.
        yield
        return
    stop = threading.Event()
    listener = threading.Thread(target=_listen, args=(box, stop, on_release), daemon=True)
    listener.start()
    try:
        yield
    finally:
        stop.set()
        listener.join(timeout=0.5)
        try:
            box.rmdir()
        except OSError:
            # In-flight clients may still be collecting their results.
            pass


def request_release(root, native_pid, thread_id, timeout=8.0):
    """Ask this exact native server to release a single thread before the deadline."""
    if str(uuid.UUID(thread_id)) != thread_id:
        raise ValueError("Expected a canonical thread ID.")
    if not math.isfinite(timeout) or not 0 < timeout <= MAX_TIMEOUT:
        raise ValueError("Invalid release timeout.")
    box = _mailbox(root, native_pid)
    if box is None or not box.is_dir():
        return "unmanaged"
    request = box / (uuid.uuid4().hex + ".request")
    reply = request.with_suffix(".reply")
    deadline = time.monotonic() + timeout
    try:
        _publish(request, f"{thread_id}\n{deadline}")
        while time.monotonic() < deadline:
            try:
                result = reply.read_text(encoding="ascii")
            except FileNotFoundError:
                if not box.is_dir():
                    return "unmanaged"
                time.sleep(min(0.05, max(0, deadline - time.monotonic())))
                continue
            return result if result in RESULTS else "error"
        return "timeout"
    except FileNotFoundError:
        return "unmanaged"
    finally:
        request.unlink(missing_ok=True)
        reply.unlink(missing_ok=True)
