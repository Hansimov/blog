from contextlib import closing
import json
import os
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import thread_lookup


class ThreadLookupTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.shared = Path(temp.name)
        self.state = self.shared / "custom-sqlite"
        self.state.mkdir()
        self.ids = [str(uuid.uuid4()) for _ in range(3)]

    def resolve(self, text):
        return thread_lookup.resolve_thread(self.shared, text, self.state)

    def test_index_rename_and_distinct_ids_with_identical_titles(self):
        index = self.shared / "session_index.jsonl"
        # A later migration appends an older record; a live writer has not
        # finished its last line. Neither should replace the newer display name.
        with index.open("w", encoding="utf-8") as out:
            for name, stamp in (("工具-开发", "2026-03-10T12:03:00Z"), ("old", "2026-02-01T00:00:00Z")):
                out.write(json.dumps(dict(id=self.ids[0], thread_name=name, updated_at=stamp)) + "\n")
            out.write('{"partial":')
        with closing(sqlite3.connect(self.state / "state_12.sqlite")) as db, db:
            db.execute("CREATE TABLE threads (id PRIMARY KEY, name, title)")
            db.executemany("INSERT INTO threads VALUES (?,?,?)", [
                (self.ids[0], "old", "unused"), (self.ids[1], "Other", "unused"),
                (self.ids[2], None, "Straße")])
        with closing(sqlite3.connect(self.state / "state_9.sqlite")) as db, db:
            db.execute("CREATE TABLE threads (id, title)")
            db.execute("INSERT INTO threads VALUES (?, ?)", (self.ids[1], "old"))
        self.assertEqual(self.resolve("工具-开发"), self.ids[0])
        self.assertEqual(self.resolve("other"), self.ids[1])
        self.assertEqual(self.resolve("STRASSE"), self.ids[2])
        self.assertEqual(self.resolve(self.ids[0].upper()), self.ids[0])
        with self.assertRaisesRegex(ValueError, "No thread"):
            self.resolve("old")
        with closing(sqlite3.connect(self.state / "state_12.sqlite")) as db, db:
            db.execute("UPDATE threads SET name = '工具-开发' WHERE id = ?", (self.ids[1],))
        with self.assertRaisesRegex(ValueError, "Several threads") as ambiguous:
            self.resolve("工具-开发")
        self.assertTrue(all(key in str(ambiguous.exception) for key in self.ids[:2]))

    def test_native_file_holder_and_unused_lock(self):
        lock_folder = self.shared / "thread-writer-locks"
        lock_folder.mkdir()
        path = lock_folder / (self.ids[0] + ".lock")
        self.assertEqual(thread_lookup.writer_pids(self.shared, self.ids[0]), set())
        self.assertFalse(path.exists())
        with path.open("wb"):
            self.assertIn(os.getpid(), thread_lookup.writer_pids(self.shared, self.ids[0]))
        self.assertEqual(thread_lookup.writer_pids(self.shared, self.ids[0]), set())
        self.assertTrue(path.exists())
        with self.assertRaises(ValueError):
            thread_lookup.writer_pids(self.shared, "../invalid")


if __name__ == "__main__":
    unittest.main()
