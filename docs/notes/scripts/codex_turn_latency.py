"""Observe a local Codex turn's timing and token usage without opening the thread."""
import argparse
from contextlib import ExitStack, closing
from datetime import datetime
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import time
from urllib.parse import urlsplit


class TimingError(Exception):
    """A diagnostic with fixed wording suitable for sharing."""


class TimingParser(argparse.ArgumentParser):
    def error(self, message):
        # argparse normally echoes unrecognized arguments, which may be private.
        self.print_usage(sys.stderr)
        self.exit(2, "Invalid arguments. Use --help for supported options.\n")


def database(stack, directory, prefix, optional=False):
    candidates = [(int(p.stem[len(prefix):]), p) for p in directory.glob(prefix + "*.sqlite")
                  if p.stem[len(prefix):].isdigit()]
    if not candidates:
        if optional:
            return None
        raise TimingError(f"Could not find the {prefix} database in the selected SQLite directory.")
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
        raise TimingError("Expected one matching thread. Use --thread with its full UUID.")
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
            counts = (usage["input_tokens"], usage.get("cached_input_tokens", 0))
            if any(type(n) is not int or n < 0 for n in counts):
                raise TimingError("Invalid token counts in the local rollout.")
            samples.append(counts)


TURN_FIELD = re.compile(r'\b(?:turn\.id|turn_id)="?([0-9a-fA-F-]{36})\b')
TRANSPORT_TARGETS = (
    "codex_api::endpoint::responses_websocket", "codex_core::client",
    "codex_core::stream_events_utils", "codex_core::responses_retry",
    "codex_http_client::request", "codex_http_client::client",
)


def transport_events(logs, tid, wanted_turn):
    columns = {row[1] for row in logs.execute("PRAGMA table_info(logs)")}
    if not {"id", "ts", "target", "thread_id", "feedback_log_body"} <= columns:
        raise TimingError("This logs database lacks thread-scoped transport records.")
    nanos = "COALESCE(ts_nanos,0)" if "ts_nanos" in columns else "0"
    targets = ",".join("?" for _ in TRANSPORT_TARGETS)
    query = (f"SELECT ts,{nanos},target,feedback_log_body FROM logs WHERE thread_id=? "
             f"AND target IN ({targets})")
    params = (tid, *TRANSPORT_TARGETS)
    if wanted_turn:
        query += " AND instr(feedback_log_body,?)>0"
        params += (wanted_turn,)
    # Start with the newest scoped row when history projections lag a resumed turn.
    records = []
    for sec, ns, target, body in logs.execute(query + " ORDER BY ts DESC,2 DESC,id DESC", params):
        scope, sep, message = (body or "").rpartition("}:")
        match = TURN_FIELD.search(scope)
        if not sep or not match:
            continue
        if wanted_turn is None:
            wanted_turn = match[1]
        if match[1] == wanted_turn:
            records.append((sec + ns / 1e9, target, message.strip()))
    if not records:
        raise TimingError("No retained transport records with an exact thread and turn match.")
    return reversed(records)


