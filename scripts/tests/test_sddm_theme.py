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
    def test_theme_uses_selected_user_identity_instead_of_demo_data(self):
        main = (THEME / "Main.qml").read_text(encoding="utf-8")
        theme_config = (THEME / "theme.conf").read_text(encoding="utf-8")

        self.assertIn('source: root.userAvatarSource', main)
        self.assertIn('"/var/lib/AccountsService/icons/" + user.currentText', main)
        self.assertIn("focus: true", main)
        self.assertIn("background=/usr/share/wallpapers/DylanOS/dylanos-default.png", theme_config)
        for sample in ("19°", "Dream It Possible", "72%", "237 GB libres",
                       "Estudiar para examen", "Reunión de proyecto"):
            self.assertNotIn(sample, main)
        for card in ("WeatherCard", "EventCard", "MediaCard", "SystemCard",
                     "CalendarCard", "RemindersCard", "ShortcutsCard"):
            self.assertNotIn(card, main)

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
