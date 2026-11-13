"""Pruebas del scaffold Debian de DylanOS Browser.

Estas pruebas describen el contrato de empaquetado sin fabricar ni ejecutar un
binario del navegador. El binario candidato debe producirse desde
`apps/dylanos-browser`.
"""

from configparser import ConfigParser
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
BROWSER = ROOT / "apps" / "dylanos-browser"
DEBIAN = BROWSER / "debian"


def parse_deb822(path):
    paragraphs = []
    current = {}
    field = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if not line:
            if current:
                paragraphs.append(current)
                current = {}
                field = None
            continue
        if line[:1].isspace() and field:
            current[field] += "\n" + line.strip()
            continue
        name, separator, value = line.partition(":")
        if not separator:
            raise AssertionError(f"Línea Debian inválida: {raw_line!r}")
        field = name
        current[field] = value.strip()
    if current:
        paragraphs.append(current)
    return paragraphs


class BrowserDebianPackageTest(unittest.TestCase):
    def test_control_declares_a_coexisting_amd64_browser_package(self):
        control_path = DEBIAN / "control"
        self.assertTrue(control_path.is_file(), f"Falta {control_path}")
        control = parse_deb822(control_path)
        self.assertGreaterEqual(len(control), 2)
        source, binary = control[0], control[1]

        self.assertEqual(source["Source"], "dylanos-browser")
        changelog = (DEBIAN / "changelog").read_text(encoding="utf-8").splitlines()[0]
        self.assertTrue(changelog.startswith("dylanos-browser (1.0.0"))
        self.assertEqual(binary["Package"], "dylanos-browser")
        self.assertEqual(binary["Architecture"], "amd64")
        self.assertIn("${shlibs:Depends}", binary["Depends"])
        self.assertIn("${misc:Depends}", binary["Depends"])
        self.assertIn("www-browser", binary["Provides"])
        self.assertNotIn("Conflicts", binary)
        self.assertNotIn("Replaces", binary)
        self.assertNotIn("alongside Firefox", binary["Description"])

    def test_rules_is_executable_and_exposes_a_dh_build_entrypoint(self):
        rules = DEBIAN / "rules"
        self.assertTrue(rules.is_file())
        self.assertTrue(rules.stat().st_mode & stat.S_IXUSR)
        self.assertTrue(rules.read_text(encoding="utf-8").startswith("#!/usr/bin/make -f\n"))

        result = subprocess.run(
            ["make", "--just-print", "-f", str(rules), "binary"],
            cwd=BROWSER,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("dh binary", result.stdout)

    def test_rules_blocks_packaging_without_the_real_candidate_binary(self):
        rules = DEBIAN / "rules"
        self.assertTrue(rules.is_file(), f"Falta {rules}")
        with tempfile.TemporaryDirectory() as temporary:
            missing = Path(temporary) / "package"
            result = subprocess.run(
                [
                    "make",
                    "-f",
                    str(DEBIAN / "rules"),
                    "check-browser-artifact",
                    f"BROWSER_ARTIFACT={missing}",
                ],
                cwd=BROWSER,
                check=False,
                capture_output=True,
                text=True,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("real", result.stderr.lower())
        self.assertIn("dylanos-browser", result.stderr)

    def test_rules_verify_the_complete_candidate_payload_manifest(self):
        rules = (DEBIAN / "rules").read_text(encoding="utf-8")
        self.assertIn("package_payload.py verify", rules)
        self.assertIn('"$(BROWSER_ARTIFACT)"', rules)

    def test_candidate_build_prepares_the_debian_payload(self):
        build_script = (
            BROWSER / "scripts" / "dylanos" / "build_linux.sh"
        ).read_text(encoding="utf-8")
        self.assertIn("package_payload.py", build_script)
        self.assertIn("artifacts/phase-2/package", build_script)
        self.assertIn('if test "$dylanos_mode" = candidate', build_script)

    def test_install_manifest_names_only_real_payload_and_package_metadata(self):
        install = DEBIAN / "dylanos-browser.install"
        self.assertTrue(install.is_file(), f"Falta {install}")
        entries = [line.split() for line in install.read_text(encoding="utf-8").splitlines() if line.strip()]
        destinations = {parts[0]: parts[1] for parts in entries}
        sources = set(destinations)

        self.assertIn("artifacts/phase-2/package/usr/bin/dylanos-browser", sources)
        self.assertIn("artifacts/phase-2/package/usr/lib/dylanos-browser", sources)
        self.assertIn("artifacts/phase-2/package/payload-manifest.json", sources)
        self.assertIn("debian/policies.json", sources)
        self.assertEqual(
            destinations["debian/policies.json"],
            "usr/lib/dylanos-browser/distribution",
        )
        self.assertIn("debian/org.dylanos.browser.desktop", sources)
        self.assertIn("debian/dylanos-browser.svg", sources)
        self.assertNotIn("usr/bin/firefox", sources)
        self.assertNotIn("fake", " ".join(sources).lower())

    def test_package_ships_mpl_copyright_metadata(self):
        copyright_path = DEBIAN / "copyright"
        self.assertTrue(copyright_path.is_file(), f"Falta {copyright_path}")
        copyright_text = copyright_path.read_text(encoding="utf-8")
        self.assertIn("License: MPL-2.0", copyright_text)
        self.assertIn("https://www.mozilla.org/MPL/2.0/", copyright_text)

    def test_icon_is_a_dylanos_brand_asset(self):
        icon = (DEBIAN / "dylanos-browser.svg").read_text(encoding="utf-8")
        self.assertIn('<title id="title">DylanOS Browser</title>', icon)
        self.assertIn("#DC143C", icon)
        self.assertIn("#0A0A0A", icon)
        self.assertNotIn("#e50914", icon)

    def test_desktop_entry_declares_identity_mimes_actions_and_no_updater(self):
        desktop_path = DEBIAN / "org.dylanos.browser.desktop"
        self.assertTrue(desktop_path.is_file(), f"Falta {desktop_path}")
        desktop = ConfigParser(interpolation=None, delimiters=("="), comment_prefixes=("#",))
        desktop.optionxform = str
        desktop.read(desktop_path, encoding="utf-8")

        entry = desktop["Desktop Entry"]
        self.assertEqual(entry["Type"], "Application")
        self.assertEqual(entry["Name"], "DylanOS Browser")
        self.assertEqual(entry["Exec"], "dylanos-browser %U")
        self.assertEqual(entry["Icon"], "dylanos-browser")
        self.assertEqual(entry["StartupWMClass"], "org.dylanos.browser")
        self.assertEqual(entry["GenericName"], "Navegador web")
        self.assertIn("Network;", entry["Categories"])
        self.assertIn("WebBrowser;", entry["Categories"])
        for mime in (
            "text/html;",
            "application/xhtml+xml;",
            "x-scheme-handler/http;",
            "x-scheme-handler/https;",
        ):
            self.assertIn(mime, entry["MimeType"])

        actions = {action for action in entry["Actions"].split(";") if action}
        self.assertEqual(actions, {"new-window", "private-window"})
        self.assertEqual(desktop["Desktop Action new-window"]["Exec"], "dylanos-browser")
        self.assertEqual(desktop["Desktop Action new-window"]["Name"], "Nueva ventana")
        self.assertEqual(
            desktop["Desktop Action private-window"]["Exec"],
            "dylanos-browser --private-window",
        )
        self.assertEqual(
            desktop["Desktop Action private-window"]["Name"],
            "Nueva ventana privada",
        )
        self.assertNotIn("update", " ".join(entry.values()).lower())


if __name__ == "__main__":
    unittest.main()
