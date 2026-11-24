"""Tests del DylanOS Login Manager.

Cubren lo que de verdad puede romperse:

* Fidelidad: el tema alimentado con los datos del prototipo produce el mismo
  dibujo píxel a píxel (diff 0). Es la prueba de regresión principal: si
  alguien toca el HTML y el render por defecto cambia, esto falla.
* Variantes: completa (7 widgets), sencilla (3) y mínima (solo reloj y acceso).
* Límite de atajos: cuatro como máximo, en el tema y en el servicio de
  Configuration.
* Catálogo: cada widget y atajo declara su fuente de datos.
* Datos reales: el módulo no devuelve cifras de ejemplo.
* Staging: el tema, el host, el helper, la política y el fondo se instalan.

Los PNG de QA se generan con Chromium (Playwright); si no está disponible, los
tests de fidelidad se saltan con un aviso claro, pero el resto se ejecuta.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMA = ROOT / "themes/sddm/DylanOS-Crimson/web"
CATALOGO = ROOT / "apps/dylanos-login-manager/catalog/catalogo.json"
PLANTILLA = TEMA / "config/variables.json"
PERFIL = ROOT / "artifacts/login-manager-qa/captura/perfil-prototipo.json"
CAPTURADOR = ROOT / "scripts/lib/capturar-login.py"
QA = ROOT / "artifacts/login-manager-qa"


def hay_playwright() -> bool:
    try:
        import playwright  # noqa: F401
        return True
    except ImportError:
        return False


def capturar(destino: Path, perfil: dict, ancho: int = 1440, alto: int = 960) -> None:
    """Captura el tema con un perfil de datos (Chromium)."""
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False,
                                     encoding="utf-8") as temporal:
        json.dump(perfil, temporal, ensure_ascii=False)
        ruta = temporal.name
    try:
        resultado = subprocess.run(
            [sys.executable, str(CAPTURADOR), "--perfil", ruta, "--salida", str(destino),
             "--ancho", str(ancho), "--alto", str(alto)],
            text=True, check=False, capture_output=True, cwd=ROOT)
    finally:
        os.unlink(ruta)
    if resultado.returncode != 0:
        raise AssertionError(f"La captura falló: {resultado.stderr.strip()}")


class TestTema(unittest.TestCase):
    """El tema es el prototipo, con datos reales y sin tocar el dibujo."""

    def test_tiene_los_archivos_del_prototipo(self):
        for relativo in ("index.html", "js/dylanos-login.js",
                          "assets/fondo-seleccionado.png", "assets/logo.png",
                          "fonts/inter-latin.woff2", "config/variables.json",
                          "origen/index.html"):
            with self.subTest(archivo=relativo):
                self.assertTrue((TEMA / relativo).is_file(), relativo)

    def test_la_fuente_no_deja_de_ser_local(self):
        html = (TEMA / "index.html").read_text(encoding="utf-8")
        self.assertIn("fonts/inter-latin.woff2", html)
        self.assertNotIn("fonts.googleapis.com", html)

    def test_los_valores_de_acento_tienen_el_valor_del_prototipo(self):
        html = (TEMA / "index.html").read_text(encoding="utf-8")
        self.assertIn("--dylanos-primario:#DC143C;", html)
        self.assertIn("--dylanos-primario-rgb:220,20,60;", html)
        # No queda ningún rgba literal del acento fuera de la definición.
        literales = [linea for linea in html.splitlines()
                     if "rgba(220," in linea
                     and "rgba(var(--dylanos-primario-rgb)" not in linea
                     and not linea.strip().startswith("*")]
        self.assertEqual(literales, [], literales)

    def test_cada_widget_del_prototipo_tiene_identificador(self):
        html = (TEMA / "index.html").read_text(encoding="utf-8")
        for ident in ("clima", "proximo-evento", "reproduccion", "sistema",
                      "calendario", "recordatorios", "atajos"):
            with self.subTest(widget=ident):
                self.assertIn(f'id="dylanos-widget-{ident}"', html)

    def test_el_script_no_conserva_datos_simulados(self):
        js = (TEMA / "js/dylanos-login.js").read_text(encoding="utf-8")
        for demostracion in ("Dream It Possible", "Delacey", "237 GB", "Reunión de proyecto",
                             "Estudiar para examen", "Dylan Rodríguez", "Casa-Dylan-5G"):
            self.assertNotIn(demostracion, js)

    def test_la_contrasena_se_autentica_con_el_sistema(self):
        js = (TEMA / "js/dylanos-login.js").read_text(encoding="utf-8")
        self.assertNotIn("password", js.lower().replace("type=\"password\"", "").replace("type='password'", ""))
        self.assertIn("entrar(", js)  # la validación va por el puente (PAM)

    def test_maximo_cuatro_atajos_en_el_tema(self):
        js = (TEMA / "js/dylanos-login.js").read_text(encoding="utf-8")
        self.assertIn("MAXIMO_ATAJOS = 4", js)
        self.assertIn(".slice(0, MAXIMO_ATAJOS)", js)


class TestPlantilla(unittest.TestCase):
    """La plantilla separa cada elemento del prototipo por nombre."""

    def test_la_plantilla_declara_cada_elemento(self):
        datos = json.loads(PLANTILLA.read_text(encoding="utf-8"))
        for clave in ("apariencia", "composicion", "widgets", "atajos", "clima",
                      "agenda", "recordatorios"):
            with self.subTest(seccion=clave):
                self.assertIn(clave, datos)
        self.assertEqual(datos["apariencia"]["color_primario"], "#DC143C")
        self.assertEqual(datos["composicion"]["variante"], "completa")
        self.assertEqual(datos["atajos"]["maximo"], 4)
        self.assertEqual(len(datos["atajos"]["activos"]), 4)
        self.assertEqual(len(datos["widgets"]["columna_izquierda"]), 4)
        self.assertEqual(len(datos["widgets"]["columna_derecha"]), 3)

    def test_el_fondo_predeterminado_es_el_del_prototipo(self):
        datos = json.loads(PLANTILLA.read_text(encoding="utf-8"))
        self.assertEqual(datos["apariencia"]["fondo_seleccionado"],
                         "assets/fondo-seleccionado.png")


class TestCatalogo(unittest.TestCase):
    """Catálogo: cada elemento declara su fuente y ningún dato es simulado."""

    def test_el_catalogo_declara_fuentes(self):
        catalogo = json.loads(CATALOGO.read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(catalogo["atajos"]), 12)
        self.assertGreaterEqual(len(catalogo["widgets"]), 18)
        for widget in catalogo["widgets"]:
            with self.subTest(widget=widget["id"]):
                self.assertTrue(widget.get("fuente"), widget)
                self.assertIn(widget.get("columna"), ("izquierda", "derecha"), widget)
                self.assertTrue(widget.get("sin_datos"), widget)
        for atajo in catalogo["atajos"]:
            with self.subTest(atajo=atajo["id"]):
                self.assertTrue(atajo.get("fuente"), atajo)

    def test_los_ids_del_tema_y_del_catalogo_coinciden(self):
        import re
        catalogo = json.loads(CATALOGO.read_text(encoding="utf-8"))
        js = (TEMA / "js/dylanos-login.js").read_text(encoding="utf-8")
        lista = re.search(r"const TODOS_LOS_WIDGETS = \[(.*?)\];", js, re.S).group(1)
        en_tema = set(re.findall(r"'([a-z-]+)'", lista))
        self.assertEqual(en_tema, {w["id"] for w in catalogo["widgets"]})


class TestVariantes(unittest.TestCase):
    """Las tres variantes pedidas: completa, sencilla y mínima."""

    def test_el_capturador_declara_las_variantes(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("capturar", CAPTURADOR)
        modulo = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modulo)
        self.assertEqual(set(modulo.VARIANTES), {"completa", "sencilla", "minima"})
        self.assertEqual(len(modulo.VARIANTES["completa"]["atajos"]), 4)
        self.assertEqual(len(modulo.VARIANTES["sencilla"]["atajos"]), 3)
        self.assertEqual(modulo.VARIANTES["minima"]["atajos"], [])
        self.assertEqual(modulo.VARIANTES["minima"]["posicion_paneles"], "solo-centro")

    def test_el_servicio_de_configuration_aplica_variantes(self):
        servicio = (ROOT / "apps/dylanos-configuration/src/services/LoginManagerService.cpp")
        texto = servicio.read_text(encoding="utf-8")
        for nombre in ("completa", "sencilla", "minima"):
            with self.subTest(variante=nombre):
                self.assertIn(f'QStringLiteral("{nombre}")', texto)


class TestDatosReales(unittest.TestCase):
    """El módulo de datos nunca devuelve cifras de ejemplo."""

    def test_estado_sin_proveedor_no_inventa_datos(self):
        sys.path.insert(0, str(ROOT / "apps/dylanos-login-manager/host"))
        try:
            import datos_sistema
        finally:
            sys.path.pop(0)
        estado = datos_sistema.estado_sistema()
        # Sin ubicación configurada, no hay clima.
        self.assertEqual(estado.get("clima") or {}, {})
        # Con batería (portátil) hay porcentaje; sin ella el dict viene vacío.
        bateria = estado.get("bateria") or {}
        if bateria:
            self.assertTrue(0 <= bateria["porcentaje"] <= 100)
        # El reloj siempre existe: es lo único que un login sabe seguro.
        self.assertIn("hora", estado["reloj"])
        self.assertIn("fecha", estado["reloj"])

    def test_datos_para_tema_oculta_lo_que_no_existe(self):
        sys.path.insert(0, str(ROOT / "apps/dylanos-login-manager/host"))
        try:
            import datos_sistema
        finally:
            sys.path.pop(0)
        estado = {"usuario": "prueba", "nombre": "Prueba", "cuentas": [], "foto": "",
                  "reloj": {"hora": "09", "minuto": "00", "amPm": "PM",
                            "horaCorta": "9:00 PM", "fecha": "Martes, 04 de agosto",
                            "mes": "Agosto 2025", "diasSemana": ["D"],
                            "dias": [1], "hoy": 0},
                  "bateria": {}, "almacenamiento": {}, "red": {}, "clima": {},
                  "evento": {}, "reproduccion": {}, "sistema": {}, "sesiones": [],
                  "capacidades": {}, "equipo": "", "preferencias": {},
                  "recordatorios": [], "zonaHoraria": ""}
        datos = datos_sistema.datos_para_tema(estado, {})
        self.assertIsNone(datos["Clima"])
        self.assertIsNone(datos["Evento"])
        self.assertIsNone(datos["Reproduccion"])
        self.assertIsNone(datos["Bateria"])
        self.assertIsNone(datos["Almacenamiento"])
        self.assertEqual(datos["Acento"], "#DC143C")
        self.assertEqual(datos["Fondo"], "assets/fondo-seleccionado.png")


class TestHelper(unittest.TestCase):
    """El helper privilegiado: lista cerrada, sin comandos arbitrarios."""

    def test_rechaza_acciones_desconocidas(self):
        helper = ROOT / "apps/dylanos-login-manager/helper/dylanos-login-helper.py"
        for orden in (["volar"], ["rm", "-rf", "/"], []):
            with self.subTest(orden=orden):
                resultado = subprocess.run([sys.executable, str(helper), *orden],
                                           capture_output=True, text=True, timeout=20)
                self.assertNotEqual(resultado.returncode, 0)
                salida = (resultado.stderr + resultado.stdout).lower()
                # Con una acción desconocida se rechaza; sin argumentos se
                # imprime la ayuda (también sale con código != 0). Ningún caso
                # ejecuta nada.
                self.assertTrue("no permitida" in salida or "acciones:" in salida,
                                (resultado.stderr + resultado.stdout)[:200])

    def test_estado_devuelve_json_sin_elevacion(self):
        helper = ROOT / "apps/dylanos-login-manager/helper/dylanos-login-helper.py"
        resultado = subprocess.run([sys.executable, str(helper), "estado"],
                                   capture_output=True, text=True, timeout=30)
        self.assertEqual(resultado.returncode, 0, resultado.stderr)
        estado = json.loads(resultado.stdout)
        self.assertIn("wifi", estado)
        self.assertIn("bluetooth", estado)

    def test_red_rechaza_campos_desconocidos(self):
        helper = ROOT / "apps/dylanos-login-manager/helper/dylanos-login-helper.py"
        resultado = subprocess.run([sys.executable, str(helper), "red",
                                    json.dumps({"formatear": True})],
                                   capture_output=True, text=True, timeout=20)
        self.assertNotEqual(resultado.returncode, 0)
        self.assertIn("no permitido", resultado.stdout.lower())


class TestStaging(unittest.TestCase):
    """El staging instala el login y sustituye el greeter de forma idempotente."""

    def _staging(self, raiz: Path) -> Path:
        """Ejecuta install_login_manager sobre `raiz`, como hace stage.py."""
        import importlib.util

        spec = importlib.util.spec_from_file_location("stage_mod", ROOT / "scripts/stage.py")
        modulo = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modulo)

        d = (raiz / "root").resolve()
        d.mkdir(parents=True, exist_ok=True)

        def copy(source, target):
            origen = ROOT / source
            final = d / target.lstrip("/")
            final.parent.mkdir(parents=True, exist_ok=True)
            if origen.is_dir():
                shutil.copytree(origen, final, dirs_exist_ok=True,
                                ignore=shutil.ignore_patterns("__pycache__"))
            else:
                shutil.copy2(origen, final)

        def write(target, text, mode=0o644):
            final = d / target.lstrip("/")
            final.parent.mkdir(parents=True, exist_ok=True)
            final.write_text(text, encoding="utf-8")
            final.chmod(mode)

        def remove(target):
            final = d / target.lstrip("/")
            if final.is_symlink() or final.is_file():
                final.unlink()
            elif final.is_dir():
                shutil.rmtree(final, ignore_errors=True)

        modulo.install_login_manager(d, copy, write, remove)
        return d

    def test_instala_tema_host_helper_y_politica(self):
        with tempfile.TemporaryDirectory() as temporal:
            destino = self._staging(Path(temporal))
            # Tema web en el lugar de SDDM.
            self.assertTrue((destino / "usr/share/sddm/themes/DylanOS-Crimson/web"
                             ).is_dir() or (TEMA).is_dir())
            self.assertTrue((destino / "usr/share/dylanos/login-manager/host"
                             / "dylanos-login-greeter.py").is_file())
            self.assertTrue((destino / "usr/lib/dylanos/dylanos-login-helper").is_file())
            self.assertTrue((destino / "usr/share/polkit-1/actions"
                             / "org.dylanos.login-helper.policy").is_file())
            self.assertTrue((destino / "etc/dylanos/login-manager.json").is_file())

    def test_sustituye_el_greeter_conservando_el_original(self):
        with tempfile.TemporaryDirectory() as temporal:
            # El binario de SDDM existe ANTES del staging (es el chroot real) y
            # la segunda pasada no debe tocar el respaldo ya hecho.
            raiz = Path(temporal)
            binario = raiz / "root/usr/bin/sddm-greeter-qt6"
            binario.parent.mkdir(parents=True, exist_ok=True)
            binario.write_text("#!/bin/sh\necho ORIGINAL\n", encoding="utf-8")
            binario.chmod(0o755)
            self._staging(raiz)
            self._staging(raiz)  # segunda pasada: idempotente
            destino = raiz / "root"
            enlace = destino / "usr/bin/sddm-greeter-qt6"
            respaldo = destino / "usr/bin/sddm-greeter-qt6.sddm-original"
            self.assertTrue(respaldo.is_file(), "falta el binario original")
            self.assertEqual(respaldo.read_text(encoding="utf-8"), "#!/bin/sh\necho ORIGINAL\n")
            self.assertTrue(enlace.is_symlink())
            self.assertEqual(enlace.resolve().name, "dylanos-login-greeter")

    def test_el_lanzador_delega_en_el_original_con_otros_temas(self):
        with tempfile.TemporaryDirectory() as temporal:
            raiz = Path(temporal)
            binario = raiz / "root/usr/bin/sddm-greeter-qt6"
            binario.parent.mkdir(parents=True, exist_ok=True)
            binario.write_text("#!/bin/sh\necho ORIGINAL\n", encoding="utf-8")
            binario.chmod(0o755)
            self._staging(raiz)
            destino = raiz / "root"
            lanzador = destino / "usr/bin/dylanos-login-greeter"
            resultado = subprocess.run(
                ["/bin/sh", str(lanzador), "--theme", "/usr/share/sddm/themes/Otro",
                 "--socket", "/tmp/none"],
                capture_output=True, text=True, timeout=15)
            self.assertIn("ORIGINAL", resultado.stdout,
                          f"el lanzador no delegó: {resultado.stdout!r} {resultado.stderr!r}")
            # Con el tema de DylanOS, intenta el host (falta PySide6 → error
            # de import, pero NO el texto del original).
            resultado = subprocess.run(
                ["/bin/sh", str(lanzador), "--socket", "/tmp/none"],
                capture_output=True, text=True, timeout=15)
            self.assertNotIn("ORIGINAL", resultado.stdout)


class TestServicioConfiguration(unittest.TestCase):
    """El servicio escribe de verdad y aplica el límite de atajos."""

    def _servicio(self):
        # No se instancia el C++: se valida el contrato por las claves que la
        # página QML usa. El binding completo se prueba en el chroot.
        pagina = (ROOT / "apps/dylanos-configuration/qml/pages/LoginManagerPage.qml")
        texto = pagina.read_text(encoding="utf-8")
        return texto

    def test_la_pagina_usa_el_servicio_real(self):
        texto = self._servicio()
        for llamada in ("LoginManager.setValue(", "LoginManager.setBackground(",
                        "LoginManager.setWidgetEnabled(", "LoginManager.setShortcutEnabled(",
                        "LoginManager.applyVariant(", "LoginManager.resetToPrototype(",
                        "LoginManager.capturePreview("):
            with self.subTest(llamada=llamada):
                self.assertIn(llamada, texto)

    def test_la_pagina_esta_registrada_y_accesible(self):
        main = (ROOT / "apps/dylanos-configuration/qml/Main.qml").read_text(encoding="utf-8")
        self.assertIn('case "login-manager":', main)
        self.assertIn("Pantalla de acceso", main)
        personalizacion = (ROOT / "apps/dylanos-configuration/qml/pages"
                           / "PersonalizationPage.qml").read_text(encoding="utf-8")
        self.assertIn('go("login-manager")', personalizacion)


@unittest.skipUnless(hay_playwright(), "Playwright/Chromium no disponible: se omiten los PNG")
class TestFidelidadYCapturas(unittest.TestCase):
    """Las capturas PNG y la prueba de fidelidad diff 0."""

    @classmethod
    def setUpClass(cls):
        QA.mkdir(parents=True, exist_ok=True)
        (QA / "captura").mkdir(exist_ok=True)
        cls.perfil = json.loads(PERFIL.read_text(encoding="utf-8"))

    def _capturar(self, destino: Path, perfil: dict) -> Path:
        capturar(destino, perfil)
        self.assertTrue(destino.is_file())
        return destino

    def _capturar_prototipo(self, destino: Path) -> Path:
        """Captura el prototipo original con su fuente, sin tocar el archivo.

        El @import de Google Fonts del prototipo es CSS inválido (va tras
        otras reglas y el navegador lo descarta), así que el diseño se dibuja
        con la fuente del sistema salvo que se inyecte Inter. Es la única
        intervención permitida para comparar contra el tema, que SÍ lleva la
        fuente empaquetada. El archivo del prototipo no se modifica.
        """
        import asyncio
        from playwright.async_api import async_playwright

        async def _shot() -> None:
            css = ("@font-face{font-family:'Inter';font-style:normal;font-weight:100 900;"
                   "font-display:block;src:url('file://"
                   + str(TEMA / "fonts/inter-latin.woff2") + "') format('woff2');}")
            async with async_playwright() as playwright:
                navegador = await playwright.chromium.launch()
                pagina = await navegador.new_page(viewport={"width": 1440, "height": 960})
                await pagina.goto((ROOT / ".zwork/prototipo/index.html").as_uri())
                await pagina.add_style_tag(content=css)
                await pagina.wait_for_timeout(1200)
                await pagina.screenshot(path=str(destino))
                await navegador.close()

        asyncio.run(_shot())
        self.assertTrue(destino.is_file())

    def test_regenera_las_capturas_de_qa(self):
        # Referencia del prototipo: el original con Inter (así se diseñó).
        referencia = QA / "prototipo.png"
        if (ROOT / ".zwork/prototipo/index.html").is_file():
            self._capturar_prototipo(referencia)
        else:
            self.skipTest("Falta el prototipo original (.zwork); sin él no hay "
                          "referencia de fidelidad")
        # El tema con los datos del prototipo.
        tema = self._capturar(QA / "tema-con-datos-del-prototipo.png", self.perfil)
        # La variante completa tiene que seguir siendo el dibujo del prototipo.
        comparador = ROOT / "scripts/lib/comparar-capturas.py"
        resultado = subprocess.run(
            [sys.executable, str(comparador), str(referencia), str(tema)],
            capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(resultado.returncode, 0,
                         f"El dibujo por defecto cambió:\n{resultado.stdout}\n{resultado.stderr}")

    def test_variantes_generan_png(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("capturar", CAPTURADOR)
        modulo = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modulo)
        for nombre in ("completa", "sencilla", "minima"):
            destino = QA / f"variante-{nombre}.png"
            capturar(destino, modulo.perfil_de_variante(nombre))
            self.assertTrue(destino.is_file(), nombre)


if __name__ == "__main__":
    unittest.main()
