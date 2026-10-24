"""Video files: metadata (date, size, length, GPS) and poster frames.

ffprobe / ffmpeg (system packages) are used when they are installed. Without them the
date, resolution and length of MP4 / MOV / 3GP files are read straight from the file's
`moov` box, other formats fall back to the file's modification time, and thumbnails are
a neutral placeholder (no cache entry is written, so real posters appear once ffmpeg is
installed).
"""

import io
import json
import logging
import math
import os
import re
import struct
import subprocess
from datetime import datetime, timezone
from typing import NamedTuple

from PIL import Image, ImageDraw

from . import FFMPEG, FFPROBE

log = logging.getLogger(__name__)

PROBE_TIMEOUT = 20
FRAME_TIMEOUT = 30
MP4_EPOCH = 2082844800  # seconds between 1904-01-01 (QuickTime) and 1970-01-01
MAX_MOOV = 64 * 1024 * 1024
MIN_YEAR = 1971  # earlier creation dates are "never set" (0 in either epoch)
ISO6709 = re.compile(rb"([+-]\d{1,2}\.\d+)([+-]\d{1,3}\.\d+)")
CONTAINERS = {b"moov", b"trak", b"mdia", b"minf", b"udta", b"edts"}


class VideoMeta(NamedTuple):
    taken: int | None
    width: int
    height: int
    duration: float
    lat: float | None = None
    lon: float | None = None


def format_duration(seconds: float) -> str:
    """0:07, 4:32, 1:02:03."""
    s = max(0, int(round(seconds or 0)))
    h, rem = divmod(s, 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def _valid_ts(ts) -> int | None:
    try:
        ts = int(ts)
        return ts if datetime.fromtimestamp(ts).year >= MIN_YEAR else None
    except (OverflowError, OSError, ValueError, TypeError):
        return None


def parse_iso_date(value: str) -> int | None:
    """creation_time tags: 2024-05-01T10:20:30.000000Z, 2024-05-01T12:20:30+0200, ..."""
    if not value:
        return None
    value = value.strip()
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    value = re.sub(r"([+-]\d\d)(\d\d)$", r"\1:\2", value)   # +0200 -> +02:00
    value = re.sub(r"\.(\d{6})\d+", r".\1", value)            # Python wants <= 6 digits
    try:
        dt = datetime.fromisoformat(value.replace(" ", "T", 1))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)  # MP4 stores UTC
    return _valid_ts(dt.timestamp())


def parse_location(value) -> tuple[float | None, float | None]:
    """ISO 6709 strings such as "+38.7223-009.1393+012.000/"."""
    if isinstance(value, str):
        value = value.encode("ascii", "ignore")
    m = ISO6709.search(value or b"")
    if not m:
        return None, None
    try:
        lat, lon = float(m.group(1)), float(m.group(2))
    except ValueError:
        return None, None
    if not (-90 <= lat <= 90 and -180 <= lon <= 180) or (abs(lat) < 1e-6 and abs(lon) < 1e-6):
        return None, None
    return round(lat, 6), round(lon, 6)


# ---- ffprobe ------------------------------------------------------------------------------
def _ffprobe(path: str) -> VideoMeta | None:
    try:
        out = subprocess.run(
            [FFPROBE, "-v", "error", "-print_format", "json", "-show_format", "-show_streams", path],
            capture_output=True, timeout=PROBE_TIMEOUT, check=False, stdin=subprocess.DEVNULL)
        data = json.loads(out.stdout or b"{}")
    except (OSError, subprocess.SubprocessError, ValueError) as exc:
        log.debug("ffprobe %s: %s", path, exc)
        return None
    fmt = data.get("format") or {}
    streams = data.get("streams") or []
    video = next((s for s in streams if s.get("codec_type") == "video"
                  and not (s.get("disposition") or {}).get("attached_pic")), None)
    if video is None:
        return None
    width, height = int(video.get("width") or 0), int(video.get("height") or 0)
    rotation = 0
    for side in video.get("side_data_list") or []:
        if "rotation" in side:
            rotation = side["rotation"]
    rotation = rotation or (video.get("tags") or {}).get("rotate", 0)
    try:
        if abs(int(float(rotation))) % 180 == 90:
            width, height = height, width
    except (TypeError, ValueError):
        pass
    try:
        duration = float(fmt.get("duration") or video.get("duration") or 0)
    except ValueError:
        duration = 0.0
    if not math.isfinite(duration):
        duration = 0.0
    tags = {k.lower(): v for k, v in (fmt.get("tags") or {}).items()}
    vtags = {k.lower(): v for k, v in (video.get("tags") or {}).items()}
    taken = (parse_iso_date(tags.get("com.apple.quicktime.creationdate", ""))
             or parse_iso_date(tags.get("creation_time", ""))
             or parse_iso_date(vtags.get("creation_time", "")))
    lat, lon = None, None
    for key in ("com.apple.quicktime.location.iso6709", "location", "location-eng"):
        if tags.get(key):
            lat, lon = parse_location(tags[key])
            if lat is not None:
                break
    return VideoMeta(taken, width, height, duration, lat, lon)


