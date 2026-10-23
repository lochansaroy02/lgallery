"""Collections tab: Stories, Places and People (exposed to QML as `collections`)."""

import logging
from datetime import date

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

from . import db, faces, geo, stories
from .models import version
from .scanner import META_VER, read_metadata
from .tasks import run_async

log = logging.getLogger(__name__)


def backfill_metadata(batch=500) -> int:
    """Read GPS for pictures indexed before GPS support (runs in a worker)."""
    conn = db.connect()
    total = 0
    while True:
        rows = conn.execute(
            "SELECT id, path, mtime FROM images WHERE meta_ver < ? AND available = 1 LIMIT ?",
            (META_VER, batch)).fetchall()
        if not rows:
            return total
        updates = []
        for iid, path, mtime in rows:
            meta = read_metadata(path, mtime)
            lat, lon = (meta.lat, meta.lon) if meta else (None, None)
            updates.append((lat, lon, META_VER, iid))
        with conn:
            conn.executemany(
                "UPDATE images SET lat = ?, lon = ?, meta_ver = ?, place = NULL WHERE id = ?", updates)
        total += len(rows)


def update_places() -> dict:
    backfill_metadata()
    geo.assign_places()
    conn = db.connect()
    gps = conn.execute("SELECT COUNT(*) FROM images WHERE lat IS NOT NULL").fetchone()[0]
    rows = conn.execute(
        "SELECT country, place, COUNT(*), MAX(taken), id, mtime, size FROM images "
        "WHERE place IS NOT NULL AND available = 1 GROUP BY country, place").fetchall()
    places = [{
        "key": f"{place}\t{country}", "place": place, "country": country or "",
        "count": count, "cover": f"image://thumbs/{iid}/{version(mtime, size)}",
    } for country, place, count, _latest, iid, mtime, size in rows]
    places.sort(key=lambda p: (-p["count"], p["place"]))
    return {"gps": gps, "places": places}


