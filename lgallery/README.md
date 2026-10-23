# LGallery

LGallery is a desktop photo gallery for Arch-based Linux (Manjaro) on KDE Plasma, styled after Samsung One UI's Gallery app. You choose the folders it shows, including folders on other drives. It indexes them in the background and lists your pictures newest first, grouped by day, the way a phone gallery does.

- **Pictures tab:** day headers that stay visible while you scroll ("Today", "Yesterday", "Fri, Oct 23"), a title that shrinks as you scroll, a fast-scroll handle with a month bubble, and **Ctrl + mouse wheel** or **Ctrl +/-** to change the number of columns.
- **Albums tab:** one album per watched folder, or one per sub-folder (a setting), plus **Favorites**.
- **Folders tab:** add or remove watched folders and rescan. Removing a folder **never deletes files**.
- **Selection mode:** right-click or long-press a picture, or tick a day header to select the whole day. Actions: Delete (to the trash), Share (copies the files to the clipboard), Open with, Copy path, Show in folder.
- **Viewer:** arrow keys or swipe to move between pictures, wheel or double-click or pinch to zoom, drag to pan, and a Details panel.
- **Search:** by file name, folder or date (`2025`, `October`, `oct 2024`, `Screenshot`).
- **Live updates** (needs watchdog). Folders on unmounted drives are kept and marked *unavailable* instead of being removed.
- **Themes:** light and dark. By default it follows your KDE colour scheme, and you can override that in Settings.

## Install on Arch / Manjaro

### Option A: run from source in a virtual environment (recommended for development)

Arch's system Python is "externally managed", so use a venv:

```bash
sudo pacman -S --needed python qt6-declarative qt6-svg qt6-imageformats
cd lgallery
python -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python main.py
```

To use the distro's Qt bindings instead of the pip wheels (smaller and matches your Plasma's Qt):

```bash
sudo pacman -S --needed pyside6 python-pillow python-watchdog python-send2trash
python -m venv --system-site-packages .venv
.venv/bin/pip install pillow-heif      # optional; or: yay -S python-pillow-heif
.venv/bin/python main.py
```

To add "Gallery" to the KDE application launcher for this checkout:

```bash
./packaging/install-user.sh            # installs ~/.local/bin/lgallery, the .desktop file and the icon
./packaging/install-user.sh --uninstall
```

### Option B: build an Arch package

```bash
cd packaging
makepkg -si
```

This installs `/usr/bin/lgallery`, `/usr/share/applications/lgallery.desktop` and the icon. Optional extras are `python-watchdog`, `python-send2trash` and `python-pillow-heif` (AUR).

## Using it

1. On first launch the gallery is empty. Click **Add folder** (or **Add Pictures** for `~/Pictures`), or press **Ctrl+O**.
2. Scanning runs in the background, and pictures appear while it works. Later rescans only read files that changed.
3. To add folders on other drives, mount the drive and add the folder. If the drive is unmounted later, its pictures stay in the gallery, greyed out with a ⚠ mark, and become available again when you remount it. The app checks for mounts every 10 seconds.
4. To remove a folder, open the **Folders** tab and click ✕ on the folder. Its pictures disappear from the gallery, and the files are left untouched.

### Keyboard

| Key | Action |
| --- | --- |
| Ctrl + / Ctrl - / Ctrl + wheel | Fewer / more columns |
| Ctrl+F | Search |
| Ctrl+A | Select all |
| Delete | Move selection (or the viewed picture) to the trash |
| Esc | Close viewer / leave selection / go back |
| F5 | Rescan |
| Ctrl+O | Add folder |
| Viewer: ← → Space Home End | Navigate |
| Viewer: + − 0, wheel, double-click | Zoom |
| Viewer: F / I | Favorite / Details |

## Where data lives

| What | Path |
| --- | --- |
| Settings (watched folders, preferences) | `~/.config/lgallery/config.json` |
| Index (SQLite) | `~/.local/share/lgallery/index.db` |
| Thumbnail cache | `~/.cache/lgallery/thumbs/` (it is safe to delete, and Settings has a **Clear** button) |

The paths follow `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_CACHE_HOME`. Setting `LGALLERY_HOME=/some/dir` puts all three under one directory, which is useful for testing. Set `LGALLERY_LOG=DEBUG` for verbose logs.

## What is scanned

- Formats: jpg, jpeg, png, webp, gif, bmp, tif, tiff, plus heic/heif when `pillow-heif` is installed.
- Skipped: hidden folders, `node_modules`, `.cache`, trash folders, `lost+found`, unreadable or corrupt files, and files smaller than the minimum size (20 KB by default, set in Settings).
- Date taken: EXIF DateTimeOriginal, then DateTimeDigitized or DateTime, then the file's modification time.

## Testing and performance

```bash
.venv/bin/python -m unittest discover -s tests -v       # backend tests
.venv/bin/python tools/make_samples.py samples --count 5000
.venv/bin/python tools/ui_smoke.py samples --out ui-shots  # drives the UI, saves screenshots, measures scrolling
```

`ui_smoke.py` uses a temporary `LGALLERY_HOME`, so your real index and settings are not touched.

## Project layout

```
main.py               app entry: Qt setup, image providers, context objects
backend/db.py         SQLite schema; one connection per thread
backend/scanner.py    ScanThread: incremental, mount-aware folder walk + EXIF
backend/watcher.py    watchdog (inotify) live updates
backend/models.py     PhotoModel (rows of thumbnails + day sections), AlbumModel
backend/thumbs.py     async image providers: image://thumbs (disk-cached), image://full
backend/settings.py   folder list + preferences (JSON)
backend/actions.py    trash, open with, show in folder, clipboard
backend/controller.py glue object exposed to QML as `gallery`
backend/tasks.py      run work on the thread pool, get results on the GUI thread
qml/                  Main.qml, Theme.qml (all colours/sizes), views, components/
packaging/            .desktop file, icon, PKGBUILD, user install script
tools/                sample generator, UI smoke test
tests/                backend tests
```

## Notes and limitations

- **Share** copies the selected files to the clipboard so you can paste them into Dolphin, a chat app or an email. KDE has no stable command-line share dialog.
- **Edit / Open with** lists the applications that declare support for the file's MIME type, read from their `.desktop` files.
- **Show in folder** asks the file manager over D-Bus (`org.freedesktop.FileManager1`) to open the folder with the file selected. Dolphin supports this. Otherwise the parent folder is opened.
- Videos are not indexed yet.