# ---- MP4 / QuickTime without ffprobe --------------------------------------------------------
def _boxes(f, start: int, end: int):
    """Yield (type, payload_start, payload_end) for the boxes in [start, end)."""
    pos = start
    while pos + 8 <= end:
        f.seek(pos)
        header = f.read(8)
        if len(header) < 8:
            return
        size, kind = struct.unpack(">I4s", header)
        payload = pos + 8
        if size == 1:
            big = f.read(8)
            if len(big) < 8:
                return
            size = struct.unpack(">Q", big)[0]
            payload += 8
        elif size == 0:
            size = end - pos
        if size < payload - pos:
            return
        yield kind, payload, min(pos + size, end)
        pos += size


def _mp4(path: str) -> VideoMeta | None:
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        file_end = f.tell()
        moov = next(((s, e) for k, s, e in _boxes(f, 0, file_end) if k == b"moov"), None)
        if moov is None or moov[1] - moov[0] > MAX_MOOV:
            return None
        f.seek(moov[0])
        data = f.read(moov[1] - moov[0])
    buf = io.BytesIO(data)
    taken, duration, width, height = None, 0.0, 0, 0
    lat = lon = None

    def walk(start, end):
        nonlocal taken, duration, width, height, lat, lon
        for kind, s, e in list(_boxes(buf, start, end)):
            if kind in CONTAINERS:
                walk(s, e)
            elif kind == b"mvhd":
                buf.seek(s)
                body = buf.read(min(e - s, 40))
                if body[:1] == b"\x01":
                    created, _mod, scale, length = struct.unpack(">QQIQ", body[4:32])
                else:
                    created, _mod, scale, length = struct.unpack(">IIII", body[4:20])
                taken = _valid_ts(created - MP4_EPOCH) if created else None
                duration = length / scale if scale else 0.0
            elif kind == b"tkhd":
                buf.seek(s)
                body = buf.read(e - s)
                off = 4 + (32 if body[:1] == b"\x01" else 20) + 8 + 8
                if len(body) < off + 44:
                    continue
                a, b = struct.unpack(">ii", body[off:off + 8])
                w, h = struct.unpack(">II", body[off + 36:off + 44])
                w, h = w >> 16, h >> 16
                if w and h and w * h > width * height:
                    if a == 0 and abs(b) == 0x10000:  # rotated 90° / 270°
                        w, h = h, w
                    width, height = w, h
            elif kind == b"\xa9xyz" or kind == b"meta":
                buf.seek(s)
                found = parse_location(buf.read(min(e - s, 1 << 20)))
                if found[0] is not None and lat is None:
                    lat, lon = found

    walk(0, len(data))
    if not (width or duration):
        return None
    return VideoMeta(taken, width, height, duration, lat, lon)


def probe(path: str) -> VideoMeta | None:
    """Metadata of a video, or None if it is unreadable / not a video."""
    if FFPROBE:
        meta = _ffprobe(path)
        if meta is not None:
            return meta
    try:
        meta = _mp4(path)
    except (OSError, struct.error, ValueError) as exc:
        log.debug("cannot parse %s: %s", path, exc)
        meta = None
    if meta is not None:
        return meta
    if FFPROBE:
        return None  # ffprobe could not read it either: damaged or not a video
    # nothing can read this container here: index it with what the file system knows
    try:
        os.stat(path)
    except OSError:
        return None
    return VideoMeta(None, 0, 0, 0.0)


# ---- poster frames ------------------------------------------------------------------------
def _ffmpeg_frame(path: str, at: float, width: int, height: int) -> Image.Image | None:
    # fit inside width x height, never upscale
    scale = f"scale='min(iw,{width})':'min(ih,{height})':force_original_aspect_ratio=decrease"
    cmd = [FFMPEG, "-v", "error", "-nostdin", "-ss", f"{at:.2f}", "-i", path,
           "-frames:v", "1", "-vf", scale, "-f", "image2pipe", "-c:v", "png", "-"]
    try:
        out = subprocess.run(cmd, capture_output=True, timeout=FRAME_TIMEOUT, check=False,
                             stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError) as exc:
        log.debug("ffmpeg %s: %s", path, exc)
        return None
    if not out.stdout:
        return None
    try:
        im = Image.open(io.BytesIO(out.stdout))
        im.load()
        return im
    except Exception:
        return None


