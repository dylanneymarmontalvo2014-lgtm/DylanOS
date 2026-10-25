"""Desktop-entry Exec fields remain argv, never shell programs."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "apps/dylanos-spotlight"))
from exec_utils import desktop_exec_argv


class DesktopExecTest(unittest.TestCase):
    def test_quoted_arguments_and_file_field_codes(self):
        self.assertEqual(
            desktop_exec_argv('viewer --title "My image" %f'),
            ["viewer", "--title", "My image"],
        )

    def test_shell_metacharacters_are_literal_arguments(self):
        # Exec is not shell syntax: command separators must not be interpreted.
        self.assertEqual(
            desktop_exec_argv('viewer; touch /tmp/spotlight-injected'),
            ["viewer;", "touch", "/tmp/spotlight-injected"],
        )

    def test_invalid_quoting_is_rejected(self):
        with self.assertRaises(ValueError):
            desktop_exec_argv('viewer "unterminated')


if __name__ == "__main__":
    unittest.main()
