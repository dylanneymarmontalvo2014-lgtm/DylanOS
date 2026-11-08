# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import hashlib
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace

from scripts.dylanos.write_build_artifact import collect_build_artifact


class BuildArtifactTests(unittest.TestCase):
    def test_manifest_records_mode_duration_size_and_hashes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            binary = root / "dylanos-browser"
            mozconfig = root / "mozconfig"
            log = root / "build.log"
            binary.write_bytes(b"real-browser-binary")
            mozconfig.write_text("ac_add_options --disable-debug\n", encoding="utf-8")
            log.write_text("Build succeeded\n", encoding="utf-8")

            def runner(_command, **_kwargs):
                return SimpleNamespace(returncode=0, stdout="b" * 40 + "\n", stderr="")

            manifest = collect_build_artifact(
                mode="diagnostic",
                binary=binary,
                mozconfig=mozconfig,
                log=log,
                elapsed_seconds=83,
                runner=runner,
                root=root,
                now=lambda: datetime(2026, 11, 7, 1, 2, tzinfo=timezone.utc),
            )
            self.assertEqual(manifest["mode"], "diagnostic")
            self.assertEqual(manifest["elapsed_seconds"], 83)
            self.assertEqual(manifest["binary"]["size_bytes"], 19)
            self.assertEqual(
                manifest["binary"]["sha256"],
                hashlib.sha256(b"real-browser-binary").hexdigest(),
            )
            self.assertEqual(manifest["source_commit"], "b" * 40)
            self.assertEqual(manifest["schema_version"], 1)


if __name__ == "__main__":
    unittest.main()
