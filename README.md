# LGallery

LGallery is a desktop photo gallery for Arch-based Linux (Manjaro) on KDE Plasma, styled after Samsung One UI's Gallery app. You choose the folders it shows, including folders on other drives. It indexes them in the background and lists your pictures newest first, grouped by day, the way a phone gallery does.

- **Pictures tab:** day headers that stay visible while you scroll ("Today", "Yesterday", "Fri, Oct 23"), a title that shrinks as you scroll, a fast-scroll handle with a month bubble, and **Ctrl + mouse wheel** or **Ctrl +/-** to change the number of columns.
- **Albums tab:** one album per watched folder, or one per sub-folder (a setting), plus **Favorites**.
- **Folders tab:** add or remove watched folders and rescan. Removing a folder **never deletes files**.
- **Selection mode:** right-click or long-press a picture, or tick a day header to select the whole day. Actions: Delete (to the trash), Share, Open with, Copy path, Show in folder.
- **Share menu:** the same options as Dolphin's *Share* submenu: Copy to Clipboard, KDE Connect, Bluetooth, e-mail, Telegram, Imgur, Nextcloud, Google Drive and anything else your KDE has installed.
- **Viewer:** arrow keys or swipe to move between pictures, wheel or double-click or pinch to zoom, drag to pan, and a Details panel.
- **Photo editor:** Transform (crop with aspect presets, rotate, flip, straighten), 9 Filters, and Adjust (brightness, exposure, contrast, highlights, shadows, saturation, warmth, tint, sharpness, vignette). It has undo/redo and hold-to-compare, and you can **Save**, **Save as copy** or **Revert to original**.
- **Default image viewer:** open any picture from Dolphin in Gallery's viewer. Left/right moves through that folder, and the folder is **not** added to your library.
- **Search:** by file name, folder or date (`2025`, `October`, `oct 2024`, `Screenshot`).
- **Live updates** (needs watchdog). Folders on unmounted drives are kept and marked *unavailable* instead of being removed.
- **Themes:** light and dark. By default it follows your KDE colour scheme, and you can override that in Settings.

## Install on Arch / Manjaro

There are two ways to install LGallery as a KDE app. Both add **Gallery** to the application launcher (under *Graphics*) with its own icon, so you can pin it to the panel or task manager like any other app.

| | Option A: user install | Option B: Arch package |
| --- | --- | --- |
| Needs root | No | Yes (pacman) |
| Runs from | your checkout folder (`.venv`) | `/usr/share/lgallery` |
| Update | `git pull` | `git pull` + `makepkg -si` again |
| Best for | trying it out, development | everyday use |

### 1. Get the code

```bash
sudo pacman -S --needed git
git clone https://github.com/lochansaroy02/lgallery.git
cd lgallery
```

### Option A: user install (recommended)

From the project folder, one command does everything:

```bash
./update.sh --install
```

It:
1. installs the system packages with pacman: `pyside6` (the system Qt bindings), `python-pillow`, `qt6-declarative`, `qt6-svg`, `qt6-imageformats` and, when available, `python-watchdog`, `python-send2trash`, `purpose`, `plasma-integration` and `xdg-utils`;
2. creates `.venv` on top of them (`--system-site-packages`) and adds `pillow-heif` from PyPI for HEIC photos;
3. installs the launcher, menu entry and icon (`~/.local/bin/lgallery`, `~/.local/share/applications/lgallery.desktop`).

Gallery runs on **Manjaro's own Qt**, not on pip's bundled copy. That is what makes the **KDE global menu**, native KDE file dialogs and the KDE theme work, and it saves about 1 GB of downloads.

Open the application launcher and search for **Gallery**. If it doesn't show up right away, run `kbuildsycoca6` or log out and back in. You can also start it from a terminal with `lgallery` (if `~/.local/bin` is on your `PATH`).

> The launcher points to this folder. If you move or rename the project folder, run `./update.sh --no-pull` again.

