# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "dylanos" / "package_payload.py"
SOURCE_COMMIT = "a" * 40


def load_payload_module():
    spec = importlib.util.spec_from_file_location("dylanos_package_payload", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PackagePayloadTests(unittest.TestCase):
    def make_dist(self, root, *, remoting_name="dylanos-browser"):
        dist = root / "dist"
        dist.mkdir()
        binary = dist / "dylanos-browser"
        binary.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        binary.chmod(0o755)
        (dist / "application.ini").write_text(
            "[App]\n"
            "Vendor=DylanOS\n"
            "Name=DylanOSBrowser\n"
            f"RemotingName={remoting_name}\n"
            "CodeName=DylanOS Browser\n"
            "Profile=dylanos-browser\n",
            encoding="utf-8",
        )
        (dist / "omni.ja").write_bytes(b"runtime")
        (dist / "dylanos-link").symlink_to("omni.ja")
        return dist

    def run_cli(self, *arguments):
        return subprocess.run(
            ["python3", str(SCRIPT), *map(str, arguments)],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

    def test_prepare_creates_deterministic_verified_candidate_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dist = self.make_dist(root)
            first = root / "first"
            second = root / "second"

            for output in (first, second):
                result = self.run_cli(
                    "prepare",
                    "--dist",
                    dist,
                    "--output",
                    output,
                    "--source-commit",
                    SOURCE_COMMIT,
                )
                self.assertEqual(result.returncode, 0, result.stderr)

            first_manifest = (first / "payload-manifest.json").read_bytes()
            second_manifest = (second / "payload-manifest.json").read_bytes()
            self.assertEqual(first_manifest, second_manifest)
            manifest = json.loads(first_manifest)
            self.assertEqual(manifest["mode"], "candidate")
            self.assertEqual(manifest["source_commit"], SOURCE_COMMIT)
            self.assertEqual(manifest["desktop_id"], "org.dylanos.browser.desktop")
            self.assertIn("usr/bin/dylanos-browser", manifest["files"])
            self.assertIn(
                "usr/lib/dylanos-browser/application.ini", manifest["files"]
            )
            wrapper = first / "usr/bin/dylanos-browser"
            self.assertTrue(os.access(wrapper, os.X_OK))
            self.assertIn(
                'exec /usr/lib/dylanos-browser/dylanos-browser "$@"',
                wrapper.read_text(encoding="utf-8"),
            )

            verified = self.run_cli("verify", "--payload", first)
            self.assertEqual(verified.returncode, 0, verified.stderr)

    def test_verify_rejects_a_tampered_runtime_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = root / "payload"
            prepared = self.run_cli(
                "prepare",
                "--dist",
                self.make_dist(root),
                "--output",
                payload,
                "--source-commit",
                SOURCE_COMMIT,
            )
            self.assertEqual(prepared.returncode, 0, prepared.stderr)
            (payload / "usr/lib/dylanos-browser/omni.ja").write_bytes(b"alterado")

            verified = self.run_cli("verify", "--payload", payload)

            self.assertNotEqual(verified.returncode, 0)
            self.assertIn("SHA-256", verified.stderr)

    def test_prepare_rejects_a_non_dylanos_product_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            result = self.run_cli(
                "prepare",
                "--dist",
                self.make_dist(root, remoting_name="zen"),
                "--output",
                root / "payload",
                "--source-commit",
                SOURCE_COMMIT,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("RemotingName", result.stderr)

    def test_prepare_rejects_an_output_nested_inside_the_runtime(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dist = self.make_dist(root)

            result = self.run_cli(
                "prepare",
                "--dist",
                dist,
                "--output",
                dist / "payload",
                "--source-commit",
                SOURCE_COMMIT,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("independiente", result.stderr)
            self.assertTrue((dist / "dylanos-browser").is_file())

    def test_verify_rejects_a_manifest_with_a_different_binary_path(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = root / "payload"
            prepared = self.run_cli(
                "prepare",
                "--dist",
                self.make_dist(root),
                "--output",
                payload,
                "--source-commit",
                SOURCE_COMMIT,
            )
            self.assertEqual(prepared.returncode, 0, prepared.stderr)
            manifest_path = payload / "payload-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["binary"] = "usr/lib/dylanos-browser/otro-binario"
            manifest_path.write_text(
                f"{json.dumps(manifest, indent=2, sort_keys=True)}\n",
                encoding="utf-8",
            )

            verified = self.run_cli("verify", "--payload", payload)

            self.assertNotEqual(verified.returncode, 0)
            self.assertIn("binario", verified.stderr.lower())

    def test_prepare_materializes_external_absolute_and_relative_symlinks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dist = self.make_dist(root)
            external = root / "external-runtime"
            external.mkdir()
            (external / "absolute.dat").write_bytes(b"absolute")
            (external / "relative.dat").write_bytes(b"relative")
            (dist / "absolute-link").symlink_to(
                external / "absolute.dat"
            )
            (dist / "relative-link").symlink_to(
                Path("../external-runtime/relative.dat")
            )
            payload = root / "payload"

            prepared = self.run_cli(
                "prepare",
                "--dist",
                dist,
                "--output",
                payload,
                "--source-commit",
                SOURCE_COMMIT,
            )

            self.assertEqual(prepared.returncode, 0, prepared.stderr)
            runtime = payload / "usr/lib/dylanos-browser"
            for name, contents in (
                ("absolute-link", b"absolute"),
                ("relative-link", b"relative"),
            ):
                copied = runtime / name
                self.assertTrue(copied.is_file())
                self.assertFalse(copied.is_symlink())
                self.assertEqual(copied.read_bytes(), contents)

    def test_prepare_rejects_a_dangling_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dist = self.make_dist(root)
            (dist / "missing-link").symlink_to("missing-target")

            prepared = self.run_cli(
                "prepare",
                "--dist",
                dist,
                "--output",
                root / "payload",
                "--source-commit",
                SOURCE_COMMIT,
            )

            self.assertNotEqual(prepared.returncode, 0)
            self.assertIn("enlace", prepared.stderr.lower())

    def test_verify_inventories_directory_symlinks_and_rejects_target_changes(self):
        module = load_payload_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = root / "payload"
            prepared = self.run_cli(
                "prepare",
                "--dist",
                self.make_dist(root),
                "--output",
                payload,
                "--source-commit",
                SOURCE_COMMIT,
            )
            self.assertEqual(prepared.returncode, 0, prepared.stderr)
            runtime = payload / "usr/lib/dylanos-browser"
            (runtime / "first-directory").mkdir()
            (runtime / "second-directory").mkdir()
            directory_link = runtime / "directory-link"
            directory_link.symlink_to("first-directory", target_is_directory=True)
            manifest_path = payload / "payload-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["files"] = module.file_inventory(payload)
            manifest_path.write_text(
                f"{json.dumps(manifest, indent=2, sort_keys=True)}\n",
                encoding="utf-8",
            )

            verified = self.run_cli("verify", "--payload", payload)
            self.assertEqual(verified.returncode, 0, verified.stderr)
            self.assertEqual(
                manifest["files"][
                    "usr/lib/dylanos-browser/directory-link"
                ],
                {"type": "symlink", "target": "first-directory"},
            )

            directory_link.unlink()
            directory_link.symlink_to("second-directory", target_is_directory=True)
            changed = self.run_cli("verify", "--payload", payload)

            self.assertNotEqual(changed.returncode, 0)
            self.assertIn("metadatos", changed.stderr.lower())

    def test_verify_rejects_external_and_dangling_payload_symlinks(self):
        module = load_payload_module()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            payload = root / "payload"
            prepared = self.run_cli(
                "prepare",
                "--dist",
                self.make_dist(root),
                "--output",
                payload,
                "--source-commit",
                SOURCE_COMMIT,
            )
            self.assertEqual(prepared.returncode, 0, prepared.stderr)
            runtime = payload / "usr/lib/dylanos-browser"
            for target in (root / "outside", runtime / "missing"):
                with self.subTest(target=target):
                    link = runtime / "unsafe-link"
                    try:
                        link.symlink_to(target)
                        with self.assertRaisesRegex(ValueError, "Enlace"):
                            module.file_inventory(payload)
                    finally:
                        link.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
