#!/usr/bin/env python3
"""DylanOS Workspace entry point; also supports isolated rendering for QA."""
import argparse
import os
from pathlib import Path
import sys

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from backend import Backend


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--page", default="welcome", choices=["welcome", "files", "notes", "monitor", "dev", "store", "settings"])
    parser.add_argument("--screenshot", type=Path)
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--appearance", choices=["dark", "light"])
    args = parser.parse_args()
    QQuickStyle.setStyle("Basic")
    app = QGuiApplication(sys.argv)
    app.setOrganizationName("DylanOS")
    app.setApplicationName("Workspace")
    app.setDesktopFileName("org.dylanos." + args.page)
    app.setWindowIcon(QIcon.fromTheme("distributor-logo-dylanos"))
    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("initialPage", args.page)
    engine.load(QUrl.fromLocalFile(str(Path(__file__).parent / "qml/Main.qml")))
    if not engine.rootObjects():
        return 1
    if args.appearance:
        engine.rootObjects()[0].setProperty("dark", args.appearance == "dark")
    def capture():
        if args.screenshot:
            args.screenshot.parent.mkdir(parents=True, exist_ok=True)
            if not engine.rootObjects()[0].grabWindow().save(str(args.screenshot)):
                app.exit(2)
                return
        app.quit()
    if args.smoke or args.screenshot:
        QTimer.singleShot(1800, capture)
    result = app.exec()
    backend.pool.waitForDone()
    del engine
    return result


if __name__ == "__main__":
    sys.exit(main())