**Update:** `./update.sh` (see [Updating](#updating)).
**Uninstall:** `./packaging/install-user.sh --uninstall`

<details>
<summary>Other distributions / manual setup with pip</summary>

Without pacman, `update.sh` falls back to pip's PySide6. Everything works except the global menu on Wayland, and you use the ⋮ menu instead.

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
./packaging/install-user.sh
```
</details>

### Option B: system-wide Arch package

This builds a real pacman package from your checkout, using the distro's Python packages (no venv):

```bash
sudo pacman -S --needed base-devel pyside6 python-pillow qt6-declarative qt6-svg qt6-imageformats
sudo pacman -S --needed python-watchdog python-send2trash   # optional: live updates, trash
cd packaging
makepkg -si
```

This installs `/usr/bin/lgallery`, `/usr/share/lgallery/`, `/usr/share/applications/lgallery.desktop` and the icon. **Gallery** then appears in the launcher for all users. HEIC support is optional: `yay -S python-pillow-heif`.

**Update:** `./update.sh` (see [Updating](#updating)).
**Uninstall:** `sudo pacman -R lgallery`

### Updating

From the project folder, run:

```bash
./update.sh
```

It pulls the latest commits from GitHub, shows what changed, and updates whichever install you have:

- **User install (option A):** installs any missing system packages with pacman, then refreshes the launcher, menu entry and icon. An older install that used pip's PySide6 is switched to Manjaro's `pyside6` automatically (needed for the global menu). If an Arch Python upgrade broke `.venv`, it is recreated.
- **Arch package (option B):** rebuilds and reinstalls the package with `makepkg` (asks for your password).
- **Not installed yet:** sets up `.venv`; add `--install` to also put Gallery in the launcher.

| Option | What it does |
| --- | --- |
| `--restart` | restart Gallery afterwards if it is open (otherwise just close and reopen it) |
| `--no-pull` | skip `git pull`, only reinstall from the current folder |
| `--install` | install the launcher if Gallery isn't installed yet |

The script stops without changing anything if you have edited tracked files locally (commit them or `git stash` first). It also checks that the new version starts before reinstalling a package. Your settings, library, favorites and saved originals are never touched by an update.

### Make Gallery your image viewer (open pictures from Dolphin)

After installing with option A or B, choose one of these:

- **Everything at once:** open Gallery, go to **Settings → Default app → Set as default**. Gallery becomes the default for JPEG, PNG, WebP, GIF, BMP and TIFF (and HEIC/HEIF if supported).
- **One format at a time, from Dolphin:** right-click a picture, choose **Properties**, click the **⚙ File Type Options** button next to the type, select **Gallery** in the application list, click **Move Up** to put it first, then **Apply**. If Gallery isn't listed, click **Add…** and choose **Gallery** (Graphics).
- **Just once:** right-click a picture, choose **Open With**, then **Gallery**.

Then double-clicking a picture in Dolphin (or any file manager):

- opens it directly in Gallery's full-screen viewer;
- lets you use **← / →** (or swipe) to go through the other pictures in **that folder**, in the same natural name order as Dolphin (`IMG_2` before `IMG_10`);
- does **not** add that folder to the library. Nothing is indexed, and your Pictures/Albums tabs stay unchanged;
- if Gallery is already open, shows the picture in that window instead of starting a second copy.

Edit, Share, Delete, Details and Show in folder all work there. Favorites are only for pictures in your library, so the heart is hidden for other pictures. **Esc** / **←** closes the viewer and quits, like a photo viewer. Use **⋮ → Open Gallery** to switch to the full library instead.

From a terminal, `lgallery ~/Downloads/photo.jpg` does the same. If you select several pictures and open them together, navigation is limited to just those files.

To stop using Gallery as the default, pick another app in Dolphin's **File Type Options**, or in **System Settings → Default Applications** / **File Associations**.

### After installing (optional)

- **Pin to the panel:** start Gallery, right-click its icon in the task manager, and choose **Pin to Task Manager**.
- **Your data survives reinstalls:** uninstalling either way leaves your settings, index and thumbnail cache in place (see [Where data lives](#where-data-lives)). Delete those folders for a clean slate.

## Using it

1. On first launch the gallery is empty. Click **Add folder** (or **Add Pictures** for `~/Pictures`), or press **Ctrl+O**.
2. Scanning runs in the background, and pictures appear while it works. Later rescans only read files that changed.
3. To add folders on other drives, mount the drive and add the folder. If the drive is unmounted later, its pictures stay in the gallery, greyed out with a ⚠ mark, and become available again when you remount it. The app checks for mounts every 10 seconds.
4. To remove a folder, open the **Folders** tab and click ✕ on the folder. Its pictures disappear from the gallery, and the files are left untouched.

### Editing photos

Open a picture and click the **pencil** (or press **E**).

| Tab | What it does |
| --- | --- |
| **Transform** | Drag the corners or edges of the crop box, or pick an aspect ratio (Free, Original, 1:1, 4:3, 3:4, 16:9, 9:16). Rotate 90°, flip, and straighten by up to ±45°. |
| **Filters** | Vivid, Bright, Warm, Cool, Dramatic, Fade, Vintage, Mono and Noir, with an intensity slider. |
| **Adjust** | Pick a tool and drag the slider. Double-click the slider or the tool to reset it. A blue dot marks tools you've changed. |

- **Undo / Redo:** the arrows at the top left, or **Ctrl+Z** / **Ctrl+Shift+Z**.
- **Compare:** hold the split-square button at the bottom right of the picture (or hold **\\**) to see the original.
- **Reset:** discards all unsaved edits. **✕** or **Esc** closes the editor and asks before throwing changes away.

**Saving.** There are two ways to save, and an edited picture keeps its original date, so it stays in the same place in your timeline.

- **Save** (**Ctrl+S**) overwrites the picture with your edits. Before the **first** save of a file, LGallery copies the untouched original to `~/.local/share/lgallery/originals/`.
- **Save as copy** (**Ctrl+Shift+S**) writes a new file next to the original, for example `IMG_1234_edited.jpg`, and leaves the original untouched.

EXIF data (camera, date, GPS) and colour profiles are kept, and the orientation tag is reset because the pixels are already upright.

**Reverting.** After a **Save**, you can always go back to the original, even weeks later:

- in the viewer, open the **⋮** menu and choose **Revert to original**, or
- in the editor, click **Revert**. It appears when the picture has a saved original and has no unsaved edits.

Reverting restores the original file exactly (byte for byte, including its modification time) and deletes the backup. To reclaim disk space, **Settings → Storage → Saved originals → Delete** removes all backups, after which edited pictures can no longer be reverted.

You can edit and save JPEG, PNG, WebP, TIFF, BMP and static GIF files, plus HEIC when pillow-heif has an encoder. Animated GIF/WebP files can't be edited.

### Menus: KDE global menu and the ⋮ menu

Gallery has a full application menu: **File, Edit, View, Go, Settings, Help**.

- **With the Global Menu widget** (Plasma panel → *Add Widgets → Global Menu*), the menu appears in your panel like on macOS. It works on Wayland and X11.
- **Without it,** the same menu is behind the **⋮** button at the top right of the Pictures, Albums and Folders tabs.

Items enable themselves from context: a picture open in the viewer, a selection, or the editor.

| Menu | What's in it |
| --- | --- |
| **File** | Add Folder…, Open Picture… (view a picture without adding its folder), **Open Recent ▸**, Save / Save as Copy (in the editor), **Share ▸** (KDE share targets), Open With…, Show in Folder, Rescan Folders, Move to Trash, Quit |
| **Edit** | Undo / Redo (editor), Select All, Deselect All, Copy Picture, Copy Path, Edit Picture…, **Rotate ▸** Left / Right (saved, revertible), Add to / Remove from Favorites, Revert to Original |
| **View** | Pictures / Albums / Folders, **Thumbnail Size ▸** (bigger, smaller, 2–12 columns), **Sort ▸** Newest / Oldest First, **Theme ▸** System / Light / Dark, Albums per Sub-folder, Zoom In / Out / Fit, Show Details, Full Screen |
| **Go** | Back, Previous / Next / First / Last Picture, Today, **Jump to Year ▸**, **Albums ▸** (every album), Favorites, Search |
| **Settings** | Settings…, Live Updates, Set as Default Image Viewer, Clear Thumbnail Cache |
| **Help** | Keyboard Shortcuts, Project Page, Report a Problem, About Gallery |

**If the global menu stays empty:**
1. Run `./update.sh`. The global menu needs Gallery on Manjaro's PySide6 (`pyside6`) plus `plasma-integration`, and the script switches older installs over.
2. Make sure a Global Menu widget is in a panel, then **restart Gallery**. Gallery checks for the global menu when it starts.
3. Check that `qdbus6 com.canonical.AppMenu.Registrar` (or `qdbus`) lists a service. If it doesn't, the Plasma global-menu service isn't running; adding the widget starts it.

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
| Ctrl+Shift+O | Open picture (without adding its folder) |
| Ctrl+1 / Ctrl+2 / Ctrl+3 | Pictures / Albums / Folders |
| Ctrl+C / Ctrl+Shift+C | Copy picture / copy path |
| Ctrl+L / Ctrl+R | Rotate left / right (saved; revert from ⋮) |
| Ctrl+Shift+A | Deselect all |
| Ctrl+Home | Today |
| F11 | Full screen |
| Ctrl+F1 | All keyboard shortcuts |
| Ctrl+Q | Quit |
| Viewer: ← → Space Home End | Navigate |
| Viewer: + − 0, wheel, double-click | Zoom |
| Viewer: F / I / E | Favorite / Details / Edit |
| Viewer opened from Dolphin: Esc | Close (quits Gallery) |
| Editor: Ctrl+Z / Ctrl+Shift+Z | Undo / Redo |
| Editor: Ctrl+S / Ctrl+Shift+S | Save / Save as copy |
| Editor: hold \\ | Compare with the original |

## Where data lives

| What | Path |
| --- | --- |
| Settings (watched folders, preferences) | `~/.config/lgallery/config.json` |
| Index (SQLite) | `~/.local/share/lgallery/index.db` |
| Thumbnail cache | `~/.cache/lgallery/thumbs/` (it is safe to delete, and Settings has a **Clear** button) |
| Originals of edited photos | `~/.local/share/lgallery/originals/` (needed for **Revert to original**) |

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
.venv/bin/python tools/editor_smoke.py samples --out ui-shots  # editor: tabs, save as copy, save, revert
.venv/bin/python tools/open_with_smoke.py samples --out ui-shots # open a file, browse its folder, hand-off
.venv/bin/python tools/menu_smoke.py samples --out ui-shots     # every menu action in context
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
backend/external.py   pictures opened from a file manager (folder browsing without indexing)
backend/editor.py     photo editor: edit pipeline, preview provider, save / copy / revert
backend/controller.py glue object exposed to QML as `gallery`
backend/tasks.py      run work on the thread pool, get results on the GUI thread
qml/                  Main.qml, Theme.qml (all colours/sizes), views, components/
packaging/            .desktop file, icon, PKGBUILD, user install script
tools/                sample generator, UI smoke test
tests/                backend tests
```

## Notes and limitations

- **Share** uses KDE's sharing framework (*Purpose*, package `purpose`, normally installed with Dolphin). Because pip's PySide6 bundles its own Qt, Purpose runs in a small helper under the system Qt (`qml/share/ShareHelper.qml`, started with `/usr/lib/qt6/bin/qml` from `qt6-declarative`). Targets that need input (which KDE Connect device, which e-mail account, …) open a small KDE window. Uploads such as Imgur copy the resulting link to the clipboard. Without Purpose, the menu offers only *Copy to Clipboard*.
- **Edit / Open with** lists the applications that declare support for the file's MIME type, read from their `.desktop` files.
- **Show in folder** asks the file manager over D-Bus (`org.freedesktop.FileManager1`) to open the folder with the file selected. Dolphin supports this. Otherwise the parent folder is opened.
- Videos are not indexed yet.
