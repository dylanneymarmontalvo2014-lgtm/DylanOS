"""Validación de sintaxis QML de los archivos críticos del Crimson Glass."""
import os
from pathlib import Path
import unittest
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
try:
    from PySide6.QtCore import QUrl
    from PySide6.QtQml import QQmlEngine, QQmlComponent
    from PySide6.QtGui import QGuiApplication
    HAS_QT = True
except ImportError:
    HAS_QT = False
ROOT = Path(__file__).resolve().parents[2]

QML_FILES = (
    "apps/calculator/qml/Main.qml",
    "themes/sddm/DylanOS-Crimson/Main.qml",
)

# Páginas que dependen del módulo de Configuration (usan sus componentes y el
# singleton Theme) y por eso se validan con el binario de la aplicación, no
# sueltas. La QA concreta de la página del login está en
# test_login_manager.py.
QML_DE_CONFIGURACION = (
    "apps/dylanos-configuration/qml/pages/LoginManagerPage.qml",
)


@unittest.skipUnless(HAS_QT, 'PySide6 needed')
class QmlSyntaxTest(unittest.TestCase):
    def test_qml_files_parse_without_errors(self):
        app = QGuiApplication.instance() or QGuiApplication([])
        engine = QQmlEngine()
        engine.addImportPath(str(ROOT))
        for relative in QML_FILES:
            if not (ROOT / relative).is_file():
                continue
            component = QQmlComponent(engine, QUrl.fromLocalFile(str(ROOT / relative)))
            self.assertEqual(component.status(), QQmlComponent.Status.Ready,
                             "%s: %s" % (relative, component.errorString()))

    def test_paginas_de_configuration_declaran_sus_componentes(self):
        """Cada página importa el módulo del que salen sus componentes.

        Una página que usa BadgePill o DToggle sin importar
        `org.dylanos.configuration` compila pero falla al abrirse; el error solo
        se ve en tiempo de ejecución.
        """
        for relative in QML_DE_CONFIGURACION:
            ruta = ROOT / relative
            if not ruta.is_file():
                continue
            texto = ruta.read_text(encoding="utf-8")
            with self.subTest(fichero=relative):
                self.assertIn("import org.dylanos.configuration", texto)
                self.assertIn("import QtQuick", texto)

    def test_pagina_de_login_sin_datos_simulados(self):
        ruta = ROOT / "apps/dylanos-configuration/qml/pages/LoginManagerPage.qml"
        if not ruta.is_file():
            self.skipTest("la página del login no está en este árbol")
        texto = ruta.read_text(encoding="utf-8")
        # La página configura el login real: no lleva maquetas ni cifras de
        # ejemplo, solo controles que escriben la configuración del sistema.
        for simulado in ("19°", "237 GB", "Dream It Possible", "Reunión de proyecto"):
            with self.subTest(simulado=simulado):
                self.assertNotIn(simulado, texto)


if __name__ == "__main__":
    unittest.main()
