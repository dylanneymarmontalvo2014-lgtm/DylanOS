# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import os
import tempfile
import unittest
from pathlib import Path

from scripts.dylanos.smoke_browser import (
    FORBIDDEN_UPDATE_HOST,
    validate_http_log,
    validate_product_installation,
)


class BrowserSmokeTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.dist = Path(self.temp_dir.name)
        self.binary = self.dist / "dylanos-browser"
        self.binary.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        os.chmod(self.binary, 0o755)
        (self.dist / "application.ini").write_text(
            """[App]
Vendor=DylanOS
Name=DylanOSBrowser
RemotingName=dylanos-browser
CodeName=DylanOS Browser
Profile=dylanos-browser
""",
            encoding="utf-8",
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_product_installation_uses_isolated_dylanos_identity(self):
        identity = validate_product_installation(self.dist)
        self.assertEqual(identity["Vendor"], "DylanOS")
        self.assertEqual(identity["RemotingName"], "dylanos-browser")
        self.assertEqual(identity["Profile"], "dylanos-browser")

    def test_product_installation_rejects_zen_remoting_name(self):
        ini = self.dist / "application.ini"
        ini.write_text(
            ini.read_text(encoding="utf-8").replace(
                "RemotingName=dylanos-browser", "RemotingName=zen"
            ),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(AssertionError, "RemotingName"):
            validate_product_installation(self.dist)

    def test_http_log_rejects_zen_update_traffic(self):
        log = self.dist / "http.log"
        log.write_text(
            f"nsHttp request https://{FORBIDDEN_UPDATE_HOST}/update.xml\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(AssertionError, FORBIDDEN_UPDATE_HOST):
            validate_http_log(log)

    def test_http_log_accepts_local_navigation(self):
        log = self.dist / "http.log"
        log.write_text(
            "nsHttp request http://127.0.0.1:8123/smoke\n",
            encoding="utf-8",
        )
        validate_http_log(log)


if __name__ == "__main__":
    unittest.main()
