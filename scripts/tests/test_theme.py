"""Check the DylanOS Crimson GTK theme and the KDE color schemes."""
import configparser
from pathlib import Path
import re
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

    def test_translucent_plasma_surfaces_keep_nine_patch_contract_and_soft_opacity(self):
        theme = ROOT / "themes/plasma/DylanOS-Crimson"
        desktop_entry = (theme / "metadata.desktop").read_text(encoding="utf-8")
        self.assertIn("[BlurBehindEffect]\nenabled=true", desktop_entry)
        for relative in ("translucent/widgets/panel-background.svg", "translucent/dialogs/background.svg"):
            content = (theme / relative).read_text(encoding="utf-8")
            self.assertIn('<g opacity="0.84">', content)
            self.assertIn('id="center"', content)
            self.assertIn('id="hint-stretch-borders"', content)
            self.assertIn('id="hint-apply-color-scheme"', content)
            self.assertEqual(content.count("<g "), content.count("</g>"))

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


class CrimsonGlassTest(unittest.TestCase):
    """El acabado Crimson-glass: marco translúcido + perfil de efectos de KWin."""

    glass_svg = None

    @classmethod
    def setUpClass(cls):
        cls.glass_svg = (ROOT / "themes/aurorae/DylanOS-Crimson-Glass/decoration.svg").read_text(encoding="utf-8")

    def test_glass_theme_is_a_complete_aurorae(self):
        theme = ROOT / "themes/aurorae/DylanOS-Crimson-Glass"
        entry = (theme / "metadata.desktop").read_text(encoding="utf-8")
        self.assertIn("X-KDE-PluginInfo-Name=DylanOS-Crimson-Glass", entry)
        self.assertIn("Name=DylanOS Crimson Glass", entry)
        for relative in ("DylanOS-Crimson-Glassrc", "close.svg", "minimize.svg", "maximize.svg", "restore.svg"):
            self.assertTrue((theme / relative).is_file(), relative)

    def test_glass_light_theme_is_a_complete_aurorae(self):
        theme = ROOT / "themes/aurorae/DylanOS-Crimson-Glass-Light"
        entry = (theme / "metadata.desktop").read_text(encoding="utf-8")
        self.assertIn("X-KDE-PluginInfo-Name=DylanOS-Crimson-Glass-Light", entry)
        self.assertIn("Name=DylanOS Crimson Glass Light", entry)
        for relative in ("DylanOS-Crimson-Glass-Lightrc", "close.svg", "minimize.svg", "maximize.svg", "restore.svg"):
            self.assertTrue((theme / relative).is_file(), relative)

    def test_glass_light_uses_light_colors_and_gradients(self):
        light_svg = (ROOT / "themes/aurorae/DylanOS-Crimson-Glass-Light/decoration.svg").read_text(encoding="utf-8")
        self.assertIn('id="glassSheenLight"', light_svg)
        self.assertIn('id="glassCrimsonLight"', light_svg)
        self.assertIn('stop-color="#9c8498"', light_svg)
        self.assertIn('stop-color="#f1e7ee"', light_svg)
        self.assertIn('stop-color="#8e2a44"', light_svg)
        self.assertIn('stop-color="#d8788c"', light_svg)
        self.assertIn('fill="#eef0f6"', light_svg)

    def test_visible_patches_are_translucent_and_masks_stay_opaque(self):
        # La máscara es lo que KWin convierte en región de desenfoque: si fuera
        # translúcida, el vidrio de cualquier app dejaría de verse.
        for element in re.finditer(r'<(rect|path) id="((?:decoration|mask)-[a-z-]+)"[^>]*>', self.glass_svg):
            opaque_frame = element.group(2).startswith(("decoration-opaque-", "mask-"))
            alpha = re.search(r'fill-opacity="([\d.]+)"', element.group(0))
            if opaque_frame:
                self.assertIsNone(alpha, element.group(2))
            else:
                self.assertIsNotNone(alpha, element.group(2))
                self.assertLess(float(alpha.group(1)), 1.0, element.group(2))

    def test_glass_keeps_the_full_nine_patch_contract(self):
        self.assertEqual(self.glass_svg.count("<g "), self.glass_svg.count("</g>"))
        for prefix in ("decoration-", "decoration-inactive-", "decoration-maximized-",
                       "decoration-maximized-inactive-", "decoration-opaque-",
                       "decoration-opaque-inactive-", "mask-"):
            for part in ("topleft", "top", "topright", "left", "center", "right",
                         "bottomleft", "bottom", "bottomright"):
                self.assertIn('id="%s%s"' % (prefix, part), self.glass_svg, prefix + part)

    def test_skel_pins_the_glass_profile(self):
        kwinrc = configparser.ConfigParser(interpolation=None)
        kwinrc.optionxform = str
        kwinrc.read(ROOT / "configs/plasma/skel/kwinrc")
        self.assertEqual(kwinrc.get("org.kde.kdecoration2", "theme"), "__aurorae__svg__DylanOS-Crimson-Glass")
        self.assertEqual(kwinrc.get("Plugins", "blurEnabled"), "true")
        self.assertEqual(kwinrc.get("Plugins", "translucencyEnabled"), "true")
        self.assertEqual(kwinrc.get("Effect-blur", "BlurStrength"), "30")
        self.assertEqual(kwinrc.get("Effect-blur", "NoiseStrength"), "4")
        self.assertEqual(kwinrc.get("Effect-translucency", "Inactive"), "80")
        self.assertEqual(kwinrc.get("Effect-translucency", "Dialogs"), "85")

    def test_look_and_feel_defaults_avoid_ignored_kwinrc_groups(self):
        defaults = (ROOT / "themes/lookandfeel/org.dylanos.crimson/contents/defaults").read_text(encoding="utf-8")
        self.assertIn("__aurorae__svg__DylanOS-Crimson-Glass", defaults)
        # LookAndFeelManager solo lee una lista fija de claves: los grupos de
        # efectos del `defaults` se descartan en silencio y confieren.
        self.assertNotIn("[kwinrc][Effect-", defaults)
        self.assertNotIn("[kwinrc][Plugins]", defaults)

    def test_theme_switch_keeps_the_glass_frame(self):
        backend = (ROOT / "apps/workspace/backend.py").read_text(encoding="utf-8")
        self.assertIn("DylanOS-Crimson-Glass", backend)
        self.assertIn("kwinDecoration", backend)


if __name__ == "__main__":
    unittest.main()
