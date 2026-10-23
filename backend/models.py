"""Qt models: the date-grouped photo grid and the album list.

The photo grid is a ListView whose rows are runs of `columns` thumbnails; each
row carries its day as the ListView section, which gives One UI style sticky
day headers without a nested view per day.
"""

import bisect
import calendar
import logging
import os
from datetime import date, datetime

from PySide6.QtCore import (
    QAbstractListModel, QByteArray, QDate, QLocale, QModelIndex, Property, Qt,
    QUrl, Signal, Slot,
)

from . import db, external
from .tasks import run_async

log = logging.getLogger(__name__)

# item layout (lists so favorite can be updated in place)
F_ID, F_PATH, F_TAKEN, F_MTIME, F_W, F_H, F_SIZE, F_AVAIL, F_FAV, F_DAY = range(10)

COLUMNS_SQL = "id, path, taken, mtime, width, height, size, available, favorite"


def _day_ordinal(ts: int) -> int:
    try:
        return datetime.fromtimestamp(ts).toordinal()
    except (OverflowError, OSError, ValueError):
        return date(1970, 1, 1).toordinal()


def _escape_like(text: str) -> str:
    return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _month_names() -> dict[str, int]:
    names = {}
    locale = QLocale()
    for m in range(1, 13):
        for n in (calendar.month_name[m], calendar.month_abbr[m],
                  locale.monthName(m, QLocale.LongFormat),
                  locale.monthName(m, QLocale.ShortFormat)):
            if n:
                names[n.lower().rstrip(".")] = m
    return names


def build_filter(kind: str, value: str) -> tuple[str, list]:
    """SQL WHERE clause for a grid filter."""
    if kind == "root":
        return "root = ?", [value]
    if kind == "dir":
        return "dir = ?", [value]
    if kind == "favorites":
        return "favorite = 1", []
    if kind == "search":
        clauses, params = [], []
        months = _month_names()
        for token in value.split():
            low = token.lower().rstrip(".,")
            if len(low) == 4 and low.isdigit():
                clauses.append("strftime('%Y', taken, 'unixepoch', 'localtime') = ?")
                params.append(low)
            elif low in months:
                clauses.append("strftime('%m', taken, 'unixepoch', 'localtime') = ?")
                params.append(f"{months[low]:02d}")
            else:
                like = f"%{_escape_like(token)}%"
                clauses.append("(name LIKE ? ESCAPE '\\' OR dir LIKE ? ESCAPE '\\')")
                params += [like, like]
        if not clauses:
            return "0", []
        return " AND ".join(clauses), params
    return "1", []


def query_items(where: str, params: list, ascending: bool = False) -> list[list]:
    """Runs in a worker thread."""
    order = "taken ASC, path ASC" if ascending else "taken DESC, path DESC"
    rows = db.connect().execute(
        f"SELECT {COLUMNS_SQL} FROM images WHERE {where} ORDER BY {order}",
        params,
    ).fetchall()
    return [list(r) + [_day_ordinal(r[2])] for r in rows]


def format_size(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n} B"


def version(mtime, size) -> str:
    """Changes whenever the file content changes; part of image URLs and cache keys."""
    return f"{int(mtime)}-{size}"


def thumb_url(item) -> str:
    return f"image://thumbs/{item[F_ID]}/{version(item[F_MTIME], item[F_SIZE])}"


