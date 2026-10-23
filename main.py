#!/usr/bin/env python3
"""LGallery entry point: sets up Qt, the index, providers and models, then loads QML."""

import json
import logging
import os
import signal
import sys
from pathlib import Path

from PySide6.QtCore import QObject, QSize, QUrl
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtGui import QGuiApplication, QIcon, QPixmap
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtQuickControls2 import QQuickStyle

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from backend import db, external  # noqa: E402
from backend.controller import Gallery  # noqa: E402
from backend.editor import EditImageProvider, Editor  # noqa: E402
from backend.settings import Settings  # noqa: E402
from backend.thumbs import ImageProvider  # noqa: E402

APP_ID = "lgallery"
SERVER_NAME = f"{APP_ID}-{os.getuid()}" if hasattr(os, "getuid") else APP_ID


def forward_to_running_instance(files: list[str]) -> bool:
    """If Gallery is already running, hand it the files (or just raise it) and return True."""
    sock = QLocalSocket()
    sock.connectToServer(SERVER_NAME)
    if not sock.waitForConnected(400):
        return False
    sock.write(json.dumps(files).encode() + b"\n")
    sock.flush()
    sock.waitForBytesWritten(1000)
    sock.disconnectFromServer()
    return True


class InstanceServer(QObject):
    """Receives files from later launches ("Open with Gallery" while Gallery is open)."""

    def __init__(self, gallery, parent=None):
        super().__init__(parent)
        self.gallery = gallery
        self.server = QLocalServer(self)
        self.server.newConnection.connect(self._accept)
        if not self.server.listen(SERVER_NAME):
            QLocalServer.removeServer(SERVER_NAME)  # stale socket from a crashed instance
            if not self.server.listen(SERVER_NAME):
                logging.getLogger(__name__).warning("single-instance server unavailable")

    def _accept(self):
        while self.server.hasPendingConnections():
            sock = self.server.nextPendingConnection()
            buffer = bytearray()

            def read(sock=sock, buffer=buffer):
                buffer.extend(bytes(sock.readAll()))
                if b"\n" in buffer:
                    try:
                        files = json.loads(buffer.split(b"\n", 1)[0].decode())
                    except ValueError:
                        files = []
                    sock.disconnectFromServer()
                    self.gallery.openFiles([str(f) for f in files])

            sock.readyRead.connect(read)
            sock.disconnected.connect(sock.deleteLater)


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


def create_app(argv=None, files=None):
    """Build the application. Returns (app, engine, gallery).

    files: pictures to open right away in the viewer (opened from a file manager)."""
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
    ctx.setContextProperty("externalPhotos", gallery.externalPhotos)
    ctx.setContextProperty("launchedWithFiles", bool(files))
    ctx.setContextProperty("editor", editor)

    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        raise SystemExit("Failed to load the QML user interface (see errors above).")
    app.aboutToQuit.connect(gallery.shutdown)
    if files:
        gallery.openFiles(files)
    return app, engine, gallery


def main():
    args = sys.argv[1:]
    app = QGuiApplication.instance() or QGuiApplication(sys.argv)
    files = external.paths_from_args(args)
    if "--new-instance" not in args and forward_to_running_instance(files):
        return  # the running Gallery window shows the files
    app, engine, gallery = create_app(files=files)
    server = InstanceServer(gallery)  # noqa: F841 (kept alive for the app's lifetime)
    signal.signal(signal.SIGINT, signal.SIG_DFL)  # Ctrl+C in a terminal quits
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
