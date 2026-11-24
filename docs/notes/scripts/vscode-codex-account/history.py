"""Import history left in CODEX_HOME directories created by the old launcher."""
from contextlib import closing, contextmanager
import errno
import filecmp
import hashlib
import json
import msvcrt
import os
from pathlib import Path
import re
import shutil
import sqlite3
import tempfile

import account


# Import thread data, including paginated history that no longer lives in JSONL.
# Keep installation bookkeeping and remote-control registrations out of the merge.
DATABASES = {
    "thread_history": ("thread_turns", "thread_items", "thread_realtime_items",
                       "thread_history_projection_state"),
    "goals": ("thread_goals", "thread_goal_continuation_deferrals"),
    "state": ("projects", "project_roots", "thread_sections", "threads", "thread_dynamic_tools",
              "thread_spawn_edges", "thread_attachments", "thread_read_receipts",
              "session_model_ids", "guardian_review_feedback"),
}
DIRECTORIES = ("sessions", "archived_sessions", "attachments", "generated_images")


@contextmanager
def lock_file(path):
    with path.open("a+b") as lock:
        lock.seek(0)
        while True:
            try:
                msvcrt.locking(lock.fileno(), msvcrt.LK_LOCK, 1)
                break
            except OSError as exc:
                if exc.errno not in (errno.EACCES, errno.EDEADLK):
                    raise
        try:
            yield
        finally:
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


def import_file(source, target):
    """Return False for a divergent pair, leaving both paths intact."""
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if source.samefile(target) or filecmp.cmp(source, target, shallow=False):
            return True
        if source.suffix == ".jsonl":
            # Cross-volume installs cannot hard-link a still-growing rollout.
            # Reconcile an append-only tail; preserve both files if they diverged.
            with source.open("rb") as old, target.open("r+b") as current:
                while True:
                    left, right = old.read(1024 * 1024), current.read(1024 * 1024)
                    if left == right and left:
                        continue
                    if left.startswith(right):
                        current.write(left[len(right):])
                        shutil.copyfileobj(old, current)
                        return True
                    if right.startswith(left):
                        return True
                    break
        return False
    try:
        # A legacy window may still be appending to this rollout.
        os.link(source, target)
    except OSError:
        with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as tmp:
            name = Path(tmp.name)
        try:
            shutil.copy2(source, name)
            name.rename(target)  # On Windows, never overwrite an existing destination.
        finally:
            name.unlink(missing_ok=True)
    return True


def merge_lines(source, target, excluded_ids, id_key):
    if not source.is_file():
        return
    with lock_file(target.with_suffix(target.suffix + ".lock")):
        with target.open("a+b") as output, source.open("rb") as old:
            output.seek(0)
            seen = set()
            for line in output:
                seen.add(hashlib.sha256(line.rstrip(b"\r\n")).digest())
                if not line.endswith(b"\n"):
                    json.loads(line)
                    output.write(b"\n")
            for line in old:
                if excluded_ids:
                    try:
                        record = json.loads(line)
                    except ValueError:
                        continue
                    if isinstance(record, dict) and str(record.get(id_key)).lower() in excluded_ids:
                        continue
                if not line.endswith(b"\n"):
                    try:
                        json.loads(line)
                    except ValueError:
                        continue  # An active writer may still be finishing this line.
                    line += b"\n"
                digest = hashlib.sha256(line.rstrip(b"\r\n")).digest()
                if digest not in seen:
                    output.write(line)
                    seen.add(digest)


