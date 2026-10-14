"""Keyboard input must still work after focus moves to an on-screen key."""
import os
from pathlib import Path
import unittest
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
try:
    from PySide6.QtCore import QObject, QUrl, Qt
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQuick import QQuickWindow
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtTest import QTest
    HAS_QT = True
except ImportError:
    HAS_QT = False
ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(HAS_QT, 'PySide6 needed')
class CalculatorKeyboardTest(unittest.TestCase):
    def test_type_with_button_focused(self):
        app = QGuiApplication.instance() or QGuiApplication([])
        engine = QQmlApplicationEngine()
        engine.load(QUrl.fromLocalFile(str(ROOT / 'apps/calculator/qml/Main.qml')))
        self.assertTrue(engine.rootObjects())
        window = engine.rootObjects()[0]
        window.requestActivate()
        app.processEvents()
        button = next(child for child in window.findChildren(QObject) if child.property('label') == '7')
        button.forceActiveFocus()
        QTest.qWait(60)
        QTest.keyClick(window, Qt.Key_7)
        QTest.keyClick(window, Qt.Key_2)
        self.assertEqual(window.findChild(QObject, 'display').property('text'), '72')
        QTest.keyClick(window, Qt.Key_Plus)
        QTest.keyClick(window, Qt.Key_3)
        QTest.keyClick(window, Qt.Key_Return)
        self.assertEqual(window.findChild(QObject, 'display').property('text'), '75')
        window.close()
