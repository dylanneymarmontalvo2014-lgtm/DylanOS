"""Regression checks for Plasma launchers and installer staging order."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ShellContractTest(unittest.TestCase):
    def test_active_application_title_has_readable_minimum_width(self):
        qml = (ROOT / "apps/com.dylanos.activeapp/contents/ui/main.qml").read_text(encoding="utf-8")
        self.assertIn("Layout.minimumWidth: 192", qml)

    def test_official_code_launcher_is_used_consistently(self):
        layout = (ROOT / "themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        dock = (ROOT / "apps/com.dylanos.dock/contents/ui/main.qml").read_text(encoding="utf-8")
        packages = (ROOT / "packages/development/packages.list").read_text(encoding="utf-8").splitlines()
        setup = (ROOT / "packages/development/setup-repos.sh").read_text(encoding="utf-8")
        # El paquete `code` de Microsoft instala com.microsoft.VSCode.desktop
        # (Icon=vscode); NO existe ningún code.desktop y fijarlo deja el icono
        # del dock roto (pin sin resolver).
        self.assertIn("applications:com.microsoft.VSCode.desktop", layout)
        self.assertIn("applications:com.microsoft.VSCode.desktop", dock)
        self.assertNotIn("applications:code.desktop", layout + dock)
        self.assertIn("code", [line.strip() for line in packages if line.strip() and not line.lstrip().startswith("#")])
        self.assertIn("packages.microsoft.com/repos/vscode", setup)


    def test_dashboard_and_control_center_use_real_local_and_global_state(self):
        dashboard = (ROOT / "apps/com.dylanos.dashboard/contents/ui/main.qml").read_text(encoding="utf-8")
        status = (ROOT / "apps/dylanos-control-center/contents/ui/SystemStatus.qml").read_text(encoding="utf-8")
        notifications = (ROOT / "apps/dylanos-control-center/contents/ui/NotificationsPanel.qml").read_text(encoding="utf-8")
        mock_data = (ROOT / "apps/dylanos-control-center/contents/ui/MockData.qml").read_text(encoding="utf-8")
        self.assertIn("cat /proc/meminfo", dashboard)
        self.assertIn("cat /proc/uptime", dashboard)
        self.assertIn('"cat /proc/stat"', dashboard)
        self.assertIn('"df -B1 --output=used,size /"', dashboard)
        self.assertIn("cpuUsagePercent", dashboard)
        self.assertIn("cpuCountersFromStatLine", dashboard)
        self.assertIn("const guestTicks = (ticks[8] || 0) + (ticks[9] || 0)", dashboard)
        self.assertIn("- guestTicks", dashboard)
        self.assertIn("totalDelta > 0 && idleDelta >= 0 && idleDelta <= totalDelta", dashboard)
        self.assertIn("diskUsedBytes", dashboard)
        self.assertIn("diskTotalBytes", dashboard)
        self.assertIn("NotificationManager.Settings", status)
        self.assertIn("setNotificationsInhibitedUntil", status)
        self.assertIn("resetNotificationsInhibitedUntil", status)
        self.assertNotIn('property bool doNotDisturb: false', status)
        self.assertIn("model: notificationsModel", notifications)
        self.assertIn('label: "KDE Connect"', mock_data)
        self.assertNotIn('label: "AirDrop"', mock_data)

    def test_shell_keeps_wallpaper_and_console_contract(self):
        layout = (ROOT / "themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        kitty = (ROOT / "configs/kitty/kitty.conf").read_text(encoding="utf-8")
        wallpaper = ROOT / "branding/wallpapers/dylanos-default.png"
        self.assertIn('desktop.writeConfig("Image", "file:///usr/share/wallpapers/DylanOS/dylanos-default.png")', layout)
        self.assertIn("scrollback_lines 50000", kitty)
        self.assertIn("background_opacity 0.80", kitty)
        self.assertTrue(wallpaper.is_file())
        self.assertFalse((ROOT / "configs/konsole").exists())
        self.assertFalse((ROOT / "configs/fastfetch").exists())

    def test_console_recommender_finds_and_accepts_a_real_command(self):
        ghost = ROOT / "configs/bash/dylanos-ghost.sh"
        with tempfile.TemporaryDirectory() as folder:
            command = Path(folder) / "dylanos-prueba"
            command.write_text("#!/bin/sh\n", encoding="utf-8")
            command.chmod(0o755)
            script = f'''source "{ghost}"
READLINE_LINE=dylanos-pr
READLINE_POINT=${{#READLINE_LINE}}
__dylanos_ghost_find
printf 'sugerencia=%s\\n' "$DYLANOS_GHOST"
__dylanos_ghost_accept
printf 'aceptada=%s\\n' "$READLINE_LINE"
'''
            result = subprocess.run(
                ["bash", "--noprofile", "--norc", "-c", script],
                text=True,
                capture_output=True,
                env={**os.environ, "PATH": f"{folder}:{os.environ['PATH']}"},
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertEqual(
            result.stdout,
            "sugerencia=ueba\n\x1b[Kaceptada=dylanos-prueba\n",
        )

    def test_installer_is_built_before_staging(self):
        build = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
        check = (ROOT / "scripts/check.sh").read_text(encoding="utf-8")
        self.assertLess(build.index("build-installer.sh"), build.index("sudo unshare"))
        self.assertLess(check.index("build-installer.sh"), check.index("test_packages.sh"))
        helper = ROOT / "scripts/build-installer.sh"
        self.assertTrue(helper.is_file())


if __name__ == "__main__":
    unittest.main()