def merge_database(source, target, tables, old_home, shared, excluded_ids):
    def remap(path):
        if not path:
            return path
        try:
            relative = Path(path).resolve().relative_to(old_home)
        except ValueError:
            return path
        return str(shared / relative)

    target.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(target.as_uri(), uri=True, timeout=30)) as db:
        db.create_function("shared_path", 1, remap)
        db.create_function("import_thread", 1, lambda tid: str(tid).lower() not in excluded_ids)
        if source.samefile(target):
            if "threads" in tables:
                with db:
                    db.execute("UPDATE threads SET rollout_path=shared_path(rollout_path) "
                               "WHERE import_thread(id) AND rollout_path != shared_path(rollout_path)")
            return
        db.execute("PRAGMA foreign_keys=ON")
        db.execute("ATTACH DATABASE ? AS legacy", (source.as_uri() + "?mode=ro",))
        with db:
            db.execute("BEGIN IMMEDIATE")
            rows = db.execute("SELECT name, sql FROM legacy.sqlite_schema WHERE type='table' "
                              "AND name NOT LIKE 'sqlite_%'").fetchall()
            source_tables = {name for name, _ in rows}
            if not db.execute("SELECT 1 FROM main.sqlite_schema WHERE type='table'").fetchone():
                # Seed the schema of a history database the shared home hasn't used yet.
                for _, ddl in rows:
                    db.execute(ddl)
                for (ddl,) in db.execute("SELECT sql FROM legacy.sqlite_schema WHERE "
                                         "type IN ('index','trigger','view') AND sql IS NOT NULL"):
                    db.execute(ddl)
                if "_sqlx_migrations" in source_tables:
                    db.execute("INSERT INTO main._sqlx_migrations SELECT * FROM legacy._sqlx_migrations")
            for table in tables:
                if table not in source_tables:
                    continue
                old = [r[1] for r in db.execute(f"PRAGMA legacy.table_info({table})")]
                current = {r[1] for r in db.execute(f"PRAGMA main.table_info({table})")}
                # Only these columns identify the owning thread or a graph edge
                # endpoint. Item, turn, goal and project IDs have other meanings.
                keys = ("id",) if table == "threads" else ("thread_id", "session_id",
                                                            "parent_thread_id", "child_thread_id")
                checks = [f"import_thread({key})" for key in keys if key in old and excluded_ids]
                predicate = " AND ".join(checks) or "true"
                if set(old) - current:
                    if db.execute(f"SELECT 1 FROM legacy.{table} WHERE {predicate} LIMIT 1").fetchone():
                        raise ValueError(f"Upgrade the shared Codex database before importing {source.name} ({table}).")
                    continue
                names = ", ".join('"' + c.replace('"', '""') + '"' for c in old)
                values = ", ".join("shared_path(rollout_path)" if c == "rollout_path"
                                   else '"' + c.replace('"', '""') + '"' for c in old)
                db.execute(f"INSERT INTO main.{table} ({names}) SELECT {values} FROM legacy.{table} "
                           f"WHERE {predicate} ON CONFLICT DO NOTHING")


def sqlite_dir(home, config):
    path = config(home).get("sqlite_home") or os.environ.get("CODEX_SQLITE_HOME") or home
    return Path(path).resolve()


def reindex_missing(folder, ids):
    if not ids:
        return
    for path in folder.glob("state_[0-9]*.sqlite"):
        with closing(sqlite3.connect(path.as_uri(), uri=True, timeout=30)) as db, db:
            if db.execute("SELECT 1 FROM sqlite_schema WHERE name='backfill_state'").fetchone():
                if any(not db.execute("SELECT 1 FROM threads WHERE id=?", (tid,)).fetchone() for tid in ids):
                    # Some older homes only have rollout files. Let Codex rebuild
                    # their metadata even if it had already indexed the original home.
                    db.execute("UPDATE backfill_state SET status='pending', last_watermark=NULL "
                               "WHERE id=1 AND status='complete'")


def import_accounts(shared, config):
    """Import independent history and return the number of file conflicts to retry."""
    conflicts = 0
    marker_dir = account.ROOT / "history-imports"
    marker_dir.mkdir(exist_ok=True)
    with lock_file(marker_dir / "import.lock"):
        shared_db = None
        for homes in account.accounts_by_email().values():
            for home in homes:
                done = marker_dir / home.name
                if done.exists():
                    continue
                legacy_was_running = account.in_use(home.name)
                rollout_ids = set()
                excluded_ids = set()
                previous_conflicts = conflicts
                for directory in DIRECTORIES:
                    for file in (home / directory).rglob("*"):
                        if file.is_file():
                            imported = import_file(file, shared / file.relative_to(home))
                            if not imported:
                                conflicts += 1
                            if directory in ("sessions", "archived_sessions"):
                                match = re.fullmatch(r"rollout-.+-([0-9a-fA-F-]{36})\.jsonl", file.name)
                                if match:
                                    (rollout_ids if imported else excluded_ids).add(match[1].lower())
                for name, id_key in (("history.jsonl", "session_id"), ("session_index.jsonl", "id")):
                    merge_lines(home / name, shared / name, excluded_ids, id_key)
                if (any((home / name).exists() for name in DIRECTORIES) or
                        any(home.glob("state_*.sqlite")) or (home / "config.toml").exists()):
                    old_db = sqlite_dir(home, config)
                    if shared_db is None:
                        shared_db = sqlite_dir(shared, config)
                    for kind, tables in DATABASES.items():
                        for source in old_db.glob(kind + "_[0-9]*.sqlite"):
                            merge_database(source, shared_db / source.name, tables, home.resolve(), shared,
                                           excluded_ids)
                    reindex_missing(shared_db, rollout_ids - excluded_ids)
                # Old windows can still create threads until their next reload.
                # Retry their import on startup. Only the old launcher owns this event.
                if conflicts == previous_conflicts and not legacy_was_running and not account.in_use(home.name):
                    account.atomic_write(done, b"1")
    return conflicts