def show_transport(logs, tid, turn_id):
    records = transport_events(logs, tid, turn_id)
    upgrade_started = upgraded = None
    first_output = False
    for when, target, message in records:
        elapsed = f"  since_101={when-upgraded:.2f}s" if upgraded is not None else ""
        if target.endswith("::responses_websocket"):
            if message.startswith("connecting to Responses WebSocket"):
                upgrade_started, upgraded = when, None
                continue
            if not message.startswith("successfully connected to Responses WebSocket status=101"):
                continue
            event = "websocket_101"
            if upgrade_started is not None:
                event += f"  handshake={when-upgrade_started:.2f}s"
            upgrade_started, upgraded, first_output = None, when, False
        elif message.startswith("non-incremental request"):
            reason = re.search(r'\breason="(restored_history|connection_closed)"', message)
            event = "full_request" + (f"  reason={reason[1]}" if reason else "")
        elif target.endswith("::stream_events_utils"):
            if upgraded is None or first_output or not re.match(r"(?:handle_output_item_done: )?Output item\b", message):
                continue
            first_output = True
            event = "first_logged_output_item" + elapsed
        elif target.endswith("::responses_retry"):
            if "retry" not in message:
                continue
            event = "retry" + elapsed
            if "websocket closed by server before response.completed" in message:
                event += "  websocket_closed_before_completion"
            upgraded = None
        elif message.startswith("falling back to HTTP"):
            event = "http_fallback" + elapsed
            upgraded = None
        elif message.startswith("Compressed request body with zstd"):
            fields = re.findall(r"\b(pre_compression_bytes|post_compression_bytes|compression_duration_ms)=(\d+)\b", message)
            event = "http_zstd " + " ".join(f"{key}={value}" for key, value in fields)
        elif target.endswith("codex_http_client::client"):
            url = re.search(r'\burl="?([^"\s]+)', message)
            if not url or urlsplit(url[1]).path.rstrip("/").rsplit("/", 1)[-1] != "responses":
                continue
            status = re.search(r"\bstatus=(\d{3})\b", message)
            if message.startswith("Request completed") and status:
                event = "http_status=" + status[1]
            elif message.startswith("Request failed"):
                event = "http_request_failed"
            else:
                continue
        else:
            continue
        stamp = datetime.fromtimestamp(when).astimezone().isoformat(timespec="milliseconds")
        print(stamp, event)


def observe(args):
    with ExitStack() as stack:
        state = database(stack, args.sqlite_home, "state_")
        tid, path = select_thread(state, args)
        if args.transport:
            show_transport(database(stack, args.sqlite_home, "logs_"), tid, args.turn)
            return
        history = database(stack, args.sqlite_home, "thread_history_")
        selection = "SELECT turn_id,rollout_byte_offset,started_at FROM thread_turns WHERE thread_id=?"
        if args.turn:
            turn = history.execute(selection + " AND turn_id=?", (tid, args.turn)).fetchone()
        else:
            turn = history.execute(selection + " ORDER BY started_at DESC,rollout_ordinal DESC LIMIT 1",
                                   (tid,)).fetchone()
        if not turn:
            raise TimingError("No matching recorded turn in the history database.")
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
            if status not in ("inProgress", "interrupted", "failed", "completed"):
                status = "unknown"
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
    parser = TimingParser(prog="codex_turn_latency.py", description=__doc__)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--thread", help="exact local thread UUID")
    target.add_argument("--workspace", type=Path, help="folder with a single unarchived top-level conversation")
    parser.add_argument("--sqlite-home", type=Path, help="directory containing Codex databases")
    parser.add_argument("--turn", help="select an exact turn UUID (default: latest in the selected source)")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--watch", action="store_true", help="follow this turn until it ends or Ctrl+C is pressed")
    mode.add_argument("--transport", action="store_true",
                      help="show offline WebSocket and HTTP timings using only retained, turn-scoped logs")
    try:
        args = parser.parse_args()
        if args.sqlite_home is None:
            home = os.environ.get("CODEX_SQLITE_HOME") or os.environ.get("CODEX_HOME") or Path.home() / ".codex"
            args.sqlite_home = Path(home)
        observe(args)
    except KeyboardInterrupt:
        return 0
    except TimingError as error:
        message = str(error)
    except FileNotFoundError:
        message = "A required local Codex file is missing. Check the SQLite directory and rollout availability."
    except PermissionError:
        message = "Access to a required local Codex file was denied."
    except OSError:
        message = "Could not read a local Codex file. Check its accessibility."
    except sqlite3.Error:
        message = "Could not query the local Codex database. Check that it is readable and uses a supported schema."
    except (ValueError, TypeError, LookupError, AttributeError, OverflowError):
        message = "Invalid timing data in the local Codex records."
    except Exception:
        # Exception text and tracebacks may include record contents or local paths.
        message = "Could not process the local Codex timing records."
    else:
        return 0
    print(message, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
