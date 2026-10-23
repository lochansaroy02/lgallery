"""Minimal stand-in for Qt's `qml` runtime (used to test qml/share/ShareHelper.qml).

    fake_qml.py file.qml -- args...      (QML_IMPORT_PATH is honoured like the real tool)
"""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import QUrl  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
engine.exit.connect(app.exit)
engine.quit.connect(app.quit)
engine.load(QUrl.fromLocalFile(os.path.abspath(sys.argv[1])))
if not engine.rootObjects():
    sys.exit(3)
sys.exit(app.exec())
