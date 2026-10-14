#!/usr/bin/env python3
"""
DylanOS Spotlight Search Runner.
"""

from pathlib import Path
import sys

from PySide6.QtCore import QSize, QUrl, QTimer, Qt
from PySide6.QtGui import QGuiApplication, QIcon, QImage
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtQuickControls2 import QQuickStyle

from backend import SpotlightBackend


class IconProvider(QQuickImageProvider):
    """Resuelve nombres de icono del tema actual en imágenes para QML.

    Los resultados del Spotlight guardan el campo Icon= de los .desktop;
    este proveedor lo convierte con QIcon.fromTheme para poder pintarlo
    en un Image de QML (image://icons/<nombre>).
    """

    def __init__(self):
        super().__init__(QQuickImageProvider.Image)

    def requestImage(self, icon_id, size, requestedSize):
        icon = QIcon.fromTheme(icon_id)
        if icon.isNull() or not icon.availableSizes():
            icon = QIcon.fromTheme("application-x-executable")

        target = 64
        if requestedSize is not None and requestedSize.width() > 0:
            target = requestedSize.width()
        elif icon.availableSizes():
            biggest = icon.availableSizes()[-1]
            target = max(biggest.width(), 32)

        image = icon.pixmap(target, target).toImage()
        if image.isNull():
            image = QImage(target, target, QImage.Format_ARGB32_Premultiplied)
            image.fill(Qt.transparent)

        return image, QSize(image.width(), image.height())


def main():
    QQuickStyle.setStyle("Basic")
    app = QGuiApplication(sys.argv)
    app.setOrganizationName("DylanOS")
    app.setApplicationName("org.dylanos.spotlight")
    app.setDesktopFileName("org.dylanos.spotlight")
    app.setWindowIcon(QIcon.fromTheme("system-search"))
    QIcon.setFallbackThemeName("breeze")

    engine = QQmlApplicationEngine()
    engine.addImageProvider("icons", IconProvider())
    backend = SpotlightBackend()
    engine.rootContext().setContextProperty("backend", backend)

    qml_file = Path(__file__).resolve().parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        return 1

    if "--smoke" in sys.argv:
        QTimer.singleShot(1000, app.quit)

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())

