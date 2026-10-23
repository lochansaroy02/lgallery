"""LGallery backend: index, scanner, thumbnails, models and actions."""

__version__ = "0.2.0"
PROJECT_URL = "https://github.com/lochansaroy02/lgallery"

import os
import shutil
from pathlib import Path


def _xdg(var: str, fallback: str) -> Path:
    value = os.environ.get(var)
    return Path(value) if value else Path.home() / fallback


# LGALLERY_HOME redirects every location (used by the tests and sample runs).
_home = os.environ.get("LGALLERY_HOME")
if _home:
    CONFIG_DIR = Path(_home) / "config"
    DATA_DIR = Path(_home) / "data"
    CACHE_DIR = Path(_home) / "cache"
else:
    CONFIG_DIR = _xdg("XDG_CONFIG_HOME", ".config") / "lgallery"
    DATA_DIR = _xdg("XDG_DATA_HOME", ".local/share") / "lgallery"
    CACHE_DIR = _xdg("XDG_CACHE_HOME", ".cache") / "lgallery"

DB_PATH = DATA_DIR / "index.db"
CONFIG_PATH = CONFIG_DIR / "config.json"
THUMB_DIR = CACHE_DIR / "thumbs"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff"}
HEIF_EXTS = {".heic", ".heif"}
VIDEO_EXTS = {".mp4", ".m4v", ".mov", ".mkv", ".webm", ".avi", ".3gp", ".mts", ".m2ts",
              ".wmv", ".ogv", ".mpg", ".mpeg"}

# Video posters, thumbnails and metadata come from the system ffmpeg when it is installed
# (sudo pacman -S ffmpeg). Without it MP4/MOV dates still come from the file itself.
FFMPEG = shutil.which("ffmpeg")
FFPROBE = shutil.which("ffprobe")

try:
    from pillow_heif import register_heif_opener

    register_heif_opener()
    HEIF_SUPPORTED = True
except Exception:  # not installed or broken libheif
    HEIF_SUPPORTED = False


def supported_exts() -> set[str]:
    images = IMAGE_EXTS | HEIF_EXTS if HEIF_SUPPORTED else IMAGE_EXTS
    return images | VIDEO_EXTS


def is_video(path: str) -> bool:
    return os.path.splitext(path)[1].lower() in VIDEO_EXTS