def placeholder(width: int, height: int) -> Image.Image:
    """A dark tile with a play symbol, for videos without a poster frame."""
    width, height = max(16, width), max(16, height)
    im = Image.new("RGB", (width, height), (38, 40, 46))
    draw = ImageDraw.Draw(im)
    for y in range(height):  # soft vertical gradient
        c = int(52 - 22 * y / height)
        draw.line([(0, y), (width, y)], fill=(c, c + 2, c + 8))
    r = min(width, height) * 0.16
    cx, cy = width / 2, height / 2
    draw.ellipse([cx - r * 1.6, cy - r * 1.6, cx + r * 1.6, cy + r * 1.6], fill=(70, 74, 84))
    draw.polygon([(cx - r * 0.55, cy - r * 0.8), (cx - r * 0.55, cy + r * 0.8), (cx + r * 0.85, cy)],
                 fill=(235, 235, 240))
    return im


def poster(path: str, width: int, height: int, duration: float = 0.0) -> tuple[Image.Image, bool]:
    """(frame fitting in width x height, real) — real is False for the placeholder."""
    if FFMPEG:
        # a moment in, so the poster is not a black fade-in frame (retried at 0 when the
        # video is shorter than that)
        at = min(1.0, duration / 3) if duration > 0 else 1.0
        im = _ffmpeg_frame(path, at, width, height)
        if im is None and at > 0:
            im = _ffmpeg_frame(path, 0.0, width, height)
        if im is not None:
            return im, True
    elif not os.path.exists(path):
        raise FileNotFoundError(path)
    return placeholder(width, height), False


# ---- frame capture ------------------------------------------------------------------------
def frame_at(path: str, ms: int) -> Image.Image:
    """The frame shown at ms, at the video's full resolution (rotation applied)."""
    if not FFMPEG:
        raise RuntimeError("Capturing frames needs ffmpeg (sudo pacman -S ffmpeg)")
    at = max(0, ms) / 1000
    # input seeking is frame-accurate when decoding; PNG keeps the frame lossless until saved
    cmd = [FFMPEG, "-v", "error", "-nostdin", "-ss", f"{at:.3f}", "-i", path,
           "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "-"]
    try:
        out = subprocess.run(cmd, capture_output=True, timeout=FRAME_TIMEOUT, check=False,
                             stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError) as exc:
        raise RuntimeError(f"ffmpeg failed: {exc}") from exc
    if not out.stdout and at > 0.05:  # asked for the very end: take the last frame instead
        return frame_at(path, int(ms - 100))
    if not out.stdout:
        raise RuntimeError("No frame at this position")
    im = Image.open(io.BytesIO(out.stdout))
    im.load()
    return im.convert("RGB")


def capture_name(video_path: str, ms: int) -> str:
    """clip_frame_01-23-456.jpg for a frame at 1:23.456."""
    base = os.path.splitext(os.path.basename(video_path))[0]
    s, millis = divmod(max(0, int(ms)), 1000)
    h, rem = divmod(s, 3600)
    m, s = divmod(rem, 60)
    stamp = (f"{h}-" if h else "") + f"{m:02d}-{s:02d}-{millis:03d}"
    return f"{base}_frame_{stamp}.jpg"


def save_frame(video_path: str, ms: int, folder: str, taken: int | None) -> str:
    """Write the frame at ms as a JPEG in folder; EXIF date = recording date + ms. Returns its path."""
    im = frame_at(video_path, ms)
    out = os.path.join(folder, capture_name(video_path, ms))
    root, ext = os.path.splitext(out)
    n = 2
    while os.path.exists(out):
        out = f"{root} ({n}){ext}"
        n += 1
    exif = Image.Exif()
    if taken:
        when = datetime.fromtimestamp(taken + ms / 1000)
        exif.get_ifd(0x8769)[36867] = when.strftime("%Y:%m:%d %H:%M:%S")   # DateTimeOriginal
    exif[0x010E] = f"Frame from {os.path.basename(video_path)}"         # ImageDescription
    tmp = out + ".part"
    im.save(tmp, "JPEG", quality=95, exif=exif)
    os.replace(tmp, out)
    return out
