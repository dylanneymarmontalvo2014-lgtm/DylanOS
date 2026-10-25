"""Contract tests for the production installer completion flow."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCREEN = (ROOT / "../installer/dylanos-installer/src/screens/InstallationScreen/index.tsx").resolve().read_text()


class InstallerCompletionContractTest(unittest.TestCase):
    def test_installation_success_requires_backend_confirmation(self):
        self.assertNotIn("startSimulatedInstallation", SCREEN)
        self.assertIn('fetch("/api/install/status")', SCREEN)
        self.assertIn('status.status === "running"', SCREEN)
        self.assertIn('status.status === "complete" || status.complete', SCREEN)
        self.assertIn('SET_INSTALLATION_COMPLETE', SCREEN)

    def test_backend_unavailability_is_reported_as_error_not_success(self):
        self.assertIn('SET_INSTALLATION_ERROR', SCREEN)
        self.assertIn("No se realizó ni se confirmó ninguna instalación", SCREEN)


if __name__ == "__main__":
    unittest.main()

class InstallerDiskSafetyContractTest(unittest.TestCase):
    def test_production_disk_list_starts_empty_and_requires_detected_device(self):
        state = (ROOT / "../installer/dylanos-installer/src/state/installerState.tsx").resolve().read_text()
        screen = (ROOT / "../installer/dylanos-installer/src/screens/PartitioningScreen/index.tsx").resolve().read_text()
        self.assertIn('partitioning: { mode: "auto", disk: "" }', state)
        self.assertIn('useState<Disk[]>([])', screen)
        self.assertNotIn("mockDisks[0]", screen)
        self.assertIn('"/api/disks"', screen)
        self.assertIn('void detectDisks()', screen)
        self.assertIn('!disk || disk.device !== state.partitioning.disk', screen)
        self.assertIn('!usable.length', screen)
