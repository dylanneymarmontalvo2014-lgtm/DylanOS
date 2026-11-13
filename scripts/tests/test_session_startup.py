"""Contratos del arranque de sesión que produjeron el escritorio negro.

Cada aserción corresponde a un fallo reproducido en VM (Plasma 6.3.6, X11):
el usuario ve el splash y luego todo negro. No son preferencias de estilo.
"""
import re
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
import importlib.util

_spec = importlib.util.spec_from_file_location("stage", ROOT / "scripts/stage.py")
module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(module)


class SessionStartupTest(unittest.TestCase):
    def test_configuration_never_refreshes_the_shell(self):
        """refreshCurrentShell termina plasmashell en X11 y no vuelve.

        Reproducido en la VM: con el binario que llamaba a refreshCurrentShell
        plasmashell moría tras el autostart de Crimson Glass; sin la llamada
        sobrevive. El shell ya aplica el script de evaluateScript.
        """
        source = (ROOT / "apps/dylanos-configuration/src/services/"
                         "CrimsonGlassService.cpp").read_text(encoding="utf-8")
        # El nombre aparece como literal en la llamada DBus
        # (QStringLiteral("refreshCurrentShell")), así que se busca el literal
        # entre comillas y se descartan las líneas de comentario.
        calls = [line for line in source.splitlines()
                 if re.search(r'"refreshCurrentShell"', line)
                 and not line.lstrip().startswith("//")]
        self.assertEqual(calls, [], "CrimsonGlassService no debe invocar refreshCurrentShell")

    def test_session_wrapper_does_not_wait_before_the_bus_exists(self):
        """El wrapper corre ANTES de que startplasma cree el bus de sesión.

        Cualquier dbus-send ahí falla (no hay DBUS_SESSION_BUS_ADDRESS) y solo
        añade espera muerta antes del splash. La activación de
        kactivitymanagerd la hace systemd --user por DBus.
        """
        stage = (ROOT / "scripts/stage.py").read_text(encoding="utf-8")
        wrapper = stage.split('"/usr/bin/dylanos-startplasma-x11"', 1)[1].split('"""', 2)[1]
        self.assertNotIn("dbus-send", wrapper)
        self.assertIn('exec /usr/bin/startplasma-x11', wrapper)

    def test_kglobalaccel_has_enough_timeout_for_tcg(self):
        """TimeoutSec=5 hace que la sesión nunca arranque en VM sin KVM.

        Reproducido en QEMU TCG: plasma-kglobalaccel.service consumía 3-4 s de
        CPU cargando el plugin xcb, systemd lo mataba antes de registrar
        org.kde.kglobalaccel, entraba en bucle de reinicio, y ksmserver
        abortaba el arranque de la sesión con ServiceUnknown. KSplash se
        quedaba en stage 0: logo y puntos grises, sin escritorio (negro).
        """
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            module.stage(root)
            units = ("plasma-kglobalaccel", "plasma-kwin_x11", "plasma-plasmashell",
                     "plasma-ksmserver", "plasma-kcminit", "plasma-kactivitymanagerd",
                     "xdg-desktop-portal")
            for unit in units:
                dropin = root / f"etc/systemd/user/{unit}.service.d/50-dylanos-vm-timeout.conf"
                self.assertTrue(dropin.is_file(), dropin)
                text = dropin.read_text(encoding="utf-8")
                self.assertIn("TimeoutStartSec=300", text)
                self.assertIn("TimeoutSec=300", text)

    def test_session_wrapper_never_forces_qpainter(self):
        """KWIN_COMPOSE=Q no es válido en X11 y hace salir a KWin."""
        stage = (ROOT / "scripts/stage.py").read_text(encoding="utf-8")
        wrapper = stage.split('"/usr/bin/dylanos-startplasma-x11"', 1)[1]
        self.assertNotIn("export KWIN_COMPOSE=", wrapper)
        self.assertIn("unset KWIN_COMPOSE", wrapper)
        self.assertIn("export LIBGL_ALWAYS_SOFTWARE=1", wrapper)


if __name__ == "__main__":
    unittest.main()
