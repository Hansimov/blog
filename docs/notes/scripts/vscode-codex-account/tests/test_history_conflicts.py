from contextlib import closing
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import account
import history


class HistoryConflictTest(unittest.TestCase):
    def test_independent_threads_import_while_divergent_rollouts_remain_intact(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            legacy = root / "accounts" / "old"
            shared = root / "original"
            for home in (shared, legacy):
                (home / "sessions").mkdir(parents=True)
            (legacy / "email").write_text("test@example.invalid")
            divergent = "01234567-1234-5678-90ab-0123456789ab"
            safe = "01234567-1234-5678-90ab-0123456789ac"
            other = "01234567-1234-5678-90ab-0123456789ad"
            path = Path("sessions") / f"rollout-date-{divergent}.jsonl"
            (legacy / path).write_bytes(b'{"event":"legacy"}\n')
            (shared / path).write_bytes(b'{"event":"shared"}\n')
            independent = Path("sessions") / f"rollout-date-{safe}.jsonl"
            (legacy / independent).write_bytes(b'{"event":"safe"}\n')
            for filename, key in (("session_index.jsonl", "id"), ("history.jsonl", "session_id")):
                (legacy / filename).write_text("".join(json.dumps({key: tid}) + "\n"
                                                       for tid in (divergent, safe)))

            # Populate a shared canonical turn and additional legacy-only turn IDs:
            # ON CONFLICT DO NOTHING alone would insert the unrelated snapshot.
            for home, rows in ((shared, [(divergent, "canonical")]),
                               (legacy, [(divergent, "legacy"), (safe, "independent")])):
                with closing(sqlite3.connect(home / "thread_history_1.sqlite")) as db, db:
                    db.execute("CREATE TABLE thread_items(thread_id, item_id PRIMARY KEY)")
                    db.executemany("INSERT INTO thread_items VALUES(?, ?)", rows)
            with closing(sqlite3.connect(legacy / "state_5.sqlite")) as db, db:
                db.execute("CREATE TABLE threads(id PRIMARY KEY, rollout_path)")
                db.executemany("INSERT INTO threads VALUES(?, ?)", [
                    (divergent, str(legacy / path)), (safe, str(legacy / independent))])
                db.execute("CREATE TABLE session_model_ids(session_id PRIMARY KEY)")
                db.executemany("INSERT INTO session_model_ids VALUES(?)", [(divergent,), (safe,)])
                db.execute("CREATE TABLE thread_spawn_edges(parent_thread_id, child_thread_id, "
                           "PRIMARY KEY(parent_thread_id, child_thread_id))")
                db.executemany("INSERT INTO thread_spawn_edges VALUES(?, ?)",
                               [(safe, divergent), (divergent, safe), (safe, other)])

            def import_once():
                with patch.object(account, "ROOT", root), patch.object(account, "ACCOUNTS", legacy.parent), \
                        patch.object(account, "in_use", return_value=False):
                    return history.import_accounts(shared, lambda home: {})

            for _ in range(2):
                self.assertEqual(import_once(), 1)
                self.assertEqual((legacy / path).read_bytes(), b'{"event":"legacy"}\n')
                self.assertEqual((shared / path).read_bytes(), b'{"event":"shared"}\n')
                self.assertFalse((root / "history-imports" / legacy.name).exists())
            self.assertEqual((shared / independent).read_bytes(), (legacy / independent).read_bytes())
            for filename, key in (("session_index.jsonl", "id"), ("history.jsonl", "session_id")):
                lines = (shared / filename).read_text().splitlines()
                self.assertEqual([json.loads(line)[key] for line in lines], [safe])
            with closing(sqlite3.connect(shared / "thread_history_1.sqlite")) as db:
                self.assertEqual(set(db.execute("SELECT * FROM thread_items")),
                                 {(divergent, "canonical"), (safe, "independent")})
            with closing(sqlite3.connect(shared / "state_5.sqlite")) as db:
                self.assertEqual(list(db.execute("SELECT * FROM threads")), [(safe, str(shared / independent))])
                self.assertEqual(list(db.execute("SELECT * FROM session_model_ids")), [(safe,)])
                self.assertEqual(list(db.execute("SELECT * FROM thread_spawn_edges")), [(safe, other)])
            # After the external conflict is resolved, a retry imports its metadata.
            (legacy / path).write_bytes((shared / path).read_bytes())
            self.assertEqual(import_once(), 0)
            self.assertTrue((root / "history-imports" / legacy.name).exists())
            with closing(sqlite3.connect(shared / "state_5.sqlite")) as db:
                self.assertEqual({row[0] for row in db.execute("SELECT id FROM threads")}, {safe, divergent})


if __name__ == "__main__":
    unittest.main()
