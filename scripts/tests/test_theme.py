"""Check the DylanOS Crimson GTK theme and the KDE color schemes."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
GTK_THEME = ROOT / "themes/gtk/DylanOS-Crimson"


class GtkThemeTest(unittest.TestCase):
    def test_structure_and_identity(self):
        self.assertTrue((GTK_THEME / "index.theme").is_file())
        index_theme = (GTK_THEME / "index.theme").read_text(encoding="utf-8")
        self.assertIn("Name=DylanOS Crimson", index_theme)
        self.assertIn("GtkTheme=DylanOS-Crimson", index_theme)
        # pone los controles de ventana a la izquierda; el tema lo declara.
        self.assertIn("ButtonLayout=close,minimize,maximize:menu", index_theme)

    def test_css_variants_use_crimson_identity(self):
        for gtk_version in ("gtk-3.0", "gtk-4.0"):
            css_path = GTK_THEME / gtk_version / "gtk.css"
            self.assertTrue(css_path.is_file(), css_path)
            css = css_path.read_text(encoding="utf-8")
            self.assertIn("#DC143C", css, gtk_version)
            self.assertIn("#0A0A0A", css, gtk_version)
            # Los colores del acento viejo (azul Netflix/violeta) ya no caben.
            self.assertNotIn("#E50914", css, gtk_version)
            self.assertNotIn("#e11d2a", css, gtk_version)
            # Sintaxis básica: cada regla abierta se cierra y no hay llaves huérfanas.
            self.assertEqual(css.count("{"), css.count("}"), gtk_version)

    def test_traffic_lights_style(self):
        for gtk_version in ("gtk-3.0", "gtk-4.0"):
            css = (GTK_THEME / gtk_version / "gtk.css").read_text(encoding="utf-8")
            for light in ("#FF5F57", "#FEBC2E", "#28C840"):
                self.assertIn(light, css, (gtk_version, light))


class ColorSchemeTest(unittest.TestCase):
    def test_schemes_use_crimson_accent(self):
        for scheme in ("DylanOSDark.colors", "DylanOSLight.colors"):
            path = ROOT / "themes/colors" / scheme
            self.assertTrue(path.is_file(), scheme)
            content = path.read_text(encoding="utf-8")
            self.assertIn("220,20,60", content, scheme)          # DC143C
            self.assertNotIn("10,132,255", content, scheme)      # azul viejo
            self.assertNotIn("0,122,255", content, scheme)       # azul stock

    def test_dark_scheme_keeps_neutral_backgrounds(self):
        content = (ROOT / "themes/colors/DylanOSDark.colors").read_text(encoding="utf-8")
        self.assertIn("30,30,32", content)                      # window neutral oscura
        self.assertIn("220,20,60", content.split("[WM]")[0])   # acento en colores, no solo en WM


class QmlBrandConsistencyTest(unittest.TestCase):
    def test_primary_qml_apps_share_the_official_crimson_accent(self):
        configuration = (ROOT / "apps/dylanos-configuration/qml/theme/Theme.qml").read_text(encoding="utf-8")
        explorer = (ROOT / "apps/dylanos-explorer/qml/theme/Theme.qml").read_text(encoding="utf-8")
        config_button = (ROOT / "apps/dylanos-configuration/qml/components/ActionButton.qml").read_text(encoding="utf-8")
        workspace_button = (ROOT / "apps/workspace/qml/ActionButton.qml").read_text(encoding="utf-8")
        personalization = (ROOT / "apps/dylanos-configuration/qml/pages/PersonalizationPage.qml").read_text(encoding="utf-8")
        self.assertIn('property color accent: "#DC143C"', configuration)
        self.assertIn('property color accentStrong: "#FF4565"', configuration)
        self.assertIn('property color accentPressed: "#A50F2E"', configuration)
        self.assertIn('property color accent: "#DC143C"', explorer)
        self.assertIn('property color accentBright: "#FF4565"', explorer)
        self.assertIn('Theme.accentPressed', config_button)
        self.assertIn('mouse.containsMouse ? Theme.accentStrong : Theme.accent', config_button)
        self.assertIn('hoverEnabled: true', config_button)
        self.assertIn('Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }', config_button)
        self.assertIn('Qt.lighter(control.palette.highlight, 1.18)', workspace_button)
        self.assertIn('"#DC143C"', personalization)
        for legacy in ("#e0182d", "#ff2a40", "#e0222d", "#ff4a55"):
            self.assertNotIn(legacy, configuration + explorer + config_button + workspace_button + personalization)


class StagedAppsUseCrimsonTest(unittest.TestCase):
    def test_no_legacy_accent_left_in_qml(self):
        legacy = ("#e11d2a", "#e3485b", "#E50914", "#e11d2e")
        for relative in ("apps/calculator/qml/Main.qml",
                         "apps/calculator/icons/org.dylanos.calculator.svg",
                         "themes/sddm/DylanOS-Crimson/Main.qml",
                         "apps/com.dylanos.dock/contents/ui/DockItemDelegate.qml",
                         "apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml",
                         "apps/dylanos-control-center/contents/ui/NotificationsPanel.qml",
                         "apps/workspace/qml/Main.qml",
                         "apps/workspace/qml/SettingsPage.qml",
                         "apps/workspace/qml/ActionButton.qml",
                         "themes/sddm/DylanOS-SDDM/components/Clock.qml"):
            content = (ROOT / relative).read_text(encoding="utf-8")
            for color in legacy:
                self.assertNotIn(color, content, (relative, color))


if __name__ == "__main__":
    unittest.main()
