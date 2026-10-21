"""Exercise the DylanOS SDDM theme with the real greeter."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "themes/sddm/DylanOS-Crimson"


class SddmThemeTest(unittest.TestCase):
    def test_theme_matches_dashboard_reference_with_real_login_identity(self):
        main = (THEME / "Main.qml").read_text(encoding="utf-8")
        theme_config = (THEME / "theme.conf").read_text(encoding="utf-8")

        self.assertIn('source: root.userAvatarSource', main)
        self.assertIn('"/var/lib/AccountsService/icons/" + user.currentText', main)
        self.assertIn('valueRole: "icon"', main)
        self.assertIn("user.currentValue", main)
        self.assertIn("focus: true", main)
        self.assertIn("sddm.login(", main)
        self.assertIn("sddm.powerOff()", main)
        self.assertIn("sddm.reboot()", main)
        self.assertIn("sddm.suspend()", main)
        # La captura de QA es opt-in vía theme.conf: en producción el Timer
        # de captura no debe ejecutarse ni escribir en /tmp.
        self.assertIn('config.screenshot.length > 0', main)
        self.assertNotIn("dylanos-sddm-final-review", main)
        self.assertIn("WeatherCard {}", main)
        self.assertIn("CalendarCard {}", main)
        self.assertIn("ShortcutsCard {}", main)
        self.assertNotIn("fingerprint.svg", main)
        self.assertNotIn("Usa tu huella", main)
        self.assertIn("screenshot=", theme_config)
        self.assertIn("id: session", main)
        self.assertLess(main.index("id: session"), main.index("Connections {"))
        for accessible_name in ("Iniciar sesión", "Apagar", "Reiniciar", "Suspender", "Enfocar contraseña"):
            self.assertIn(f'Accessible.name: "{accessible_name}"', main)
        self.assertIn("background=/usr/share/wallpapers/DylanOS/dylanos-default.png", theme_config)
        for component in (
            "SideCard.qml", "WeatherCard.qml", "EventCard.qml",
            "MediaCard.qml", "SystemCard.qml", "CalendarCard.qml",
            "RemindersCard.qml", "ShortcutsCard.qml",
        ):
            self.assertTrue((THEME / "components" / component).is_file())

    def test_greeter_loads_theme_without_fallback(self):
        greeter = shutil.which("sddm-greeter")
        if greeter is None:
            self.skipTest("sddm-greeter is not installed")

        environment = os.environ.copy()
        environment["QT_QPA_PLATFORM"] = "offscreen"
        environment["QT_QUICK_BACKEND"] = "software"
        with tempfile.TemporaryDirectory() as folder:
            theme = Path(folder) / "theme"
            shutil.copytree(THEME, theme)
            config = theme / "theme.conf"
            config.write_text(
                config.read_text(encoding="utf-8").replace(
                    "background=/usr/share/wallpapers/DylanOS/dylanos-default.png",
                    f"background={ROOT / 'branding/wallpapers/dylanos-default.png'}",
                ),
                encoding="utf-8",
            )
            process = subprocess.Popen(
                [greeter, "--test-mode", "--theme", str(theme)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=environment,
            )
            try:
                output, _ = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                output, _ = process.communicate()

        self.assertIn(f"Loading {theme.as_uri()}/Main.qml", output)
        self.assertNotIn("Fallback to embedded theme", output)
        self.assertNotIn("Library import requires a version", output)
        self.assertNotIn("ReferenceError:", output)
        self.assertNotIn("TypeError:", output)
        self.assertNotIn("Cannot open:", output)


if __name__ == "__main__":
    unittest.main()