class PhotoModel(QAbstractListModel):
    ItemsRole = Qt.UserRole + 1
    SectionRole = Qt.UserRole + 2
    RowStartRole = Qt.UserRole + 3

    columnsChanged = Signal()
    itemCountChanged = Signal()
    selectionChanged = Signal()
    loadingChanged = Signal()
    filterChanged = Signal()
    viewAboutToReset = Signal()
    viewReset = Signal()

    def __init__(self, columns=5, kind="all", value="", auto_load=True, parent=None):
        super().__init__(parent)
        self._items: list[list] = []
        self._rows: list[tuple[int, int, int]] = []  # (start, end, day)
        self._row_starts: list[int] = []
        self._columns = columns
        self._selected: set[int] = set()
        self._anchor = -1
        self._kind, self._value = kind, value
        self._generation = 0
        self._loading = False
        self._label_cache: dict[int, str] = {}
        self._external_files: list[str] = []
        self._external_quick = False
        self._ascending = False
        if auto_load:
            self.reload()

    # ---- loading -------------------------------------------------------
    @Slot()
    def reload(self):
        self._generation += 1
        gen = self._generation
        if self._kind == "none":
            self._apply(gen, [])
            return
        if self._kind == "external":
            self._reload_external(gen)
            return
        where, params = build_filter(self._kind, self._value)
        self._set_loading(True)
        run_async(
            query_items, where, params, self._ascending,
            on_done=lambda items: self._apply(gen, items),
            on_error=lambda exc: self._set_loading(False),
        )

    def _reload_external(self, gen):
        focus, files = self._value, list(self._external_files)

        def full_list():
            paths = files or external.list_folder(os.path.dirname(focus))
            if focus not in paths:
                paths.insert(0, focus)
            return external.load_items(paths)

        def load_rest(items):
            self._apply(gen, items)
            if gen == self._generation:
                run_async(full_list, on_done=lambda all_items: self._apply(gen, all_items),
                          on_error=lambda exc: self._set_loading(False))

        self._set_loading(True)
        if self._external_quick:
            # show the clicked picture immediately, then list the rest of its folder
            self._external_quick = False
            run_async(external.load_items, [focus], on_done=load_rest,
                      on_error=lambda exc: self._set_loading(False))
        else:
            run_async(full_list, on_done=lambda items: self._apply(gen, items),
                      on_error=lambda exc: self._set_loading(False))

    @Slot(str, "QStringList")
    def openExternal(self, focus, files):
        """Browse focus's folder (or only `files`, if several were opened) without indexing it."""
        self._kind, self._value = "external", focus
        self._external_files = [f for f in files if f]
        self._external_quick = True
        self._selected.clear()
        self.selectionChanged.emit()
        self.filterChanged.emit()
        self.reload()

    def _apply(self, gen, items):
        if gen != self._generation:
            return  # a newer query is in flight
        self.viewAboutToReset.emit()
        self.beginResetModel()
        self._items = items
        self._label_cache.clear()
        ids = {it[F_ID] for it in items}
        sel_before = len(self._selected)
        self._selected &= ids
        self._anchor = -1
        self._rebuild_rows()
        self.endResetModel()
        self._set_loading(False)
        self.itemCountChanged.emit()
        if len(self._selected) != sel_before:
            self.selectionChanged.emit()
        self.viewReset.emit()

    def _rebuild_rows(self):
        rows = []
        items, cols, n = self._items, self._columns, len(self._items)
        i = 0
        while i < n:
            day = items[i][F_DAY]
            j = i + 1
            while j < n and items[j][F_DAY] == day:
                j += 1
            for s in range(i, j, cols):
                rows.append((s, min(s + cols, j), day))
            i = j
        self._rows = rows
        self._row_starts = [r[0] for r in rows]

    def _set_loading(self, value):
        if self._loading != value:
            self._loading = value
            self.loadingChanged.emit()

    @Slot(str, str)
    def setFilter(self, kind, value=""):
        if (kind, value) == (self._kind, self._value):
            return
        self._kind, self._value = kind, value
        self._selected.clear()
        self.selectionChanged.emit()
        self.filterChanged.emit()
        self.reload()

    # ---- Qt model API ----------------------------------------------------
    def roleNames(self):
        return {
            self.ItemsRole: QByteArray(b"rowItems"),
            self.SectionRole: QByteArray(b"day"),
            self.RowStartRole: QByteArray(b"rowStart"),
        }

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._rows)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self._rows):
            return None
        start, end, day = self._rows[index.row()]
        if role == self.ItemsRole:
            sel = self._selected
            return [
                {
                    "index": i,
                    "src": thumb_url(it),
                    "selected": it[F_ID] in sel,
                    "available": bool(it[F_AVAIL]),
                    "favorite": bool(it[F_FAV]),
                }
                for i, it in ((i, self._items[i]) for i in range(start, end))
            ]
        if role == self.SectionRole:
            return str(day)
        if role == self.RowStartRole:
            return start
        return None

    def _rows_changed(self, item_indices):
        rows = sorted({self._row_of(i) for i in item_indices})
        for r in rows:
            idx = self.index(r)
            self.dataChanged.emit(idx, idx, [self.ItemsRole])

    def _row_of(self, item_index: int) -> int:
        return max(0, bisect.bisect_right(self._row_starts, item_index) - 1)

    # ---- properties --------------------------------------------------------
    def _get_columns(self):
        return self._columns

    def _set_columns(self, value):
        value = max(1, int(value))
        if value == self._columns:
            return
        self.viewAboutToReset.emit()
        self.beginResetModel()
        self._columns = value
        self._rebuild_rows()
        self.endResetModel()
        self.columnsChanged.emit()
        self.viewReset.emit()

    columns = Property(int, _get_columns, _set_columns, notify=columnsChanged)

    def set_ascending(self, value: bool):
        if bool(value) != self._ascending:
            self._ascending = bool(value)
            if self._kind not in ("none", "external"):
                self.reload()

    @Slot(result="QVariantList")
    def years(self):
        """Years present, in display order (for Go > Jump to Year)."""
        seen = []
        for it in self._items:
            year = date.fromordinal(it[F_DAY]).year
            if not seen or seen[-1] != year:
                if year not in seen:
                    seen.append(year)
        return seen

    @Slot(int, result=int)
    def firstIndexOfYear(self, year):
        for i, it in enumerate(self._items):
            if date.fromordinal(it[F_DAY]).year == year:
                return i
        return -1

    @Property(int, notify=itemCountChanged)
    def itemCount(self):
        return len(self._items)

    @Property(int, notify=selectionChanged)
    def selectionCount(self):
        return len(self._selected)

    @Property(bool, notify=loadingChanged)
    def loading(self):
        return self._loading

    @Property(str, notify=filterChanged)
    def filterKind(self):
        return self._kind

    @Property(str, notify=filterChanged)
    def filterValue(self):
        return self._value

    # ---- lookups used by QML -------------------------------------------------
    @Slot(int, result=int)
    def rowForItem(self, item_index):
        return self._row_of(item_index) if self._rows else -1

    @Slot(int, result=int)
    def firstItemOfRow(self, row):
        if 0 <= row < len(self._rows):
            return self._rows[row][0]
        return -1

    @Slot(int, result=int)
    def idAt(self, item_index):
        if 0 <= item_index < len(self._items):
            return self._items[item_index][F_ID]
        return -1

    @Slot(str, result=int)
    def indexOfPath(self, path):
        for i, it in enumerate(self._items):
            if it[F_PATH] == path:
                return i
        return -1

    @Slot(int, result=int)
    def indexOfId(self, image_id):
        for i, it in enumerate(self._items):
            if it[F_ID] == image_id:
                return i
        return -1

    @Slot(str, result=str)
    def dayLabel(self, day):
        try:
            ordinal = int(day)
        except ValueError:
            return ""
        label = self._label_cache.get(ordinal)
        if label is None:
            d = date.fromordinal(ordinal)
            today = date.today()
            if d == today:
                label = self.tr("Today")
            elif d.toordinal() == today.toordinal() - 1:
                label = self.tr("Yesterday")
            else:
                fmt = "ddd, MMM d" if d.year == today.year else "ddd, MMM d, yyyy"
                label = QLocale().toString(QDate(d.year, d.month, d.day), fmt)
            self._label_cache[ordinal] = label
        return label

    @Slot(int, result=str)
    def monthLabelForRow(self, row):
        if not self._rows:
            return ""
        row = max(0, min(row, len(self._rows) - 1))
        d = date.fromordinal(self._rows[row][2])
        return QLocale().toString(QDate(d.year, d.month, d.day), "MMMM yyyy")

    @Slot(int, result="QVariantMap")
    def itemAt(self, i):
        if not 0 <= i < len(self._items):
            return {}
        it = self._items[i]
        try:
            taken = datetime.fromtimestamp(it[F_TAKEN])
            dt = QLocale().toString(
                QDate(taken.year, taken.month, taken.day), "dddd, MMMM d, yyyy"
            ) + taken.strftime("  %H:%M")
        except (OverflowError, OSError, ValueError):
            dt = ""
        path = it[F_PATH]
        return {
            "index": i,
            "id": it[F_ID],
            "path": path,
            "url": QUrl.fromLocalFile(path).toString(),
            "name": os.path.basename(path),
            "folder": os.path.dirname(path),
            "date": dt,
            "width": it[F_W],
            "height": it[F_H],
            "size": format_size(it[F_SIZE]),
            "available": bool(it[F_AVAIL]),
            "favorite": bool(it[F_FAV]),
            "thumb": thumb_url(it),
            "full": f"image://full/{it[F_ID]}/{version(it[F_MTIME], it[F_SIZE])}",
            "animated": path.lower().endswith(".gif"),
            "selected": it[F_ID] in self._selected,
            "external": it[F_ID] < 0,
        }

    # ---- selection -------------------------------------------------------------
    @Slot(int)
    def toggleSelected(self, i):
        if 0 <= i < len(self._items):
            image_id = self._items[i][F_ID]
            if image_id in self._selected:
                self._selected.discard(image_id)
            else:
                self._selected.add(image_id)
            self._anchor = i
            self._rows_changed([i])
            self.selectionChanged.emit()

    @Slot(int)
    def selectRangeTo(self, i):
        """Shift-click: select everything between the last clicked item and i."""
        if self._anchor < 0:
            self.toggleSelected(i)
            return
        lo, hi = sorted((self._anchor, i))
        hi = min(hi, len(self._items) - 1)
        for k in range(lo, hi + 1):
            self._selected.add(self._items[k][F_ID])
        self._rows_changed(range(lo, hi + 1))
        self.selectionChanged.emit()

    def _day_range(self, day):
        try:
            ordinal = int(day)
        except ValueError:
            return range(0)
        idx = [i for i, it in enumerate(self._items) if it[F_DAY] == ordinal]
        return range(idx[0], idx[-1] + 1) if idx else range(0)

    @Slot(str, result=bool)
    def isDaySelected(self, day):
        r = self._day_range(day)
        return len(r) > 0 and all(self._items[i][F_ID] in self._selected for i in r)

    @Slot(str)
    def toggleDay(self, day):
        r = self._day_range(day)
        ids = [self._items[i][F_ID] for i in r]
        if all(i in self._selected for i in ids):
            self._selected.difference_update(ids)
        else:
            self._selected.update(ids)
        self._rows_changed(r)
        self.selectionChanged.emit()

    @Slot()
    def selectAll(self):
        self._selected = {it[F_ID] for it in self._items}
        if self._rows:
            self.dataChanged.emit(self.index(0), self.index(len(self._rows) - 1), [self.ItemsRole])
        self.selectionChanged.emit()

    @Slot()
    def clearSelection(self):
        if not self._selected:
            return
        self._selected.clear()
        self._anchor = -1
        if self._rows:
            self.dataChanged.emit(self.index(0), self.index(len(self._rows) - 1), [self.ItemsRole])
        self.selectionChanged.emit()

    @Slot(result="QStringList")
    def selectedPaths(self):
        return [it[F_PATH] for it in self._items if it[F_ID] in self._selected]

    @Slot(result="QVariantList")
    def selectedIds(self):
        return [it[F_ID] for it in self._items if it[F_ID] in self._selected]

    @Slot(result=bool)
    def selectionAllFavorite(self):
        sel = [it for it in self._items if it[F_ID] in self._selected]
        return bool(sel) and all(it[F_FAV] for it in sel)

    # ---- in-place updates ------------------------------------------------------
    def apply_favorite(self, ids, value):
        ids = set(ids)
        changed = [i for i, it in enumerate(self._items) if it[F_ID] in ids]
        for i in changed:
            self._items[i][F_FAV] = int(value)
        if changed:
            self._rows_changed(changed)
        if self._kind == "favorites":
            self.reload()


