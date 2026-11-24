"""Locate a named Codex thread and inspect the holders of its native writer lock."""
from contextlib import closing
import ctypes
from ctypes import wintypes
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import sqlite3
import uuid


def canonical_id(text):
    if not isinstance(text, str):
        return None
    try:
        value = str(uuid.UUID(text))
    except ValueError:
        return None
    return value if text.lower() == value else None


def indexed_names(shared):
    latest = {}
    index = shared / "session_index.jsonl"
    if index.is_file():
        with index.open("rb") as lines:
            for line in lines:
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue  # A writer can still be appending the last line.
                if not isinstance(entry, dict):
                    continue
                thread = canonical_id(entry.get("id"))
                name = entry.get("thread_name")
                if thread is None or not isinstance(name, str):
                    continue
                try:
                    stamp = datetime.fromisoformat(entry["updated_at"].replace("Z", "+00:00"))
                    stamp = stamp.replace(tzinfo=stamp.tzinfo or timezone.utc)
                except (AttributeError, KeyError, ValueError):
                    stamp = datetime.min.replace(tzinfo=timezone.utc)
                if thread not in latest or stamp >= latest[thread][0]:
                    latest[thread] = stamp, name
    return {thread: name for thread, (_, name) in latest.items()}


def resolve_thread(shared, selector, sqlite_home=None):
    """Accept an exact UUID or a unique, case-insensitive display name."""
    selector = selector.strip()
    if not selector:
        raise ValueError("Enter a full thread title or UUID.")
    thread = canonical_id(selector)
    if thread:
        return thread
    shared = Path(shared)
    names = indexed_names(shared)
    query = selector.casefold()
    matches = {thread for thread, name in names.items() if name.casefold() == query}

    # Fresh or imported threads may not have an index entry yet. Read only
    # metadata from the latest database schema, respecting renamed index entries.
    folder = Path(sqlite_home or os.environ.get("CODEX_SQLITE_HOME") or shared)
    versions = [(int(found[1]), path) for path in folder.glob("state_*.sqlite")
                if (found := re.fullmatch(r"state_(\d+)\.sqlite", path.name))]
    if versions:
        path = max(versions)[1]
        with closing(sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)) as db:
            columns = {row[1] for row in db.execute("PRAGMA table_info(threads)")}
            if "name" in columns and "title" in columns:
                display = "coalesce(nullif(name, ''), title)"
            elif "name" in columns:
                display = "name"
            else:
                display = "title"
            if "id" in columns and columns.intersection(("name", "title")):
                db.create_function("casefold", 1, lambda text: text.casefold() if isinstance(text, str) else None)
                for (value,) in db.execute(f"SELECT id FROM threads WHERE casefold({display}) = ?", (query,)):
                    thread = canonical_id(value)
                    if thread and thread not in names:
                        matches.add(thread)
    if not matches:
        raise ValueError("No thread has this exact title. Check the spelling or use its full UUID.")
    if len(matches) > 1:
        raise ValueError("Several threads have this title. Use one of their UUIDs: " + ", ".join(sorted(matches)))
    return matches.pop()


class UniqueProcess(ctypes.Structure):
    _fields_ = [("pid", wintypes.DWORD), ("start", wintypes.FILETIME)]


class ProcessInfo(ctypes.Structure):
    _fields_ = [("process", UniqueProcess), ("name", wintypes.WCHAR * 256),
                ("service", wintypes.WCHAR * 64), ("type", wintypes.DWORD),
                ("status", wintypes.DWORD), ("session", wintypes.DWORD), ("restartable", wintypes.BOOL)]


def writer_pids(shared, thread_id):
    """Inspect Windows Restart Manager's file holders; never modify the lock."""
    thread = canonical_id(thread_id)
    if not thread:
        raise ValueError("Invalid thread UUID.")
    lock = Path(shared) / "thread-writer-locks" / (thread + ".lock")
    if not lock.is_file():
        return set()
    rm = ctypes.windll.rstrtmgr
    session = wintypes.DWORD()
    key = ctypes.create_unicode_buffer(33)  # CCH_RM_SESSION_KEY + 1
    error = rm.RmStartSession(ctypes.byref(session), 0, key)
    if error:
        raise ctypes.WinError(error)
    try:
        paths = (wintypes.LPCWSTR * 1)(str(lock.resolve()))
        error = rm.RmRegisterResources(session, 1, paths, 0, None, 0, None)
        if error:
            raise ctypes.WinError(error)
        needed, count, reasons = wintypes.UINT(), wintypes.UINT(), wintypes.DWORD()
        records = None
        while True:
            error = rm.RmGetList(session, ctypes.byref(needed), ctypes.byref(count),
                                 records, ctypes.byref(reasons))
            if error == 0:
                return {records[i].process.pid for i in range(count.value)}
            if error != 234:  # ERROR_MORE_DATA; holders may change between calls.
                raise ctypes.WinError(error)
            count.value = needed.value
            records = (ProcessInfo * count.value)()
    finally:
        rm.RmEndSession(session)
