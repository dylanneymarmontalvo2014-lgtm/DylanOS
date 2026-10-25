import os
import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class BuildEntrypointTest(unittest.TestCase):
    def test_build_script_can_be_invoked_directly(self):
        self.assertTrue(os.access(ROOT / "scripts/build.sh", os.X_OK))

    def test_version_argument_is_validated_before_build_side_effects(self):
        result = subprocess.run(
            ["bash", "scripts/build.sh", "--version=not-a-version"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(2, result.returncode)
        self.assertIn("Versión DylanOS inválida", result.stderr)
        self.assertNotIn("npm error", result.stdout + result.stderr)

    def test_external_build_rejects_root_before_running_npm(self):
        command = ["bash", "scripts/build.sh"]
        if os.geteuid() != 0:
            if shutil.which("sudo") is None:
                self.skipTest("sudo no está disponible")
            probe = subprocess.run(
                ["sudo", "-n", "true"], capture_output=True, text=True, check=False
            )
            if probe.returncode != 0:
                self.skipTest("sudo sin interacción no está disponible")
            command = ["sudo", "-n", *command]

        result = subprocess.run(
            command,
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(2, result.returncode)
        self.assertIn("No ejecutes scripts/build.sh con sudo", result.stderr)
        self.assertNotIn("npm error", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
