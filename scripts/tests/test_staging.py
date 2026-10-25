"""Check that the installed payload is complete and safe to regenerate."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("stage", ROOT / "scripts/stage.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StagingTest(unittest.TestCase):
    def test_about_command_uses_the_maintainers_file(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            module.stage(root)
            about = root / "usr/bin/about"
            self.assertTrue(about.stat().st_mode & 0o111)
            credits = root / "usr/share/dylanos/MAINTAINERS.txt"
            env = {**__import__("os").environ, "DYLANOS_MAINTAINERS_FILE": str(credits)}
            result = __import__("subprocess").run(
                ["python3", str(about)], text=True, capture_output=True, check=False, env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "Gracias a: Cristopher Borjas, podemos mantener este bonito sistema.\n")
            credits.write_text(credits.read_text(encoding="utf-8") + "\nMANTENEDOR\n----------\nDylan Montalvo\n", encoding="utf-8")
            result = __import__("subprocess").run(
                ["python3", str(about)], text=True, capture_output=True, check=False, env=env,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "Gracias a: Cristopher Borjas, Dylan Montalvo, podemos mantener este bonito sistema.\n")

    def test_refuses_host_and_repository(self):
        for path in ("/", ROOT, ROOT.parent):
            with self.assertRaises(ValueError): module.stage(path)

    def test_payload_and_repeat_staging(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            module.stage(root)
            paths = ["usr/bin/dylanos", "usr/bin/dylanos-spotlight", "usr/bin/dylanos-installer",
                     "usr/share/dylanos/workspace/qml/Main.qml",
                     "usr/share/dylanos/installer/backend/server.py",
                     "usr/share/dylanos/installer/native/main.py",
                     "usr/share/dylanos/spotlight/qml/Main.qml",
                     "usr/share/dylanos/neofetch/logo.png",
                     "usr/share/icons/hicolor/512x512/apps/distributor-logo-dylanos.png",
                     "usr/share/aurorae/themes/DylanOS-Crimson/DylanOS-Crimsonrc",
                     "usr/share/aurorae/themes/DylanOS-Crimson-Light/DylanOS-Crimson-Lightrc",
                     "usr/share/wallpapers/DylanOS/DylanOS-Dark.png",
                     "usr/share/wallpapers/DylanOS/dylanos-default.png",
                     "usr/share/plasma/look-and-feel/org.dylanos.crimson/contents/splash/Splash.qml",
                     "usr/share/plasma/plasmoids/com.dylanos.activeapp/contents/ui/main.qml",
                     "usr/share/dylanos/workspace/assets/logo.png",
                     "etc/skel/.config/ksplashrc",
                     "etc/skel/.config/kitty/kitty.conf",
                     "etc/xdg/kitty/kitty.conf",
                     "etc/skel/.config/neofetch/config.conf",
                     "etc/xdg/neofetch/config.conf",
                     "usr/bin/dylanos-console",
                     "usr/bin/neofetch",
                     "usr/share/applications/org.dylanos.console.desktop",
                     "usr/share/dylanos/shell/dylanos-ghost.sh",
                     "usr/share/icons/hicolor/scalable/apps/dylanos-console.svg",
                     "etc/skel/.bashrc",
                     "usr/share/applications/dylanos-installer.desktop",
                     "etc/skel/Desktop/instalar-dylanos.desktop",
                     "etc/skel/Escritorio/instalar-dylanos.desktop",
                     "usr/share/wallpapers/DylanOS/DylanOS-Light.png",
                     "usr/share/sddm/themes/DylanOS-Crimson/Main.qml",
                     "usr/share/grub/themes/dylanos/theme.txt",
                     "usr/share/plymouth/themes/dylanos/dylanos.script",
                     "usr/share/plasma/look-and-feel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js",
                     "usr/share/plasma/desktoptheme/DylanOS-Crimson/translucent/widgets/panel-background.svg",
                     "usr/share/plasma/desktoptheme/DylanOS-Crimson/translucent/dialogs/background.svg",
                     "usr/share/themes/DylanOS-Crimson/gtk-3.0/gtk.css",
                     "usr/share/themes/DylanOS-Crimson/gtk-4.0/gtk.css",
                     "usr/share/themes/DylanOS-Crimson/index.theme",
                     "etc/skel/.config/gtk-3.0/settings.ini",
                     "etc/skel/.config/gtk-4.0/settings.ini"]
            for path in paths: self.assertTrue((root / path).is_file(), path)
            source_dist = ROOT / "installer/dylanos-installer/dist"
            staged_dist = root / "usr/share/dylanos/installer/dist/index.html"
            if source_dist.is_dir():
                self.assertTrue(staged_dist.is_file())
            else:
                self.assertFalse(staged_dist.exists(), "El staging sin build no debe inventar el frontend")
            # Calamares quedó eliminado: sin branding ni lanzadores de terceros.
            self.assertFalse((root / "etc/calamares").exists())
            self.assertFalse((root / "usr/share/applications/calamares-install-debian.desktop").exists())
            # El instalador nativo abre su propia ventana de escritorio (Qt
            # WebEngine): nunca se lanza Firefox ni un navegador externo.
            installer = (root / "usr/bin/dylanos-installer").read_text()
            self.assertIn("installer/native/main.py", installer)
            self.assertNotIn("firefox", installer.lower())
            self.assertNotIn("xdg-open", installer)
            self.assertNotIn('-P "DylanOSInstaller"', installer)
            native = (root / "usr/share/dylanos/installer/native/main.py").read_text()
            self.assertIn("QWebEngineView", native)
            self.assertIn("launch_backend", native)
            desktop = (root / "usr/share/applications/dylanos-installer.desktop").read_text()
            self.assertIn("Exec=/usr/bin/dylanos-installer", desktop)
            self.assertIn("StartupWMClass=dylanos-installer", desktop)
            # El instalador debe aparecer como icono de escritorio en la sesión live:
            # el archivo de escritorio en skel/Desktop/ con permisos de ejecución
            # hace que Plasma lo trate como lanzador de confianza (doble clic directo).
            desktop_shortcut_path = root / "etc/skel/Desktop/instalar-dylanos.desktop"
            self.assertTrue(desktop_shortcut_path.is_file(),
                            "Falta el acceso directo del instalador en el escritorio live")
            desktop_shortcut = desktop_shortcut_path.read_text()
            self.assertIn("Exec=/usr/bin/dylanos-installer", desktop_shortcut)
            self.assertIn("Icon=distributor-logo-dylanos", desktop_shortcut)
            self.assertIn("StartupWMClass=dylanos-installer", desktop_shortcut)
            # Permisos 0o755: Plasma solo muestra el icono sin diálogo si el
            # archivo es ejecutable.
            mode = desktop_shortcut_path.stat().st_mode & 0o777
            self.assertEqual(mode, 0o755,
                             f"El acceso directo del instalador debe ser 0o755, tiene {oct(mode)}")
            # El escritorio se traduce según el locale (xdg-user-dirs), así que
            # el lanzador debe existir también en ~/Escritorio para el live es_ES.
            localized_shortcut = root / "etc/skel/Escritorio/instalar-dylanos.desktop"
            self.assertTrue(localized_shortcut.is_file(),
                            "Falta el acceso directo del instalador en ~/Escritorio")
            self.assertEqual(localized_shortcut.read_text(), desktop_shortcut_path.read_text())
            # La sesión live es un escritorio de vista previa: el instalador NO
            # debe autoejecutarse al iniciar sesión (nada de /etc/xdg/autostart).
            self.assertFalse((root / "etc/xdg/autostart/dylanos-installer.desktop").exists(),
                             "El instalador no debe autoejecutarse en la sesión live")
            # El nombre de la aplicación activa no se corta con topes fijos:
            # el applet toma el espacio libre del panel y solo elida cuando
            # de verdad no queda sitio (nada de máximos de 200/400 px).
            activeapp = (root / "usr/share/plasma/plasmoids/com.dylanos.activeapp/contents/ui/main.qml").read_text()
            self.assertIn("Layout.fillWidth: true", activeapp)
            self.assertNotIn("maxTitleWidth", activeapp)
            # DylanOS Shell: búsqueda (Spotlight) y Centro de Control en la
            # barra superior, papelera al final del dock, reloj 12h con fecha.
            self.assertTrue((root / "usr/share/plasma/plasmoids/com.dylanos.search/metadata.json").is_file())
            self.assertTrue((root / "usr/share/plasma/plasmoids/com.dylanos.search/contents/ui/main.qml").is_file())
            dashboard = root / "usr/share/plasma/plasmoids/com.dylanos.dashboard"
            self.assertTrue((dashboard / "metadata.json").is_file())
            dashboard_qml = (dashboard / "contents/ui/main.qml").read_text()
            self.assertIn("/proc/meminfo", dashboard_qml)
            self.assertIn("/proc/uptime", dashboard_qml)
            self.assertIn("Mes anterior", dashboard_qml)
            self.assertIn("function selectDate(date)", dashboard_qml)
            self.assertIn("delegate: QQC2.Button", dashboard_qml)
            self.assertIn("Día seleccionado · ", dashboard_qml)
            dash_meta = json.loads((dashboard / "metadata.json").read_text())
            self.assertEqual(dash_meta["KPlugin"]["Version"], "0.7.0")
            self.assertIn("function usagePercent(used, total)", dashboard_qml)
            self.assertIn("Accessible.name: \"Uso de memoria: \"", dashboard_qml)
            self.assertEqual(dashboard_qml.count("Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }"), 3)
            self.assertIn('isToday ? ", hoy" : \"', dashboard_qml)
            self.assertIn('isSelected ? ", seleccionado" : \"', dashboard_qml)
            self.assertIn('ColorAnimation { duration: 130; easing.type: Easing.OutCubic }', dashboard_qml)
            self.assertIn('commandRunner.connectSource("plasma-systemmonitor")', dashboard_qml)
            self.assertIn('text: "Abrir Monitor del sistema"', dashboard_qml)
            self.assertIn('text: "Actualizar"', dashboard_qml)
            self.assertIn('root.lastRefreshRequested = new Date()', dashboard_qml)
            self.assertIn('"Consulta · " + Qt.formatTime(root.lastRefreshRequested, "hh:mm:ss")', dashboard_qml)
            self.assertIn('property var cpuHistory: []', dashboard_qml)
            self.assertIn('root.cpuHistory = root.cpuHistory.concat([root.cpuUsagePercent]).slice(-24)', dashboard_qml)
            self.assertIn('id: cpuTrend', dashboard_qml)
            self.assertIn('ctx.strokeStyle = "#DC143C"', dashboard_qml)
            self.assertIn('function cpuHistoryDescription()', dashboard_qml)
            self.assertTrue((dashboard / "contents/ui/PomodoroClock.js").is_file())
            self.assertIn('function startPomodoro()', dashboard_qml)
            self.assertIn('function pausePomodoro()', dashboard_qml)
            self.assertIn('function resetPomodoro()', dashboard_qml)
            self.assertIn('id: pomodoroCard', dashboard_qml)
            self.assertIn('"Ciclos · " + root.completedFocusSessions', dashboard_qml)
            self.assertTrue((root / "usr/share/plasma/plasmoids/com.dylanos.controlcenter/metadata.json").is_file())
            cc_root = root / "usr/share/plasma/plasmoids/com.dylanos.controlcenter"
            cc_main = (cc_root / "contents/ui/main.qml").read_text()
            self.assertIn("compactRepresentation", cc_main)
            self.assertIn("notificationModel: notifModel", cc_main)
            self.assertIn("SystemStatus.setMonitoringActive(root.expanded)", cc_main)
            status_qml = (cc_root / "contents/ui/SystemStatus.qml").read_text()
            self.assertIn("function toggleMute()", status_qml)
            self.assertIn("function setMicrophoneVolume(normalizedValue)", status_qml)
            self.assertIn("function toggleMicrophoneMute()", status_qml)
            self.assertIn("pactl get-source-volume @DEFAULT_SOURCE@", status_qml)
            self.assertIn("pactl set-source-volume @DEFAULT_SOURCE@", status_qml)
            self.assertIn("pactl set-source-mute @DEFAULT_SOURCE@ toggle", status_qml)
            cc_panel = (cc_root / "contents/ui/ControlCenterPanel.qml").read_text()
            self.assertIn('Accessible.name: "Nivel del micrófono"', cc_panel)
            self.assertIn('"Micrófono no detectado"', cc_panel)
            self.assertIn("DylanOSDark", status_qml)
            self.assertIn("interval: 15000", status_qml)
            self.assertIn("running: root.monitoringActive", status_qml)
            self.assertIn("function setMonitoringActive(active)", status_qml)
            notifications_qml = (cc_root / "contents/ui/NotificationsPanel.qml").read_text()
            self.assertIn("model: root.notificationModel", notifications_qml)
            self.assertNotIn("NotificationManager.Notifications", notifications_qml)
            cc_meta = json.loads((cc_root / "metadata.json").read_text())
            self.assertEqual(cc_meta["KPlugin"]["Version"], "0.4.0")
            shell_layout = (root / "usr/share/plasma/look-and-feel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text()
            self.assertIn("com.dylanos.search", shell_layout)
            self.assertIn('allDesktops[i].addWidget("com.dylanos.dashboard"', shell_layout)
            self.assertIn("com.dylanos.controlcenter", shell_layout)
            self.assertIn("org.kde.plasma.trash", shell_layout)
            self.assertIn('"ddd dd \'de\' MMM"', shell_layout)
            self.assertIn("use24hFormat\", 1", shell_layout)
            # SDDM replica el dashboard de referencia con identidad local real.
            sddm_main = (root / "usr/share/sddm/themes/DylanOS-Crimson/Main.qml").read_text()
            self.assertIn("sddm.login(", sddm_main)
            self.assertIn("userAvatarSource", sddm_main)
            self.assertIn("focus: true", sddm_main)
            for component in ("AccountCard", "SessionCard", "LocalTimeCard", "PowerCard"):
                self.assertIn(f"{component} {{}}", sddm_main)
                self.assertTrue((root / f"usr/share/sddm/themes/DylanOS-Crimson/components/{component}.qml").is_file())
            self.assertNotIn("fingerprint.svg", sddm_main)
            self.assertNotIn("WeatherCard", sddm_main)
            self.assertNotIn("CalendarCard", sddm_main)
            self.assertNotIn("MediaCard", sddm_main)
            self.assertNotIn("RemindersCard", sddm_main)
            self.assertNotIn("ShortcutsCard", sddm_main)
            self.assertNotIn("Battery", sddm_main)
            self.assertNotIn("Storage", sddm_main)
            self.assertNotIn("Network", sddm_main)
            power_card = (root / "usr/share/sddm/themes/DylanOS-Crimson/components/PowerCard.qml").read_text()
            for capability in ("sddm.canPowerOff", "sddm.canReboot", "sddm.canSuspend"):
                self.assertIn(capability, power_card)
            self.assertIn("background=/usr/share/wallpapers/DylanOS/dylanos-default.png",
                          (root / "usr/share/sddm/themes/DylanOS-Crimson/theme.conf").read_text())
            self.assertTrue((root / "usr/share/sddm/themes/DylanOS-Crimson/logo.png").is_file())
            # En el sistema instalado el GRUB arranca DylanOS sin menú; el
            # menú visible solo existe en el LIVE (scripts/iso.sh, timeout=3).
            grubcfg = (root / "etc/default/grub.d/dylanos.cfg").read_text()
            self.assertIn("GRUB_TIMEOUT=0", grubcfg)
            self.assertIn("GRUB_TIMEOUT_STYLE=hidden", grubcfg)
            # La ventana del instalador abre con los botones de menú nativos
            # (minimizar/maximizar/cerrar); la pantalla completa es opcional.
            installer_native = (root / "usr/share/dylanos/installer/native/main.py").read_text()
            self.assertIn('"--fullscreen"', installer_native)
            self.assertIn("if args.fullscreen:", installer_native)
            self.assertIn("button[title=", installer_native)

            backend = (root / "usr/share/dylanos/installer/backend/server.py").read_text()
            self.assertIn("perform_installation", backend)
            self.assertIn("/api/install", backend)
            self.assertNotIn("firefox", backend.lower())

            # Terminal DylanOS: Kitty translúcido + neofetch con logo PNG.
            kitty = (root / "etc/skel/.config/kitty/kitty.conf").read_text()
            self.assertIn("background_opacity 0.40", kitty)
            self.assertIn("background_blur 24", kitty)
            self.assertIn("tab_bar_style separator", kitty)
            self.assertIn("scrollback_lines 50000", kitty)
            self.assertIn("#DC143C", kitty)
            console = (root / "usr/share/applications/org.dylanos.console.desktop").read_text()
            self.assertIn("Name=DylanOS Console", console)
            self.assertIn("Exec=dylanos-console", console)
            self.assertIn("StartupWMClass=org.dylanos.console", console)
            self.assertIn("org.dylanos.console",
                          (root / "usr/bin/dylanos-console").read_text())
            bashrc = (root / "etc/skel/.bashrc").read_text()
            self.assertIn("command_not_found_handle", bashrc)
            self.assertIn("PROMPT_COMMAND", bashrc)
            self.assertIn("dylanos-ghost.sh", bashrc)
            self.assertIn("neofetch", bashrc)
            self.assertNotIn("fastfetch", bashrc)
            neofetch = (root / "etc/skel/.config/neofetch/config.conf").read_text()
            self.assertIn('image_backend="kitty"', neofetch)
            self.assertIn("/usr/share/dylanos/neofetch/logo.png", neofetch)
            self.assertIn("DylanOS · Resumen del sistema", neofetch)
            self.assertEqual((root / "usr/share/dylanos/neofetch/logo.png").read_bytes(),
                             (ROOT / "branding/logo.png").read_bytes())
            neofetch_wrapper = (root / "usr/bin/neofetch").read_text()
            self.assertIn("XDG_CONFIG_HOME", neofetch_wrapper)
            self.assertIn("/etc/xdg/neofetch/config.conf", neofetch_wrapper)
            self.assertIn('exec /usr/bin/neowofetch --config "$config"', neofetch_wrapper)
            self.assertFalse((root / "etc/skel/.config/konsolerc").exists())
            self.assertFalse((root / "usr/share/dylanos/fastfetch/logo.txt").exists())
            ghost = (root / "usr/share/dylanos/shell/dylanos-ghost.sh").read_text()
            self.assertIn("__dylanos_tab", ghost)
            self.assertIn(r'"\t"', ghost)
            kdeglobals = (root / "etc/skel/.config/kdeglobals").read_text()
            self.assertIn("TerminalApplication=dylanos-console", kdeglobals)
            self.assertIn("TerminalService=org.dylanos.console.desktop", kdeglobals)
            # El layout del panel nunca debe incluir el cambiador de escritorios.
            layout = (root / "usr/share/plasma/look-and-feel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text()
            self.assertNotIn('addWidget("org.kde.plasma.pager")', layout)
            self.assertIn('dock.addWidget("com.dylanos.dock")', layout)
            self.assertIn('dock.addWidget("org.kde.plasma.trash")', layout)
            staged_dock = root / "usr/share/plasma/plasmoids/com.dylanos.dock"
            self.assertTrue((staged_dock / "metadata.json").is_file())
            dock_meta = json.loads((staged_dock / "metadata.json").read_text())
            self.assertEqual(dock_meta["KPlugin"]["Version"], "0.4")
            dock_delegate = (staged_dock / "contents/ui/DockItemDelegate.qml").read_text()
            self.assertIn("hoverDistance === 1", dock_delegate)
            self.assertIn("hoverDistance === 2", dock_delegate)
            for gtk_version in ("gtk-3.0", "gtk-4.0"):
                settings_ini = (root / "etc/skel/.config" / gtk_version / "settings.ini").read_text()
                self.assertIn("gtk-theme-name=DylanOS-Crimson", settings_ini)
                self.assertIn("gtk-application-prefer-dark-theme=1", settings_ini)
            self.assertEqual((root / "usr/share/wallpapers/DylanOS/dylanos-default.png").read_bytes(),
                             (ROOT / "branding/wallpapers/dylanos-default.png").read_bytes())
            for key in ("monitor", "dev", "notes"):
                launcher = (root / f"usr/share/applications/org.dylanos.{key}.desktop").read_text()
                self.assertIn(f"StartupWMClass=org.dylanos.{key}", launcher)
            # La tienda es la app nativa dylanos-store (fork de Discover),
            # ya no una página del workspace que lance plasma-discover.
            store = (root / "usr/share/applications/org.dylanos.store.desktop").read_text()
            self.assertIn("Exec=dylanos-store", store)
            self.assertIn("StartupWMClass=dylanos-store", store)
            self.assertIn("Icon=dylanos-store", store)
            self.assertNotIn("plasma-discover", store)
            # "Archivos" del menú es DylanOS Explorer (binario real), no una
            # página del workspace: la entrada staged es la canónica de la app.
            explorer = (root / "usr/share/applications/org.dylanos.explorer.desktop").read_text()
            self.assertIn("Exec=dylanos-explorer %U", explorer)
            self.assertIn("StartupWMClass=dylanos-explorer", explorer)
            self.assertNotIn("dylanos --page", explorer)
            # Las carpetas se abren con el Explorer: dolphin no se envía.
            mimeapps = (root / "etc/skel/.config/mimeapps.list").read_text()
            self.assertIn("inode/directory=org.dylanos.explorer.desktop;", mimeapps)
            self.assertIn("x-scheme-handler/terminal=org.dylanos.console.desktop;", mimeapps)
            # XDG solo lee mimeapps.list; mimeapps.info no aplica asociaciones
            # predeterminadas del sistema.
            system_mimeapps = (root / "usr/share/applications/mimeapps.list").read_text()
            self.assertIn("inode/directory=org.dylanos.explorer.desktop;", system_mimeapps)
            self.assertFalse((root / "usr/share/applications/mimeapps.info").exists())
            self.assertNotIn("dolphin", mimeapps)
            self.assertNotIn("konsole", mimeapps)
            # Re-staging sobre un root existente: debe limpiar artefactos
            # obsoletos (autostart del instalador y restos de Discover) sin
            # sobrescribir la configuración existente del usuario.
            stale_autostart = root / "etc/xdg/autostart/dylanos-installer.desktop"
            stale_autostart.parent.mkdir(parents=True, exist_ok=True)
            stale_autostart.write_text("[Desktop Entry]\nType=Application\n")
            stale_discover = root / "usr/share/applications/org.kde.discover.desktop"
            stale_discover.write_text("[Desktop Entry]\nType=Application\n")
            stale_files = root / "usr/share/applications/org.dylanos.files.desktop"
            stale_files.write_text("[Desktop Entry]\nType=Application\nName=Archivos\nExec=dylanos --page files\n")
            stale_konsole = root / "usr/share/applications/org.kde.konsole.desktop"
            stale_konsole.write_text("[Desktop Entry]\nType=Application\nName=Konsole\n")
            stale_konsolerc = root / "etc/skel/.config/konsolerc"
            stale_konsolerc.write_text("[Desktop Entry]\nDefaultProfile=DylanOS.profile\n")
            stale_kitty = root / "usr/share/applications/kitty.desktop"
            stale_kitty.write_text("[Desktop Entry]\nType=Application\nName=kitty\n")
            stale_notifier = root / "etc/xdg/autostart/org.kde.discover.notifier.desktop"
            stale_notifier.parent.mkdir(parents=True, exist_ok=True)
            stale_notifier.write_text("[Desktop Entry]\nType=Application\n")
            original = (root / "etc/skel/.config/kdeglobals").read_text()
            module.stage(root)
            self.assertFalse(stale_autostart.exists(),
                             "stage() debe borrar el autostart obsoleto del instalador")
            self.assertFalse(stale_discover.exists(),
                             "stage() debe borrar los restos de plasma-discover")
            self.assertFalse(stale_notifier.exists(),
                             "stage() debe borrar el autostart obsoleto del notifier de Discover")
            self.assertFalse(stale_files.exists(),
                             "stage() debe borrar la entrada obsoleta org.dylanos.files.desktop (Archivos del workspace)")
            self.assertFalse(stale_konsole.exists(),
                             "stage() debe borrar el lanzador de Konsole")
            self.assertFalse(stale_konsolerc.exists(),
                             "stage() debe borrar el perfil skel de Konsole")
            self.assertIn("NoDisplay=true", stale_kitty.read_text(),
                          "stage() debe ocultar el lanzador genérico de Kitty")
            self.assertEqual((root / "etc/skel/.config/kdeglobals").read_text(), original)
            self.assertEqual(len(list((root / "usr/share/applications").glob("org.dylanos.*.desktop"))), 9)
            self.assertFalse(list(root.rglob("*.otf")))

    def test_installer_frontend_can_be_staged_from_temporary_dist(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            dist = base / "installer-build" / "dist"
            dist.mkdir(parents=True)
            (dist / "index.html").write_text("<html>fresh build</html>", encoding="utf-8")
            (dist / "assets").mkdir()
            (dist / "assets/app.js").write_text("console.log('fresh');", encoding="utf-8")
            root = base / "chroot"
            root.mkdir()
            staged = root / "usr/share/dylanos/installer/dist"
            staged.mkdir(parents=True)
            (staged / "obsolete.js").write_text("stale", encoding="utf-8")

            module.stage(root, dist)

            self.assertEqual((staged / "index.html").read_text(encoding="utf-8"),
                             "<html>fresh build</html>")
            self.assertEqual((staged / "assets/app.js").read_text(encoding="utf-8"),
                             "console.log('fresh');")
            self.assertFalse((staged / "obsolete.js").exists())
            # Staging reads the isolated build result; it neither rewrites nor
            # consumes the installer source tree. A later iso.sh restage with
            # no checkout dist must retain the frontend already in the chroot.
            source_dist = ROOT / "installer/dylanos-installer/dist"
            if source_dist.is_dir():
                self.assertTrue((source_dist / "index.html").is_file())
            else:
                module.stage(root)
                self.assertEqual((staged / "index.html").read_text(encoding="utf-8"),
                                 "<html>fresh build</html>")
            self.assertEqual((dist / "index.html").read_text(encoding="utf-8"),
                             "<html>fresh build</html>")

    def test_installer_frontend_rejects_empty_index(self):
        with tempfile.TemporaryDirectory() as folder:
            dist = Path(folder) / "dist"
            dist.mkdir()
            (dist / "index.html").touch()
            with self.assertRaises(FileNotFoundError):
                module.stage(Path(folder) / "chroot", dist)

    def test_aurorae_required_svg_elements(self):
        for variant in ("DylanOS-Crimson", "DylanOS-Crimson-Light"):
            root = ROOT / "themes/aurorae" / variant
            for button in ("close", "minimize", "maximize", "restore"):
                tree = ET.parse(root / (button + ".svg"))
                self.assertIn("active-center", [node.get("id") for node in tree.iter()])
            tree = ET.parse(root / "decoration.svg")
            ids = {node.get("id") for node in tree.iter()}
            for suffix in ("center", "top", "bottom", "left", "right", "topleft", "topright", "bottomleft", "bottomright"):
                self.assertIn("decoration-" + suffix, ids)


if __name__ == "__main__":
    unittest.main()
