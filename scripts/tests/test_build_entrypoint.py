import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class BuildEntrypointTest(unittest.TestCase):
    def test_build_and_setup_entrypoints_can_be_invoked_directly(self):
        for script in (
            "init.sh",
            "scripts/build.sh",
            "scripts/check.sh",
            "scripts/test-build-host.sh",
            "scripts/iso.sh",
            "scripts/test.sh",
        ):
            with self.subTest(script=script):
                self.assertTrue(os.access(ROOT / script, os.X_OK), f"{script} debe tener modo ejecutable en Git")

    def test_build_and_iso_use_a_shared_lock_outside_work(self):
        build = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
        iso = (ROOT / "scripts/iso.sh").read_text(encoding="utf-8")
        helper = (ROOT / "scripts/lib/lock.sh").read_text(encoding="utf-8")
        self.assertIn('source=scripts/lib/lock.sh', build)
        self.assertIn('source=scripts/lib/lock.sh', iso)
        self.assertIn('dylanos_acquire_build_lock "$ROOT"', build)
        self.assertIn('dylanos_acquire_build_lock "$ROOT"', iso)
        self.assertIn('${TMPDIR:-/tmp}/dylanos-build-', helper)
        self.assertIn('exec 9< "$lock_file"', helper)
        self.assertNotIn('"$WORK/build.lock"', build + iso)

    def test_build_lock_is_shared_and_stored_outside_work(self):
        helper = ROOT / "scripts/lib/lock.sh"
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            (repo / "work").mkdir(parents=True)
            env = {**os.environ, "TMPDIR": tmp}
            holder = subprocess.Popen(
                ["bash", "-c", f'source "{helper}"; dylanos_acquire_build_lock "{repo}"; echo LOCKED; while :; do sleep 1; done'],
                cwd=ROOT,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                self.assertEqual("LOCKED", holder.stdout.readline().strip())
                contender = subprocess.run(
                    ["bash", "-c", f'set -e; source "{helper}"; dylanos_acquire_build_lock "{repo}" "build busy"'],
                    cwd=ROOT,
                    env=env,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertNotEqual(0, contender.returncode)
                self.assertIn("build busy", contender.stderr)
                self.assertEqual([], list((repo / "work").iterdir()))
                self.assertTrue(list(Path(tmp).glob("dylanos-build-*.lock")))
            finally:
                holder.terminate()
                holder.wait(timeout=5)
                if holder.stdout:
                    holder.stdout.close()
                if holder.stderr:
                    holder.stderr.close()

    def test_iso_preserves_tmpdir_when_escalating(self):
        iso = (ROOT / "scripts/iso.sh").read_text(encoding="utf-8")
        self.assertIn('TMPDIR="${TMPDIR:-/tmp}"', iso.splitlines()[7])

    def test_build_lock_can_open_existing_read_only_root_style_file(self):
        helper = ROOT / "scripts/lib/lock.sh"
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "repo"
            repo.mkdir()
            env = {**os.environ, "TMPDIR": tmp}
            key = subprocess.check_output(["sha256sum"], input=str(repo).encode()).decode().split()[0][:24]
            lock_file = Path(tmp) / f"dylanos-build-{key}.lock"
            lock_file.write_text("created by privileged phase\n", encoding="utf-8")
            lock_file.chmod(0o444)
            result = subprocess.run(
                ["bash", "-c", f'source "{helper}"; dylanos_acquire_build_lock "{repo}"'],
                cwd=ROOT,
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(0, result.returncode, result.stderr)

    def test_build_repairs_root_owned_work_directory_before_privilege_escalation(self):
        build = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
        self.assertIn('mkdir -p "$WORK"', build)
        self.assertIn("WORK_OWNER=\"$(stat -c '%u' \"$WORK\")\"", build)
        self.assertIn('[[ "$WORK_OWNER" != "$(id -u)" || ! -w "$WORK" ]]', build)
        self.assertIn('sudo chown "$(id -u):$(id -g)" "$WORK"', build)
        self.assertLess(build.index('sudo chown "$(id -u):$(id -g)" "$WORK"'), build.index('sudo unshare'))

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
