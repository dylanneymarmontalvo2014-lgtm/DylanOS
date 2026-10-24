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

    def test_dolphin_engine(self):
        # El motor de datos es el de Dolphin (KIO), no una reimplementación.
        model = (APP / "src/models/FileListModel.cpp").read_text(encoding="utf-8")
        self.assertIn("KDirLister", model)
        places = (APP / "src/models/PlacesService.cpp").read_text(encoding="utf-8")
        self.assertIn("KFilePlacesModel", places)
        self.assertIn("requestSetup", places)
        ctl = (APP / "src/services/ExplorerController.cpp").read_text(encoding="utf-8")
        self.assertIn("KIO::trash", ctl)
        self.assertIn("KIO::emptyTrash", ctl)
        self.assertIn("KIO::restoreFromTrash", ctl)
        self.assertIn("FileUndoManager", ctl)
        self.assertIn("OpenUrlJob", ctl)
        cmake = (APP / "CMakeLists.txt").read_text(encoding="utf-8")
        self.assertIn("KF6::KIOCore", cmake)
        self.assertIn("KF6::KIOFileWidgets", cmake)
        main_qml = (APP / "qml/Main.qml").read_text(encoding="utf-8")
        self.assertIn('Ctrl+Z', main_qml)  # deshacer, como Dolphin

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
        # El menú "Archivos" abre el Explorer real: stage.py copia el .desktop
        # canónico y elimina la entrada obsoleta que abría el workspace.
        self.assertIn("apps/dylanos-explorer/assets/org.dylanos.explorer.desktop", stage)
        self.assertIn('remove("/usr/share/applications/org.dylanos.files.desktop")', stage)
        layout = (ROOT / "themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        self.assertIn('dock.addWidget("com.dylanos.dock")', layout)
        dock = (ROOT / "apps/com.dylanos.dock/contents/ui/main.qml").read_text(encoding="utf-8")
        self.assertIn("applications:org.dylanos.explorer.desktop", dock)
        # Un solo explorador: dolphin ya no se envía en el ISO; el Explorer
        # (motor KIO de Dolphin) es el gestor de archivos del sistema.
        default = (ROOT / "packages/default/packages.list").read_text(encoding="utf-8")
        package_lines = [l.strip() for l in default.splitlines() if l.strip() and not l.strip().startswith("#")]
        self.assertNotIn("dolphin", package_lines)
        stage = (ROOT / "scripts/stage.py").read_text(encoding="utf-8")
        self.assertIn("inode/directory=org.dylanos.explorer.desktop", stage)

    def test_build_wiring(self):
        buildsh = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
        self.assertIn("dylanos-explorer/build", buildsh)
        self.assertIn("dylanos-src/dylanos-explorer", buildsh)

    def test_readme_documents_status(self):
        readme = (APP / "README.md").read_text(encoding="utf-8")
        self.assertIn("cmake", readme.lower())
        # el informe debe ser honesto sobre lo pendiente
        self.assertTrue("Pendiente" in readme or "pendiente" in readme)

    def test_reference_previews_preserved(self):
        for name in ("explorer.png", "explorer-home.png", "explorer-dir.png"):
            preview = ROOT / "previews/DylanOS explorer" / name
            self.assertTrue(preview.is_file(), name)
            self.assertGreater(preview.stat().st_size, 0, name)


if __name__ == "__main__":
    unittest.main()
