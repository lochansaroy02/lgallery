"""Async image providers: cached thumbnails (image://thumbs) and full images (image://full).

Requests run on a dedicated thread pool. Newer requests get higher priority so
the rows currently on screen load first while fast-scrolling, and requests for
delegates that scrolled away are cancelled before any decoding happens.
"""

import hashlib
import io
import itertools
import logging
import os
import shutil

from PIL import Image, ImageOps
from PySide6.QtCore import QRunnable, QThreadPool
from PySide6.QtGui import QImage
from PySide6.QtQuick import (
    QQuickAsyncImageProvider, QQuickImageResponse, QQuickTextureFactory,
)

from . import THUMB_DIR, db, external, is_video, video

log = logging.getLogger(__name__)

THUMB_SHORT_SIDE = 320
MAX_ASPECT = 3.0
FULL_DEFAULT = 2560
Image.MAX_IMAGE_PIXELS = 400_000_000  # big panoramas are legitimate photos


def cache_path(path: str, version) -> "Path":
    """Cache file for path; `version` (mtime-size) changes when the file is edited."""
    digest = hashlib.sha1(path.encode("utf-8", "surrogateescape")).hexdigest()
    return THUMB_DIR / digest[:2] / f"{digest}_{version}.jpg"


def _flatten(im: Image.Image) -> Image.Image:
    if im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info):
        im = im.convert("RGBA")
        bg = Image.new("RGB", im.size, (255, 255, 255))
        bg.paste(im, mask=im.getchannel("A"))
        return bg
    return im.convert("RGB") if im.mode != "RGB" else im


def _to_qimage(im: Image.Image) -> QImage:
    im = _flatten(im)
    data = im.tobytes("raw", "RGB")
    return QImage(data, im.width, im.height, im.width * 3, QImage.Format_RGB888).copy()


def _open_upright(path: str, width: int, height: int):
    """(upright image decoded for about width x height, cacheable)."""
    if is_video(path):
        return video.poster(path, width, height)
    im = Image.open(path)
    try:
        im.draft("RGB", (width, height))
        upright = ImageOps.exif_transpose(im)
        if upright is not im:
            im.close()
        return upright, True
    except Exception:
        im.close()
        raise


def thumbnail_image(path: str) -> tuple[Image.Image, bool]:
    """(thumbnail with short side THUMB_SHORT_SIDE, cacheable). Videos use a poster frame;
    their placeholder (no ffmpeg) is not cacheable."""
    edge = THUMB_SHORT_SIDE * 2 if is_video(path) else THUMB_SHORT_SIDE
    im, cacheable = _open_upright(path, edge, edge)
    with im:
        w, h = im.size
        # crop extreme panoramas around the centre; the grid shows squares anyway
        if w / h > MAX_ASPECT:
            nw = int(h * MAX_ASPECT)
            im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
        elif h / w > MAX_ASPECT:
            nh = int(w * MAX_ASPECT)
            im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
        w, h = im.size
        scale = THUMB_SHORT_SIDE / min(w, h)
        if scale < 1:
            im = im.resize((max(1, round(w * scale)), max(1, round(h * scale))),
                           Image.BICUBIC, reducing_gap=2.0)
        im = _flatten(im)
    return im, cacheable


def thumbnail_jpeg(path: str, quality: int = 85) -> bytes:
    """The thumbnail as JPEG bytes, without touching the disk cache (private album)."""
    im, _cacheable = thumbnail_image(path)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=quality)
    return buf.getvalue()


def forget_cached(path: str) -> None:
    """Delete every cached thumbnail of path (all versions)."""
    folder = cache_path(path, "x").parent
    digest = cache_path(path, "x").name.split("_", 1)[0]
    for f in folder.glob(f"{digest}_*") if folder.exists() else ():
        try:
            f.unlink()
        except OSError:
            pass


def make_thumbnail(path: str, out) -> Image.Image:
    """Decode path into a thumbnail and cache it at out (placeholders are not cached)."""
    im, cacheable = thumbnail_image(path)
    if not cacheable:
        return im
    try:
        out.parent.mkdir(parents=True, exist_ok=True)
        tmp = out.with_suffix(".tmp%d" % os.getpid())
        im.save(tmp, "JPEG", quality=82, optimize=False)
        os.replace(tmp, out)
    except OSError as exc:  # read-only or full cache: still show the thumbnail
        log.debug("cannot cache thumbnail for %s: %s", path, exc)
    return im


