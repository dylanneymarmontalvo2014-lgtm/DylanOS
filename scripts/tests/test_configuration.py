"""Pruebas de DylanOS Configuration (app nativa + integracion de staging)."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

spec = importlib.util.spec_from_file_location("stage", ROOT / "scripts/stage.py")
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

APP = ROOT / "apps/dylanos-configuration"


class TestDylanOSConfiguration(unittest.TestCase):

    def test_estructura_aplicacion(self):
        for rel in [
            "CMakeLists.txt",
            "src/main.cpp",
            "src/services/SystemService.cpp",
            "src/services/LucideProvider.cpp",
            "qml/theme/Theme.qml",
            "qml/Main.qml",
            "assets/logo.png",
            "assets/dylanos-configuration.svg",
            "assets/dylanos-configuration.png",
            "assets/org.dylanos.configuration.desktop",
        ]:
            self.assertTrue((APP / rel).is_file(), rel)

    def test_16_paginas_del_prototipo(self):
        pages = {p.stem for p in (APP / "qml/pages").glob("*.qml")}
        for esperada in ["SystemPage", "AboutPage", "PersonalizationPage", "NetworkPage",
                         "BluetoothPage", "AppsPage", "AccountsPage", "DateTimePage",
                         "PrivacyPage", "PowerPage", "AccessibilityPage", "UpdatesPage",
                         "DisplayPage", "SoundPage", "NotificationsPage", "StoragePage"]:
            self.assertIn(esperada, pages)

    def test_crimson_glass_is_a_real_configuration_route(self):
        page = APP / "qml/pages/CrimsonGlassPage.qml"
        preview = APP / "qml/components/GlassPreview.qml"
        self.assertTrue(page.is_file())
        self.assertTrue(preview.is_file())
        content = page.read_text(encoding="utf-8")
        for key in ["enabled", "globalEffects", "glassIntensity", "transparency",
                    "blur", "reflections", "shadows", "cornerRadius", "accent",
                    "mode", "panelTransparency", "dockTransparency", "menuTransparency",
                    "windowEffects", "backgroundBlur", "animations", "animationDuration",
                    "additionalEffects", "lowPower", "autoDetect"]:
            self.assertIn(f'"{key}"', content)
        self.assertIn("CrimsonGlass.apply()", content)
        self.assertIn("CrimsonGlass.restorePrevious()", content)
        self.assertIn("CrimsonGlass.resetDefaults()", content)
        self.assertIn("CrimsonGlass.detectCapabilities()", content)
        self.assertNotIn("demo", content.lower())

        main = (APP / "qml/Main.qml").read_text(encoding="utf-8")
        self.assertIn('{ id: "crimson-glass"', main)
        self.assertIn('case "crimson-glass"', main)
        personalization = (APP / "qml/pages/PersonalizationPage.qml").read_text(encoding="utf-8")
        self.assertIn('Window.window.go("crimson-glass")', personalization)

        source = (APP / "src/main.cpp").read_text(encoding="utf-8")
        self.assertIn('setContextProperty(QStringLiteral("CrimsonGlass")', source)
        self.assertIn('QStringLiteral("apply-crimson-glass")', source)
        self.assertIn("glassService->apply()", source)

    def test_crimson_glass_controls_respect_motion_and_contrast(self):
        components = APP / "qml/components"
        for name in ["DToggle.qml", "DSlider.qml", "DSelect.qml"]:
            content = (components / name).read_text(encoding="utf-8")
            self.assertIn("motionDuration", content, name)
            self.assertIn("CrimsonGlass.effectiveEffects.animations", content, name)
            self.assertIn("Theme.glassBorder", content, name)
            self.assertIn("Theme.glassSpecular", content, name)

        for variant in ["DylanOS-Crimson", "DylanOS-Crimson-Light"]:
            for version in ["gtk-3.0", "gtk-4.0"]:
                css = (ROOT / "themes/gtk" / variant / version / "gtk.css").read_text(encoding="utf-8")
                self.assertIn("@define-color glass_surface", css)
                self.assertIn("@define-color glass_border", css)
                self.assertIn("@define-color glass_specular", css)
                self.assertIn("background-color: @glass_surface", css)

    def test_navigation_history_restores_route_and_selected_tab(self):
        main = (APP / "qml/Main.qml").read_text(encoding="utf-8")
        self.assertIn('property var history: [{ route: startPage, tab: "" }]', main)
        self.assertIn('history = history.concat([{ route: target, tab: nextTab }])', main)
        self.assertIn('route = prev.route', main)
        self.assertIn('tab = prev.tab || ""', main)
        # Tabs are real page state: returning to AppsPage must preserve the
        # Predeterminadas tab instead of silently showing its Instaladas default.
        apps = (APP / "qml/pages/AppsPage.qml").read_text(encoding="utf-8")
        self.assertIn('property string tab: Window.window && Window.window.tab ? Window.window.tab : "Instaladas"', apps)
        self.assertIn('visible: root.tab === "Predeterminadas"', apps)

    def test_sin_rastro_de_systemsettings_en_la_ui(self):
        for qml in APP.rglob("*.qml"):
            contenido = qml.read_text(encoding="utf-8")
            self.assertNotIn("systemsettings", contenido.lower(), str(qml))

    def test_entrada_de_escritorio(self):
        entry = (APP / "assets/org.dylanos.configuration.desktop").read_text()
        self.assertIn("Name=DylanOS Configuration", entry)
        self.assertIn("Exec=dylanos-configuration", entry)
        self.assertIn("Icon=dylanos-configuration", entry)
        self.assertNotIn("systemsettings", entry)

    def test_sound_selectors_map_device_names_to_friendly_descriptions(self):
        sound = (APP / "qml/pages/SoundPage.qml").read_text(encoding="utf-8")
        self.assertIn("function sinkDescription(name)", sound)
        self.assertIn("function sourceDescription(name)", sound)
        self.assertIn("devices[i].name === name", sound)
        self.assertIn("return devices[i].description || devices[i].name", sound)
        self.assertIn("value: root.sinkDescription(state.defaultSink)", sound)
        self.assertIn("value: root.sourceDescription(state.defaultSource)", sound)
        self.assertIn("System.setDefaultSink(root.findSink(v))", sound)
        self.assertIn("System.setDefaultSource(root.findSource(v))", sound)

    def test_sound_device_parser_reads_description_not_short_list_state(self):
        cpp = (APP / "src/services/SystemService.cpp").read_text(encoding="utf-8")
        self.assertIn('QStringLiteral("list"), kind', cpp)
        self.assertIn('Description: (.+)$', cpp)
        self.assertIn('Name: (.+)$', cpp)
        self.assertIn('current.insert(QStringLiteral("name"), nameMatch.captured(1).trimmed())', cpp)
        self.assertNotIn('fields.value(fields.size() - 1, fields.value(1))', cpp)

    def test_power_page_handles_missing_battery_percentage(self):
        power = (APP / "qml/pages/PowerPage.qml").read_text(encoding="utf-8")
        self.assertIn("root.state.battery.percent !== undefined", power)
        self.assertIn("Number(root.state.battery.percent)", power)

    def test_system_service_glass_toggle_keeps_light_variant(self):
        cpp = (APP / "src/services/SystemService.cpp").read_text(encoding="utf-8")
        self.assertIn('QStringLiteral("__aurorae__svg__DylanOS-Crimson-Glass-Light")', cpp)
        self.assertIn('QStringLiteral("__aurorae__svg__DylanOS-Crimson-Glass")', cpp)
        self.assertIn("glassTheme", cpp)

    def test_staging_registra_dylanos_configuration(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            stage.stage(root)
            entry = root / "usr/share/applications/org.dylanos.configuration.desktop"
            self.assertTrue(entry.is_file())
            self.assertIn("Exec=dylanos-configuration", entry.read_text())
            icono = root / "usr/share/icons/hicolor/scalable/apps/dylanos-configuration.svg"
            self.assertTrue(icono.is_file())
            # Sin duplicados visibles: las entradas de otros centros de
            # configuracion quedan ocultas (NoDisplay) si existen en el root.
            ocultas = [root / "usr/share/applications/systemsettings.desktop",
                       root / "usr/share/applications/org.kde.kinfocenter.desktop"]
            for oculta in ocultas:
                if oculta.exists():
                    self.assertIn("NoDisplay=true", oculta.read_text())
            # El navegador oficial suma su entrada al conjunto canónico del menú.
            browser = root / "usr/share/applications/org.dylanos.browser.desktop"
            self.assertTrue(browser.is_file())
            # 11 entradas canónicas + la galería DylanOS Widgets (app nativa).
            entries = sorted(p.name for p in (root / "usr/share/applications").glob("org.dylanos.*.desktop"))
            self.assertEqual(len(entries), 12, entries)
            self.assertIn("org.dylanos.widgets.desktop", entries)

    def test_version_single_source_pre_beta_1_1_0(self):
        """La versión vive en CMake (DYLANOS_RELEASE) y os-release; sin copias."""
        cmake = (APP / "CMakeLists.txt").read_text(encoding="utf-8")
        self.assertIn('project(dylanos-configuration VERSION 1.1.0', cmake)
        self.assertIn('set(DYLANOS_RELEASE "1.1.0-pre-beta" CACHE STRING', cmake)
        self.assertIn('DYLANOS_VERSION="${DYLANOS_RELEASE}"', cmake)
        main_cpp = (APP / "src/main.cpp").read_text(encoding="utf-8")
        self.assertIn('setApplicationVersion(QStringLiteral(DYLANOS_VERSION))', main_cpp)
        cpp = (APP / "src/services/SystemService.cpp").read_text(encoding="utf-8")
        self.assertIn('QStringLiteral(DYLANOS_VERSION)', cpp)
        self.assertNotIn('QStringLiteral("1.0 Beta")', cpp)
        self.assertIn("QString SystemService::version() const", cpp)
        self.assertIn("QString SystemService::releaseChannel() const", cpp)
        for page in ["qml/pages/SystemPage.qml", "qml/pages/AboutPage.qml"]:
            content = (APP / page).read_text(encoding="utf-8")
            self.assertIn("System.version", content)
            self.assertIn("System.releaseChannel", content)
            self.assertNotIn("1.0 Beta", content)
            self.assertNotIn('text: "Estable"', content)

    def test_theme_watch_survives_kdeglobals_rewrite(self):
        cpp = (APP / "src/services/SystemService.cpp").read_text(encoding="utf-8")
        self.assertIn("m_watcher.files().contains(path)", cpp)
        self.assertIn("m_watcher.addPath(path)", cpp)

    def test_selector_nativo_de_iconos(self):
        # El selector de tema de iconos es nativo (no atajo al KCM externo),
        # lista los temas instalados y aplica vía kdeglobals [Icons] Theme.
        cpp = (APP / "src/services/SystemService.cpp").read_text(encoding="utf-8")
        self.assertIn("QVariantList SystemService::iconThemes()", cpp)
        self.assertIn("bool SystemService::applyIconTheme(const QString &name)", cpp)
        self.assertIn("QString SystemService::iconThemeName() const", cpp)
        self.assertIn("Icon Theme", cpp)   # grupos [Icon Theme] de los index.theme
        self.assertIn("Icons", cpp)        # grupo [Icons] de kdeglobals
        self.assertIn("GenericDataLocation", cpp)
        self.assertIn("XDG_DATA_DIRS", cpp)
        header = (APP / "src/services/SystemService.h").read_text(encoding="utf-8")
        self.assertIn("iconThemeName", header)
        self.assertIn("iconThemeChanged", header)
        page = (APP / "qml/pages/PersonalizationPage.qml").read_text(encoding="utf-8")
        self.assertIn("System.applyIconTheme", page)
        self.assertIn("iconThemeList", page)
        self.assertNotIn("kcm_icons", page)

    def test_selector_valida_temas_y_descubre_rutas_xdg(self):
        cpp = (APP / "src/services/SystemService.cpp").read_text(encoding="utf-8")
        self.assertIn("QStandardPaths::locateAll", cpp)
        self.assertIn("index.theme", cpp)
        self.assertIn("iconThemes()", cpp.split("bool SystemService::applyIconTheme", 1)[1])

    def test_selector_reintenta_watcher_despues_de_reescritura_atomica(self):
        cpp = (APP / "src/services/SystemService.cpp").read_text(encoding="utf-8")
        self.assertIn("QTimer::singleShot", cpp)

    def test_auto_updates_backend_real(self):
        cpp = (APP / "src/services/SystemService.cpp").read_text(encoding="utf-8")
        self.assertIn("QVariantMap SystemService::autoUpdates() const", cpp)
        self.assertIn("bool SystemService::setAutoUpdates(bool enabled)", cpp)
        self.assertIn("20auto-upgrades", cpp)
        self.assertIn("unattended-upgrade", cpp)
        updates = (APP / "qml/pages/UpdatesPage.qml").read_text(encoding="utf-8")
        self.assertIn("System.autoUpdates()", updates)
        self.assertIn("System.setAutoUpdates(v)", updates)
        self.assertNotIn('"Pendiente"', updates)
        # Sin herramienta de copias en el ecosistema: estado honesto, no botón muerto.
        self.assertIn('"No disponible"', updates)

    def test_estados_honestos_y_sin_codigo_muerto(self):
        access = (APP / "qml/pages/AccessibilityPage.qml").read_text(encoding="utf-8")
        self.assertIn('System.has("orca")', access)
        privacy = (APP / "qml/pages/PrivacyPage.qml").read_text(encoding="utf-8")
        self.assertNotIn("property bool autolock", privacy)
        self.assertNotIn("property int lockTimeout", privacy)

    def test_responsive_sidebar_compacta_y_breakpoints(self):
        theme = (APP / "qml/theme/Theme.qml").read_text(encoding="utf-8")
        self.assertIn("property bool compact: false", theme)
        main = (APP / "qml/Main.qml").read_text(encoding="utf-8")
        self.assertIn("minimumWidth: 880", main)
        self.assertIn("readonly property bool compact: width < 1024", main)
        self.assertIn("window.compact ? 92 : Theme.sidebarWidth", main)
        navrow = (APP / "qml/components/NavRow.qml").read_text(encoding="utf-8")
        self.assertIn("property bool compact: false", navrow)
        tabs = (APP / "qml/components/TabsBar.qml").read_text(encoding="utf-8")
        self.assertIn("Flow {", tabs)
        self.assertNotIn("\nRow {", tabs)

    def test_medidor_de_salida_proporcional_al_volumen(self):
        sound = (APP / "qml/pages/SoundPage.qml").read_text(encoding="utf-8")
        self.assertIn("Math.round((state.volume || 0) / 100 * 14)", sound)
        self.assertNotIn("index < 9", sound)


if __name__ == "__main__":
    unittest.main()
