# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import shutil
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from scripts.dylanos.check_build_environment import check_environment


GIB = 1024**3


class BuildEnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        (self.root / ".nvmrc").write_text("22\n", encoding="utf-8")
        (self.root / "rust-toolchain.toml").write_text(
            '[toolchain]\nchannel = "1.95.0"\n', encoding="utf-8"
        )
        self.outputs = {
            "node": "v22.23.2\n",
            "python3": "Python 3.12.3\n",
            "rustc": "rustc 1.95.0 (59807616e 2026-04-14)\n",
        }
        self.commands = {
            "git",
            "npm",
            "cargo",
            "rustc",
            "cmake",
            "ninja",
            "pkg-config",
            "tar",
            "xz",
            "make",
            "python3",
        }

    def tearDown(self):
        self.temp_dir.cleanup()

    def runner(self, command, **_kwargs):
        return SimpleNamespace(
            returncode=0,
            stdout=self.outputs[command[0]],
            stderr="",
        )

    def which(self, command):
        return f"/usr/bin/{command}" if command in self.commands else None

    def disk_usage(self, _path):
        return shutil._ntuple_diskusage(80 * GIB, 40 * GIB, 40 * GIB)

    def memory_info(self):
        return 8 * GIB, 8 * GIB

    def checks(self, **overrides):
        arguments = {
            "runner": self.runner,
            "which": self.which,
            "disk_usage": self.disk_usage,
            "memory_info": self.memory_info,
            "min_free_gib": 30,
        }
        arguments.update(overrides)
        return check_environment(self.root, **arguments)

    def test_supported_environment_passes_every_check(self):
        failures = [check for check in self.checks() if not check.ok]
        self.assertEqual(failures, [])

    def test_wrong_node_major_fails_with_expected_version(self):
        self.outputs["node"] = "v20.19.0\n"
        failures = [check.detail for check in self.checks() if not check.ok]
        self.assertTrue(any("Node.js 22" in detail for detail in failures))

    def test_wrong_rust_toolchain_fails(self):
        self.outputs["rustc"] = "rustc 1.94.0 (example)\n"
        failures = [check.detail for check in self.checks() if not check.ok]
        self.assertTrue(any("Rust 1.95.0" in detail for detail in failures))

    def test_insufficient_space_fails(self):
        def disk_usage(_path):
            return shutil._ntuple_diskusage(80 * GIB, 51 * GIB, 29 * GIB)

        failures = [
            check.detail
            for check in self.checks(disk_usage=disk_usage)
            if not check.ok
        ]
        self.assertTrue(any("30 GiB" in detail for detail in failures))

    def test_insufficient_combined_memory_and_swap_fails(self):
        failures = [
            check.detail
            for check in self.checks(memory_info=lambda: (8 * GIB, 2 * GIB))
            if not check.ok
        ]
        self.assertTrue(any("16 GiB" in detail for detail in failures))

    def test_missing_required_tool_fails(self):
        self.commands.remove("ninja")
        failures = [check.detail for check in self.checks() if not check.ok]
        self.assertTrue(any("ninja" in detail for detail in failures))


if __name__ == "__main__":
    unittest.main()
