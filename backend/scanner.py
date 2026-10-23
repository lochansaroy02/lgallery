"""Background scanner: walks the watched folders and keeps the index in sync."""

import logging
import os
import time
from typing import NamedTuple
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

from PIL import Image, UnidentifiedImageError
from PySide6.QtCore import QThread, Signal

from . import db, supported_exts

log = logging.getLogger(__name__)

SKIP_DIRS = {
    "node_modules", "__pycache__", "lost+found", "$RECYCLE.BIN",
    "System Volume Information", "Trash", "trash",
}
EXIF_IFD = 0x8769
TAG_DATETIME_ORIGINAL = 36867
TAG_DATETIME_DIGITIZED = 36868
TAG_DATETIME = 306
TAG_ORIENTATION = 274
GPS_IFD = 0x8825
BATCH = 256
META_VER = 2  # bump to make the GPS backfill re-read files indexed by older versions

# A changed file gets its place and faces recomputed (place = NULL, faces_ver = 0).
UPSERT = f"""
INSERT INTO images (path, root, dir, name, taken, mtime, size, width, height, lat, lon,
                    meta_ver, available)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, {META_VER}, 1)
ON CONFLICT(path) DO UPDATE SET
    root = excluded.root, dir = excluded.dir, name = excluded.name,
    taken = excluded.taken, mtime = excluded.mtime, size = excluded.size,
    width = excluded.width, height = excluded.height, lat = excluded.lat, lon = excluded.lon,
    meta_ver = {META_VER}, place = NULL, country = NULL, faces_ver = 0, available = 1
"""


class Meta(NamedTuple):
    taken: int
    width: int
    height: int
    lat: float | None = None
    lon: float | None = None


def _gps_coord(values, ref) -> float | None:
    try:
        d, m, s = (float(v) for v in values)
    except (TypeError, ValueError, ZeroDivisionError):
        return None
    value = d + m / 60 + s / 3600
    if isinstance(ref, bytes):
        ref = ref.decode("ascii", "ignore")
    return -value if str(ref).strip().upper() in ("S", "W") else value


def parse_gps(exif) -> tuple[float | None, float | None]:
    try:
        gps = exif.get_ifd(GPS_IFD)
    except Exception:
        return None, None
    if not gps or 2 not in gps or 4 not in gps:
        return None, None
    lat, lon = _gps_coord(gps.get(2), gps.get(1, "N")), _gps_coord(gps.get(4), gps.get(3, "E"))
    if lat is None or lon is None or not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return None, None
    if abs(lat) < 1e-6 and abs(lon) < 1e-6:  # "0,0" written by some cameras without a fix
        return None, None
    return round(lat, 6), round(lon, 6)


def should_skip_dir(name: str) -> bool:
    return name.startswith(".") or name in SKIP_DIRS or name.startswith(".Trash")


def root_available(entry: dict) -> bool:
    """False when the folder's drive is unmounted or the folder vanished."""
    mount = entry.get("mount") or "/"
    if mount != "/" and not os.path.ismount(mount):
        return False
    return os.path.isdir(entry["path"])


def parse_exif_date(value) -> int | None:
    if not value:
        return None
    if isinstance(value, bytes):
        value = value.decode("ascii", "ignore")
    value = str(value).strip().rstrip("\x00")[:19]
    for fmt, length in (("%Y:%m:%d %H:%M:%S", 19), ("%Y-%m-%d %H:%M:%S", 19), ("%Y:%m:%d", 10)):
        try:
            dt = datetime.strptime(value[:length], fmt)
        except ValueError:
            continue
        if dt.year < 1900:
            return None
        try:
            return int(dt.timestamp())
        except (OverflowError, OSError, ValueError):
            return None
    return None


def read_metadata(path: str, mtime: float) -> Meta | None:
    """Meta(taken, width, height, lat, lon), or None if the file is not a readable image."""
    try:
        with Image.open(path) as im:
            width, height = im.size
            taken = None
            lat = lon = None
            exif = im.getexif()
            if exif:
                sub = exif.get_ifd(EXIF_IFD)
                taken = (
                    parse_exif_date(sub.get(TAG_DATETIME_ORIGINAL))
                    or parse_exif_date(sub.get(TAG_DATETIME_DIGITIZED))
                    or parse_exif_date(exif.get(TAG_DATETIME))
                )
                if exif.get(TAG_ORIENTATION) in (5, 6, 7, 8):
                    width, height = height, width
                lat, lon = parse_gps(exif)
    except (UnidentifiedImageError, Image.DecompressionBombError):
        return None
    except Exception as exc:  # permission denied, truncated header, I/O error
        log.debug("cannot read %s: %s", path, exc)
        return None
    return Meta(taken or int(mtime), width, height, lat, lon)


