"""Live updates through watchdog (inotify on Linux). Optional: disabled if not installed."""

import logging
import os

from PySide6.QtCore import QObject, Signal

from . import supported_exts
from .scanner import should_skip_dir

log = logging.getLogger(__name__)

try:
    from watchdog.events import FileSystemEventHandler
    from watchdog.observers import Observer

    WATCHDOG_AVAILABLE = True
except ImportError:
    FileSystemEventHandler = object
    Observer = None
    WATCHDOG_AVAILABLE = False


class _Handler(FileSystemEventHandler):
    def __init__(self, root: str, emit):
        super().__init__()
        self.root = root
        # events may arrive with the resolved path (symlinks, /private on macOS)
        self.prefixes = {root.rstrip(os.sep), os.path.realpath(root).rstrip(os.sep)}
        self.emit = emit
        self.exts = supported_exts()

    def _relevant(self, path) -> bool:
        if isinstance(path, bytes):
            path = os.fsdecode(path)
        rel = None
        for prefix in self.prefixes:
            if path.startswith(prefix + os.sep):
                rel = path[len(prefix) + 1:]
                break
        if rel is None:
            return path.rstrip(os.sep) in self.prefixes
        parts = rel.split(os.sep)
        if any(should_skip_dir(p) for p in parts[:-1]):
            return False
        name = parts[-1]
        if name.startswith("."):
            return False
        ext = os.path.splitext(name)[1].lower()
        return ext in self.exts or ext == ""  # "" covers directory moves/deletes

    def on_any_event(self, event):
        if event.event_type in ("opened", "closed_no_write"):
            return
        paths = [event.src_path, getattr(event, "dest_path", "")]
        if any(p and self._relevant(p) for p in paths):
            self.emit(self.root)


class FolderWatcher(QObject):
    """Emits rootChanged(root) from watchdog's thread; Qt queues it to the GUI thread."""

    rootChanged = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._observer = None
        self._roots: tuple = ()

    @property
    def available(self) -> bool:
        return WATCHDOG_AVAILABLE

    def watch(self, roots: list[str]) -> list[str]:
        """(Re)start watching roots. Returns the roots that could not be watched."""
        roots_t = tuple(sorted(r for r in roots if os.path.isdir(r)))
        if roots_t == self._roots and self._observer is not None:
            return []
        self.stop()
        if not WATCHDOG_AVAILABLE or not roots_t:
            return []
        failed = []
        observer = Observer()
        for root in roots_t:
            try:
                observer.schedule(_Handler(root, self.rootChanged.emit), root, recursive=True)
            except OSError as exc:  # e.g. inotify watch limit reached
                log.warning("cannot watch %s: %s", root, exc)
                failed.append(root)
        try:
            observer.daemon = True
            observer.start()
        except OSError as exc:
            log.warning("file watcher failed to start: %s", exc)
            return list(roots_t)
        self._observer = observer
        self._roots = roots_t
        return failed

    def stop(self):
        if self._observer is not None:
            try:
                self._observer.stop()
                self._observer.join(timeout=2)
            except Exception as exc:
                log.debug("stopping watcher: %s", exc)
        self._observer = None
        self._roots = ()
