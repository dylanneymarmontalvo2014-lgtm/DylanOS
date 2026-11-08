# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.dylanos.check_licenses import validate_repository


MPL_HEADER = """# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
"""


class LicenseGateTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp_dir.name)
        self.git("init", "-b", "development")
        self.git("config", "user.name", "DylanOS Tests")
        self.git("config", "user.email", "tests@dylanos.invalid")
        (self.repo / "README.md").write_text("base\n", encoding="utf-8")
        self.git("add", "README.md")
        self.git("commit", "-m", "base")
        self.base = self.git("rev-parse", "HEAD").stdout.strip()

    def tearDown(self):
        self.temp_dir.cleanup()

    def git(self, *arguments):
        return subprocess.run(
            ["git", *arguments],
            cwd=self.repo,
            check=True,
            capture_output=True,
            text=True,
        )

    def commit_file(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        self.git("add", name)
        self.git("commit", "-m", f"add {name}")

    def test_new_source_without_mpl_header_fails(self):
        self.commit_file("feature.py", "print('sin licencia')\n")
        issues = validate_repository(self.repo, self.base)
        self.assertEqual([issue.path.as_posix() for issue in issues], ["feature.py"])

    def test_new_source_with_mpl_header_passes(self):
        self.commit_file("feature.py", f"{MPL_HEADER}\nprint('ok')\n")
        self.assertEqual(validate_repository(self.repo, self.base), [])

    def test_json_is_excluded_because_it_cannot_carry_comments(self):
        self.commit_file("config.json", '{"enabled": true}\n')
        self.assertEqual(validate_repository(self.repo, self.base), [])

    def test_existing_header_cannot_be_removed(self):
        self.commit_file("feature.py", f"{MPL_HEADER}\nprint('base')\n")
        protected_base = self.git("rev-parse", "HEAD").stdout.strip()
        (self.repo / "feature.py").write_text("print('changed')\n", encoding="utf-8")
        self.git("add", "feature.py")
        self.git("commit", "-m", "remove header")
        issues = validate_repository(self.repo, protected_base)
        self.assertEqual([issue.path.as_posix() for issue in issues], ["feature.py"])

    def test_missing_upstream_ref_uses_integrated_head_snapshot(self):
        self.assertEqual(validate_repository(self.repo), [])


if __name__ == "__main__":
    unittest.main()