def _is_within(path: str, folder: str) -> bool:
    return path.startswith(folder.rstrip(os.sep) + os.sep)


def scan_root(entry, min_size_kb=20, should_stop=lambda: False, progress=None) -> dict:
    """Incrementally sync one watched folder into the index."""
    conn = db.connect()
    root = entry["path"]
    stats = {"found": 0, "added": 0, "updated": 0, "removed": 0, "errors": 0}

    if not root_available(entry):
        with conn:
            conn.execute("UPDATE images SET available = 0 WHERE root = ?", (root,))
        stats["unavailable"] = True
        return stats

    exts = supported_exts()
    min_bytes = max(0, min_size_kb) * 1024
    existing = {
        p: (m, s)
        for p, m, s in conn.execute(
            "SELECT path, mtime, size FROM images WHERE root = ?", (root,)
        )
    }
    with conn:
        conn.execute(
            "UPDATE images SET available = 1 WHERE root = ? AND available = 0", (root,)
        )

    seen: set[str] = set()
    error_dirs: list[str] = []
    todo: list[tuple[str, str, str, float, int]] = []
    last_emit = 0.0

    def flush(executor):
        if not todo:
            return
        metas = executor.map(lambda t: read_metadata(t[0], t[3]), todo)
        rows = []
        for (path, dirpath, name, mtime, size), meta in zip(todo, metas):
            if meta is None:
                stats["errors"] += 1
                seen.discard(path)
                continue
            rows.append((path, root, dirpath, name, meta.taken, mtime, size,
                         meta.width, meta.height, meta.lat, meta.lon))
            stats["updated" if path in existing else "added"] += 1
        with conn:
            conn.executemany(UPSERT, rows)
        todo.clear()

    with ThreadPoolExecutor(max_workers=4) as executor:
        stack = [root]
        while stack:
            if should_stop():
                return stats
            dirpath = stack.pop()
            try:
                with os.scandir(dirpath) as it:
                    entries = list(it)
            except OSError as exc:
                log.info("skipping %s: %s", dirpath, exc)
                error_dirs.append(dirpath)
                stats["errors"] += 1
                continue
            for e in entries:
                try:
                    if e.is_dir(follow_symlinks=False):
                        if not should_skip_dir(e.name):
                            stack.append(e.path)
                        continue
                    if os.path.splitext(e.name)[1].lower() not in exts:
                        continue
                    if not e.is_file():
                        continue
                    st = e.stat()
                except OSError:
                    stats["errors"] += 1
                    continue
                if st.st_size < min_bytes:
                    continue
                seen.add(e.path)
                stats["found"] += 1
                old = existing.get(e.path)
                if old and old[0] == st.st_mtime and old[1] == st.st_size:
                    continue
                todo.append((e.path, dirpath, e.name, st.st_mtime, st.st_size))
                if len(todo) >= BATCH:
                    flush(executor)
            now = time.monotonic()
            if progress and now - last_emit > 0.1:
                last_emit = now
                progress(stats["found"], dirpath)
        flush(executor)

    gone = [
        p for p in existing
        if p not in seen and not any(_is_within(p, d) for d in error_dirs)
    ]
    if gone:
        db.delete_paths(gone)
        stats["removed"] = len(gone)
    return stats


class ScanThread(QThread):
    """Scans the given folder entries off the GUI thread."""

    progress = Signal(int, str)  # files found so far, current directory
    scanFinished = Signal(dict)

    def __init__(self, entries: list[dict], min_size_kb: int, parent=None):
        super().__init__(parent)
        self.entries = entries
        self.min_size_kb = min_size_kb

    def run(self):
        total = {"found": 0, "added": 0, "updated": 0, "removed": 0, "errors": 0,
                 "unavailable": [], "cancelled": False}
        base = 0
        for entry in self.entries:
            if self.isInterruptionRequested():
                total["cancelled"] = True
                break
            try:
                stats = scan_root(
                    entry,
                    self.min_size_kb,
                    self.isInterruptionRequested,
                    lambda n, d, b=base: self.progress.emit(b + n, d),
                )
            except Exception as exc:  # never let one folder kill the scan
                log.exception("scan of %s failed: %s", entry.get("path"), exc)
                total["errors"] += 1
                continue
            if stats.pop("unavailable", False):
                total["unavailable"].append(entry["path"])
            for k, v in stats.items():
                total[k] += v
            base = total["found"]
        self.scanFinished.emit(total)
