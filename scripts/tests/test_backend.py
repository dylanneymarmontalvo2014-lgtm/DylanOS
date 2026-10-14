"""Exercise the Qt bridge with real temporary files and its asynchronous signals."""
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "apps/workspace"))
try:
    from PySide6.QtGui import QGuiApplication
    from backend import Backend
    HAS_QT = True
except ImportError:
    HAS_QT = False


@unittest.skipUnless(HAS_QT, "PySide6 and psutil required")
class BackendTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        os.environ["XDG_DATA_HOME"] = cls.temp.name
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        cls.app.setOrganizationName("DylanOSTest")
        cls.app.setApplicationName("WorkspaceTest")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        self.backend = Backend()
        self.messages = []
        self.backend.message.connect(self.messages.append)
        self.wait()
        self.backend.navigate(str(self.root))
        self.wait()

    def tearDown(self):
        self.backend.pool.waitForDone()
        self.backend.timer.stop()
        self.backend.notes_store.db.close()
        self.backend.deleteLater()
        self.app.processEvents()
        self.folder.cleanup()

    def wait(self):
        end = time.monotonic() + 5
        while self.backend.busy and time.monotonic() < end:
            self.app.processEvents()
            time.sleep(.005)
        self.assertFalse(self.backend.busy, "Background operation timed out")

    def test_independent_apps_and_monitor_lifecycle(self):
        from unittest.mock import patch
        import sys
        isolated = Backend(page="dev")
        self.assertFalse(isolated.timer.isActive())
        self.assertFalse(isolated.watcher.directories())
        self.assertEqual(isolated.stats["processes"], [])
        with patch.object(isolated, "launch") as launch:
            isolated.openApp("monitor")
            args = launch.call_args.args[0]
            self.assertEqual(args[0], sys.executable)
            self.assertEqual(args[-2:], ["--page", "monitor"])
            isolated.openApp("invalid")
            self.assertEqual(launch.call_count, 1)
        self.backend.pauseMonitor(True)
        self.assertFalse(self.backend.timer.isActive())
        self.backend.pauseMonitor(False)
        self.assertTrue(self.backend.timer.isActive())
        self.assertTrue(self.backend.stats["cpuHistory"])
        self.assertLessEqual(len(self.backend.stats["cpuHistory"]), 60)
        isolated.notes_store.db.close()
        isolated.deleteLater()

    def test_navigation_failure_preserves_current_folder_and_history(self):
        self.backend.newFolder("sub")
        self.wait()
        self.backend.navigate(str(self.root / "sub"))
        self.wait()
        self.backend.back()
        self.wait()
        self.assertEqual(self.backend.folder, str(self.root))
        self.backend.navigate(str(self.root / "missing"))
        self.wait()
        self.assertEqual(self.backend.folder, str(self.root))
        self.assertTrue(self.messages)
        self.backend.forward()
        self.wait()
        self.assertEqual(self.backend.folder, str(self.root / "sub"))

    def test_rename_will_not_replace_existing_files(self):
        a, b = self.root / "a", self.root / "b"
        a.write_text("A")
        b.write_text("B")
        self.backend.rename(str(a), "b")
        self.assertEqual(b.read_text(), "B")
        self.assertEqual(a.read_text(), "A")
        self.backend.rename(str(a), "renamed")
        self.wait()
        self.assertEqual((self.root / "renamed").read_text(), "A")

    def test_async_copy_and_project_creation(self):
        original = self.root / "original"
        original.write_text("contenido")
        dest = self.root / "dest"
        dest.mkdir()
        self.backend.copy(str(original))
        self.backend.navigate(str(dest))
        self.wait()
        self.backend.paste()
        self.wait()
        self.assertEqual((dest / "original").read_text(), "contenido")
        projects = []
        self.backend.projectCreated.connect(projects.append)
        self.backend.createProject(str(dest), "demo", "Python")
        self.wait()
        self.assertEqual(projects, [str(dest / "demo")])
        self.assertTrue((dest / "demo/main.py").exists())


if __name__ == "__main__":
    unittest.main()
