"""Desktop-entry Exec fields remain argv, never shell programs."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "apps/dylanos-spotlight"))
from exec_utils import desktop_exec_argv
from calculator import safe_calculate


class SpotlightCalculatorTest(unittest.TestCase):
    def test_basic_arithmetic_and_caret_power(self):
        self.assertEqual(safe_calculate("2 + 3 * 4"), 14)
        self.assertEqual(safe_calculate("2^3"), 8)
        self.assertEqual(safe_calculate("-5 / 2"), -2.5)

    def test_rejects_unbounded_exponent_before_computing(self):
        with self.assertRaisesRegex(ValueError, "exponente"):
            safe_calculate("9**99999999")

    def test_rejects_result_outside_supported_range(self):
        with self.assertRaisesRegex(ValueError, "rango"):
            safe_calculate("99**100")

    def test_rejects_python_constructs_and_overlong_input(self):
        for expression in ("__import__('os')", "(1, 2)", "9" * 129):
            with self.subTest(expression=expression[:20]):
                with self.assertRaises((ValueError, SyntaxError)):
                    safe_calculate(expression)

    def test_rejects_division_by_zero(self):
        with self.assertRaises(ZeroDivisionError):
            safe_calculate("1/0")


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
