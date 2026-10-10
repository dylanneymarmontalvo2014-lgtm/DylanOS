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
            (root / "etc/calamares").mkdir(parents=True)
            (root / "etc/calamares/settings.conf").write_text("branding: debian\nsequence: keep\n")
            module.stage(root)
            paths = ["usr/bin/dylanos", "usr/share/dylanos/workspace/qml/Main.qml",
                     "usr/share/icons/hicolor/512x512/apps/distributor-logo-dylanos.png",
                     "usr/share/aurorae/themes/DylanOS-Crimson/DylanOS-Crimsonrc",
                     "usr/share/aurorae/themes/DylanOS-Crimson-Light/DylanOS-Crimson-Lightrc",
                     "usr/share/wallpapers/DylanOS/DylanOS-Dark.png",
                     "usr/share/wallpapers/DylanOS/DylanOS-Light.png",
                     "usr/share/sddm/themes/DylanOS-Crimson/Main.qml",
                     "usr/share/grub/themes/dylanos/theme.txt",
                     "usr/share/plymouth/themes/dylanos/dylanos.script",
                     "usr/share/plasma/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js",
                     "usr/share/themes/DylanOS-Crimson/gtk-3.0/gtk.css",
                     "usr/share/themes/DylanOS-Crimson/gtk-4.0/gtk.css",
                     "usr/share/themes/DylanOS-Crimson/index.theme",
                     "etc/skel/.config/gtk-3.0/settings.ini",
                     "etc/skel/.config/gtk-4.0/settings.ini",
                     "etc/calamares/branding/dylanos/branding.desc",
                     "etc/calamares/branding/dylanos/logo.png"]
            for path in paths: self.assertTrue((root / path).is_file(), path)
            branding_desc = (root / "etc/calamares/branding/dylanos/branding.desc").read_text()
            self.assertIn("productLogo: logo.png", branding_desc)
            self.assertIn("productIcon: logo.png", branding_desc)
            self.assertNotIn("logo.svg", branding_desc)
            for gtk_version in ("gtk-3.0", "gtk-4.0"):
                settings_ini = (root / "etc/skel/.config" / gtk_version / "settings.ini").read_text()
                self.assertIn("gtk-theme-name=DylanOS-Crimson", settings_ini)
                self.assertIn("gtk-application-prefer-dark-theme=1", settings_ini)
            original = (root / "etc/skel/.config/kdeglobals").read_text()
            module.stage(root)
            self.assertEqual((root / "etc/skel/.config/kdeglobals").read_text(), original)
            self.assertEqual((root / "etc/calamares/settings.conf").read_text(), "branding: dylanos\nsequence: keep\n")
            self.assertEqual(len(list((root / "usr/share/applications").glob("org.dylanos.*.desktop"))), 7)
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
