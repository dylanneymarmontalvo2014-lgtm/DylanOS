"""Regression tests for building the installer outside checkout node_modules."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/build-installer.sh"


class InstallerBuildIsolationTest(unittest.TestCase):
    def test_npm_runs_in_private_copy_and_writes_requested_dist(self):
        app = ROOT / "installer/dylanos-installer"
        self.assertTrue((app / "package.json").is_file())
        with tempfile.TemporaryDirectory() as folder:
            tmp = Path(folder)
            fake_bin = tmp / "bin"
            fake_bin.mkdir()
            npm_log = tmp / "npm-cwd.log"
            fake_node = fake_bin / "node"
            fake_node.write_text("#!/bin/sh\nprintf 'v22.12.0\\n'\n", encoding="utf-8")
            fake_node.chmod(0o755)
            fake_npm = fake_bin / "npm"
            fake_npm.write_text(
                "#!/bin/sh\n"
                "printf '%s\\n' \"$PWD\" >> \"$DYLANOS_TEST_NPM_LOG\"\n"
                "case \"$1\" in\n"
                "  ci) mkdir -p node_modules/.bin; printf test > node_modules/.bin/jiti ;;\n"
                "  run)\n"
                "    shift 2\n"
                "    while [ $# -gt 0 ]; do\n"
                "      if [ \"$1\" = --outDir ]; then out=$2; shift 2; else shift; fi\n"
                "    done\n"
                "    mkdir -p \"$out\"; printf '<html>built</html>\\n' > \"$out/index.html\" ;;\n"
                "  *) exit 90 ;;\n"
                "esac\n",
                encoding="utf-8",
            )
            fake_npm.chmod(0o755)
            output = tmp / "dist"
            env = os.environ.copy()
            env.update(
                PATH=f"{fake_bin}:{env.get('PATH', '')}",
                TMPDIR=str(tmp),
                DYLANOS_INSTALLER_DIST=str(output),
                DYLANOS_TEST_NPM_LOG=str(npm_log),
            )
            result = subprocess.run(
                ["bash", str(SCRIPT)], cwd=ROOT, env=env,
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            npm_cwds = npm_log.read_text(encoding="utf-8").splitlines()
            self.assertEqual(2, len(npm_cwds), "npm ci and npm run build should both run")
            self.assertEqual(npm_cwds[0], npm_cwds[1])
            self.assertNotEqual(Path(npm_cwds[0]).resolve(), app.resolve())
            Path(npm_cwds[0]).resolve().relative_to(tmp.resolve())
            self.assertTrue((output / "index.html").is_file())
            self.assertEqual((output / "index.html").read_text(encoding="utf-8"),
                             "<html>built</html>\n")


if __name__ == "__main__":
    unittest.main()
