# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import configparser
import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UPSTREAM_PATH = ROOT / "dylanos" / "upstream.json"
EXPECTED_UPSTREAM = {
    "repository": "https://github.com/zen-browser/desktop.git",
    "tag": "1.24b",
    "commit": "f75390aa2b797ddc3524ff9ed52ceb32a839f9fa",
    "firefox_version": "159.0",
    "audit_date": "2026-11-02",
}


class ProductContractTests(unittest.TestCase):
    def load_upstream(self):
        self.assertTrue(
            UPSTREAM_PATH.is_file(),
            f"Falta el registro de procedencia: {UPSTREAM_PATH.relative_to(ROOT)}",
        )
        return json.loads(UPSTREAM_PATH.read_text(encoding="utf-8"))

    def git(self, *args):
        return subprocess.run(
            ["git", *args],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def load_json(self, relative_path):
        return json.loads((ROOT / relative_path).read_text(encoding="utf-8"))

    def load_desktop_entry(self):
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        parser.read(ROOT / "build" / "AppDir" / "zen.desktop", encoding="utf-8")
        return parser

    def load_product_preferences(self):
        path = ROOT / "prefs" / "dylanos" / "product.yaml"
        self.assertTrue(
            path.is_file(),
            f"Falta el esquema de preferencias: {path.relative_to(ROOT)}",
        )
        text = path.read_text(encoding="utf-8")
        self.assertIn("mozilla.org/MPL/2.0/", text)
        payload = "\n".join(
            line for line in text.splitlines() if not line.lstrip().startswith("#")
        )
        return json.loads(payload)

    def test_upstream_record_is_exact(self):
        self.assertEqual(self.load_upstream(), EXPECTED_UPSTREAM)

    def test_checkout_descends_from_pinned_upstream_commit(self):
        expected = self.load_upstream()["commit"]
        tag = subprocess.run(
            ["git", "rev-parse", "1.24b^{commit}"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        if tag.returncode == 0:
            actual = tag.stdout.strip()
            self.assertEqual(
                actual,
                expected,
                f"La etiqueta 1.24b usa {actual}; se esperaba el upstream fijado {expected}",
            )
            ancestry = subprocess.run(
                ["git", "merge-base", "--is-ancestor", expected, "HEAD"],
                cwd=ROOT,
                check=False,
            )
            self.assertEqual(
                ancestry.returncode,
                0,
                f"El checkout no desciende del upstream fijado {expected}",
            )
        else:
            self.assertTrue((ROOT / "surfer.json").is_file())
            self.assertIn(expected, (ROOT / "README.md").read_text(encoding="utf-8"))

    def test_repository_identity_keeps_dylanos_origin_and_zen_provenance(self):
        self.assertEqual(
            self.git("remote", "get-url", "origin"),
            "git@github.com:dylanneymarmontalvo2014-lgtm/DylanOS.git",
        )
        remotes = self.git("remote").splitlines()
        if "upstream" in remotes:
            self.assertEqual(
                self.git("remote", "get-url", "upstream"),
                "https://github.com/zen-browser/desktop.git",
            )
        self.assertEqual(
            self.load_upstream()["repository"],
            "https://github.com/zen-browser/desktop.git",
        )

    def test_license_preserves_mpl_2(self):
        license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
        self.assertIn("Mozilla Public License Version 2.0", license_text)

    def test_readme_documents_identity_and_provenance(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        for notice in (
            "DylanOS Browser",
            "https://github.com/zen-browser/desktop",
            "f75390aa2b797ddc3524ff9ed52ceb32a839f9fa",
            "MPL-2.0",
            "no está afiliado ni respaldado",
        ):
            with self.subTest(notice=notice):
                self.assertIn(notice, readme)

    def test_build_metadata_uses_dylanos_identity(self):
        surfer = self.load_json("surfer.json")
        self.assertEqual(surfer["name"], "DylanOS Browser")
        self.assertEqual(surfer["vendor"], "DylanOS")
        self.assertEqual(surfer["appId"], "org.dylanos.browser")
        self.assertEqual(surfer["binaryName"], "dylanos-browser")
        self.assertEqual(surfer["version"]["version"], "159.0")
        self.assertEqual(
            surfer["brands"]["release"]["release"]["displayVersion"],
            "1.0.0-alpha.1",
        )
        self.assertEqual(surfer["updateHostname"], "updates.dylanos.invalid")
        for channel in ("release", "twilight"):
            with self.subTest(channel=channel):
                brand = surfer["brands"][channel]
                self.assertNotIn("Zen", brand["brandShorterName"])
                self.assertNotIn("Zen", brand["brandShortName"])
                self.assertNotIn("Zen", brand["brandFullName"])
                self.assertEqual(
                    brand["release"]["github"]["repo"],
                    "dylanneymarmontalvo2014-lgtm/DylanOS",
                )

    def test_package_scripts_expose_reproducible_dylanos_gates(self):
        package = self.load_json("package.json")
        self.assertEqual(package["name"], "dylanos-browser")
        self.assertEqual(
            package["repository"]["url"],
            "git+https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS.git",
        )
        self.assertEqual(
            package["bugs"]["url"],
            "https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS/issues",
        )
        scripts = package["scripts"]
        self.assertEqual(
            scripts["check:environment"],
            "python3 scripts/dylanos/check_build_environment.py",
        )
        self.assertEqual(scripts["lc"], "python3 scripts/dylanos/check_licenses.py")
        self.assertEqual(scripts["lc:upstream"], "surfer license-check")
        self.assertNotIn("lc:fix", scripts)
        self.assertEqual(
            scripts["test:dylanos"],
            "python3 -m unittest discover -v scripts/dylanos 'test_*.py'",
        )

    def test_bootstrap_artifacts_are_generated_outside_version_control(self):
        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("artifacts/", gitignore.splitlines())
        package = self.load_json("package.json")
        self.assertEqual(
            package["scripts"]["manifest:environment"],
            "python3 scripts/dylanos/write_build_manifest.py",
        )

    def test_gecko_bootstrap_is_reproducible_and_valid_shell(self):
        script_path = ROOT / "scripts" / "dylanos" / "bootstrap_gecko.sh"
        self.assertTrue(script_path.is_file())
        script = script_path.read_text(encoding="utf-8")
        for command in (
            "npm run check:environment",
            "npm ci",
            "npm run download",
            "npm run import",
            "npm run bootstrap",
            "npm run manifest:environment",
            "./mach configure",
            "npm run lint",
        ):
            self.assertIn(command, script)
        subprocess.run(["bash", "-n", script_path], check=True)
        package = self.load_json("package.json")
        self.assertEqual(
            package["scripts"]["bootstrap:dylanos"],
            "bash scripts/dylanos/bootstrap_gecko.sh",
        )

    def test_linux_build_scripts_pin_platform_architecture_and_pgo_policy(self):
        script_path = ROOT / "scripts" / "dylanos" / "build_linux.sh"
        self.assertTrue(script_path.is_file())
        script = script_path.read_text(encoding="utf-8")
        for contract in (
            "SURFER_PLATFORM=linux",
            "SURFER_COMPAT=x86_64",
            "ZEN_GA_DISABLE_PGO=1",
            "ZEN_RELEASE=1",
            "DYLANOS_BUILD_JOBS:-1",
            "npm run build",
        ):
            self.assertIn(contract, script)
        subprocess.run(["bash", "-n", script_path], check=True)
        package = self.load_json("package.json")
        self.assertEqual(
            package["scripts"]["build:linux"],
            "bash scripts/dylanos/build_linux.sh",
        )
        self.assertEqual(
            package["scripts"]["smoke:dylanos"],
            "xvfb-run -a -s '-screen 0 1280x800x24' "
            "python3 scripts/dylanos/smoke_browser.py",
        )

    def test_mozconfig_uses_dylanos_identifiers_and_secure_addon_defaults(self):
        mozconfig = (ROOT / "configs" / "common" / "mozconfig").read_text(
            encoding="utf-8"
        )
        for setting in (
            "ac_add_options --with-app-basename=DylanOSBrowser",
            "export MOZ_APP_BASENAME=DylanOSBrowser",
            "ac_add_options --with-distribution-id=org.dylanos.browser",
            "export MOZ_SOURCE_REPO=https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS",
        ):
            with self.subTest(setting=setting):
                self.assertIn(setting, mozconfig)
        self.assertNotIn("--with-unsigned-addon-scopes", mozconfig)
        self.assertNotRegex(
            mozconfig,
            r"(?m)^(?:export|mk_add_options) MOZ_REQUIRE_SIGNING=\s*$",
        )

    def test_product_metadata_never_uses_zen_update_service(self):
        critical_paths = (
            "surfer.json",
            "configs/common/mozconfig",
            "build/AppDir/distribution/policies.json",
            "build/AppDir/zen.desktop",
        )
        for relative_path in critical_paths:
            with self.subTest(path=relative_path):
                text = (ROOT / relative_path).read_text(encoding="utf-8")
                self.assertNotIn("updates.zen-browser.app", text)

    def test_desktop_entry_exposes_dylanos_browser_actions(self):
        desktop = self.load_desktop_entry()
        entry = desktop["Desktop Entry"]
        self.assertEqual(entry["Name"], "DylanOS Browser")
        self.assertEqual(entry["Exec"], "dylanos-browser %U")
        self.assertEqual(entry["Icon"], "dylanos-browser")
        self.assertEqual(entry["StartupWMClass"], "org.dylanos.browser")
        self.assertEqual(entry["Categories"], "Network;WebBrowser;")
        mime_types = set(filter(None, entry["MimeType"].split(";")))
        self.assertTrue(
            {"text/html", "x-scheme-handler/http", "x-scheme-handler/https"}
            <= mime_types
        )
        actions = set(filter(None, entry["Actions"].split(";")))
        self.assertTrue({"new-window", "new-private-window"} <= actions)
        self.assertEqual(
            desktop["Desktop Action new-window"]["Exec"],
            "dylanos-browser --new-window %U",
        )
        self.assertEqual(
            desktop["Desktop Action new-private-window"]["Exec"],
            "dylanos-browser --private-window %U",
        )
        for section in desktop.sections():
            if "Exec" in desktop[section]:
                with self.subTest(section=section):
                    self.assertNotIn("Exec=zen", f"Exec={desktop[section]['Exec']}")

    def test_package_policy_disables_every_internal_update_path(self):
        policies = self.load_json("build/AppDir/distribution/policies.json")["policies"]
        self.assertEqual(
            {key: policies[key] for key in (
                "DisableAppUpdate",
                "AppAutoUpdate",
                "ManualAppUpdateOnly",
                "BackgroundAppUpdate",
            )},
            {
                "DisableAppUpdate": True,
                "AppAutoUpdate": False,
                "ManualAppUpdateOnly": True,
                "BackgroundAppUpdate": False,
            },
        )

    def test_dylanos_preferences_define_only_the_product_contract(self):
        preferences = self.load_product_preferences()
        by_name = {preference["name"]: preference for preference in preferences}
        self.assertEqual(
            set(by_name),
            {
                "dylanos.browser.schema-version",
                "dylanos.browser.follow-system-theme",
                "dylanos.browser.performance-profile",
                "dylanos.browser.crimson-glass.force-opaque",
                "dylanos.browser.accent",
            },
        )
        self.assertEqual(by_name["dylanos.browser.schema-version"]["value"], 1)
        self.assertIs(
            by_name["dylanos.browser.follow-system-theme"]["value"], True
        )
        self.assertEqual(
            by_name["dylanos.browser.performance-profile"]["value"], "balanced"
        )
        self.assertIs(
            by_name["dylanos.browser.crimson-glass.force-opaque"]["value"],
            False,
        )
        self.assertEqual(by_name["dylanos.browser.accent"]["value"], "#E50914")

    def test_effective_overlay_keeps_signatures_and_separate_profile(self):
        patch = (ROOT / "src" / "toolkit" / "moz-configure.patch").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("def require_signing", patch)
        self.assertIn('default="DylanOS"', patch)
        self.assertIn('default="dylanos-browser"', patch)
        self.assertIn('default="org.dylanos.browser"', patch)
        self.assertIn('return "dylanos"', patch)

    def test_overlay_never_bypasses_updater_certificate_validation(self):
        forbidden = (
            "ZEN_SKIP_ALLOWED_CERTIFICATE_CHECK",
            "Skipping the allowed certificate check",
            "override_cert_checks_temp.patch",
        )
        for path in (ROOT / "src").rglob("*"):
            if not path.is_file():
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for value in forbidden:
                with self.subTest(path=path.relative_to(ROOT), value=value):
                    self.assertNotIn(value, text)

    def test_imported_engine_keeps_the_security_contract(self):
        engine = ROOT / "engine"
        if not engine.is_dir():
            self.skipTest("El árbol Gecko se valida después de npm run import")

        moz_configure = (engine / "toolkit" / "moz.configure").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            "return milestone.is_release_or_beta and not milestone.is_esr",
            moz_configure,
        )
        for expected in (
            'default="DylanOS"',
            'default="dylanos-browser"',
            'default="org.dylanos.browser"',
            'return "dylanos"',
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, moz_configure)

        updater_certificates = (
            engine
            / "toolkit"
            / "mozapps"
            / "update"
            / "common"
            / "registrycertificates.cpp"
        ).read_text(encoding="utf-8")
        self.assertNotIn("ZEN_SKIP_ALLOWED_CERTIFICATE_CHECK", updater_certificates)
        self.assertNotIn(
            "Skipping the allowed certificate check", updater_certificates
        )

        moz_build = (engine / "build" / "moz.build").read_text(encoding="utf-8")
        self.assertIn(
            'appini_defines["MOZ_APPUPDATE_HOST"] = "updates.dylanos.invalid"',
            moz_build,
        )

    def test_appimage_launcher_uses_product_binary_and_isolated_profiles(self):
        app_run = (ROOT / "build" / "AppDir" / "AppRun").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("MOZ_LEGACY_PROFILES", app_run)
        self.assertIn('exec "${CURRENTDIR}/dylanos-browser" "$@"', app_run)

    def test_overlay_and_workflows_never_reference_zen_update_infrastructure(self):
        roots = (ROOT / "src", ROOT / "build", ROOT / ".github" / "workflows")
        forbidden = (
            "updates.zen-browser.app",
            "zen-browser/updates-server",
            "zen-browser/windows-binaries",
            "zen-browser/release-utils",
        )
        for root in roots:
            for path in root.rglob("*"):
                if not path.is_file():
                    continue
                try:
                    text = path.read_text(encoding="utf-8")
                except UnicodeDecodeError:
                    continue
                for value in forbidden:
                    with self.subTest(path=path.relative_to(ROOT), value=value):
                        self.assertNotIn(value, text)

    def test_ci_protects_development_with_the_product_contract(self):
        pr_test = (ROOT / ".github" / "workflows" / "pr-test.yml").read_text(
            encoding="utf-8"
        )
        sync = (ROOT / ".github" / "workflows" / "sync-upstream.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("      - development", pr_test)
        self.assertIn(
            "python3 scripts/dylanos/test_product_contract.py -v", pr_test
        )
        self.assertGreaterEqual(
            pr_test.count("python3 scripts/dylanos/test_product_contract.py -v"),
            2,
        )
        self.assertIn("base: development", sync)


if __name__ == "__main__":
    unittest.main()
