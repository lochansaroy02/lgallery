"""Gallery controller: glue between settings, scanner, watcher, models and QML."""

import configparser
import logging
import os

from PySide6.QtCore import (
    Property, QFileSystemWatcher, QObject, Qt, QTimer, QUrl, Signal, Slot,
)
from PySide6.QtGui import QGuiApplication

from . import CACHE_DIR, CONFIG_PATH, DATA_DIR, DB_PATH, HEIF_SUPPORTED, actions, db, thumbs
from .models import AlbumModel, PhotoModel, format_size
from .scanner import ScanThread, root_available
from .settings import Settings
from .tasks import run_async
from .watcher import FolderWatcher

log = logging.getLogger(__name__)

MOUNT_POLL_MS = 10_000
WATCH_DEBOUNCE_MS = 2_000
LIVE_RELOAD_MS = 4_000


def _kde_prefers_dark() -> bool | None:
    path = os.path.join(
        os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "kdeglobals"
    )
    parser = configparser.RawConfigParser(strict=False, interpolation=None)
    try:
        if not parser.read(path, encoding="utf-8"):
            return None
        rgb = parser["Colors:Window"]["BackgroundNormal"]
        r, g, b = (int(x) for x in rgb.split(",")[:3])
    except (configparser.Error, KeyError, ValueError, UnicodeDecodeError):
        return None
    return (0.299 * r + 0.587 * g + 0.114 * b) < 128


