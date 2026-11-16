"""Contract checks for the DylanOS Process glass UI and safe process actions."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROCESS_UI = ROOT / "apps/dylanos-process/src/faces/dylanosprocesstable/contents/ui/FullRepresentation.qml"
README = ROOT / "apps/dylanos-process/README.dylanos.md"


class ProcessUiContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.qml = PROCESS_UI.read_text(encoding="utf-8")
        cls.readme = README.read_text(encoding="utf-8")

    def test_process_page_has_crimson_translucent_activity_header(self):
        self.assertIn("id: activityHeader", self.qml)
        self.assertIn("Kirigami.Theme.highlightColor", self.qml)
        self.assertIn("0.78", self.qml)
        self.assertIn('i18nc("@title:section", "Process activity")', self.qml)
        self.assertIn('i18nc("@info:status", "LIVE")', self.qml)

    def test_process_filters_are_direct_and_keep_real_filter_modes(self):
        self.assertIn('i18nc("@action:button", "Mine")', self.qml)
        self.assertIn('i18nc("@action:button", "Users")', self.qml)
        self.assertIn('i18nc("@action:button", "System")', self.qml)
        self.assertIn('i18nc("@action:button", "All")', self.qml)
        self.assertIn("checked: root.config.userFilterMode === modelData.mode", self.qml)
        self.assertIn("onClicked: root.config.userFilterMode = modelData.mode", self.qml)
        self.assertNotIn("id: showGroup", self.qml)

    def test_ending_processes_still_requires_confirmation(self):
        self.assertIn("allowDoNotAskAgain: false", self.qml)
        self.assertIn("processHelper.sendSignalToSelection", self.qml)
        self.assertIn("killDialog.open()", self.qml)
        self.assertIn("diálogo de confirmación", self.readme.lower())


if __name__ == "__main__":
    unittest.main()
