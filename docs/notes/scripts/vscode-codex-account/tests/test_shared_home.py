import base64
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import account
import backend
import history


class SharedHomeTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        self.shared = root / "original"
        self.shared.mkdir()
        self.slot = root / "accounts" / "secondary"
        self.slot.mkdir(parents=True)
        (self.slot / "email").write_text("test@example.invalid")
        for key, value in (("ROOT", root), ("ACCOUNTS", self.slot.parent)):
            change = patch.object(account, key, value)
            change.start()
            self.addCleanup(change.stop)

    def test_import_live_archived_and_paginated_then_retry(self):
        archive = self.slot / "archived_sessions" / "old.jsonl"
        archive.parent.mkdir()
        archive.write_bytes(b"previous turn\n")
        (self.slot / "session_index.jsonl").write_bytes(b'{"id":"old","thread_name":"Named"}\n')
        (self.shared / "config.toml").write_bytes(b'model = "shared"\n')
        (self.slot / "config.toml").write_bytes(b'model = "private"\n')
        with closing(sqlite3.connect(self.slot / "state_5.sqlite")) as db, db:
            db.execute("CREATE TABLE threads(id PRIMARY KEY, rollout_path, archived)")
            db.execute("INSERT INTO threads VALUES ('old', ?, 1)", (str(archive),))
        with closing(sqlite3.connect(self.slot / "thread_history_1.sqlite")) as db, db:
            db.execute("CREATE TABLE thread_items(thread_id, item_id PRIMARY KEY, item_json)")
            db.execute("INSERT INTO thread_items VALUES ('old','turn-1','body')")
        shared_db = self.shared / "sqlite"
        def config(home):
            return {"sqlite_home": str(shared_db)} if home == self.shared else {}

        with patch.object(account, "in_use", return_value=True):
            history.import_accounts(self.shared, config)
        with archive.open("ab") as writer:
            writer.write(b"last turn before reload\n")
        late = self.slot / "sessions" / "new.jsonl"
        late.parent.mkdir()
        late.write_bytes(b"another old window\n")
        with patch.object(account, "in_use", return_value=False):
            history.import_accounts(self.shared, config)
            history.import_accounts(self.shared, config)
        with closing(sqlite3.connect(shared_db / "state_5.sqlite")) as db:
            [(path, archived)] = db.execute("SELECT rollout_path,archived FROM threads")
            self.assertEqual(Path(path), self.shared / "archived_sessions" / "old.jsonl")
            self.assertEqual(Path(path).read_bytes(), archive.read_bytes())
            self.assertEqual(archived, 1)
        with closing(sqlite3.connect(shared_db / "thread_history_1.sqlite")) as db:
            self.assertEqual(db.execute("SELECT item_json FROM thread_items").fetchall(), [("body",)])
        self.assertEqual((self.shared / "sessions/new.jsonl").read_bytes(), late.read_bytes())
        self.assertEqual((self.shared / "session_index.jsonl").read_bytes(),
                         (self.slot / "session_index.jsonl").read_bytes())
        self.assertEqual((self.shared / "config.toml").read_bytes(), b'model = "shared"\n')

    def test_conflict_keeps_both_originals_and_does_not_mark_done(self):
        for home, data in ((self.slot, b"one"), (self.shared, b"two")):
            (home / "sessions").mkdir()
            (home / "sessions/thread.jsonl").write_bytes(data)
        self.assertEqual(history.import_accounts(self.shared, lambda home: {}), 1)
        self.assertEqual((self.shared / "sessions/thread.jsonl").read_bytes(), b"two")
        self.assertEqual((self.slot / "sessions/thread.jsonl").read_bytes(), b"one")
        self.assertFalse((account.ROOT / "history-imports" / self.slot.name).exists())

    def test_unindexed_rollout_and_cross_volume_tail(self):
        tid = "01234567-1234-5678-90ab-0123456789ab"
        old = self.slot / "sessions" / f"rollout-2026-11-01-{tid}.jsonl"
        old.parent.mkdir()
        old.write_bytes(b"first\n")
        with closing(sqlite3.connect(self.shared / "state_5.sqlite")) as db, db:
            db.execute("CREATE TABLE threads(id PRIMARY KEY)")
            db.execute("CREATE TABLE backfill_state(id PRIMARY KEY, status, last_watermark)")
            db.execute("INSERT INTO backfill_state VALUES(1, 'complete', 'later')")
        with patch.object(history.os, "link", side_effect=OSError()), patch.object(account, "in_use", return_value=True):
            history.import_accounts(self.shared, lambda home: {})
            with old.open("ab") as f:
                f.write(b"last\n")
            history.import_accounts(self.shared, lambda home: {})
        self.assertEqual((self.shared / "sessions" / old.name).read_bytes(), b"first\nlast\n")
        with closing(sqlite3.connect(self.shared / "state_5.sqlite")) as db:
            self.assertEqual(db.execute("SELECT status,last_watermark FROM backfill_state").fetchone(),
                             ("pending", None))

    def test_refresh_uses_selected_file_and_reuses_concurrent_rotation(self):
        original = self.shared / "auth.json"
        original.write_bytes(b"original credentials")
        def cache(generation):
            payload = {"exp": int(time.time()) + 3600, "email": "test@example.invalid",
                       "generation": generation}
            token = "x." + base64.urlsafe_b64encode(json.dumps(payload).encode()).decode() + ".x"
            (self.slot / "auth.json").write_text(json.dumps({"tokens": dict(
                access_token=token, id_token=token, refresh_token="private", account_id="workspace")}))
            return token
        first = cache(1)
        with patch.object(backend, "local_request", side_effect=lambda *_: cache(2)) as native:
            renewed = backend.login_tokens("codex", self.slot, first)
            self.assertEqual(renewed, backend.login_tokens("codex", self.slot, first))
            native.assert_called_once_with("codex", self.slot, "getAuthStatus",
                                           {"includeToken": False, "refreshToken": True})
        self.assertNotEqual(renewed["accessToken"], first)
        self.assertNotIn("refreshToken", renewed)
        self.assertEqual(original.read_bytes(), b"original credentials")


if __name__ == "__main__":
    unittest.main()
