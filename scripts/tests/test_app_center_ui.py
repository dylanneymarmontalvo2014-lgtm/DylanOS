"""Exercise app search, paging and resize without launching user applications."""
import os
from pathlib import Path
import unittest
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
try:
    from PySide6.QtCore import QObject, Qt, Signal, Slot, QUrl
    from PySide6.QtGui import QAccessible, QGuiApplication, QImage, QColor, QWindow
    from PySide6.QtQuick import QQuickImageProvider
    from PySide6.QtQml import QQmlApplicationEngine
    HAS_QT = True
except ImportError:
    HAS_QT = False
ROOT = Path(__file__).resolve().parents[2]

if HAS_QT:
    class Catalog(QObject):
        modelReset = Signal()
        launchSucceeded = Signal()
        launchFailed = Signal(str)
        def __init__(self):
            super().__init__()
            self.query = ''
        def items(self):
            return [dict(name=f'App {i:02}', icon='test', desktopId=f'test-{i}.desktop') for i in range(31)
                    if self.query in f'App {i:02}'.lower()]
        @Slot(str)
        def setFilter(self, text): self.query = text.lower()
        @Slot(int, result=int)
        def pageCount(self, size): return (len(self.items()) + size - 1) // size
        @Slot(int, int, result='QVariantList')
        def itemsForPage(self, page, size): return self.items()[page * size:(page + 1) * size]
        @Slot(str)
        def launchApp(self, desktop_id): pass

    class Icons(QQuickImageProvider):
        def __init__(self): super().__init__(QQuickImageProvider.Image)
        def requestImage(self, name, size, requestedSize):
            image = QImage(64, 64, QImage.Format_ARGB32)
            image.fill(QColor('#DC143C'))
            size.setWidth(64); size.setHeight(64)
            return image


@unittest.skipUnless(HAS_QT, 'PySide6 required')
class AppCenterUiTest(unittest.TestCase):
    def load_window(self):
        app = QGuiApplication.instance() or QGuiApplication([])
        model = Catalog()
        engine = QQmlApplicationEngine()
        engine.addImageProvider('icon', Icons())
        engine.rootContext().setContextProperty('appModel', model)
        engine.load(QUrl.fromLocalFile(str(ROOT / 'apps/dylanos-app-center/qml/Main.qml')))
        self.assertTrue(engine.rootObjects())
        app.processEvents()
        return app, model, engine, engine.rootObjects()[0]

    def test_app_center_opens_as_fullscreen_overlay(self):
        _app, _model, _engine, window = self.load_window()
        self.assertEqual(window.visibility(), QWindow.FullScreen)
        self.assertTrue(window.flags() & Qt.FramelessWindowHint)
        window.close()

    def test_app_center_has_no_window_chrome_actions(self):
        _app, _model, _engine, window = self.load_window()
        names = set()
        for item in [window, *window.findChildren(QObject)]:
            interface = QAccessible.queryAccessibleInterface(item)
            if interface:
                name = interface.text(QAccessible.Text.Name)
                if name:
                    names.add(name)
        self.assertTrue(names.isdisjoint({
            'Cerrar App Center',
            'Minimizar App Center',
            'Maximizar o restaurar App Center',
        }))
        window.close()

    def test_search_paging_and_resize(self):
        app = QGuiApplication.instance() or QGuiApplication([])
        model = Catalog()
        engine = QQmlApplicationEngine()
        engine.addImageProvider('icon', Icons())
        engine.rootContext().setContextProperty('appModel', model)
        engine.load(QUrl.fromLocalFile(str(ROOT / 'apps/dylanos-app-center/qml/Main.qml')))
        self.assertTrue(engine.rootObjects())
        window = engine.rootObjects()[0]
        window.setVisibility(QWindow.Windowed)
        window.resize(800, 600)
        app.processEvents()
        self.assertEqual(window.property('columns'), 4)
        self.assertEqual(window.property('pageSize'), 8)
        self.assertEqual(window.property('totalPages'), 4)
        window.goToPage(3, -1)
        self.assertEqual(window.property('currentPage'), 3)
        window.applySearch('missing')
        self.assertEqual(window.property('currentPage'), 0)
        self.assertEqual(window.property('totalPages'), 1)
        self.assertEqual(window.property('pageItems'), [])
        window.applySearch('App 01')
        self.assertEqual(len(window.property('pageItems')), 1)
        window.resize(1440, 900)
        app.processEvents()
        self.assertEqual(window.property('columns'), 6)
        self.assertEqual(window.property('pageSize'), 18)
        window.close()
