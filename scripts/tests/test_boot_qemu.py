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
        self.assertIn("Graphical Interface", script)
        self.assertIn("Started sddm.service", script)
        self.assertIn("DYLANOS_QEMU_BOOT_TIMEOUT", script)

    def test_smoke_test_is_headless_and_cleans_up_qemu(self):
        script = (ROOT / "scripts/test-boot-qemu.sh").read_text(encoding="utf-8")
        self.assertIn("-display none", script)
        self.assertIn("-no-reboot", script)
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
