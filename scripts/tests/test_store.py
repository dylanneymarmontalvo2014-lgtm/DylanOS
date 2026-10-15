import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORE = ROOT / "apps/dylanos-store/src/store"


class StoreStructureTest(unittest.TestCase):
    """La DylanOS Store es un fork nativo de Discover: UI 100% del prototipo,
    datos reales vía libdiscover y ningún rastro visible de Discover/KDE."""

    def test_pages_and_components_present(self):
        for page in ("HomePage", "CategoriesPage", "BrowsePage", "SearchPage", "DetailPage",
                     "InstalledPage", "UpdatesPage", "LibraryPage", "SettingsPage"):
            self.assertTrue((STORE / f"qml/pages/{page}.qml").exists(), page)
        self.assertFalse((STORE / "qml/pages/StatesPage.qml").exists(),
                         "La página de estados era un artefacto del modo demo")

    def test_real_backend_and_controller(self):
        self.assertTrue((STORE / "services/LibDiscoverBackend.cpp").exists())
        self.assertTrue((STORE / "models/StoreController.cpp").exists())
        controller = (STORE / "models/StoreController.cpp").read_text(encoding="utf-8")
        self.assertIn("loadFromResources", controller)
        self.assertIn("ResourcesModel", controller)
        backend = (STORE / "services/LibDiscoverBackend.cpp").read_text(encoding="utf-8")
        self.assertIn("installApplication", backend)
        self.assertIn("removeApplication", backend)

    def test_qml_files_declared_in_cmake_exist(self):
        cmake = (STORE / "CMakeLists.txt").read_text(encoding="utf-8")
        for ref in re.findall(r"\$\{QML_DIR\}/([\w/]+\.qml)", cmake):
            self.assertTrue((STORE / "qml" / ref).exists(), ref)

    def test_logo_is_dylanos_not_letter_block(self):
        main = (STORE / "qml/Main.qml").read_text(encoding="utf-8")
        self.assertIn("qrc:/data/logo.png", main)
        self.assertNotIn('text: "D"', main)
        self.assertTrue((STORE / "data/logo.png").exists())
        self.assertEqual((STORE / "data/logo.png").read_bytes(),
                         (ROOT / "branding/logo.png").read_bytes())

    def test_no_demo_artifacts(self):
        main = (STORE / "qml/Main.qml").read_text(encoding="utf-8")
        self.assertNotIn("Datos de demostración", main)
        sidebar = (STORE / "qml/components/SidebarPanel.qml").read_text(encoding="utf-8")
        self.assertNotIn('"states"', sidebar)
        settings = (STORE / "qml/pages/SettingsPage.qml").read_text(encoding="utf-8")
        self.assertNotIn("Demostración", settings)
        installed = (STORE / "qml/pages/InstalledPage.qml").read_text(encoding="utf-8")
        self.assertNotIn("demostración", installed)
        updates = (STORE / "qml/pages/UpdatesPage.qml").read_text(encoding="utf-8")
        self.assertNotIn("Diálogo de demostración", updates)

    def test_no_visible_discover_branding(self):
        texts = list((STORE / "qml").rglob("*.qml"))
        texts += [STORE / "org.dylanos.store.desktop.cmake",
                  ROOT / "apps/dylanos-store/src/notifier/org.dylanos.store.notifier.desktop.cmake"]
        for f in texts:
            content = f.read_text(encoding="utf-8")
            self.assertNotIn("Discover", content, f)
            self.assertNotIn("plasma-discover", content, f)

    def test_desktop_entries(self):
        desktop = (STORE / "org.dylanos.store.desktop.cmake").read_text(encoding="utf-8")
        self.assertIn("Name=DylanOS Store", desktop)
        self.assertIn("Exec=dylanos-store", desktop)
        self.assertIn("Icon=dylanos-store", desktop)
        notifier = (ROOT / "apps/dylanos-store/src/notifier/org.dylanos.store.notifier.desktop.cmake").read_text(encoding="utf-8")
        self.assertIn("DylanOS Store Notifier", notifier)

    def test_notifier_rebranded(self):
        cpp = (ROOT / "apps/dylanos-store/src/notifier/DiscoverNotifier.cpp").read_text(encoding="utf-8")
        self.assertNotIn("org.kde.discover", cpp)
        self.assertIn("dylanos-store", cpp)
        item = (ROOT / "apps/dylanos-store/src/notifier/NotifierItem.cpp").read_text(encoding="utf-8")
        self.assertIn("Abrir DylanOS Store", item)
        self.assertNotIn('"plasmadiscover"', item)

    def test_workspace_store_page_removed(self):
        self.assertFalse((ROOT / "apps/workspace/qml/StorePage.qml").exists())
        main = (ROOT / "apps/workspace/qml/Main.qml").read_text(encoding="utf-8")
        self.assertNotIn("StorePage.qml", main)
        self.assertNotIn('"DylanOS Store"', main)
        backend = (ROOT / "apps/workspace/backend.py").read_text(encoding="utf-8")
        self.assertNotIn("plasma-discover", backend)
        self.assertIn('"store": ["dylanos-store"]', backend)

    def test_packages_and_build_wiring(self):
        default = (ROOT / "packages/default/packages.list").read_text(encoding="utf-8")
        self.assertNotIn("plasma-discover", default)
        for runtime in ("appstream", "libpackagekitqt6-1", "packagekit", "flatpak"):
            self.assertIn(runtime, default.split())
        build = (ROOT / "packages/build/packages.list").read_text(encoding="utf-8")
        for dev in ("libpackagekitqt6-dev", "libappstreamqt-dev", "qcoro-qt6-dev",
                    "libflatpak-dev", "qt6-svg-dev", "kirigami-addons-dev"):
            self.assertIn(dev, build.split())
        buildsh = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
        self.assertIn("dylanos-store/build", buildsh)
        self.assertIn("ctest --test-dir /tmp/dylanos-src/dylanos-store/build", buildsh)
        self.assertIn("apt-get -y purge", buildsh)


if __name__ == "__main__":
    unittest.main()
