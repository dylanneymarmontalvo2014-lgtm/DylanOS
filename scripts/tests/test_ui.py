"""Load the real QML and exercise calculations and note persistence."""
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "apps/workspace"))
try:
    from PySide6.QtCore import QObject, QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuickControls2 import QQuickStyle
    from backend import Backend
    HAS_QT = True
except ImportError:
    HAS_QT = False


@unittest.skipUnless(HAS_QT, "PySide6 required")
class UiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        os.environ["XDG_DATA_HOME"] = cls.temp.name
        os.environ["XDG_CONFIG_HOME"] = cls.temp.name
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        cls.app.setOrganizationName("DylanOSTest")
        cls.app.setApplicationName("WorkspaceTest")
        QQuickStyle.setStyle("Basic")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def spin(self, milliseconds):
        deadline = time.monotonic() + milliseconds / 1000
        while time.monotonic() < deadline:
            self.app.processEvents()
            time.sleep(.005)

    def test_calculator_chain_and_divide_by_zero(self):
        engine = QQmlApplicationEngine()
        engine.load(QUrl.fromLocalFile(str(ROOT / "apps/calculator/qml/Main.qml")))
        self.assertTrue(engine.rootObjects())
        window = engine.rootObjects()[0]
        display = window.findChild(QObject, "display")
        window.inputDigit("2")
        window.setOperator("+")
        window.inputDigit("3")
        window.setOperator("×")
        window.inputDigit("4")
        window.compute()
        self.assertEqual(display.property("text"), "20")
        window.setOperator("÷")
        window.inputDigit("0")
        window.inputDigit("0")
        window.compute()
        self.assertEqual(display.property("text"), "Error")
        window.inputDigit("7")
        self.assertEqual(display.property("text"), "7")
        window.close()
        del engine

    def test_notes_autosave_and_navigation_flush(self):
        backend = Backend()
        engine = QQmlApplicationEngine()
        engine.rootContext().setContextProperty("backend", backend)
        engine.rootContext().setContextProperty("initialPage", "notes")
        engine.load(QUrl.fromLocalFile(str(ROOT / "apps/workspace/qml/Main.qml")))
        self.assertTrue(engine.rootObjects())
        window = engine.rootObjects()[0]
        title = window.findChild(QObject, "noteTitle")
        body = window.findChild(QObject, "noteBody")
        self.assertIsNotNone(title)
        title.setProperty("text", "Prueba real")
        body.setProperty("text", "Contenido persistente")
        self.spin(900)
        self.assertEqual(backend.notes[0]["body"], "Contenido persistente")
        body.setProperty("text", "Cambio antes de navegar")
        window.changePage("dev")
        self.assertEqual(backend.notes[0]["body"], "Cambio antes de navegar")
        window.close()
        backend.timer.stop()
        backend.pool.waitForDone()
        del engine
        backend.notes_store.db.close()


if __name__ == "__main__":
    unittest.main()