def load_full(path: str, width: int, height: int) -> Image.Image:
    im, _cacheable = _open_upright(path, width, height)
    with im:
        if im.width > width or im.height > height:
            im.thumbnail((width, height), Image.BICUBIC, reducing_gap=2.0)
        return _flatten(im)


def clear_cache() -> None:
    shutil.rmtree(THUMB_DIR, ignore_errors=True)


def cache_size() -> int:
    total = 0
    for dirpath, _dirs, files in os.walk(THUMB_DIR):
        for f in files:
            try:
                total += os.path.getsize(os.path.join(dirpath, f))
            except OSError:
                pass
    return total


class _Response(QQuickImageResponse):
    def __init__(self):
        super().__init__()
        self._image = QImage()
        self._error = ""
        self.cancelled = False

    def textureFactory(self):
        return QQuickTextureFactory.textureFactoryForImage(self._image)

    def errorString(self):
        return self._error

    def cancel(self):
        self.cancelled = True

    def finish(self, image: QImage | None, error: str = ""):
        if image is not None:
            self._image = image
        self._error = error
        self.finished.emit()


class _Job(QRunnable):
    def __init__(self, provider, response, image_id, version, width, height):
        super().__init__()
        self.provider = provider
        self.response = response
        self.image_id = image_id
        self.version = version
        self.width = width
        self.height = height

    def run(self):
        response = self.response
        try:
            if response.cancelled:
                response.finish(None, "cancelled")
                return
            if self.provider.mode == "faces":  # id is a face id; the face module finds the file
                found = ("", 1)
            elif self.image_id < 0:  # opened from a file manager, not in the index
                path = external.lookup(self.image_id)
                found = (path, 1) if path else None
            else:
                found = db.path_for_id(self.image_id)
            if not found:
                response.finish(None, "not in index")
                return
            path, available = found
            if self.provider.mode == "faces":
                from .faces import face_thumbnail
                image = _to_qimage(face_thumbnail(self.image_id))
            elif self.provider.mode == "thumbs":
                image = self._thumb(path)
            else:
                w = self.width if self.width > 0 else FULL_DEFAULT
                h = self.height if self.height > 0 else FULL_DEFAULT
                image = _to_qimage(load_full(path, w, h))
            response.finish(image)
        except FileNotFoundError:
            response.finish(None, "file missing")
        except Exception as exc:  # corrupt image, permission denied, ...
            log.debug("image %s failed: %s", self.image_id, exc)
            response.finish(None, str(exc) or exc.__class__.__name__)
        finally:
            self.provider.release(response)

    def _thumb(self, path):
        cached = cache_path(path, self.version)
        if cached.exists():
            image = QImage(str(cached))
            if not image.isNull():
                return image
        if self.response.cancelled:
            raise RuntimeError("cancelled")
        return _to_qimage(make_thumbnail(path, cached))


class ImageProvider(QQuickAsyncImageProvider):
    """mode "thumbs": cached thumbnails; mode "full": viewer-size decode via Pillow."""

    def __init__(self, mode="thumbs", threads=None):
        super().__init__()
        self.mode = mode
        self.pool = QThreadPool()
        self.pool.setMaxThreadCount(threads or max(2, (os.cpu_count() or 4) - 1))
        self._priority = itertools.count()
        self._live = set()

    def requestImageResponse(self, image_id, requested_size):
        response = _Response()
        id_part, _, version = image_id.partition("/")
        try:
            iid = int(id_part)
        except ValueError:
            response.finish(None, "bad id")
            return response
        version = "".join(c for c in version if c.isalnum() or c == "-") or "0"
        self._live.add(response)
        job = _Job(self, response, iid, version,
                   requested_size.width(), requested_size.height())
        # newest request first: visible rows win while scrolling quickly
        self.pool.start(job, next(self._priority) % 2_000_000_000)
        return response

    def release(self, response):
        self._live.discard(response)
