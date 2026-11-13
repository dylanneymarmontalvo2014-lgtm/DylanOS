"""Keep the active usage documentation discoverable and internally coherent."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class DocumentationTest(unittest.TestCase):
    def test_current_component_guides_are_indexed(self):
        index = (ROOT / "docs/README.md").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        guide = ROOT / "docs/guia-de-uso.md"
        self.assertTrue(guide.is_file())
        self.assertIn("guia-de-uso.md", index)
        self.assertIn("guia-de-uso.md", readme)
        for component in (
            "apps/workspace/README.md",
            "apps/dylanos-spotlight/README.md",
            "apps/dylanos-app-center/README.md",
            "apps/dylanos-store/README.md",
            "apps/calculator/README.md",
            "apps/com.dylanos.dashboard/README.md",
            "apps/dylanos-control-center/README.md",
            "apps/com.dylanos.activeapp/README.md",
            "apps/com.dylanos.search/README.md",
            "apps/com.dylanos.dock/README.md",
        ):
            self.assertTrue((ROOT / component).is_file(), component)

    def test_agents_app_map_matches_repository_and_routes_exist(self):
        agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        app_dirs = {path.name for path in (ROOT / "apps").iterdir() if path.is_dir()}
        documented = set(re.findall(r"`apps/([^`/]+)/`", agents))
        self.assertEqual(app_dirs, documented)
        for relative in re.findall(r"`(apps/[A-Za-z0-9_.-]+(?:/[^`]*)?)`", agents):
            with self.subTest(path=relative):
                self.assertTrue((ROOT / relative.rstrip("/")).exists(), relative)
        self.assertIn("apps/calculator/", agents)
        self.assertNotIn("apps/dylanos-calculator/", agents)
        self.assertIn("DylanOS Browser predeterminado", agents)
        self.assertIn("payload-manifest.json", agents)
        self.assertIn("org.dylanos.browser.desktop", agents)

    def test_brand_assets_have_single_versioned_sources(self):
        canonical = ROOT / "branding/logo.png"
        for relative in (
            "apps/workspace/assets/logo.png",
            "apps/dylanos-configuration/assets/logo.png",
            "apps/dylanos-control-center/contents/ui/logo.png",
            "apps/dylanos-store/src/store/data/logo.png",
            "themes/lookandfeel/org.dylanos.crimson/contents/splash/images/logo.png",
            "themes/sddm/DylanOS-Crimson/logo.png",
            "themes/plymouth/DylanOS-Plymouth/logo.png",
        ):
            path = ROOT / relative
            with self.subTest(path=relative):
                self.assertTrue(path.is_symlink())
                self.assertEqual(path.resolve(), canonical.resolve())
        for name in ("close", "minimize", "maximize", "restore"):
            source = ROOT / "themes/aurorae/shared" / f"{name}.svg"
            self.assertTrue(source.is_file())
            for variant in ("DylanOS-Crimson", "DylanOS-Crimson-Light", "DylanOS-Crimson-Glass", "DylanOS-Crimson-Glass-Light"):
                link = ROOT / "themes/aurorae" / variant / f"{name}.svg"
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), source.resolve())

    def test_current_docs_do_not_repeat_retired_claims(self):
        files = (
            ROOT / "README.md",
            ROOT / "docs/guia-de-uso.md",
            ROOT / "docs/architecture.md",
            ROOT / "docs/install.md",
            ROOT / "apps/archivos/README.md",
            ROOT / "apps/dylanos-store/README.md",
            ROOT / "installer/dylanos-installer/docs/README.md",
        )
        current = "\n".join(path.read_text(encoding="utf-8") for path in files)
        self.assertNotIn("Dolphin sigue siendo el gestor predeterminado", current)
        self.assertNotIn("nothing is ever installed or removed on the host", current)
        self.assertIn("dylanos-explorer", current)
        self.assertIn("MockPackageBackend", current)
        self.assertIn("no instala el sistema", current)

    def test_new_documentation_relative_links_resolve(self):
        files = (
            ROOT / "README.md",
            ROOT / "docs/README.md",
            ROOT / "docs/guia-de-uso.md",
            ROOT / "docs/architecture.md",
            ROOT / "docs/install.md",
            ROOT / "docs/dylanos-shell.md",
            *ROOT.glob("apps/*/README.md"),
            ROOT / "installer/dylanos-installer/docs/README.md",
        )
        for document in files:
            text = document.read_text(encoding="utf-8")
            for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
                target = target.split("#", 1)[0]
                if not target or "://" in target or target.startswith(("mailto:", "file:")):
                    continue
                with self.subTest(document=document.relative_to(ROOT), target=target):
                    self.assertTrue((document.parent / target).exists(), target)


if __name__ == "__main__":
    unittest.main()
