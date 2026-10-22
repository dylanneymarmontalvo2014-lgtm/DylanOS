"""Regression checks for Plasma launchers and installer staging order."""
from pathlib import Path
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
        self.assertIn("applications:code.desktop", layout)
        self.assertIn("applications:code.desktop", dock)
        self.assertNotIn("applications:com.microsoft.VSCode.desktop", layout + dock)
        self.assertIn("code", [line.strip() for line in packages if line.strip() and not line.lstrip().startswith("#")])
        self.assertIn("packages.microsoft.com/repos/vscode", setup)

    def test_installer_is_built_before_staging(self):
        build = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
        check = (ROOT / "scripts/check.sh").read_text(encoding="utf-8")
        self.assertLess(build.index("build-installer.sh"), build.index("sudo unshare"))
        self.assertLess(check.index("build-installer.sh"), check.index("test_packages.sh"))
        helper = ROOT / "scripts/build-installer.sh"
        self.assertTrue(helper.is_file())


if __name__ == "__main__":
    unittest.main()
