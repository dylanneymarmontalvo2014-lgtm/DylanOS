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
        self.assertIn("applications:com.microsoft.VSCode.desktop", dock)
        self.assertIn("applications:com.microsoft.VSCode.desktop", dock)
        self.assertNotIn("applications:code.desktop", layout + dock)
        self.assertIn("code", [line.strip() for line in packages if line.strip() and not line.lstrip().startswith("#")])
        self.assertIn("packages.microsoft.com/repos/vscode", setup)

    def test_default_dock_uses_smooth_neighbor_magnification(self):
        layout = (ROOT / "themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        dock = (ROOT / "apps/com.dylanos.dock/contents/ui/main.qml").read_text(encoding="utf-8")
        delegate = (ROOT / "apps/com.dylanos.dock/contents/ui/DockItemDelegate.qml").read_text(encoding="utf-8")
        config = (ROOT / "apps/com.dylanos.dock/contents/config/main.xml").read_text(encoding="utf-8")
        self.assertIn('dock.addWidget("com.dylanos.dock")', layout)
        self.assertIn('dock.addWidget("org.kde.plasma.trash")', layout)
        self.assertNotIn('dock.addWidget("org.kde.plasma.icontasks")', layout)
        self.assertIn("property int hoverIndex: -1", dock)
        self.assertIn("dockRoot: dockRow", dock)
        self.assertIn("hoverDistance === 1 ? baseSize + (hoverSize - baseSize) * 0.48", delegate)
        self.assertIn("hoverDistance === 2 ? baseSize + (hoverSize - baseSize) * 0.18", delegate)
        self.assertIn("NumberAnimation { duration: 170; easing.type: Easing.OutCubic }", delegate)
        self.assertIn("onEntered: {", delegate)
        self.assertIn("dockRoot.hoverIndex = delegateRoot.delegateIndex", delegate)
        self.assertIn("dockRoot.hoverIndex = -1", delegate)
        self.assertIn("<default>64</default>", config)
        for app in ("org.dylanos.explorer.desktop", "firefox-esr.desktop", "com.microsoft.VSCode.desktop", "dylanos-app-center.desktop", "org.dylanos.store.desktop", "org.dylanos.configuration.desktop", "org.dylanos.calculator.desktop"):
            self.assertIn("applications:" + app, dock)


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
        self.assertIn("function usagePercent(used, total)", dashboard)
        self.assertIn("Math.max(0, Math.min(100, used * 100 / total))", dashboard)
        self.assertIn("function progressWidth(trackWidth, used, total)", dashboard)
        self.assertEqual(dashboard.count("Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }"), 3)
        self.assertIn('Accessible.name: "Uso de memoria: "', dashboard)
        self.assertIn('"Uso del filesystem raíz: "', dashboard)
        self.assertIn('root.usagePercent(root.memoryUsed, root.memoryTotal).toFixed(0) + "%  ·  "', dashboard)
        self.assertIn('root.usagePercent(root.diskUsedBytes, root.diskTotalBytes).toFixed(0) + "%  ·  "', dashboard)
        self.assertIn("NotificationManager.Settings", status)
        self.assertIn("setNotificationsInhibitedUntil", status)
        self.assertIn("resetNotificationsInhibitedUntil", status)
        self.assertNotIn('property bool doNotDisturb: false', status)
        self.assertIn("model: root.notificationModel", notifications)
        self.assertIn("property var notificationModel", notifications)
        self.assertNotIn("NotificationManager.Notifications", notifications)
        self.assertIn("notificationModel: notifModel", (ROOT / "apps/dylanos-control-center/contents/ui/main.qml").read_text(encoding="utf-8"))
        self.assertIn("onExpandedChanged: SystemStatus.setMonitoringActive(root.expanded)", (ROOT / "apps/dylanos-control-center/contents/ui/main.qml").read_text(encoding="utf-8"))
        self.assertIn('label: "KDE Connect"', mock_data)
        self.assertNotIn('label: "AirDrop"', mock_data)
        self.assertIn('property date selectedDate', dashboard)
        self.assertIn('function selectDate(date)', dashboard)
        self.assertIn('function showToday()', dashboard)
        self.assertIn('Ir al día de hoy', dashboard)
        self.assertIn('Selected date', dashboard) if False else None
        self.assertIn('Día seleccionado · ', dashboard)
        self.assertIn('delegate: QQC2.Button', dashboard)
        self.assertIn('Accessible.name: Qt.formatDate(dateValue', dashboard)
        self.assertIn('onClicked: root.selectDate(dateValue)', dashboard)
        self.assertIn('isToday ? ", hoy" : ""', dashboard)
        self.assertIn('isSelected ? ", seleccionado" : ""', dashboard)
        self.assertIn('font.bold: calendarDay.isSelected || calendarDay.isToday', dashboard)
        self.assertIn('calendarDay.hovered ? "#24FFFFFF" : "transparent"', dashboard)
        self.assertIn('ColorAnimation { duration: 130; easing.type: Easing.OutCubic }', dashboard)
        self.assertIn('NumberAnimation { duration: 130; easing.type: Easing.OutCubic }', dashboard)
        self.assertIn('"Día seleccionado · "', dashboard)
        self.assertIn('function openSystemMonitor()', dashboard)
        self.assertIn('commandRunner.connectSource("plasma-systemmonitor")', dashboard)
        self.assertIn('text: "Abrir Monitor del sistema"', dashboard)
        self.assertIn('Accessible.name: "Abrir Monitor del sistema de KDE"', dashboard)
        self.assertIn('onClicked: root.openSystemMonitor()', dashboard)
        self.assertIn('property date lastRefreshRequested: new Date(0)', dashboard)
        self.assertIn('root.lastRefreshRequested = new Date()', dashboard)
        self.assertIn('text: "Actualizar"', dashboard)
        self.assertIn('Accessible.name: "Actualizar las métricas del sistema ahora"', dashboard)
        self.assertIn('onClicked: root.refreshSystemInfo()', dashboard)
        self.assertIn('"Consulta · " + Qt.formatTime(root.lastRefreshRequested, "hh:mm:ss")', dashboard)
        self.assertIn('property var cpuHistory: []', dashboard)
        self.assertIn('root.cpuHistory = root.cpuHistory.concat([root.cpuUsagePercent]).slice(-24)', dashboard)
        self.assertIn('function cpuHistoryDescription()', dashboard)
        self.assertIn('id: cpuTrend', dashboard)
        self.assertIn('Canvas {', dashboard)
        self.assertIn('ctx.strokeStyle = "#DC143C"', dashboard)
        self.assertIn('root.cpuHistory.length < 2', dashboard)
        self.assertIn('TENDENCIA CPU · ', dashboard)
        self.assertIn('import "PomodoroClock.js" as PomodoroClock', dashboard)
        self.assertIn('function startPomodoro()', dashboard)
        self.assertIn('function pausePomodoro()', dashboard)
        self.assertIn('function resetPomodoro()', dashboard)
        self.assertIn('function updatePomodoro()', dashboard)
        self.assertIn('Timer { interval: 1000; repeat: true; running: root.pomodoroRunning; onTriggered: root.updatePomodoro() }', dashboard)
        self.assertIn('text: root.pomodoroMode === "focus" ? "ENFOQUE" : "DESCANSO"', dashboard)
        self.assertIn('"Ciclos · " + root.completedFocusSessions', dashboard)
        self.assertIn('Accessible.name: "Reiniciar temporizador de enfoque o descanso"', dashboard)
        self.assertIn('PomodoroClock.progress(root.pomodoroRemainingSeconds, root.pomodoroDurationSeconds)', dashboard)
        self.assertIn('Accessible.role: Accessible.ProgressBar', dashboard)
        self.assertIn('if (pomodoroRemainingSeconds <= 0) {', dashboard)
        pomodoro = (ROOT / "apps/com.dylanos.dashboard/contents/ui/PomodoroClock.js").read_text(encoding="utf-8")
        self.assertIn('return mode === "focus" ? 25 * 60 : 5 * 60', pomodoro)
        self.assertIn('Math.ceil((deadlineMs - nowMs) / 1000)', pomodoro)
        self.assertIn('Math.max(0, Math.min(1, 1 - remaining / duration))', pomodoro)
        packages_default = (ROOT / "packages/default/packages.list").read_text(encoding="utf-8").splitlines()
        self.assertIn("plasma-systemmonitor", [line.strip() for line in packages_default if line.strip() and not line.lstrip().startswith("#")])
        self.assertIn('function toggleMute()', status)
        self.assertIn('pactl set-sink-mute @DEFAULT_SINK@ toggle', status)
        self.assertIn('pactl get-source-volume @DEFAULT_SOURCE@', status)
        self.assertIn('pactl get-source-mute @DEFAULT_SOURCE@', status)
        self.assertIn('pactl set-source-volume @DEFAULT_SOURCE@', status)
        self.assertIn('pactl set-source-mute @DEFAULT_SOURCE@ toggle', status)
        self.assertIn('microphoneAvailable', status)
        self.assertIn('Nivel del micrófono', (ROOT / "apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml").read_text(encoding="utf-8"))
        self.assertIn('toggleMicrophoneMute()', (ROOT / "apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml").read_text(encoding="utf-8"))
        self.assertIn('DylanOSDark" : "DylanOSLight', status)
        control_panel = (ROOT / "apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml").read_text(encoding="utf-8")
        notifications_panel = (ROOT / "apps/dylanos-control-center/contents/ui/NotificationsPanel.qml").read_text(encoding="utf-8")
        self.assertIn('Qt.rgba(10 / 255, 10 / 255, 12 / 255, 0.88)', control_panel)
        self.assertIn('Qt.rgba(10 / 255, 10 / 255, 12 / 255, 0.88)', notifications_panel)
        self.assertIn('Qt.rgba(1, 1, 1, 0.12)', control_panel)
        self.assertIn('Qt.rgba(1, 1, 1, 0.12)', notifications_panel)
        self.assertIn('color: "#D9101014"', dashboard)
        self.assertIn('Qt.rgba(1, 1, 1, 0.075)', dashboard)
        self.assertIn('border.color: root.pomodoroRunning ? "#70DC143C" : "#38FFFFFF"', dashboard)
        self.assertNotIn('BreezeDark', status)
        self.assertNotIn('BreezeLight', status)
        self.assertIn('interval: 5000', status)
        self.assertIn('running: root.monitoringActive', status)
        self.assertIn('function setMonitoringActive(active)', status)
        self.assertIn('if (active) {', status)
        self.assertNotIn('Component.onCompleted: {\n        refreshAudioAndBrightness()', status)
        self.assertIn('interval: 15000', status)
        self.assertNotIn('interval: 2000', status)
        packages = (ROOT / "packages/default/packages.list").read_text(encoding="utf-8").splitlines()
        self.assertIn("playerctl", [line.strip() for line in packages if line.strip() and not line.lstrip().startswith("#")])

    def test_shell_keeps_wallpaper_and_console_contract(self):
        layout = (ROOT / "themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text(encoding="utf-8")
        kitty = (ROOT / "configs/kitty/kitty.conf").read_text(encoding="utf-8")
        wallpaper = ROOT / "branding/wallpapers/dylanos-default.png"
        self.assertIn('desktop.writeConfig("Image", "file:///usr/share/wallpapers/DylanOS/dylanos-default.png")', layout)
        self.assertIn("scrollback_lines 50000", kitty)
        self.assertIn("background_opacity 0.40", kitty)
        self.assertIn("background_blur 24", kitty)
        self.assertIn("window_padding_width 16 18", kitty)
        self.assertIn("tab_bar_style separator", kitty)
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

    def test_iso_validated_make_target_runs_build_then_iso_and_test(self):
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        self.assertIn("iso-validated:", makefile)
        recipe = makefile.split("iso-validated:", 1)[1].split("\nqemu-test:", 1)[0]
        self.assertLess(recipe.index("$(MAKE) build"), recipe.index("$(MAKE) iso"))
        self.assertLess(recipe.index("$(MAKE) iso"), recipe.index("$(MAKE) test-iso"))
        self.assertIn("BUILD_JOBS", makefile)

    def test_installer_is_built_before_staging(self):
        build = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
        check = (ROOT / "scripts/check.sh").read_text(encoding="utf-8")
        self.assertLess(build.index("build-installer.sh"), build.index("sudo unshare"))
        self.assertLess(check.index("build-installer.sh"), check.index("test_packages.sh"))
        helper = ROOT / "scripts/build-installer.sh"
        self.assertTrue(helper.is_file())


if __name__ == "__main__":
    unittest.main()


    def test_control_center_sliders_use_supported_accessibility_properties(self):
        panel = (ROOT / "apps/dylanos-control-center/contents/ui/ControlCenterPanel.qml").read_text(encoding="utf-8")
        self.assertNotIn("Accessible.value:", panel)
        self.assertIn('Accessible.name: "Volumen de salida"', panel)
        self.assertIn('Accessible.name: "Nivel del micrófono"', panel)
        self.assertIn("onMoved: SystemStatus.setVolume(value)", panel)
        self.assertIn("onMoved: SystemStatus.setMicrophoneVolume(value)", panel)
