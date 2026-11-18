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

    def test_no_invoca_modulos_kcm_inexistentes(self):
        """Cada openKcm() debe pedir módulos que DylanOS instala de verdad.

        La UI pedía kcm_sddm, kcm_login, kcm_behavior, kcm_location y
        user_manager, que no existen en la imagen: esos botones fallaban siempre
        con «No se encontró el módulo de configuración solicitado».
        """
        invalidos = {
            "kcm_sddm", "kcm_login", "kcm_behavior", "kcm_location",
            "desktopbehavior", "kcm_desktopbehavior", "kcm_locale", "user_manager",
        }
        usados = set()
        for qml in APP.rglob("*.qml"):
            contenido = qml.read_text(encoding="utf-8")
            for llamada in contenido.split("System.openKcm(")[1:]:
                lista = llamada.split("]", 1)[0]
                for modulo in lista.replace('"', ' ').replace(',', ' ').split():
                    if modulo.startswith("kcm_") or modulo in invalidos:
                        usados.add(modulo)
                        self.assertNotIn(
                            modulo, invalidos,
                            f"{qml.name} pide el módulo inexistente {modulo}",
                        )
        self.assertTrue(usados, "la UI debería seguir ofreciendo módulos reales")

    def test_kcmshell6_se_instala_en_la_imagen(self):
        """Configuration abre sus KCM con kcmshell6, que aporta libkf6kcmutils-bin.

        El ISO enviaba systemsettings pero no ese paquete, así que no existía
        /usr/bin/kcmshell6 y todas las acciones de configuración fallaban.
        """
        packages = (ROOT / "packages/default/packages.list").read_text(encoding="utf-8")
        lineas = [l.strip() for l in packages.splitlines() if l.strip() and not l.strip().startswith("#")]
        self.assertIn("libkf6kcmutils-bin", lineas)

    def test_qdbus_usa_el_binario_de_qt6(self):
        """`qdbus` no existe en Qt 6: el binario es qdbus6 (cerrar sesión fallaba)."""
        accounts = (APP / "qml/pages/AccountsPage.qml").read_text(encoding="utf-8")
        self.assertIn('System.has("qdbus6")', accounts)
        self.assertNotIn('launchDetached("qdbus"', accounts)

    def test_configuracion_del_sistema_no_delega_en_kde(self):
        """Abrir la configuración del sistema nunca debe mostrar el centro de KDE."""
        stage = (ROOT / "scripts/stage.py").read_text(encoding="utf-8")
        self.assertIn("/usr/bin/plasma-open-settings", stage)
        self.assertIn("/usr/bin/dylanos-configuration", stage)

    def test_systemsettings_redirige_a_dylanos_configuration(self):
        """El binario systemsettings no puede abrir el centro de KDE.

        Se conserva en la imagen porque históricamente aportaba kcmshell6, y
        cualquier invocación suya (bandeja, «Configurar escritorio», un KCM con
        Exec=systemsettings) abría «Configuración del sistema» de KDE en lugar
        de la configuración de DylanOS.
        """
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            fake = root / "usr/bin/systemsettings"
            fake.parent.mkdir(parents=True)
            fake.write_text("#!/bin/sh\necho KDE\n", encoding="utf-8")
            fake.chmod(0o755)

            stage.stage(root)

            wrapper = fake.read_text(encoding="utf-8")
            self.assertIn("exec /usr/bin/dylanos-configuration", wrapper)
            self.assertNotIn("echo KDE", wrapper)
            backup = root / "usr/bin/systemsettings.kde"
            self.assertTrue(backup.is_file(), "el binario original debe conservarse")
            self.assertIn("echo KDE", backup.read_text(encoding="utf-8"))

    def test_kcmshell6_no_abre_ventanas_de_kde(self):
        """kcmshell6 es la puerta por la que seguía apareciendo Configuración de KDE.

        Cada botón que abre un módulo lanzaba un proceso aparte con su propio
        marco de KDE. El wrapper debe traducir el módulo a una página de DylanOS
        Configuration y no invocar nunca al kcmshell6 real.
        """
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            fake = root / "usr/bin/kcmshell6"
            fake.parent.mkdir(parents=True)
            fake.write_text("#!/bin/sh\necho KDE_SHELL\n", encoding="utf-8")
            fake.chmod(0o755)

            stage.stage(root)

            wrapper = fake.read_text(encoding="utf-8")
            self.assertIn("exec /usr/bin/dylanos-configuration", wrapper)
            self.assertNotIn("echo KDE_SHELL", wrapper)
            # El binario original se conserva aparte para depuración.
            self.assertTrue((root / "usr/bin/kcmshell6.kde").is_file())
            # Todo módulo mapeado apunta a una página que existe de verdad.
            import re as _re
            main = (APP / "qml/Main.qml").read_text(encoding="utf-8")
            paginas = set(_re.findall(r'\{ id: "([a-z-]+)"', main))
            destinos = set(_re.findall(r"page=([a-z-]+) ;;", wrapper))
            self.assertTrue(destinos, "el wrapper debe mapear módulos a páginas")
            for destino in destinos:
                self.assertIn(destino, paginas, f"la página {destino} no existe en Main.qml")

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
            # Sin payload verificado no se instala el .desktop del navegador:
            # un lanzador sin binario sería un acceso roto en el menú.
            browser = root / "usr/share/applications/org.dylanos.browser.desktop"
            self.assertFalse(browser.exists())
            # 10 entradas base + la galería DylanOS Widgets (app nativa).
            entries = sorted(p.name for p in (root / "usr/share/applications").glob("org.dylanos.*.desktop"))
            self.assertEqual(len(entries), 11, entries)
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
