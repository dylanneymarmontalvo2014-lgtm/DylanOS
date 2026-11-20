"""Contract checks for DylanOS's system light/dark theme synchronization."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SystemThemeSourceTest(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_configuration_remains_the_system_theme_authority(self):
        service_h = self.read("apps/dylanos-configuration/src/services/SystemService.h")
        service_cpp = self.read("apps/dylanos-configuration/src/services/SystemService.cpp")
        personalization = self.read("apps/dylanos-configuration/qml/pages/PersonalizationPage.qml")
        self.assertIn("Q_PROPERTY(bool dark READ dark NOTIFY darkChanged)", service_h)
        self.assertIn("SystemService::dark() const", service_cpp)
        self.assertIn("currentSchemeFile()", service_cpp)
        self.assertIn("isDarkSchemeFile(file)", service_cpp)
        self.assertIn("QFileSystemWatcher::fileChanged", service_cpp)
        self.assertIn('["DylanOSDark", "BreezeDark"]', personalization)
        self.assertIn('["DylanOSLight", "BreezeLight"]', personalization)
        self.assertIn("System.applyColorScheme(s.name)", personalization)

    def test_primary_native_apps_follow_the_live_qt_palette(self):
        cases = {
            "apps/archivos/qml/Main.qml": ("systemPalette.window.hsvValue", "cAccent"),
            "apps/dylanos-app-center/qml/Main.qml": ("systemPalette.window.hsvValue", "#DC143C"),
            "apps/dylanos-spotlight/qml/Main.qml": ("systemPalette.window.hsvValue", "#DC143C"),
            "apps/dylanos-widgets/qml/Main.qml": ("systemPalette.window.hsvValue", "Tokens.crimson"),
        }
        for path, (marker, crimson) in cases.items():
            with self.subTest(path=path):
                source = self.read(path)
                self.assertIn("SystemPalette {", source)
                self.assertIn(marker, source)
                self.assertIn(crimson, source)

    def test_calculator_buttons_use_live_foreground_and_keep_crimson_operations(self):
        button = self.read("apps/calculator/qml/CalcButton.qml")
        main = self.read("apps/calculator/qml/Main.qml")
        self.assertIn("SystemPalette {", button)
        self.assertIn("systemPalette.window.hsvValue", button)
        self.assertIn("property color textColor: dark ?", button)
        self.assertIn('accentRed: "#DC143C"', main)

    def test_tokenized_apps_switch_existing_palettes_without_replacing_crimson(self):
        explorer = self.read("apps/dylanos-explorer/qml/theme/Theme.qml")
        process = self.read("apps/dylanos-process/qml/Theme.qml")
        store = self.read("apps/dylanos-store/src/store/qml/theme/Colors.qml")
        for path, source in (("explorer", explorer), ("process", process), ("store", store)):
            with self.subTest(path=path):
                self.assertIn("SystemPalette {", source)
                self.assertIn("systemPalette.window.hsvValue", source)
        self.assertIn('property color accent: "#DC143C"', explorer)
        self.assertIn('property color red: "#e0293b"', process)
        self.assertIn('property color crimson: dark ? "#c0181f"', store)
        self.assertIn('"#f4f2f2"', store)
        self.assertIn('"#211a1b"', store)
        self.assertIn('"#ffffff"', explorer)
        self.assertIn('"#201a1b"', process)

    def test_every_packaged_widget_uses_the_active_plasma_theme(self):
        widgets = sorted(p for p in (ROOT / "apps").glob("dylanos-widgets-*")
                         if p.is_dir() and (p / "contents/ui/main.qml").is_file())
        self.assertEqual(len(widgets), 20)
        for app in widgets:
            with self.subTest(widget=app.name):
                shell = (app / "contents/ui/lib/WidgetShell.qml").read_text(encoding="utf-8")
                card = (app / "contents/ui/lib/WidgetCard.qml").read_text(encoding="utf-8")
                self.assertIn("PlasmaCore.Theme.textColor", shell)
                self.assertIn("Tokens.variantLight", shell)
                self.assertIn("PlasmaCore.Theme.textColor", card)
                self.assertIn("Tokens.variantLight", card)

    def test_plasma_helpers_use_theme_foreground_and_control_center_surfaces(self):
        search = self.read("apps/com.dylanos.search/contents/ui/main.qml")
        active = self.read("apps/com.dylanos.activeapp/contents/ui/main.qml")
        dashboard = self.read("apps/com.dylanos.dashboard/contents/ui/main.qml")
        control = self.read("apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml")
        notices = self.read("apps/dylanos-control-center/contents/ui/NotificationsPanel.qml")
        self.assertIn("PlasmaCore.Theme.textColor", search)
        self.assertIn("PlasmaCore.Theme.textColor", active)
        self.assertIn("PlasmaCore.Theme.textColor", dashboard)
        for source in (control, notices):
            self.assertIn("PlasmaCore.Theme.textColor.hsvValue", source)
            self.assertIn("PlasmaCore.Theme.disabledTextColor", source)

    def test_workspace_asks_configuration_to_apply_mode_instead_of_private_override(self):
        main = self.read("apps/workspace/qml/Main.qml")
        settings = self.read("apps/workspace/qml/SettingsPage.qml")
        self.assertIn("SystemPalette {", main)
        self.assertIn("systemPalette.window.hsvValue", main)
        self.assertIn('backend.theme(win.dark ? "Light" : "Dark")', main)
        self.assertNotIn('Settings { id: preferences; category: "Appearance"', main)
        self.assertIn("backend.theme(modelData.variant)", settings)
        self.assertNotIn("win.dark = modelData.variant", settings)

    def test_browser_has_both_system_color_scheme_variants(self):
        css = self.read("apps/dylanos-browser/src/zen/common/styles/zen-theme.css")
        self.assertIn("(-moz-system-dark-theme)", css)
        self.assertIn("schemes/dark.inc.css", css)
        self.assertIn("schemes/light.inc.css", css)


if __name__ == "__main__":
    unittest.main()
