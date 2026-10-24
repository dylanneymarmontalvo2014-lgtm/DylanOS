"""Regression tests for the SDDM theme's real-data contract."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "themes/sddm/DylanOS-Crimson"


class SddmThemeTest(unittest.TestCase):
    def test_theme_uses_only_real_greeter_data(self):
        main = (THEME / "Main.qml").read_text(encoding="utf-8")
        theme_config = (THEME / "theme.conf").read_text(encoding="utf-8")
        for snippet in (
            'source: root.userAvatarSource',
            '"/var/lib/AccountsService/icons/" + user.currentText',
            'valueRole: "icon"', 'user.currentValue', 'focus: true',
            'sddm.login(', 'sddm.powerOff()', 'sddm.reboot()', 'sddm.suspend()',
            'AccountCard {}', 'SessionCard {}', 'LocalTimeCard {}', 'PowerCard {}',
            'config.screenshot.length > 0',
            'id: loginPanel', 'Bienvenido a DylanOS', 'Accede a tu sesión',
            'visible: parent.width >= 1280 && parent.height >= 700',
            'Behavior on border.color', 'onTextChanged: if (root.errorText !== "") root.errorText = ""',
            'BusyIndicator { running: root.authenticating',
        ):
            with self.subTest(snippet=snippet):
                self.assertIn(snippet, main)
        power = (THEME / "components/PowerCard.qml").read_text(encoding="utf-8")
        for capability in ('sddm.canPowerOff', 'sddm.canReboot', 'sddm.canSuspend'):
            with self.subTest(capability=capability):
                self.assertIn(capability, power)
        self.assertIn('sessionModel.count', (THEME / "components/SessionCard.qml").read_text(encoding="utf-8"))
        self.assertIn('Qt.formatDateTime(new Date()', (THEME / "components/LocalTimeCard.qml").read_text(encoding="utf-8"))
        self.assertIn('Introducir contraseña', main)
        self.assertIn('echoMode: TextInput.Password', main)
        self.assertIn('radius: 16', main)
        self.assertIn('radius: 24', main)
        for removed_component in ("WeatherCard.qml", "EventCard.qml", "MediaCard.qml", "SystemCard.qml", "CalendarCard.qml", "RemindersCard.qml", "ShortcutsCard.qml"):
            self.assertFalse((THEME / "components" / removed_component).exists(), removed_component)
        theme_sources = "\n".join(p.read_text(encoding="utf-8") for p in (THEME / "components").glob("*.qml"))
        for demo_value in ('19°', 'Dream It Possible', '237 GB libres', 'Reunión de proyecto', 'Estudiar para examen'):
            self.assertNotIn(demo_value, theme_sources)
        self.assertNotIn('fingerprint.svg', main)
        self.assertNotIn('Usa tu huella', main)
        self.assertIn('background=/usr/share/wallpapers/DylanOS/dylanos-default.png', theme_config)
        for component in ("SideCard.qml", "AccountCard.qml", "SessionCard.qml", "LocalTimeCard.qml", "PowerCard.qml"):
            self.assertTrue((THEME / "components" / component).is_file(), component)

    def test_avatar_widget_uses_selected_profile_and_fallback(self):
        main = (THEME / "Main.qml").read_text(encoding="utf-8")
        account = (THEME / "components/AccountCard.qml").read_text(encoding="utf-8")
        self.assertIn('source: root.userAvatarSource', main)
        self.assertIn('source: root.userAvatarSource', account)
        self.assertIn('visible: avatarImage.status !== Image.Ready', main)
        self.assertIn('visible: profilePhoto.status !== Image.Ready', account)
        self.assertNotIn('faces/', main + account)

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
            config.write_text(config.read_text(encoding="utf-8").replace(
                "background=/usr/share/wallpapers/DylanOS/dylanos-default.png",
                f"background={ROOT / 'branding/wallpapers/dylanos-default.png'}"), encoding="utf-8")
            process = subprocess.Popen([greeter, "--test-mode", "--theme", str(theme)],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=environment)
            try:
                output, _ = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                output, _ = process.communicate()
        self.assertIn(f"Loading {theme.as_uri()}/Main.qml", output)
        for forbidden in ("Fallback to embedded theme", "Library import requires a version",
                          "ReferenceError:", "TypeError:", "Cannot open:"):
            self.assertNotIn(forbidden, output)


if __name__ == "__main__":
    unittest.main()
