#!/usr/bin/env python3
"""
Archivos — explorador de archivos de DylanOS
Bootstrap: solo levanta el motor QML y carga Main.qml.
Toda la lógica de la app vive en QML (navegación, menús, etiquetas, favoritos).
"""
import sys
import runpy
from pathlib import Path
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

APP_DIR = Path(__file__).resolve().parent

def main():
    # The previous QML prototype remains available in qml/ for design reference.
    # The beta entry point uses the shared, real filesystem implementation.
    workspace = APP_DIR.parent / "workspace"
    sys.path.insert(0, str(workspace))
    sys.argv[1:1] = ["--page", "files"]
    runpy.run_path(str(workspace / "main.py"), run_name="__main__")
    return
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Archivos")
    app.setOrganizationName("DylanOS")

    logo = APP_DIR / "assets" / "archivos-logo.svg"
    if logo.exists():
        app.setWindowIcon(QIcon(str(logo)))

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(APP_DIR / "qml"))
    engine.rootContext().setContextProperty("appDir", str(APP_DIR))

    engine.load(str(APP_DIR / "qml" / "Main.qml"))
    if not engine.rootObjects():
        print("Error: Main.qml no cargó. Revisa la consola arriba para el detalle.", file=sys.stderr)
        sys.exit(1)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
