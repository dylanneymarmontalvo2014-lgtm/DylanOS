# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import json
import shutil
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace

from scripts.dylanos.write_build_manifest import build_manifest, write_manifest


GIB = 1024**3


class BuildManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        (self.root / "dylanos").mkdir()
        (self.root / "dylanos" / "upstream.json").write_text(
            json.dumps(
                {
                    "repository": "https://github.com/zen-browser/desktop.git",
                    "tag": "1.24b",
                    "commit": "f75390aa2b797ddc3524ff9ed52ceb32a839f9fa",
                    "firefox_version": "159.0",
                    "audit_date": "2026-11-02",
                }
            ),
            encoding="utf-8",
        )
        (self.root / "package-lock.json").write_text(
            json.dumps(
                {
                    "packages": {
                        "node_modules/@zen-browser/surfer": {"version": "1.14.9"}
                    }
                }
            ),
            encoding="utf-8",
        )
        self.outputs = {
            ("git", "rev-parse", "HEAD"): "a" * 40,
            ("node", "--version"): "v22.23.2",
            ("npm", "--version"): "10.9.8",
            ("python3", "--version"): "Python 3.12.3",
            ("rustc", "--version"): "rustc 1.95.0 (example)",
            ("cargo", "--version"): "cargo 1.95.0 (example)",
            ("/toolchain/clang", "--version"): "clang version 21.1.0",
        }

    def tearDown(self):
        self.temp_dir.cleanup()

    def runner(self, command, **_kwargs):
        output = self.outputs[tuple(command)]
        return SimpleNamespace(returncode=0, stdout=f"{output}\n", stderr="")

    def which(self, command):
        if command == "clang":
            return "/toolchain/clang"
        return f"/usr/bin/{command}"

    def disk_usage(self, _path):
        return shutil._ntuple_diskusage(80 * GIB, 36 * GIB, 44 * GIB)

    def test_manifest_records_pinned_source_and_tool_versions(self):
        manifest = build_manifest(
            self.root,
            runner=self.runner,
            which=self.which,
            disk_usage=self.disk_usage,
            now=lambda: datetime(2026, 11, 6, 12, 0, tzinfo=timezone.utc),
        )
        self.assertEqual(manifest["schema_version"], 1)
        self.assertEqual(manifest["generated_at"], "2026-11-06T12:00:00+00:00")
        self.assertEqual(manifest["source"]["firefox_version"], "159.0")
        self.assertEqual(manifest["source"]["zen_tag"], "1.24b")
        self.assertEqual(manifest["source"]["dylanos_browser_commit"], "a" * 40)
        self.assertEqual(manifest["tools"]["node"], "v22.23.2")
        self.assertEqual(manifest["tools"]["rustc"], "rustc 1.95.0 (example)")
        self.assertEqual(manifest["tools"]["clang"], "clang version 21.1.0")
        self.assertEqual(manifest["tools"]["surfer"], "1.14.9")
        self.assertEqual(manifest["disk"]["free_gib"], 44.0)

    def test_writer_creates_parent_and_valid_json(self):
        output = self.root / "artifacts" / "bootstrap" / "environment.json"
        write_manifest(output, {"schema_version": 1, "tools": {"node": "v22"}})
        self.assertEqual(
            json.loads(output.read_text(encoding="utf-8")),
            {"schema_version": 1, "tools": {"node": "v22"}},
        )


if __name__ == "__main__":
    unittest.main()
