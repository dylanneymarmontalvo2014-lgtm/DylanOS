"""Check that the installed payload is complete and safe to regenerate."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("stage", ROOT / "scripts/stage.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StagingTest(unittest.TestCase):
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
                     "usr/share/dylanos/installer/dist/index.html",
                     "usr/share/dylanos/spotlight/qml/Main.qml",
                     "usr/share/dylanos/fastfetch/logo.txt",
                     "usr/share/icons/hicolor/512x512/apps/distributor-logo-dylanos.png",
                     "usr/share/aurorae/themes/DylanOS-Crimson/DylanOS-Crimsonrc",
                     "usr/share/aurorae/themes/DylanOS-Crimson-Light/DylanOS-Crimson-Lightrc",
                     "usr/share/wallpapers/DylanOS/DylanOS-Dark.png",
                     "usr/share/wallpapers/DylanOS/dylanos-default.png",
                     "usr/share/plasma/look-and-feel/org.dylanos.crimson/contents/splash/Splash.qml",
                     "usr/share/plasma/plasmoids/com.dylanos.activeapp/contents/ui/main.qml",
                     "usr/share/dylanos/workspace/assets/logo.png",
                     "etc/skel/.config/ksplashrc",
                     "etc/skel/.config/konsolerc",
                     "etc/skel/.local/share/konsole/DylanOS.profile",
                     "etc/skel/.local/share/konsole/DylanOS-Crimson.colorscheme",
                     "etc/skel/.config/fastfetch/config.jsonc",
                     "etc/skel/.bashrc",
                     "usr/share/applications/dylanos-installer.desktop",
                     "etc/skel/Desktop/instalar-dylanos.desktop",
                     "etc/skel/Escritorio/instalar-dylanos.desktop",
                     "usr/share/wallpapers/DylanOS/DylanOS-Light.png",
                     "usr/share/sddm/themes/DylanOS-Crimson/Main.qml",
                     "usr/share/grub/themes/dylanos/theme.txt",
                     "usr/share/plymouth/themes/dylanos/dylanos.script",
                     "usr/share/plasma/look-and-feel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js",
                     "usr/share/themes/DylanOS-Crimson/gtk-3.0/gtk.css",
                     "usr/share/themes/DylanOS-Crimson/gtk-4.0/gtk.css",
                     "usr/share/themes/DylanOS-Crimson/index.theme",
                     "etc/skel/.config/gtk-3.0/settings.ini",
                     "etc/skel/.config/gtk-4.0/settings.ini"]
            for path in paths: self.assertTrue((root / path).is_file(), path)
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
            # El nombre de la aplicación activa nunca debe colapsar a una letra:
            # el applet de la barra superior no admite un ancho menor que su título.
            activeapp = (root / "usr/share/plasma/plasmoids/com.dylanos.activeapp/contents/ui/main.qml").read_text()
            self.assertIn("Layout.minimumWidth: Layout.preferredWidth", activeapp)
            # El tope de ancho del título debe cubrir nombres largos: con el
            # límite anterior (200 px) el nombre salía cortado con elipsis.
            self.assertIn("maxTitleWidth: 400", activeapp)
            self.assertNotIn("maxTitleWidth: 200", activeapp)
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

            # Terminal DylanOS: Konsole translúcido + fastfetch con logo propio.
            colors = (root / "etc/skel/.local/share/konsole/DylanOS-Crimson.colorscheme").read_text()
            self.assertIn("Opacity=0.82", colors)
            profile = (root / "etc/skel/.local/share/konsole/DylanOS.profile").read_text()
            self.assertIn("ColorScheme=DylanOS-Crimson", profile)
            self.assertIn("DefaultProfile=DylanOS.profile",
                          (root / "etc/skel/.config/konsolerc").read_text())
            bashrc = (root / "etc/skel/.bashrc").read_text()
            self.assertIn("command_not_found_handle", bashrc)
            self.assertIn("PROMPT_COMMAND", bashrc)
            fastfetch = (root / "etc/skel/.config/fastfetch/config.jsonc").read_text()
            self.assertIn("logo.txt", fastfetch)
            self.assertIn("DylanOS", (root / "usr/share/dylanos/fastfetch/logo.txt").read_text())
            # El layout del panel nunca debe incluir el cambiador de escritorios.
            layout = (root / "usr/share/plasma/look-and-feel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js").read_text()
            self.assertNotIn('addWidget("org.kde.plasma.pager")', layout)
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
            # Re-staging sobre un root existente: debe limpiar artefactos
            # obsoletos (autostart del instalador y restos de Discover) sin
            # sobrescribir la configuración existente del usuario.
            stale_autostart = root / "etc/xdg/autostart/dylanos-installer.desktop"
            stale_autostart.parent.mkdir(parents=True, exist_ok=True)
            stale_autostart.write_text("[Desktop Entry]\nType=Application\n")
            stale_discover = root / "usr/share/applications/org.kde.discover.desktop"
            stale_discover.write_text("[Desktop Entry]\nType=Application\n")
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
            self.assertEqual((root / "etc/skel/.config/kdeglobals").read_text(), original)
            self.assertEqual(len(list((root / "usr/share/applications").glob("org.dylanos.*.desktop"))), 8)
            self.assertFalse(list(root.rglob("*.otf")))

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
