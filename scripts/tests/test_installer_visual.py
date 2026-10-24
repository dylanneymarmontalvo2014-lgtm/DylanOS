"""Visual and offline-safety contracts for the native DylanOS installer."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INSTALLER = ROOT / "installer/dylanos-installer"
SRC = INSTALLER / "src"


class InstallerVisualContractTest(unittest.TestCase):
    def test_installer_uses_offline_system_font_fallbacks(self):
        css = (SRC / "index.css").read_text()
        typography = (SRC / "styles/typography.css").read_text()
        self.assertNotIn("fonts.googleapis.com", css)
        self.assertIn("Noto Sans", typography)
        self.assertIn("Cantarell", typography)

    def test_installer_palette_matches_dylanos_crimson(self):
        colors = (SRC / "styles/colors.css").read_text()
        effects = (SRC / "styles/effects.css").read_text()
        self.assertIn("--red: #DC143C", colors)
        self.assertIn("--red-hover: #FF2A54", colors)
        self.assertIn("--red-dark: #9C0B28", colors)
        self.assertIn("rgba(220, 20, 60", colors + effects)
        for path in SRC.rglob("*"):
            if path.is_file() and path.suffix in {".tsx", ".ts", ".css"}:
                source = path.read_text()
                self.assertNotIn("#dc2626", source.lower(), str(path))
                self.assertNotIn("#ef4444", source.lower(), str(path))
                self.assertNotIn("#991b1b", source.lower(), str(path))

    def test_installer_remains_responsive_and_respects_reduced_motion(self):
        css = (SRC / "index.css").read_text()
        self.assertIn("max-width: 1120px", css)
        self.assertIn("prefers-reduced-motion: reduce", css)
        self.assertIn("installer-sidebar", (SRC / "components/Sidebar/index.tsx").read_text())
        self.assertIn("installer-system-info", (SRC / "components/SystemInfo/index.tsx").read_text())

    def test_local_installer_disables_remote_webengine_content(self):
        native = (INSTALLER / "native/main.py").read_text()
        self.assertIn("LocalContentCanAccessRemoteUrls, False", native)

    def test_native_wrapper_close_control_contract_is_preserved(self):
        app = (SRC / "App.tsx").read_text()
        wrapper = (INSTALLER / "native/main.py").read_text()
        self.assertIn('title: "Cerrar"', app)
        self.assertIn('button[title=\\"Cerrar\\"]', wrapper)
        self.assertIn("hide_decoration_buttons", wrapper)


if __name__ == "__main__":
    unittest.main()
