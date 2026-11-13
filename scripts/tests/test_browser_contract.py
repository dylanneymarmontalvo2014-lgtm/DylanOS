"""Valida el contrato de fuente previo al empaquetado de DylanOS Browser."""

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
LOCK_PATH = ROOT / "apps" / "dylanos-browser" / "source.lock.json"
EXPECTED_LOCK = {
    "schema_version": 1,
    "repository": "https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS.git",
    "upstream": {
        "repository": "https://github.com/zen-browser/desktop.git",
        "tag": "1.24b",
        "commit": "f75390aa2b797ddc3524ff9ed52ceb32a839f9fa",
    },
    "product_version": "1.0.0-alpha.1",
    "firefox_version": "159.0",
    "binary": "dylanos-browser",
    "desktop_id": "org.dylanos.browser.desktop",
    "source_archive": "unpublished",
    "sha256": "unpublished",
    "update_authority": "apt",
}


class BrowserSourceContractTest(unittest.TestCase):
    def load_lock(self):
        self.assertTrue(
            LOCK_PATH.is_file(),
            f"Falta el contrato de fuente: {LOCK_PATH.relative_to(ROOT)}",
        )
        return json.loads(LOCK_PATH.read_text(encoding="utf-8"))

    def test_source_lock_is_exact_and_not_published(self):
        source_lock = self.load_lock()
        self.assertEqual(source_lock, EXPECTED_LOCK)
        self.assertEqual(source_lock["source_archive"], "unpublished")
        self.assertEqual(source_lock["sha256"], "unpublished")

    def test_pre_beta_packages_browser_in_tree_without_firefox_esr(self):
        packages = {
            line.strip()
            for line in (ROOT / "packages" / "default" / "packages.list")
            .read_text(encoding="utf-8")
            .splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        self.assertNotIn("firefox-esr", packages)
        self.assertNotIn("dylanos-browser", packages)
        defaults = (ROOT / "configs" / "default-apps.conf").read_text(
            encoding="utf-8"
        )
        self.assertIn("[Browser]\ndylanos-browser\n", defaults)
        build = (ROOT / "scripts" / "build.sh").read_text(encoding="utf-8")
        self.assertIn("dpkg-buildpackage", build)
        self.assertIn("dylanos-browser_*_amd64.deb", build)
        self.assertIn("purge dolphin dolphin-plugins kcalc konsole firefox-esr", build)

    def test_resumed_build_resets_browser_packaging_workspace(self):
        build = (ROOT / "scripts" / "build.sh").read_text(encoding="utf-8")
        reset = 'rm -rf -- "$CHROOT/tmp/dylanos-src/dylanos-browser"'
        create = 'mkdir -p "$CHROOT/tmp/dylanos-src/dylanos-browser/scripts/dylanos"'
        old_debs = 'rm -f -- "$CHROOT"/tmp/dylanos-src/dylanos-browser_*_amd64.deb'
        self.assertIn(reset, build)
        self.assertIn(create, build)
        self.assertLess(build.index(reset), build.index(create))
        self.assertIn(old_debs, build)
        self.assertIn(
            'BROWSER_ARTIFACT="$(cd -- "$BROWSER_ARTIFACT" && pwd -P)"',
            build,
        )


if __name__ == "__main__":
    unittest.main()
