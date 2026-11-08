"""Contrato de catálogo, perfiles y staging para DylanOS Gaming."""
import json
from pathlib import Path
import tempfile
import unittest
import importlib.util

ROOT = Path(__file__).resolve().parents[2]
GAMING = ROOT / "packages/gaming"
CONFIG = ROOT / "apps/dylanos-configuration"

spec = importlib.util.spec_from_file_location("stage", ROOT / "scripts/stage.py")
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)


class TestGaming(unittest.TestCase):
    def test_catalog_has_twenty_unique_apps_with_allowlisted_install_methods(self):
        catalog = json.loads((GAMING / "catalog.json").read_text(encoding="utf-8"))
        apps = catalog["apps"]
        self.assertEqual(20, len(apps))
        self.assertEqual(20, len({app["id"] for app in apps}))
        self.assertEqual(["flathub"], catalog["remote_allowlist"])
        for app in apps:
            if app["method"] == "apt":
                self.assertTrue(app["packages"], app["id"])
            else:
                self.assertEqual("flatpak", app["method"], app["id"])
                self.assertTrue(app["flatpak_id"], app["id"])
                self.assertEqual("flathub", app["remote"], app["id"])

    def test_profiles_and_hardware_constraints_are_explicit(self):
        expected = {"balanced", "performance", "competitive", "streaming", "emulation"}
        profiles = {p.stem for p in (GAMING / "profiles").glob("*.json")}
        self.assertEqual(expected, profiles)
        catalog = json.loads((GAMING / "catalog.json").read_text(encoding="utf-8"))
        apps = {app["id"]: app for app in catalog["apps"]}
        self.assertEqual(["x86_64"], apps["rpcs3"]["arches"])
        self.assertIn("avx", apps["rpcs3"]["cpu_flags"])
        self.assertTrue(apps["rpcs3"]["requires_vulkan"])
        self.assertEqual(["amd"], apps["corectrl"]["gpu"])
        self.assertEqual("trixie", apps["gamescope"]["unavailable_in"])

    def test_configuration_and_control_center_share_the_limited_cli(self):
        main = (CONFIG / "src/main.cpp").read_text(encoding="utf-8")
        self.assertIn('QStringLiteral("gaming-profile")', main)
        self.assertIn('QStringLiteral("gaming-status")', main)
        self.assertIn('QStringLiteral("restore-gaming-profile")', main)
        service = (CONFIG / "src/services/GamingService.h").read_text(encoding="utf-8")
        self.assertIn("Q_INVOKABLE bool updateApp", service)
        qml = (CONFIG / "qml/Main.qml").read_text(encoding="utf-8")
        self.assertIn('case "gaming"', qml)
        control_center = (ROOT / "apps/dylanos-control-center/contents/ui/MockData.qml").read_text(encoding="utf-8")
        self.assertIn("dylanos-configuration --gaming-status --headless", control_center)
        self.assertIn("dylanos-configuration --gaming-profile ", control_center)

    def test_helper_whitelists_privileged_operations_and_paths(self):
        helper = (CONFIG / "helper/dylanos-gaming-helper.py").read_text(encoding="utf-8")
        self.assertIn('"enable-i386"', helper)
        self.assertIn(r"sys/devices/system/cpu/cpu[0-9]+/cpufreq/scaling_governor", helper)
        self.assertNotIn("shell=True", helper)
        policy = (GAMING / "polkit/org.dylanos.gaming.policy").read_text(encoding="utf-8")
        self.assertIn("/usr/lib/dylanos/dylanos-gaming-helper", policy)

    def test_stage_copies_runtime_data_and_removes_stale_gaming_files(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            stage.stage(root)
            runtime = root / "usr/share/dylanos/gaming"
            self.assertTrue((runtime / "catalog.json").is_file())
            self.assertEqual(5, len(list((runtime / "profiles").glob("*.json"))))
            self.assertTrue((runtime / "overlay/mangohud/competitive.conf").is_file())
            self.assertTrue((root / "usr/share/polkit-1/actions/org.dylanos.gaming.policy").is_file())
            self.assertTrue((root / "usr/lib/dylanos/dylanos-gaming-helper.py").is_file())
            (runtime / "stale.json").write_text("{}", encoding="utf-8")
            stage.stage(root)
            self.assertFalse((runtime / "stale.json").exists())


if __name__ == "__main__":
    unittest.main()
