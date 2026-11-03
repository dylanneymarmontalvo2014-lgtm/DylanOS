"""Validación de sintaxis QML de los archivos críticos del Crimson Glass."""
import os
from pathlib import Path
import unittest
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
try:
    from PySide6.QtCore import QUrl
    from PySide6.QtQml import QQmlEngine, QQmlComponent
    from PySide6.QtGui import QGuiApplication
    HAS_QT = True
except ImportError:
    HAS_QT = False
ROOT = Path(__file__).resolve().parents[2]

QML_FILES = (
    "apps/calculator/qml/Main.qml",
    "themes/sddm/DylanOS-Crimson/Main.qml",
)


@unittest.skipUnless(HAS_QT, 'PySide6 needed')
class QmlSyntaxTest(unittest.TestCase):
    def test_qml_files_parse_without_errors(self):
        app = QGuiApplication.instance() or QGuiApplication([])
        engine = QQmlEngine()
        engine.addImportPath(str(ROOT))
        for relative in QML_FILES:
            if not (ROOT / relative).is_file():
                continue
            component = QQmlComponent(engine, QUrl.fromLocalFile(str(ROOT / relative)))
            self.assertEqual(component.status(), QQmlComponent.Status.Ready,
                             "%s: %s" % (relative, component.errorString()))


if __name__ == "__main__":
    unittest.main()
