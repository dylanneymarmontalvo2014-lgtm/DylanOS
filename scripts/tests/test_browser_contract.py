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

    def test_phase_one_keeps_firefox_and_does_not_install_unpublished_browser(self):
        packages = {
            line.strip()
            for line in (ROOT / "packages" / "default" / "packages.list")
            .read_text(encoding="utf-8")
            .splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        self.assertIn("firefox-esr", packages)
        self.assertNotIn("dylanos-browser", packages)


if __name__ == "__main__":
    unittest.main()
