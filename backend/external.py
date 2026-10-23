"""Pictures opened from a file manager ("Open with Gallery") that are not in the library.

Their folder is listed on the fly and never added to the index. Files get stable
negative ids so the image providers and the viewer can treat them like indexed ones;
files that *are* in the library keep their real id (favorites, albums still work).
"""

import os
import re
import threading
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import QUrl

from . import db, supported_exts
from .scanner import read_metadata

_lock = threading.Lock()
_ids: dict[str, int] = {}
_paths: dict[int, str] = {}


def register(path: str) -> int:
    with _lock:
        iid = _ids.get(path)
        if iid is None:
            iid = -(len(_ids) + 1)
            _ids[path] = iid
            _paths[iid] = path
        return iid


def lookup(image_id: int) -> str | None:
    with _lock:
        return _paths.get(image_id)


def natural_key(path: str):
    """Sort like Dolphin: case-insensitive, numbers compared by value (IMG_2 < IMG_10)."""
    name = os.path.basename(path).casefold()
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", name)]


def is_supported(path: str) -> bool:
    return os.path.splitext(path)[1].lower() in supported_exts()


def paths_from_args(args: list[str]) -> list[str]:
    """Command-line arguments (paths or file:// URLs) -> existing supported image files."""
    files = []
    for arg in args:
        if not arg or arg.startswith("-"):
            continue
        path = QUrl(arg).toLocalFile() if arg.startswith("file:") else os.path.expanduser(arg)
        path = os.path.abspath(path)
        if os.path.isfile(path) and is_supported(path) and path not in files:
            files.append(path)
    return files


def list_folder(folder: str) -> list[str]:
    exts = supported_exts()
    try:
        with os.scandir(folder) as it:
            paths = [e.path for e in it
                     if not e.name.startswith(".")
                     and os.path.splitext(e.name)[1].lower() in exts
                     and e.is_file()]
    except OSError:
        return []
    return sorted(paths, key=natural_key)


def load_items(paths: list[str]) -> list[list]:
    """Build PhotoModel items for paths (runs in a worker). Keeps the given order."""
    known = {}
    conn = db.connect()
    for i in range(0, len(paths), 500):
        chunk = paths[i:i + 500]
        marks = ",".join("?" * len(chunk))
        for iid, path, fav in conn.execute(
                f"SELECT id, path, favorite FROM images WHERE path IN ({marks})", chunk):
            known[path] = (iid, fav)

    def meta(path):
        try:
            st = os.stat(path)
        except OSError:
            return None
        info = read_metadata(path, st.st_mtime)
        return (st, info) if info else None

    with ThreadPoolExecutor(max_workers=4) as pool:
        metas = list(pool.map(meta, paths))

    from .models import _day_ordinal  # local import: models imports this module's users

    items = []
    for path, m in zip(paths, metas):
        if m is None:
            continue
        st, meta = m
        taken, w, h = meta.taken, meta.width, meta.height
        iid, fav = known.get(path, (None, 0))
        if iid is None:
            iid = register(path)
        items.append([iid, path, taken, st.st_mtime, w, h, st.st_size, 1, fav,
                      int(meta.video), meta.duration, _day_ordinal(taken)])
    return items
