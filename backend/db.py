"""SQLite index: schema and per-thread connections."""

import sqlite3
import threading

from . import DB_PATH

SCHEMA = """
CREATE TABLE IF NOT EXISTS images (
    id        INTEGER PRIMARY KEY,
    path      TEXT NOT NULL UNIQUE,
    root      TEXT NOT NULL,          -- watched folder this file belongs to
    dir       TEXT NOT NULL,          -- parent directory
    name      TEXT NOT NULL,
    taken     INTEGER NOT NULL,       -- unix seconds (EXIF DateTimeOriginal or mtime)
    mtime     REAL NOT NULL,
    size      INTEGER NOT NULL,
    width     INTEGER NOT NULL DEFAULT 0,
    height    INTEGER NOT NULL DEFAULT 0,
    available INTEGER NOT NULL DEFAULT 1,
    favorite  INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_images_taken ON images(taken DESC);
CREATE INDEX IF NOT EXISTS idx_images_root ON images(root);
CREATE INDEX IF NOT EXISTS idx_images_dir ON images(dir);
CREATE INDEX IF NOT EXISTS idx_images_fav ON images(favorite) WHERE favorite = 1;
"""

_local = threading.local()


def connect() -> sqlite3.Connection:
    """Return this thread's connection, creating it on first use."""
    conn = getattr(_local, "conn", None)
    if conn is None or getattr(_local, "path", None) != DB_PATH:
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(DB_PATH, timeout=30)
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=NORMAL")
        conn.execute("PRAGMA busy_timeout=30000")
        _local.conn = conn
        _local.path = DB_PATH
    return conn


def init() -> None:
    conn = connect()
    conn.executescript(SCHEMA)
    conn.commit()


def remove_root(root: str) -> int:
    conn = connect()
    with conn:
        cur = conn.execute("DELETE FROM images WHERE root = ?", (root,))
    return cur.rowcount


def set_favorite(ids: list[int], value: bool) -> None:
    conn = connect()
    with conn:
        conn.executemany(
            "UPDATE images SET favorite = ? WHERE id = ?", [(int(value), i) for i in ids]
        )


def delete_paths(paths: list[str]) -> None:
    conn = connect()
    with conn:
        conn.executemany("DELETE FROM images WHERE path = ?", [(p,) for p in paths])


def path_for_id(image_id: int) -> tuple[str, int] | None:
    row = connect().execute(
        "SELECT path, available FROM images WHERE id = ?", (image_id,)
    ).fetchone()
    return (row[0], row[1]) if row else None


def root_counts() -> dict[str, int]:
    rows = connect().execute("SELECT root, COUNT(*) FROM images GROUP BY root").fetchall()
    return dict(rows)
