#!/usr/bin/env python3
"""LGallery entry point: sets up Qt, the index, providers and models, then loads QML."""

import logging
import os
import signal
import sys
from pathlib import Path

from PySide6.QtCore import QSize, QUrl
from PySide6.QtGui import QGuiApplication, QIcon, QPixmap
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtQuickControls2 import QQuickStyle

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from backend import db  # noqa: E402
from backend.controller import Gallery  # noqa: E402
from backend.editor import EditImageProvider, Editor  # noqa: E402
from backend.settings import Settings  # noqa: E402
from backend.thumbs import ImageProvider  # noqa: E402

APP_ID = "lgallery"


class ThemeIconProvider(QQuickImageProvider):
    """image://icon/<name> -> icon from the current (KDE) icon theme, for "Open with"."""

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Pixmap)

    def requestPixmap(self, icon_id, size, requested_size):
        edge = max(requested_size.width(), requested_size.height(), 48)
        icon = QIcon(icon_id) if os.path.isabs(icon_id) else QIcon.fromTheme(icon_id)
        pixmap = icon.pixmap(QSize(edge, edge)) if not icon.isNull() else QPixmap()
        if size is not None:
            size.setWidth(pixmap.width())
            size.setHeight(pixmap.height())
        return pixmap


def find_icon() -> str:
    for candidate in (HERE / "packaging" / "icon.svg",
                      Path("/usr/share/icons/hicolor/scalable/apps/lgallery.svg")):
        if candidate.exists():
            return str(candidate)
    return ""


def create_app(argv=None):
    """Build the application. Returns (app, engine, gallery)."""
    logging.basicConfig(
        level=os.environ.get("LGALLERY_LOG", "INFO").upper(),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    QGuiApplication.setApplicationName(APP_ID)
    QGuiApplication.setApplicationDisplayName("Gallery")
    QGuiApplication.setOrganizationName(APP_ID)
    QGuiApplication.setDesktopFileName(APP_ID)  # Wayland: match lgallery.desktop for the icon
    # Basic is fully customisable; the KDE desktop style would override our One UI look.
    QQuickStyle.setStyle("Basic")

    app = QGuiApplication.instance() or QGuiApplication(argv or sys.argv)
    icon = find_icon()
    if icon:
        app.setWindowIcon(QIcon(icon))

    db.init()
    settings = Settings(app)
    gallery = Gallery(settings, app)
    editor = Editor(app)
    editor.libraryChanged.connect(gallery.reloadLibrary)
    editor.message.connect(gallery.toast)

    engine = QQmlApplicationEngine()
    engine.addImageProvider("thumbs", ImageProvider("thumbs"))
    engine.addImageProvider("full", ImageProvider("full", threads=2))
    engine.addImageProvider("icon", ThemeIconProvider())
    engine.addImageProvider("edit", EditImageProvider(editor))

    ctx = engine.rootContext()
    ctx.setContextProperty("gallery", gallery)
    ctx.setContextProperty("prefs", settings)
    ctx.setContextProperty("photos", gallery.photos)
    ctx.setContextProperty("albumPhotos", gallery.albumPhotos)
    ctx.setContextProperty("searchPhotos", gallery.searchPhotos)
    ctx.setContextProperty("albums", gallery.albums)
    ctx.setContextProperty("editor", editor)

    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        raise SystemExit("Failed to load the QML user interface (see errors above).")
    app.aboutToQuit.connect(gallery.shutdown)
    return app, engine, gallery


def main():
    app, engine, _gallery = create_app()
    signal.signal(signal.SIGINT, signal.SIG_DFL)  # Ctrl+C in a terminal quits
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
