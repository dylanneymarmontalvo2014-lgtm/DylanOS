"""Offline contract and mocked integration tests for the DylanOS Process preview script."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/test-process-visual.sh"


class ProcessVisualScriptTests(unittest.TestCase):
    def test_shell_syntax_and_help_are_available_without_building(self):
        subprocess.run(["bash", "-n", str(SCRIPT)], check=True)
        result = subprocess.run(["bash", str(SCRIPT), "--help"], text=True, capture_output=True, check=True)
        self.assertIn("No construye una ISO", result.stdout)
        self.assertIn("--screenshot RUTA", result.stdout)

    def test_script_builds_and_installs_only_the_app(self):
        script = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('"$CMAKE" -S "$ROOT/apps/dylanos-process"', script)
        self.assertIn('"$CMAKE" --build "$BUILD_DIR"', script)
        self.assertIn('"$CMAKE" --install "$BUILD_DIR"', script)
        self.assertNotIn("scripts/build.sh", script)
        self.assertNotIn("scripts/iso.sh", script)
        self.assertNotIn("make iso", script)

    def test_build_only_uses_mocked_cmake_and_never_launches_gui(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp = Path(temporary)
            bindir = tmp / "bin"
            bindir.mkdir()
            log = tmp / "calls.log"
            cmake = bindir / "cmake"
            cmake.write_text(
                "#!/usr/bin/env bash\nprintf '%s\\n' \"$*\" >> \"$MOCK_LOG\"\n",
                encoding="utf-8",
            )
            cmake.chmod(0o755)
            ninja = bindir / "ninja"
            ninja.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
            ninja.chmod(0o755)
            prefix = tmp / "prefix"
            env = os.environ | {
                "PATH": f"{bindir}:{os.environ['PATH']}",
                "MOCK_LOG": str(log),
                "DYLANOS_CMAKE": str(cmake),
                "DYLANOS_PROCESS_INSTALL_PREFIX": str(prefix),
                "DYLANOS_PROCESS_BUILD_DIR": str(tmp / "build"),
            }
            subprocess.run(["bash", str(SCRIPT), "--build-only"], env=env, check=True, text=True, capture_output=True)
            calls = log.read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(calls), 3)
            self.assertIn("apps/dylanos-process", calls[0])
            self.assertIn("--build", calls[1])
            self.assertIn("--install", calls[2])
            self.assertIn(str(prefix), calls[0])

    def test_screenshot_launches_target_page_and_captures_window(self):
        with tempfile.TemporaryDirectory() as temporary:
            tmp = Path(temporary)
            bindir = tmp / "bin"
            bindir.mkdir()
            calls = tmp / "calls.log"
            app = tmp / "dylanos-process"
            app.write_text(
                "#!/usr/bin/env bash\nprintf 'app:%s\\n' \"$*\" >> \"$MOCK_LOG\"\n",
                encoding="utf-8",
            )
            app.chmod(0o755)
            dbus = bindir / "dbus-run-session"
            dbus.write_text(
                "#!/usr/bin/env bash\nshift\nexec \"$@\"\n", encoding="utf-8"
            )
            dbus.chmod(0o755)
            xdotool = bindir / "xdotool"
            xdotool.write_text(
                "#!/usr/bin/env bash\n"
                "printf 'xdotool:%s\\n' \"$*\" >> \"$MOCK_LOG\"\n"
                "[[ \"$1\" == search ]] && { printf '987\\n'; exit 0; }\n"
                "exit 0\n",
                encoding="utf-8",
            )
            xdotool.chmod(0o755)
            capture = bindir / "import"
            capture.write_text(
                "#!/usr/bin/env bash\n"
                "printf 'capture:%s\\n' \"$*\" >> \"$MOCK_LOG\"\n"
                "printf 'fake png' > \"${@: -1}\"\n",
                encoding="utf-8",
            )
            capture.chmod(0o755)
            screenshot = tmp / "preview.png"
            env = os.environ | {
                "PATH": f"{bindir}:{os.environ['PATH']}",
                "MOCK_LOG": str(calls),
                "DYLANOS_PROCESS_BINARY": str(app),
                "DYLANOS_PROCESS_VISUAL_DIR": str(tmp / "visual"),
                "DISPLAY": ":99",
            }
            subprocess.run(
                ["bash", str(SCRIPT), "--no-build", "--capture-delay", "0", "--screenshot", str(screenshot)],
                env=env,
                check=True,
                text=True,
                capture_output=True,
                timeout=15,
            )
            self.assertTrue(screenshot.is_file())
            output = calls.read_text(encoding="utf-8")
            self.assertIn("app:--page processes", output)
            self.assertIn("xdotool:windowactivate --sync 987", output)
            self.assertIn(f"capture:-window 987 {screenshot}", output)

    def test_build_only_and_no_build_are_rejected_together(self):
        result = subprocess.run(
            ["bash", str(SCRIPT), "--build-only", "--no-build"],
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("incompatibles", result.stderr)


if __name__ == "__main__":
    unittest.main()