class Gallery(QObject):
    foldersChanged = Signal()
    scanningChanged = Signal()
    scanProgressChanged = Signal()
    systemDarkChanged = Signal()
    cacheSizeChanged = Signal()
    toast = Signal(str)
    itemsRemoved = Signal()

    def __init__(self, settings: Settings, parent=None):
        super().__init__(parent)
        self.settings = settings
        cols = settings.columns
        self.photos = PhotoModel(cols, "all", parent=self)
        self.albumPhotos = PhotoModel(cols, "none", auto_load=False, parent=self)
        self.searchPhotos = PhotoModel(cols, "none", auto_load=False, parent=self)
        self.albums = AlbumModel(settings, parent=self)
        self._grids = (self.photos, self.albumPhotos, self.searchPhotos)
        settings.columnsChanged.connect(self._sync_columns)

        self._folders: list[dict] = []
        self._availability: dict[str, bool] = {}
        self._scan: ScanThread | None = None
        self._pending_roots: set[str] | None = None  # None = nothing queued
        self._removals: list[str] = []
        self._found = 0
        self._scan_dir = ""
        self._cache_size = ""

        self._watcher = FolderWatcher(self)
        self._watch_changed: set[str] = set()
        self._watcher.rootChanged.connect(self._on_watch_event, Qt.QueuedConnection)
        self._watch_timer = QTimer(self, singleShot=True, interval=WATCH_DEBOUNCE_MS)
        self._watch_timer.timeout.connect(self._flush_watch_events)
        settings.liveUpdatesChanged.connect(self._update_watcher)

        self._mount_timer = QTimer(self, interval=MOUNT_POLL_MS)
        self._mount_timer.timeout.connect(self._poll_mounts)
        self._mount_timer.start()

        self._live_reload = QTimer(self, interval=LIVE_RELOAD_MS)
        self._live_reload.timeout.connect(self._reload_grids)

        self._system_dark = False
        hints = QGuiApplication.styleHints()
        if hasattr(hints, "colorSchemeChanged"):
            hints.colorSchemeChanged.connect(self._update_system_dark)
        self._kde_watch = QFileSystemWatcher(self)
        kdeglobals = os.path.join(
            os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "kdeglobals"
        )
        if os.path.exists(kdeglobals):
            self._kde_watch.addPath(kdeglobals)
            self._kde_watch.fileChanged.connect(lambda *_: self._update_system_dark())
        self._update_system_dark()

        self._refresh_folders()
        self._update_watcher()
        if self._folders:
            QTimer.singleShot(300, self.rescan)

    # ---- theme -----------------------------------------------------------------
    def _update_system_dark(self, *_):
        dark = None
        hints = QGuiApplication.styleHints()
        if hasattr(hints, "colorScheme"):
            scheme = hints.colorScheme()
            if scheme == Qt.ColorScheme.Dark:
                dark = True
            elif scheme == Qt.ColorScheme.Light:
                dark = False
        if dark is None:
            dark = bool(_kde_prefers_dark())
        if dark != self._system_dark:
            self._system_dark = dark
            self.systemDarkChanged.emit()

    @Property(bool, notify=systemDarkChanged)
    def systemDark(self):
        return self._system_dark

    # ---- folders ------------------------------------------------------------------
    def _refresh_folders(self):
        entries = self.settings.folder_entries()
        self._availability = {e["path"]: root_available(e) for e in entries}
        self._folders = [
            {
                "path": e["path"],
                "name": os.path.basename(e["path"]) or e["path"],
                "mount": e.get("mount", "/"),
                "available": self._availability[e["path"]],
                "count": -1,
            }
            for e in entries
        ]
        self.foldersChanged.emit()
        run_async(db.root_counts, on_done=self._apply_counts)

    def _apply_counts(self, counts):
        for f in self._folders:
            f["count"] = counts.get(f["path"], 0)
        self.foldersChanged.emit()

    @Property("QVariantList", notify=foldersChanged)
    def folders(self):
        return self._folders

    @Property(bool, notify=foldersChanged)
    def hasFolders(self):
        return bool(self._folders)

    @Property(str, notify=foldersChanged)
    def suggestedFolder(self):
        pictures = os.path.expanduser("~/Pictures")
        if os.path.isdir(pictures) and pictures not in self.settings.folder_paths():
            return pictures
        return ""

    @Slot(str, result=str)
    def addFolder(self, folder):
        path = QUrl(folder).toLocalFile() if folder.startswith("file:") else folder
        error, replaced = self.settings.add_folder(path)
        if error:
            self.toast.emit(error)
            return error
        added = os.path.normpath(os.path.abspath(os.path.expanduser(path)))
        self._refresh_folders()
        self._update_watcher()
        self.rescan_roots({added})
        if replaced:
            self.toast.emit(f"Merged {len(replaced)} sub-folder(s) into {os.path.basename(added)}")
        return ""

    @Slot(str)
    def removeFolder(self, path):
        if not self.settings.remove_folder(path):
            return
        self._refresh_folders()
        self._update_watcher()
        if self._scan is not None:
            # stop the scan first so it cannot re-add rows for this folder;
            # the removal and a rescan of the remaining folders run when it ends
            self._removals.append(path)
            self._pending_roots = set(self.settings.folder_paths())
            self._scan.requestInterruption()
            return
        self._remove_rows(path)

    def _remove_rows(self, path):
        def done(count):
            self.toast.emit(f"Removed {count:,} item(s) from the gallery. Files were not touched.")
            self._reload_all()
            self._refresh_folders()

        run_async(db.remove_root, path, on_done=done)

    # ---- scanning --------------------------------------------------------------------
    @Slot()
    def rescan(self):
        self.rescan_roots(set(self.settings.folder_paths()))

    def rescan_roots(self, roots: set[str]):
        if not roots:
            return
        if self._scan is not None:
            self._pending_roots = (self._pending_roots or set()) | roots
            return
        entries = [e for e in self.settings.folder_entries() if e["path"] in roots]
        if not entries:
            return
        self._found = 0
        self._scan_dir = ""
        self._scan = ScanThread(entries, self.settings.minSizeKb)
        self._scan.progress.connect(self._on_progress)
        self._scan.scanFinished.connect(self._on_scan_finished)
        self._scan.finished.connect(self._scan.deleteLater)
        self._scan.start()
        self._live_reload.start()
        self.scanningChanged.emit()
        self.scanProgressChanged.emit()

    def _on_progress(self, found, directory):
        self._found = found
        self._scan_dir = directory
        self.scanProgressChanged.emit()

    def _on_scan_finished(self, stats):
        self._scan = None
        self._live_reload.stop()
        self.scanningChanged.emit()
        log.info("scan finished: %s", stats)
        removals, self._removals = self._removals, []
        for path in removals:
            self._remove_rows(path)
        self._reload_all()
        self._refresh_folders()
        for root in stats.get("unavailable", []):
            self.toast.emit(f"{os.path.basename(root) or root} is not available (drive unmounted?)")
        if self._pending_roots is not None:
            roots, self._pending_roots = self._pending_roots, None
            self.rescan_roots(roots & set(self.settings.folder_paths()))

    @Property(bool, notify=scanningChanged)
    def scanning(self):
        return self._scan is not None

    @Property(int, notify=scanProgressChanged)
    def scanFound(self):
        return self._found

    @Property(str, notify=scanProgressChanged)
    def scanDir(self):
        return self._scan_dir

    def _reload_grids(self):
        for m in self._grids:
            if m.filterKind != "none":
                m.reload()

    def _reload_all(self):
        self._reload_grids()
        self.albums.reload()

    @Slot()
    def reloadLibrary(self):
        """Refresh every view after files were changed by the app (editor, trash)."""
        self._reload_all()
        self._refresh_folders()

    def _sync_columns(self):
        for m in self._grids:
            m.columns = self.settings.columns

    # ---- live updates / mounts ----------------------------------------------------------
    def _update_watcher(self):
        if self.settings.liveUpdates:
            roots = [p for p, ok in self._availability.items() if ok]
            failed = self._watcher.watch(roots)
            if failed:
                self.toast.emit("Live updates unavailable for some folders (inotify limit?)")
        else:
            self._watcher.stop()

    def _on_watch_event(self, root):
        self._watch_changed.add(root)
        self._watch_timer.start()

    def _flush_watch_events(self):
        roots, self._watch_changed = self._watch_changed, set()
        self.rescan_roots(roots)

    def _poll_mounts(self):
        changed = set()
        for e in self.settings.folder_entries():
            ok = root_available(e)
            if self._availability.get(e["path"]) != ok:
                changed.add(e["path"])
        if changed:
            self._refresh_folders()
            self._update_watcher()
            self.rescan_roots(changed)

    @Property(bool, constant=True)
    def liveUpdatesSupported(self):
        return self._watcher.available

    @Property(bool, constant=True)
    def heifSupported(self):
        return HEIF_SUPPORTED

    def shutdown(self):
        self._watcher.stop()
        if self._scan is not None:
            self._scan.requestInterruption()
            self._scan.wait(5000)

    # ---- actions ---------------------------------------------------------------------------
    @Slot("QVariantList", bool)
    def setFavorite(self, ids, value):
        ids = [int(i) for i in ids]

        def done(_):
            for m in self._grids:
                m.apply_favorite(ids, value)
            self.albums.reload()

        run_async(db.set_favorite, ids, value, on_done=done)

    @Slot("QStringList")
    def trash(self, paths):
        def work(paths):
            trashed, failed = actions.trash_files(paths)
            db.delete_paths(trashed)
            return trashed, failed

        def done(result):
            trashed, failed = result
            if failed:
                self.toast.emit(f"Could not move {len(failed)} item(s) to the trash")
            elif trashed:
                self.toast.emit(f"Moved {len(trashed)} item(s) to the trash")
            self._reload_all()
            self._refresh_folders()
            self.itemsRemoved.emit()

        run_async(work, list(paths), on_done=done)

    @Slot("QStringList")
    def copyPaths(self, paths):
        actions.copy_text("\n".join(paths))
        self.toast.emit("Path copied" if len(paths) == 1 else f"{len(paths)} paths copied")

    @Slot("QStringList")
    def shareFiles(self, paths):
        actions.copy_files(list(paths))
        self.toast.emit("Copied to clipboard. Paste into any app to share.")

    @Slot(str)
    def openExternally(self, path):
        if not actions.open_default(path):
            self.toast.emit("No application is set up to open this file")

    @Slot(str)
    def showInFolder(self, path):
        def done(ok):
            if not ok:
                actions.open_folder(path)

        run_async(actions.show_in_folder_blocking, path, on_done=done,
                  on_error=lambda _e: actions.open_folder(path))

    @Slot(str, result="QVariantList")
    def appsFor(self, path):
        try:
            return actions.apps_for_file(path)
        except Exception as exc:
            log.warning("listing applications failed: %s", exc)
            return []

    @Slot(str, "QStringList")
    def openWith(self, desktop_file, paths):
        if not actions.launch_desktop_app(desktop_file, list(paths)):
            self.toast.emit("Could not start the application")

    # ---- cache / info --------------------------------------------------------------------
    @Slot()
    def refreshCacheSize(self):
        def done(size):
            self._cache_size = format_size(size)
            self.cacheSizeChanged.emit()

        run_async(thumbs.cache_size, on_done=done)

    @Slot()
    def clearThumbnailCache(self):
        def done(_):
            self.toast.emit("Thumbnail cache cleared")
            self.refreshCacheSize()

        run_async(thumbs.clear_cache, on_done=done)

    @Property(str, notify=cacheSizeChanged)
    def cacheSize(self):
        return self._cache_size

    @Property("QVariantMap", constant=True)
    def locations(self):
        return {"config": str(CONFIG_PATH), "index": str(DB_PATH), "cache": str(CACHE_DIR),
                "originals": str(DATA_DIR / "originals")}
