"""Exercise the DylanOS SDDM theme with the real greeter."""
import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "themes/sddm/DylanOS-Crimson"


class SddmThemeTest(unittest.TestCase):
    def test_greeter_loads_theme_without_fallback(self):
        greeter = shutil.which("sddm-greeter")
        if greeter is None:
            self.skipTest("sddm-greeter is not installed")

        environment = os.environ.copy()
        environment["QT_QPA_PLATFORM"] = "offscreen"
        environment["QT_QUICK_BACKEND"] = "software"
        process = subprocess.Popen(
            [greeter, "--test-mode", "--theme", str(THEME)],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=environment,
        )
        try:
            try:
                output, _ = process.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                process.terminate()
                output, _ = process.communicate(timeout=5)
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate(timeout=5)

        self.assertIn(f"Loading {THEME.as_uri()}/Main.qml", output)
        self.assertNotIn("Fallback to embedded theme", output)
        self.assertNotIn("Library import requires a version", output)


if __name__ == "__main__":
    unittest.main()
