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

    def test_sql_catalog_system(self):
        import sqlite3
        db_path = ROOT / "apps/dylanos-store/catalog/store.db"
        self.assertTrue(db_path.exists(), "el catálogo SQLite debe vivir en el repo")
        db = sqlite3.connect(db_path)
        apps = db.execute("SELECT package, backend, shelf FROM apps").fetchall()
        self.assertGreater(len(apps), 10)
        valid_backends = {"apt", "flatpak"}
        for package, backend, shelf in apps:
            self.assertTrue(package, "toda app necesita al menos nombre de paquete")
            self.assertIn(backend, valid_backends, f"gestor no válido: {backend}")
            self.assertTrue(shelf, "toda app pertenece a una estantería")
        # el gestor 'discover' del usuario se normaliza a flatpak en la app
        self.assertFalse(any(b == "discover" for _, b, _ in apps))
        db.close()

    def test_sql_client_wiring(self):
        sync_h = (STORE / "services/CatalogSync.h").read_text(encoding="utf-8")
        sync_cpp = (STORE / "services/CatalogSync.cpp").read_text(encoding="utf-8")
        self.assertIn("raw.githubusercontent.com", sync_cpp)
        self.assertIn("applySeed", sync_h)
        self.assertIn("refresh", sync_h)
        controller = (STORE / "models/StoreController.h").read_text(encoding="utf-8")
        self.assertIn("applyShelfRows", controller)
        self.assertIn("shelfVersion", controller)
        main_cpp = (STORE / "main.cpp").read_text(encoding="utf-8")
        self.assertIn("applySeed()", main_cpp)
        self.assertIn("CatalogSync::refresh", main_cpp)
        cmake = (STORE / "CMakeLists.txt").read_text(encoding="utf-8")
        self.assertIn("Qt6::Sql", cmake)
        self.assertIn("catalog/store.db", cmake)
        default = (ROOT / "packages/default/packages.list").read_text(encoding="utf-8")
        self.assertIn("libqt6sql6-sqlite", default.split())

    def test_hero_pager_drag_and_arrows(self):
        home = (STORE / "qml/pages/HomePage.qml").read_text(encoding="utf-8")
        self.assertIn("Keys.onLeftPressed", home)
        self.assertIn("Keys.onRightPressed", home)
        self.assertIn("prevHero()", home)
        self.assertIn("nextHero()", home)
        self.assertIn("heroSwipe", home)

    def test_dock_and_panel_wiring(self):
        dock = (ROOT / "apps/com.dylanos.dock/contents/ui/main.qml").read_text(encoding="utf-8")
        self.assertIn("applications:org.dylanos.store.desktop", dock)
        layout = (ROOT / "themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        self.assertIn('dock.addWidget("com.dylanos.dock")', layout)
        self.assertIn('dock.addWidget("org.kde.plasma.trash")', layout)
        # la barra superior se oculta bajo ventanas a pantalla completa
        self.assertIn('menuBar.hiding = "letwindowscover"', layout)

    def test_grub_live_visible_installed_hidden(self):
        iso = (ROOT / "scripts/iso.sh").read_text(encoding="utf-8")
        self.assertIn("set timeout=3", iso)
        self.assertNotIn("set timeout=10", iso)
        self.assertNotIn("set timeout=0", iso)
        stage = (ROOT / "scripts/stage.py").read_text(encoding="utf-8")
        self.assertIn("GRUB_TIMEOUT=0", stage)
        self.assertIn("GRUB_TIMEOUT_STYLE=hidden", stage)

    def test_appstream_cache_survives_apt_index_cleanup(self):
        build = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
        cache = build.index("appstreamcli refresh-cache --force")
        cleanup = build.index("rm -rf /var/lib/apt/lists/*")
        self.assertLess(cache, cleanup)
        self.assertIn("qml6-module-qtquick-shapes", (ROOT / "packages/default/packages.list").read_text())

    def test_qml_singletons_qtobject_sin_hijos(self):
        """QtObject no tiene propiedad por defecto: un hijo directo no carga.

        Colors.qml declaraba `SystemPalette { ... }` dentro de un QtObject raíz; el
        árbol compilaba, pero la tienda no arrancaba (fallo al cargar el QML).
        """
        for path in sorted((STORE / "qml/theme").glob("*.qml")):
            lines = path.read_text(encoding="utf-8").splitlines()
            body = [line for line in lines if not line.strip().startswith("//")]
            root = next((line for line in body if line.rstrip().endswith("{")), "")
            if root.split()[0] != "QtObject":
                continue
            for number, line in enumerate(lines, 1):
                if re.match(r"^    [A-Z][\w.]* \{", line):
                    self.fail(f"{path.name}:{number} declara un hijo dentro de QtObject: {line.strip()}")

    def test_vistas_por_enlace_directo_son_reactivas(self):
        """Abrir una ficha o las actualizaciones al arrancar debe resolverse al llegar
        el catálogo: sin la dependencia de shelfVersion la vista queda vacía."""
        detail = (STORE / "qml/pages/DetailPage.qml").read_text(encoding="utf-8")
        self.assertIn("Store.shelfVersion >= 0 ? Store.app(appId)", detail)
        updates = (STORE / "qml/pages/UpdatesPage.qml").read_text(encoding="utf-8")
        self.assertIn('Store.shelfVersion >= 0 ? Store.list("updates")', updates)

    def test_descripcion_larga_diferida(self):
        """La lista no retiene la descripción larga de las ~2600 apps: se pide al abrir
        la ficha. El campo se lee del backend una sola vez."""
        item = (STORE / "models/AppItem.h").read_text(encoding="utf-8")
        self.assertIn("Q_PROPERTY(QString longDesc READ longDesc CONSTANT)", item)
        self.assertNotIn("m_short, m_long", item)
        controller = (STORE / "models/StoreController.cpp").read_text(encoding="utf-8")
        self.assertNotIn("a->m_long = res->longDescription()", controller)
        self.assertIn("a->m_backend = m_backend", controller)

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
        self.assertIn(
            "flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo",
            buildsh,
        )
        self.assertIn("dylanos-store/build", buildsh)
        self.assertIn("dylanos-store/catalog/store.db", buildsh)
        self.assertIn("ctest --test-dir /tmp/dylanos-src/dylanos-store/build", buildsh)
        self.assertIn("apt-get -y purge", buildsh)


if __name__ == "__main__":
    unittest.main()
