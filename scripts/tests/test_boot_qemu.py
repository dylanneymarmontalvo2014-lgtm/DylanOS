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

    def test_manual_build_workflow_runs_qemu_boot_test_after_iso_validation(self):
        workflow = (ROOT / ".github/workflows/build.yml").read_text(encoding="utf-8")
        self.assertIn("qemu-system-x86", workflow)
        self.assertLess(workflow.index("bash scripts/test.sh"),
                        workflow.index("bash scripts/test-boot-qemu.sh"))


if __name__ == "__main__":
    unittest.main()
