"""Stories ("memories"): pictures taken around today's date in earlier years."""

from datetime import date, datetime, timedelta

from PySide6.QtCore import QDate, QLocale

from . import db
from .models import version

WINDOW_DAYS = 3        # today ± 3 days
PER_STORY = 24         # pictures per story
BURST_SECONDS = 4      # pictures closer than this count as one moment


def _anniversary_years_ago(d: date, today: date, window: int) -> int | None:
    """How many years ago d is, if its day falls within today ± window (any year)."""
    for offset in (-1, 0, 1):
        year = today.year + offset
        try:
            candidate = d.replace(year=year)
        except ValueError:          # 29 February
            candidate = date(year, 3, 1)
        if abs((candidate - today).days) <= window:
            years = year - d.year
            return years if years >= 1 else None
    return None


def _pick(rows: list, limit: int) -> list:
    """Drop bursts, keep favorites, spread the rest evenly over the day(s)."""
    rows = sorted(rows, key=lambda r: r[2])
    moments, last = [], None
    for r in rows:
        if last is not None and r[2] - last[2] < BURST_SECONDS and not r[7]:
            continue
        moments.append(r)
        last = r
    if len(moments) <= limit:
        return moments
    favorites = [r for r in moments if r[7]][:limit]
    others = [r for r in moments if not r[7]]
    room = limit - len(favorites)
    step = len(others) / room if room else 0
    chosen = favorites + [others[int(i * step)] for i in range(room)]
    return sorted(chosen, key=lambda r: r[2])


def memories(today: date | None = None) -> list[dict]:
    """One story per earlier year that has pictures near today's date. Runs in a worker."""
    today = today or date.today()
    days = [(today + timedelta(days=k)) for k in range(-WINDOW_DAYS, WINDOW_DAYS + 1)]
    month_days = sorted({d.strftime("%m-%d") for d in days} | ({"02-29"} if any(
        d.month == 3 and d.day == 1 for d in days) else set()))
    marks = ",".join("?" * len(month_days))
    rows = db.connect().execute(
        "SELECT id, path, taken, mtime, size, width, height, favorite FROM images "
        "WHERE available = 1 AND strftime('%m-%d', taken, 'unixepoch', 'localtime') IN (" + marks + ")",
        month_days).fetchall()
    by_years: dict[int, list] = {}
    for r in rows:
        try:
            d = datetime.fromtimestamp(r[2]).date()
        except (OverflowError, OSError, ValueError):
            continue
        years = _anniversary_years_ago(d, today, WINDOW_DAYS)
        if years:
            by_years.setdefault(years, []).append(r)

    locale = QLocale()
    stories = []
    for years in sorted(by_years):
        picked = _pick(by_years[years], PER_STORY)
        if not picked:
            continue
        first = datetime.fromtimestamp(picked[0][2]).date()
        last = datetime.fromtimestamp(picked[-1][2]).date()
        if first == last:
            subtitle = locale.toString(QDate(first.year, first.month, first.day), "MMMM d, yyyy")
        elif first.month == last.month:
            subtitle = (locale.toString(QDate(first.year, first.month, first.day), "MMMM d")
                        + f" – {last.day}, {last.year}")
        else:
            subtitle = (locale.toString(QDate(first.year, first.month, first.day), "MMM d")
                        + " – " + locale.toString(QDate(last.year, last.month, last.day), "MMM d, yyyy"))
        cover = next((r for r in picked if r[7]), picked[len(picked) // 2])
        items = [{
            "id": r[0], "path": r[1],
            "thumb": f"image://thumbs/{r[0]}/{version(r[3], r[4])}",
            "full": f"image://full/{r[0]}/{version(r[3], r[4])}",
            "width": r[5], "height": r[6],
            "date": locale.toString(QDate(*datetime.fromtimestamp(r[2]).timetuple()[:3]), "dddd, MMMM d, yyyy"),
        } for r in picked]
        stories.append({
            "key": years,
            "title": "1 year ago" if years == 1 else f"{years} years ago",
            "subtitle": subtitle,
            "cover": f"image://thumbs/{cover[0]}/{version(cover[3], cover[4])}",
            "count": len(items),
            "items": items,
        })
    return stories
