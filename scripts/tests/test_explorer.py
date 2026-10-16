import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps/dylanos-explorer"


class ExplorerStructureTest(unittest.TestCase):
    """DylanOS Explorer: gestor de archivos nativo Qt6/QML de DylanOS Crimson."""

    def test_project_structure(self):
        for f in ("CMakeLists.txt", "README.md", "docs/ARCHITECTURE.md", "src/main.cpp",
                  "src/models/FileListModel.cpp", "src/services/ExplorerController.cpp",
                  "src/services/FileOperations.cpp", "tests/tst_fileoperations.cpp",
                  "qml/Main.qml", "qml/pages/HomePage.qml", "qml/pages/DirectoryPage.qml",
                  "qml/theme/Theme.qml", "qml/theme/Icons.qml"):
            self.assertTrue((APP / f).exists(), f)

    def test_qml_files_declared_in_cmake_exist(self):
        import re
        cmake = (APP / "CMakeLists.txt").read_text(encoding="utf-8")
        for ref in re.findall(r"qml/([\w/]+\.qml)", cmake):
            self.assertTrue((APP / "qml" / ref).exists(), ref)
        self.assertIn("qt_add_qml_module", cmake)
        self.assertIn("URI DylanOS.Explorer", cmake)
        self.assertIn("Qt6::Concurrent", cmake)

    def test_no_web_runtime(self):
        main = (APP / "src/main.cpp").read_text(encoding="utf-8")
        self.assertIn("QQmlApplicationEngine", main)
        self.assertNotIn("WebEngine", main)
        self.assertNotIn("QProcess", main)

    def test_security_contract(self):
        ops = (APP / "src/services/FileOperations.cpp").read_text(encoding="utf-8")
        self.assertIn("isProtectedPath", ops)
        self.assertIn("moveToTrash", ops)
        self.assertNotIn("system(", ops)
        self.assertNotIn("QProcess", ops)
        # sin sudo y sin concatenar comandos
        for f in APP.rglob("*.cpp"):
            self.assertNotIn("sudo", f.read_text(encoding="utf-8"), f)

    def test_desktop_entry(self):
        desktop = (APP / "assets/org.dylanos.explorer.desktop").read_text(encoding="utf-8")
        self.assertIn("Name=DylanOS Explorer", desktop)
        self.assertIn("Exec=dylanos-explorer", desktop)
        self.assertIn("Icon=dylanos-explorer", desktop)
        self.assertIn("inode/directory", desktop)
        cmake = (APP / "CMakeLists.txt").read_text(encoding="utf-8")
        self.assertIn("org.dylanos.explorer.desktop", cmake)

    def test_launcher_wiring(self):
        # workspace y stage.py lanzan el Explorer nativo
        backend = (ROOT / "apps/workspace/backend.py").read_text(encoding="utf-8")
        self.assertIn('"files": ["dylanos-explorer"]', backend)
        self.assertNotIn('"files": ["dolphin"]', backend)
        stage = (ROOT / "scripts/stage.py").read_text(encoding="utf-8")
        self.assertIn('"explorer", "Archivos", "dylanos-explorer"', stage)
        layout = (ROOT / "themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        self.assertIn("applications:org.dylanos.explorer.desktop", layout)
        # dolphin permanece instalado como vía de reversión (no se desinstala)
        default = (ROOT / "packages/default/packages.list").read_text(encoding="utf-8")
        self.assertIn("dolphin", default.split())

    def test_build_wiring(self):
        buildsh = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
        self.assertIn("dylanos-explorer/build", buildsh)
        self.assertIn("dylanos-src/dylanos-explorer", buildsh)

    def test_readme_documents_status(self):
        readme = (APP / "README.md").read_text(encoding="utf-8")
        self.assertIn("cmake", readme.lower())
        # el informe debe ser honesto sobre lo pendiente
        self.assertTrue("Pendiente" in readme or "pendiente" in readme)

    def test_reference_prototype_preserved(self):
        self.assertTrue((ROOT / "previews/DylanOS explorer/DylanOS Explorer.zip").exists())


if __name__ == "__main__":
    unittest.main()
