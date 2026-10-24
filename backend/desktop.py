"""Set a picture as the desktop wallpaper and / or the lock screen background.

KDE Plasma: `plasma-apply-wallpaperimage` for the desktop (every screen) and
kscreenlockerrc (via kwriteconfig6 / kwriteconfig5) for the lock screen. GNOME and
macOS are handled too, so the action also works outside Plasma.

The picture is first copied (upright, as JPEG or PNG) to ~/.local/share/lgallery/wallpapers,
so the wallpaper keeps working when the original is edited, moved, deleted or on a drive
that gets unmounted.
"""

import hashlib
import logging
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageOps

from . import DATA_DIR

log = logging.getLogger(__name__)

WALLPAPER_DIR = DATA_DIR / "wallpapers"
KEEP = 8          # older copies are removed, the newest ones may still be in use
MAX_EDGE = 7680   # 8K is plenty for any screen
TIMEOUT = 20
TARGETS = ("wallpaper", "lockscreen", "both")


class WallpaperError(RuntimeError):
    pass


def _run(cmd: list[str]) -> None:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT,
                             stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError) as exc:
        raise WallpaperError(f"{os.path.basename(cmd[0])} failed: {exc}") from exc
    if out.returncode != 0:
        detail = (out.stderr or out.stdout).strip().splitlines()
        raise WallpaperError(detail[-1] if detail else f"{os.path.basename(cmd[0])} failed")


def prepare(path: str) -> str:
    """Upright copy of path in WALLPAPER_DIR (JPEG, or PNG for pictures with transparency)."""
    st = os.stat(path)
    key = hashlib.sha1(f"{path}\0{st.st_mtime}\0{st.st_size}".encode("utf-8", "surrogateescape"))
    WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)
    with Image.open(path) as im:
        im = ImageOps.exif_transpose(im)
        alpha = im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info)
        if max(im.size) > MAX_EDGE:
            im.thumbnail((MAX_EDGE, MAX_EDGE), Image.LANCZOS)
        ext = ".png" if alpha else ".jpg"
        name = os.path.splitext(os.path.basename(path))[0][:60]
        out = WALLPAPER_DIR / f"{name}-{key.hexdigest()[:10]}{ext}"
        if not out.exists():
            tmp = out.with_suffix(".tmp")
            if alpha:
                im.convert("RGBA").save(tmp, "PNG")
            else:
                im.convert("RGB").save(tmp, "JPEG", quality=95)
            os.replace(tmp, out)
    os.utime(out)  # newest = in use
    _prune(keep=out)
    return str(out)


def _prune(keep) -> None:
    files = sorted((p for p in WALLPAPER_DIR.iterdir() if p.is_file()),
                   key=lambda p: p.stat().st_mtime, reverse=True)
    for old in files[KEEP:]:
        if old != keep:
            try:
                old.unlink()
            except OSError:
                pass


def _gsettings_available() -> bool:
    return bool(shutil.which("gsettings")) and "GNOME" in os.environ.get("XDG_CURRENT_DESKTOP", "").upper()


def set_desktop(image: str) -> None:
    uri = "file://" + image
    if shutil.which("plasma-apply-wallpaperimage"):
        _run(["plasma-apply-wallpaperimage", image])
    elif _gsettings_available():
        _run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri", uri])
        _run(["gsettings", "set", "org.gnome.desktop.background", "picture-uri-dark", uri])
    elif sys.platform == "darwin":
        script = f'tell application "System Events" to tell every desktop to set picture to POSIX file "{image}"'
        _run(["osascript", "-e", script])
    else:
        raise WallpaperError("Setting the wallpaper needs KDE Plasma (plasma-apply-wallpaperimage)")


def set_lockscreen(image: str) -> None:
    uri = "file://" + image
    kwc = shutil.which("kwriteconfig6") or shutil.which("kwriteconfig5")
    if kwc:
        base = [kwc, "--file", "kscreenlockerrc", "--group", "Greeter"]
        _run(base + ["--key", "WallpaperPlugin", "org.kde.image"])
        image_group = base + ["--group", "Wallpaper", "--group", "org.kde.image", "--group", "General"]
        _run(image_group + ["--key", "Image", uri])
        _run(image_group + ["--key", "PreviewImage", uri])
    elif _gsettings_available():
        _run(["gsettings", "set", "org.gnome.desktop.screensaver", "picture-uri", uri])
    else:
        raise WallpaperError("Setting the lock screen needs KDE Plasma (kwriteconfig6)")


def apply(path: str, target: str) -> str:
    """Set path as the wallpaper / lock screen / both. Runs in a worker. Returns target."""
    if target not in TARGETS:
        raise WallpaperError(f"unknown target {target!r}")
    try:
        image = prepare(path)
    except FileNotFoundError as exc:
        raise WallpaperError("The picture is not available") from exc
    except OSError as exc:
        raise WallpaperError(f"Can't read the picture: {exc}") from exc
    if target in ("wallpaper", "both"):
        set_desktop(image)
    if target in ("lockscreen", "both"):
        set_lockscreen(image)
    return target