class AlbumModel(QAbstractListModel):
    KeyRole = Qt.UserRole + 1
    TitleRole = Qt.UserRole + 2
    SubtitleRole = Qt.UserRole + 3
    CountRole = Qt.UserRole + 4
    CoverRole = Qt.UserRole + 5
    KindRole = Qt.UserRole + 6
    AvailableRole = Qt.UserRole + 7

    countChanged = Signal()

    def __init__(self, settings, parent=None):
        super().__init__(parent)
        self._settings = settings
        self._albums: list[dict] = []
        self._generation = 0
        settings.albumsBySubfolderChanged.connect(self.reload)
        self.reload()

    @staticmethod
    def _query(by_subfolder: bool) -> list[dict]:
        conn = db.connect()
        albums = []
        fav = conn.execute(
            "SELECT COUNT(*), MAX(taken), id, mtime, size FROM images WHERE favorite = 1"
        ).fetchone()
        if fav and fav[0]:
            albums.append({
                "key": "", "kind": "favorites", "title": "Favorites", "subtitle": "",
                "count": fav[0], "cover": f"image://thumbs/{fav[2]}/{version(fav[3], fav[4])}",
                "available": True, "latest": fav[1] or 0,
            })
        col = "dir" if by_subfolder else "root"
        rows = conn.execute(
            f"SELECT {col}, COUNT(*), MAX(taken), id, mtime, size, SUM(available) "
            f"FROM images GROUP BY {col}"
        ).fetchall()
        folders = []
        for key, count, latest, cover_id, mtime, size, avail in rows:
            folders.append({
                "key": key, "kind": col, "title": os.path.basename(key) or key,
                "subtitle": key, "count": count,
                "cover": f"image://thumbs/{cover_id}/{version(mtime, size)}",
                "available": bool(avail), "latest": latest or 0,
            })
        folders.sort(key=lambda a: a["latest"], reverse=True)
        return albums + folders

    @Slot()
    def reload(self):
        self._generation += 1
        gen = self._generation
        run_async(
            self._query, self._settings.albumsBySubfolder,
            on_done=lambda albums: self._apply(gen, albums),
        )

    def _apply(self, gen, albums):
        if gen != self._generation:
            return
        self.beginResetModel()
        self._albums = albums
        self.endResetModel()
        self.countChanged.emit()

    def roleNames(self):
        return {
            self.KeyRole: QByteArray(b"key"),
            self.TitleRole: QByteArray(b"title"),
            self.SubtitleRole: QByteArray(b"subtitle"),
            self.CountRole: QByteArray(b"count"),
            self.CoverRole: QByteArray(b"cover"),
            self.KindRole: QByteArray(b"kind"),
            self.AvailableRole: QByteArray(b"available"),
        }

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._albums)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self._albums):
            return None
        a = self._albums[index.row()]
        return {
            self.KeyRole: a["key"],
            self.TitleRole: a["title"],
            self.SubtitleRole: a["subtitle"],
            self.CountRole: a["count"],
            self.CoverRole: a["cover"],
            self.KindRole: a["kind"],
            self.AvailableRole: a["available"],
        }.get(role)

    @Property(int, notify=countChanged)
    def count(self):
        return len(self._albums)

    @Property("QVariantList", notify=countChanged)
    def entries(self):
        return [{"kind": a["kind"], "key": a["key"], "title": a["title"], "count": a["count"]}
                for a in self._albums]
