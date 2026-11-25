from contextlib import closing
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "codex_turn_latency.py"
THREAD = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
OLD = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
NEW = "cccccccc-cccc-cccc-cccc-cccccccccccc"


class TransportTimingTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        with closing(sqlite3.connect(self.root / "state_1.sqlite")) as state, state:
            state.execute("CREATE TABLE threads (id,rollout_path)")
            state.execute("INSERT INTO threads VALUES (?,?)", (THREAD, str(self.root / "rollout.jsonl")))

    def cli(self, *args):
        result = subprocess.run([sys.executable, "-B", str(SCRIPT), "--sqlite-home", str(self.root),
                                 "--thread", THREAD, *args], text=True, capture_output=True)
        for private in (THREAD, OLD, NEW, str(self.root), str(SCRIPT), "NEVER_SHOW", "example.test"):
            self.assertNotIn(private, result.stdout + result.stderr)
        return result

    def test_transport_with_old_timestamp_schema_and_overlapping_turns(self):
        ws = "codex_api::endpoint::responses_websocket"
        client = "codex_http_client::client"
        output = "codex_core::stream_events_utils"
        events = [
            (1, OLD, ws, "connecting to Responses WebSocket"),
            (2, OLD, ws, "successfully connected to Responses WebSocket status=101"),
            (3, NEW, ws, "successfully connected to Responses WebSocket status=101"),
            (5, NEW, output, 'Output item item_type="message" private=NEVER_SHOW'),
            (6, NEW, output, 'Output item item_type="function_call"'),
            (82, OLD, "codex_core::responses_retry",
             "stream disconnected - retrying sampling request websocket closed by server before response.completed"),
            (83, OLD, ws, "successfully connected to Responses WebSocket status=101"),
            (163, OLD, "codex_core::client", "falling back to HTTP"),
            (163, OLD, "codex_http_client::request", "Compressed request body with zstd "
             "pre_compression_bytes=4000000 post_compression_bytes=2000000 compression_duration_ms=20"),
            (164, OLD, client, "Request completed method=POST url=https://example.test/models status=200"),
            (165, OLD, client, "Request completed method=POST url=https://example.test/codex/responses?NEVER_SHOW "
             "status=413 headers=NEVER_SHOW"),
            (167, NEW, output, f'Output item private="NEVER_SHOW {OLD}"'),
        ]
        with closing(sqlite3.connect(self.root / "logs_1.sqlite")) as logs, logs:
            logs.execute("CREATE TABLE logs (id INTEGER PRIMARY KEY,ts,thread_id,target,feedback_log_body)")
            logs.executemany("INSERT INTO logs(ts,thread_id,target,feedback_log_body) VALUES (?,?,?,?)",
                             [(1735689600 + ts, THREAD, target, f'turn{{turn.id="{turn}"}}: {body}')
                              for ts, turn, target, body in events])
        old = self.cli("--transport", "--turn", OLD)
        self.assertEqual(old.returncode, 0, old.stderr)
        self.assertIn("handshake=1.00s", old.stdout)
        self.assertIn("retry  since_101=80.00s  websocket_closed_before_completion", old.stdout)
        self.assertIn("http_fallback  since_101=80.00s", old.stdout)
        self.assertIn("post_compression_bytes=2000000", old.stdout)
        self.assertIn("http_status=413", old.stdout)
        for omitted in ("first_logged_output_item", "http_status=200"):
            self.assertNotIn(omitted, old.stdout)
        latest = self.cli("--transport")
        self.assertEqual(latest.returncode, 0, latest.stderr)
        self.assertEqual(latest.stdout.count("first_logged_output_item"), 1)
        self.assertIn("since_101=2.00s", latest.stdout)

    def create_history(self, status="completed"):
        with closing(sqlite3.connect(self.root / "thread_history_1.sqlite")) as history, history:
            history.execute("CREATE TABLE thread_turns "
                            "(thread_id,turn_id,rollout_byte_offset,started_at,rollout_ordinal,status)")
            history.execute("INSERT INTO thread_turns VALUES (?,?,0,1,1,?)", (THREAD, OLD, status))
            history.execute("CREATE TABLE thread_items (thread_id,turn_id,item_type,started_at_ms,completed_at_ms)")

    def test_original_watch_with_completed_turn_and_no_logs_database(self):
        self.create_history()
        record = {"type": "token_usage_record", "payload": {"turn_id": OLD, "usage": {"input_tokens": 10}}}
        (self.root / "rollout.jsonl").write_text(json.dumps(record) + "\n", encoding="utf-8")
        result = self.cli("--watch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("completed", result.stdout)
        self.assertIn("first_cached/input=0/10", result.stdout)
        self.assertIn("stream_retries_logged=-", result.stdout)

    def test_private_paths_and_arbitrary_cli_arguments(self):
        self.create_history()
        with closing(sqlite3.connect(self.root / "state_1.sqlite")) as state, state:
            state.execute("UPDATE threads SET rollout_path=?", (str(self.root / "NEVER_SHOW" / OLD),))
        missing = self.cli("--turn", OLD)
        self.assertEqual(missing.returncode, 1)
        self.assertIn("file is missing", missing.stderr)
        bad_arg = self.cli("https://NEVER_SHOW@example.test")
        self.assertEqual(bad_arg.returncode, 2)
        self.assertIn("Invalid arguments", bad_arg.stderr)

    def test_invalid_status_and_non_numeric_token_counts(self):
        self.create_history(status="https://NEVER_SHOW@example.test")
        rollout = self.root / "rollout.jsonl"
        rollout.touch()
        result = self.cli()
        self.assertEqual(result.returncode, 0)
        self.assertIn("unknown", result.stdout)
        record = {"type": "token_usage_record", "payload": {"turn_id": OLD, "usage": {"input_tokens": "NEVER_SHOW"}}}
        rollout.write_text(json.dumps(record) + "\n", encoding="utf-8")
        bad_count = self.cli()
        self.assertEqual(bad_count.returncode, 1)
        self.assertIn("Invalid token counts", bad_count.stderr)


if __name__ == "__main__":
    unittest.main()
