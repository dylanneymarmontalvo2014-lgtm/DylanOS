import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODEL_H = (ROOT / "apps/dylanos-app-center/src/appmodel.h").read_text()
MODEL_CPP = (ROOT / "apps/dylanos-app-center/src/appmodel.cpp").read_text()
QML = (ROOT / "apps/dylanos-app-center/qml/Main.qml").read_text()
CMAKE = (ROOT / "apps/dylanos-app-center/CMakeLists.txt").read_text()
DESKTOP = (ROOT / "apps/dylanos-app-center/dylanos-app-center.desktop").read_text()


class AppCenterContractTest(unittest.TestCase):
    def test_launch_contract_uses_desktop_id(self):
        self.assertIn("launchApp(const QString &desktopId)", MODEL_H)
        self.assertIn('storageId() == desktopId', MODEL_CPP)
        self.assertNotIn("globalIndex", MODEL_CPP)
        self.assertNotIn("globalIndex", QML)
        self.assertRegex(QML, r"appModel\.launchApp\(\s*modelData\.desktopId\s*\)")

    def test_install_contract_is_not_duplicated(self):
        self.assertEqual(CMAKE.count("install(\n    TARGETS dylanos-app-center"), 1)
        self.assertEqual(CMAKE.count("FILES dylanos-app-center.desktop"), 1)
        self.assertEqual(CMAKE.count("FILES icons/dylanos-app-center.png"), 1)
        self.assertEqual(CMAKE.count("include(GNUInstallDirs)"), 1)

    def test_desktop_uses_path_resolved_executable(self):
        self.assertIn("Exec=dylanos-app-center", DESKTOP)
        self.assertNotIn("/usr/local/bin", DESKTOP)


if __name__ == "__main__":
    unittest.main()
