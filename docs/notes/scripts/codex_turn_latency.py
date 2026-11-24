"""Observe a local Codex turn's timing and token usage without opening the thread."""
import argparse
from contextlib import ExitStack, closing
from datetime import datetime
import json
import os
from pathlib import Path
import sqlite3
import sys
import time


def database(stack, directory, prefix, optional=False):
    candidates = [(int(p.stem[len(prefix):]), p) for p in directory.glob(prefix + "*.sqlite")
                  if p.stem[len(prefix):].isdigit()]
    if not candidates:
        if optional:
            return None
        raise ValueError(f"Could not find the {prefix} database in the selected SQLite directory.")
    path = max(candidates)[1].resolve()
    return stack.enter_context(closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)))


def workspace_key(value):
    path = os.path.normpath(value)
    if os.name == "nt":
        if path.startswith("\\\\?\\UNC\\"):
            path = "\\\\" + path[8:]
        elif path.startswith("\\\\?\\"):
            path = path[4:]
    return os.path.normcase(path)


def select_thread(state, args):
    if args.thread:
        rows = state.execute("SELECT id,rollout_path FROM threads WHERE id=?", (args.thread,)).fetchall()
    else:
        key = workspace_key(str(args.workspace.resolve()))
        rows = [(tid, path) for tid, path, cwd in state.execute(
            "SELECT id,rollout_path,cwd FROM threads WHERE archived=0 AND agent_path IS NULL")
                if cwd and workspace_key(cwd) == key]
    if len(rows) != 1:
        raise ValueError("Expected one matching thread. Use --thread with its full UUID.")
    return rows[0]


def read_usage(reader, turn_id, samples):
    while True:
        offset = reader.tell()
        line = reader.readline()
        if not line.endswith(b"\n"):
            reader.seek(offset)  # The recorder may still be writing the last line.
            return
        if b'"token_usage_record"' not in line[:160]:
            continue
        event = json.loads(line)
        payload = event.get("payload") or {}
        if event.get("type") == "token_usage_record" and payload.get("turn_id") == turn_id:
            usage = payload["usage"]
            samples.append((usage["input_tokens"], usage.get("cached_input_tokens", 0)))


def observe(args):
    with ExitStack() as stack:
        state = database(stack, args.sqlite_home, "state_")
        history = database(stack, args.sqlite_home, "thread_history_")
        tid, path = select_thread(state, args)
        turn = history.execute("SELECT turn_id,rollout_byte_offset,started_at FROM thread_turns "
                               "WHERE thread_id=? ORDER BY started_at DESC,rollout_ordinal DESC LIMIT 1",
                               (tid,)).fetchone()
        if not turn:
            raise ValueError("No recorded turns in this thread.")
        turn_id, offset, started = turn
        logs = database(stack, args.sqlite_home, "logs_", optional=True)
        log_cursor = None
        retries = 0
        reader = stack.enter_context(Path(path).open("rb"))
        reader.seek(offset or 0)
        samples = []
        previous = None
        while True:
            read_usage(reader, turn_id, samples)
            status = history.execute("SELECT status FROM thread_turns WHERE thread_id=? AND turn_id=?",
                                     (tid, turn_id)).fetchone()[0]
            if logs is not None:
                upper = logs.execute("SELECT COALESCE(MAX(id),0) FROM logs").fetchone()[0]
                if log_cursor is None:
                    row = logs.execute("SELECT MIN(id) FROM logs WHERE thread_id=? AND ts>=?",
                                       (tid, started)).fetchone()
                    log_cursor = row[0] - 1 if row[0] is not None else upper
                if upper > log_cursor:
                    retries += logs.execute(
                        "SELECT COUNT(*) FROM logs NOT INDEXED WHERE id>? AND id<=? AND thread_id=? AND ts>=? "
                        "AND target='codex_core::responses_retry' AND instr(feedback_log_body,?)>0 "
                        "AND feedback_log_body LIKE '%retrying%'", (log_cursor, upper, tid, started, turn_id)
                    ).fetchone()[0]
                log_cursor = upper
            timing = dict(history.execute(
                "SELECT item_type,MIN(started_at_ms) FROM thread_items WHERE thread_id=? AND turn_id=? "
                "AND item_type IN ('userMessage','agentMessage') GROUP BY item_type", (tid, turn_id)))
            summaries, compact_ms = history.execute(
                "SELECT COUNT(*),COALESCE(SUM(completed_at_ms-started_at_ms),0) FROM thread_items "
                "WHERE thread_id=? AND turn_id=? AND item_type='contextCompaction' AND completed_at_ms IS NOT NULL",
                (tid, turn_id)).fetchone()
            user, reply = timing.get("userMessage"), timing.get("agentMessage")
            first_text = f"{(reply-user)/1000:.2f}s" if user is not None and reply is not None and reply >= user else "-"
            first_cache = f"{samples[0][1]}/{samples[0][0]}" if samples else "-"
            metrics = (f"{status}  first_text={first_text}  first_cached/input={first_cache}  "
                       f"usage_records={len(samples)}  stream_retries_logged={retries if logs is not None else '-'}  "
                       f"completed_compactions={summaries} ({compact_ms/1000:.1f}s)")
            if metrics != previous:
                print(datetime.now().astimezone().isoformat(timespec="seconds"), metrics, flush=True)
                previous = metrics
            if not args.watch or status != "inProgress":
                return
            time.sleep(10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--thread", help="exact local thread UUID")
    target.add_argument("--workspace", type=Path, help="folder with a single unarchived top-level conversation")
    home = os.environ.get("CODEX_SQLITE_HOME") or os.environ.get("CODEX_HOME") or Path.home() / ".codex"
    parser.add_argument("--sqlite-home", type=Path, default=Path(home), help="directory containing Codex databases")
    parser.add_argument("--watch", action="store_true", help="follow this turn until it ends or Ctrl+C is pressed")
    try:
        observe(parser.parse_args())
    except KeyboardInterrupt:
        return 0
    except (OSError, sqlite3.Error, ValueError, KeyError) as error:
        print(f"Could not read Codex timing: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
