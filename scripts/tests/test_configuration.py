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
            # El total de entradas org.dylanos.* del menu se mantiene en 9
            # (workspace + explorer + configuration + store + spotlight + console).
            self.assertEqual(len(list((root / "usr/share/applications").glob("org.dylanos.*.desktop"))), 9)


if __name__ == "__main__":
    unittest.main()
