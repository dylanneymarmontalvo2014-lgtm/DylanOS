import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class BootQemuSmokeTest(unittest.TestCase):
    def test_smoke_test_uses_iso_kernel_and_requires_graphical_sddm(self):
        script = (ROOT / "scripts/test-boot-qemu.sh").read_text(encoding="utf-8")
        self.assertIn("-extract /live/vmlinuz", script)
        self.assertIn("-extract /live/initrd.img", script)
        self.assertIn("-kernel", script)
        self.assertIn("-initrd", script)
        self.assertIn("boot=live", script)
        self.assertIn("console=ttyS0", script)
        self.assertIn("Reached target graphical.target", (ROOT / "scripts/check_boot_log.py").read_text(encoding="utf-8"))
        self.assertIn("systemd.log_color=no", script)
        self.assertIn("boot_markers_reached()", script)
        self.assertIn("Started sddm.service", (ROOT / "scripts/check_boot_log.py").read_text(encoding="utf-8"))
        self.assertIn("DYLANOS_QEMU_BOOT_TIMEOUT", script)

    def test_boot_log_parser_accepts_systemd_ansi_color_sequences(self):
        from scripts.check_boot_log import boot_milestones_reached
        log = ("\x1b[0;32m[  OK  ]\x1b[0m Reached target "
               "\x1b[0;1;39mgraphical.target\x1b[0m - Graphical Interface.\n"
               "\x1b[0;32m[  OK  ]\x1b[0m Started "
               "\x1b[0;1;39msddm.service\x1b[0m - Simple Desktop Display Manager.\n")
        self.assertTrue(boot_milestones_reached(log))
        self.assertFalse(boot_milestones_reached("Reached target multi-user.target\n"))

    def test_smoke_test_is_headless_and_cleans_up_qemu(self):
        script = (ROOT / "scripts/test-boot-qemu.sh").read_text(encoding="utf-8")
        self.assertIn("-display none", script)
        self.assertIn("-no-reboot", script)
        self.assertIn("-cpu qemu64", script)
        self.assertIn("-cpu qemu64", script)
        self.assertIn("trap cleanup EXIT", script)
        self.assertIn('kill "$QEMU_PID"', script)
        self.assertNotIn("--reset", script)
        self.assertNotIn(".qcow2", script)

    def test_iso_naming_and_boot_test_follow_release_version(self):
        iso_script = (ROOT / "scripts/iso.sh").read_text(encoding="utf-8")
        test_script = (ROOT / "scripts/test.sh").read_text(encoding="utf-8")
        boot_script = (ROOT / "scripts/test-boot-qemu.sh").read_text(encoding="utf-8")
        self.assertIn('VERSION="${DYLANOS_VERSION:-1.0-beta}"', iso_script)
        self.assertIn('DylanOS-${VERSION}-amd64.iso', iso_script)
        self.assertIn('DylanOS %s amd64', iso_script)
        self.assertIn('DylanOS @VERSION@ — Sesión live', iso_script)
        self.assertIn('DylanOS-${VERSION}-amd64.iso', test_script)
        self.assertIn('DylanOS-${VERSION}-amd64.iso', boot_script)

    def test_tag_release_builds_versioned_iso_and_publishes_only_after_qa(self):
        workflow = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        for required in (
            "tags: ['v*']", "contents: write", "DYLANOS_VERSION=$version",
            'bash scripts/build.sh --minimal "--version=$DYLANOS_VERSION"',
            'sudo env DYLANOS_VERSION="$DYLANOS_VERSION" bash scripts/iso.sh "$DYLANOS_VERSION"',
            "prerelease: ${{ contains(github.ref_name, '-') }}",
            'bash scripts/test.sh', 'bash scripts/test-boot-qemu.sh',
            'softprops/action-gh-release@v2',
            'DylanOS-${{ env.DYLANOS_VERSION }}-amd64.iso',
            'DylanOS-${{ env.DYLANOS_VERSION }}-amd64.iso.sha256',
        ):
            self.assertIn(required, workflow)
        self.assertLess(workflow.index('bash scripts/test-boot-qemu.sh'),
                        workflow.index('softprops/action-gh-release@v2'))

    def test_manual_build_workflow_runs_qemu_boot_test_after_iso_validation(self):
        workflow = (ROOT / ".github/workflows/build.yml").read_text(encoding="utf-8")
        self.assertIn("qemu-system-x86", workflow)
        self.assertLess(workflow.index("bash scripts/test.sh"),
                        workflow.index("bash scripts/test-boot-qemu.sh"))


if __name__ == "__main__":
    unittest.main()