class Collections(QObject):
    storiesChanged = Signal()
    placesChanged = Signal()
    peopleChanged = Signal()
    stateChanged = Signal()

    def __init__(self, gallery, settings, parent=None):
        super().__init__(parent)
        self.gallery = gallery
        self.settings = settings
        self._stories: list = []
        self._story_day = None
        self._places: list = []
        self._gps_count = 0
        self._places_loaded = False
        self._people: list = []
        self._hidden_people: list = []
        self._downloading = ""          # "", "places", "faces"
        self._progress = 0.0
        self._face_thread = None
        self._face_done = 0
        self._face_total = 0
        self._engine = faces.engine_available()

        self._refresh_timer = QTimer(self, singleShot=True, interval=1500)
        self._refresh_timer.timeout.connect(self.refresh)
        gallery.libraryReloaded.connect(self._refresh_timer.start)
        self._day_timer = QTimer(self, interval=10 * 60 * 1000)
        self._day_timer.timeout.connect(self._check_day)
        self._day_timer.start()
        QTimer.singleShot(1200, self.refresh)

    # ---- refresh -------------------------------------------------------------------------------
    @Slot()
    def refresh(self):
        self._load_stories()
        self._load_places()
        self._load_people()
        self._maybe_index_faces()

    def _check_day(self):
        if self._story_day != date.today():
            self._load_stories()

    def _load_stories(self):
        def done(result):
            self._stories = result
            self._story_day = date.today()
            self.storiesChanged.emit()

        run_async(stories.memories, on_done=done)

    def _load_places(self):
        def done(result):
            self._gps_count = result["gps"]
            self._places = result["places"]
            self._places_loaded = True
            self.placesChanged.emit()
            self.stateChanged.emit()

        run_async(update_places, on_done=done)

    def _load_people(self):
        def done(result):
            visible, hidden = result
            self._people, self._hidden_people = visible, hidden
            self.peopleChanged.emit()

        run_async(lambda: ([p for p in faces.list_people(True) if not p["hidden"]],
                           [p for p in faces.list_people(True) if p["hidden"]]), on_done=done)

    # ---- downloads ----------------------------------------------------------------------------
    def _download(self, kind, job, then):
        if self._downloading:
            return
        self._downloading = kind
        self._progress = 0.0
        self.stateChanged.emit()

        def progress(done, total):
            # called from the worker thread: only store a number, the UI polls it
            self._progress = (done / total) if total else 0.0

        poll = QTimer(self, interval=200)
        poll.timeout.connect(self.stateChanged.emit)
        poll.start()

        def finished(_):
            poll.stop()
            poll.deleteLater()
            self._downloading = ""
            self.stateChanged.emit()
            then()

        def failed(exc):
            poll.stop()
            poll.deleteLater()
            self._downloading = ""
            self.stateChanged.emit()
            self.gallery.toast.emit(f"Download failed: {exc}")

        run_async(job, progress, on_done=finished, on_error=failed)

    @Slot()
    def downloadPlaceNames(self):
        def then():
            self.gallery.toast.emit("Place names downloaded")
            self._load_places()

        self._download("places", geo.download, then)

    # ---- people -------------------------------------------------------------------------------
    @Slot()
    def enablePeople(self):
        if not self._engine:
            self.gallery.toast.emit("Face grouping needs OpenCV: run ./update.sh")
            return
        self.settings.facesEnabled = True
        self.stateChanged.emit()
        if faces.models_ready():
            self._maybe_index_faces()
        else:
            self._download("faces", faces.download_models, self._maybe_index_faces)

    @Slot(bool)
    def disablePeople(self, delete_data):
        self.settings.facesEnabled = False
        if self._face_thread is not None:
            self._face_thread.requestInterruption()
        if delete_data:
            def done(_):
                self.gallery.toast.emit("Face data deleted")
                self._load_people()
            run_async(faces.delete_face_data, on_done=done)
        self.stateChanged.emit()

    def _maybe_index_faces(self):
        if (not self.settings.facesEnabled or not self._engine or not faces.models_ready()
                or self._face_thread is not None or self._downloading):
            return
        thread = faces.FaceIndexThread()
        thread.setObjectName("faces")
        thread.progress.connect(self._on_face_progress)
        thread.indexFinished.connect(self._on_face_finished)
        thread.finished.connect(thread.deleteLater)
        self._face_thread = thread
        self._face_done, self._face_total = 0, 0
        thread.start(thread.Priority.LowPriority)
        self.stateChanged.emit()

    def _on_face_progress(self, done, total):
        first = self._face_total == 0 and total > 0
        self._face_done, self._face_total = done, total
        self.stateChanged.emit()
        if done and (first or done % 200 < 8):
            self._load_people()

    def _on_face_finished(self, stats):
        self._face_thread = None
        log.info("faces: %s", stats)
        if stats.get("error"):
            self.gallery.toast.emit("Face grouping failed to start (see log)")
        elif stats.get("new_people"):
            n = stats["new_people"]
            self.gallery.toast.emit(f"Found {n} new {'person' if n == 1 else 'people'}")
        self.stateChanged.emit()
        self._load_people()

    def _people_job(self, fn, *args):
        def done(_):
            self._load_people()
            self.gallery.reloadLibrary()
        run_async(fn, *args, on_done=done)

    @Slot(int, str)
    def renamePerson(self, person_id, name):
        def job(pid, name):
            with db.connect() as conn:
                conn.execute("UPDATE persons SET name = ? WHERE id = ?", (name.strip(), pid))
        self._people_job(job, person_id, name)

    @Slot(int, int)
    def mergePeople(self, source, target):
        if source != target:
            self._people_job(faces.merge_people, source, target)

    @Slot(int, bool)
    def setPersonHidden(self, person_id, hidden):
        def job(pid, hidden):
            with db.connect() as conn:
                conn.execute("UPDATE persons SET hidden = ? WHERE id = ?", (int(hidden), pid))
        self._people_job(job, person_id, hidden)

    @Slot(int, result=str)
    def personName(self, person_id):
        for p in self._people + self._hidden_people:
            if p["id"] == person_id:
                return p["name"]
        return ""

    def shutdown(self):
        if self._face_thread is not None:
            self._face_thread.requestInterruption()
            self._face_thread.wait(5000)

    # ---- properties -----------------------------------------------------------------------------
    @Property("QVariantList", notify=storiesChanged)
    def stories(self):
        return self._stories

    @Property("QVariantList", notify=placesChanged)
    def places(self):
        return self._places

    @Property(str, notify=stateChanged)
    def placesState(self):
        if self._downloading == "places":
            return "downloading"
        if not self._places_loaded:
            return "loading"
        if self._gps_count == 0:
            return "no-gps"
        if not geo.data_available():
            return "need-data"
        return "ready"

    @Property(int, notify=placesChanged)
    def gpsCount(self):
        return self._gps_count

    @Property("QVariantList", notify=peopleChanged)
    def people(self):
        return self._people

    @Property("QVariantList", notify=peopleChanged)
    def hiddenPeople(self):
        return self._hidden_people

    @Property(str, notify=stateChanged)
    def peopleState(self):
        if not self._engine:
            return "unavailable"
        if self._downloading == "faces":
            return "downloading"
        if not self.settings.facesEnabled:
            return "off"
        if self._face_thread is not None:
            return "scanning"
        return "ready"

    @Property(float, notify=stateChanged)
    def downloadProgress(self):
        return self._progress

    @Property(int, notify=stateChanged)
    def facesDone(self):
        return self._face_done

    @Property(int, notify=stateChanged)
    def facesTotal(self):
        return self._face_total
