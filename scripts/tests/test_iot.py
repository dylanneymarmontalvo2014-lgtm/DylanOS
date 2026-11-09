"""Contratos del catálogo y perfiles de DylanOS IoT."""
import json
from pathlib import Path
import tempfile
import unittest
import importlib.util

ROOT = Path(__file__).resolve().parents[2]
IOT = ROOT / "packages/iot"
spec = importlib.util.spec_from_file_location("stage", ROOT / "scripts/stage.py")
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)


class IotCatalogTest(unittest.TestCase):
    def test_catalog_has_exactly_twenty_unique_apps_with_explicit_methods(self):
        catalog = json.loads((IOT / "catalog.json").read_text(encoding="utf-8"))
        apps = catalog["apps"]
        self.assertEqual(20, len(apps))
        self.assertEqual(20, len({app["id"] for app in apps}))
        self.assertEqual(
            {"arduino-ide-2", "vscode", "platformio", "esp-idf", "thonny", "kicad",
             "freecad", "openscad", "node-red", "mosquitto", "mqtt-explorer",
             "home-assistant", "wireshark", "pulseview", "sigrok", "openocd",
             "avrdude", "esptool", "minicom", "tio"},
            {app["id"] for app in apps},
        )
        for app in apps:
            self.assertIn(app["kind"], {"gui", "gui-extension", "cli-toolchain", "cli", "service-cli", "service-web"}, app["id"])
            self.assertIn(app["method"], {"apt", "official", "vscode-extension", "external-instance"}, app["id"])
            self.assertIn("compatibility", app, app["id"])

    def test_five_profiles_reference_known_catalog_ids(self):
        catalog = json.loads((IOT / "catalog.json").read_text(encoding="utf-8"))
        ids = {app["id"] for app in catalog["apps"]}
        profiles = [json.loads(path.read_text(encoding="utf-8")) for path in (IOT / "profiles").glob("*.json")]
        self.assertEqual(5, len(profiles))
        self.assertEqual({"iot-development", "robotics-engineering", "electronics-design", "home-automation", "embedded-systems"},
                         {profile["id"] for profile in profiles})
        for profile in profiles:
            self.assertTrue(set(profile["apps"]).issubset(ids), profile["id"])

    def test_staging_copies_catalog_and_all_profiles_idempotently(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            stage.stage(root)
            runtime = root / "usr/share/dylanos/iot"
            self.assertTrue((runtime / "catalog.json").is_file())
            self.assertEqual(5, len(list((runtime / "profiles").glob("*.json"))))
            (runtime / "stale.json").write_text("{}", encoding="utf-8")
            stage.stage(root)
            self.assertFalse((runtime / "stale.json").exists())

    def test_configuration_registers_real_iot_service_and_page(self):
        config = ROOT / "apps/dylanos-configuration"
        main = (config / "src/main.cpp").read_text(encoding="utf-8")
        qml = (config / "qml/Main.qml").read_text(encoding="utf-8")
        cmake = (config / "CMakeLists.txt").read_text(encoding="utf-8")
        self.assertIn('setContextProperty(QStringLiteral("IoT")', main)
        self.assertIn('case "iot"', qml)
        self.assertIn('qml/pages/IoTPage.qml', cmake)
        self.assertIn('src/services/IoTService.cpp', cmake)
        service = (config / "src/services/IoTService.cpp").read_text(encoding="utf-8")
        self.assertIn('/dev/serial/by-id', service)
        self.assertNotIn('QStringLiteral("ttyS*")', service)
        self.assertIn('canonicalFilePath()', service)


if __name__ == "__main__":
    unittest.main()
