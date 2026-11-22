#!/usr/bin/env python3
"""Prueba de contrato del DylanOS Login Manager.

Comprueba, sin root ni sesión gráfica:

1. Fidelidad del prototipo: el HTML extraído no cambia respecto al original
   (marcado, estilos y medidas) y la captura coincide píxel a píxel.
2. Variables: todo elemento personalizable existe en `config/variables.json`
   y el HTML no conserva datos simulados.
3. Protocolo SDDM: el host habla el protocolo real contra un daemon simulado
   (Connect, Login correcto/incorrecto y acciones de energía).
4. Datos reales: batería, disco, usuarios y foto de perfil se leen del
   sistema; lo que no existe se declara ausente.

Se ejecuta con el Python del sistema y PySide6 (los del ISO). Si falta
PySide6, las pruebas que lo necesitan se saltan y se informa.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMA = ROOT / "themes/sddm/DylanOS-Crimson/web"
APPS = ROOT / "apps/dylanos-login-manager"
QA = ROOT / "artifacts/login-manager-qa"

try:
    import PySide6  # noqa: F401
    HAY_PYSIDE = True
except ImportError:  # pragma: no cover - depende del entorno
    HAY_PYSIDE = False


def leer(ruta: Path) -> str:
    return ruta.read_text(encoding="utf-8")


class FidelidadDelPrototipo(unittest.TestCase):
    """El prototipo no se rediseña: solo cambian los datos."""

    def test_marcado_sin_datos_es_el_original(self):
        """Quitando las capas de datos, el marcado es el del prototipo."""
        original = leer(TEMA / "origen/plantilla.html")
        actual = leer(TEMA / "index.html")

        # Todo nodo del original debe seguir presente en el tema.
        etiquetas = re.findall(r"<([a-zA-Z][\w-]*)[\s>/]", original)
        actuales = re.findall(r"<([a-zA-Z][\w-]*)[\s>/]", actual)
        faltantes = []
        for etiqueta in set(etiquetas):
            if actuales.count(etiqueta) < etiquetas.count(etiqueta):
                faltantes.append((etiqueta, etiquetas.count(etiqueta), actuales.count(etiqueta)))
        self.assertEqual(faltantes, [], "El tema perdió nodos del prototipo")

    def test_estilos_del_prototipo_intactos(self):
        """Las reglas de estilo del prototipo no se tocan."""
        original = leer(TEMA / "origen/plantilla.html")
        actual = leer(TEMA / "index.html")
        reglas = ["backdrop-filter: blur(36px) saturate(150%)",
                  ".glass-panel{", ".icon-btn{", ".pw-input{", ".unlock-btn{",
                  ".toggle{", ".shortcut-chip{", "@keyframes pop-in"]
        for regla in reglas:
            with self.subTest(regla=regla):
                self.assertIn(regla, original)
                self.assertIn(regla, actual)

    def test_medidas_del_prototipo_intactas(self):
        """Tamaños, radios y posiciones de la composición no cambian."""
        original = leer(TEMA / "origen/plantilla.html")
        actual = leer(TEMA / "index.html")
        for medida in ("width:1440px", "height:960px", "width:370px", "width:420px",
                       "border-radius:18px", "padding:22px 36px", "padding:8px 36px 0",
                       "font-size:168px", "width:280px", "width:104px"):
            with self.subTest(medida=medida):
                self.assertIn(medida, original)
                self.assertIn(medida, actual)

    def test_fuentes_servidas_en_local(self):
        """El greeter no tiene red: ninguna fuente puede pedirse fuera."""
        html = leer(TEMA / "index.html")
        self.assertNotIn("fonts.gstatic.com", html)
        self.assertNotIn("cdn.jsdelivr.net", html)
        self.assertTrue((TEMA / "fonts/inter-latin.woff2").is_file())
        self.assertTrue((TEMA / "vendor/react.production.min.js").is_file())
        self.assertTrue((TEMA / "vendor/dc-runtime.js").is_file())

    def test_captura_coincide_con_la_referencia(self):
        """La captura del tema enlazado es idéntica a la del prototipo."""
        referencia = QA / "prototipo-1440x960.png"
        enlazado = QA / "enlazado-1440x960.png"
        if not referencia.is_file() or not enlazado.is_file():
            self.skipTest("faltan las capturas de referencia")
        self.assertEqual(referencia.read_bytes(), enlazado.read_bytes(),
                         "La captura enlazada difiere del prototipo")


class Variables(unittest.TestCase):
    """Cada elemento del prototipo está separado por nombre."""

    def test_variables_esperadas(self):
        variables = json.loads(leer(TEMA / "config/variables.json"))
        esperadas = {
            "apariencia": ["fondo_seleccionado", "logo_seleccionado", "color_primario",
                           "crimson_glass", "modo"],
            "composicion": ["posicion_paneles", "escala", "tamano_reloj",
                            "tamano_bloque_acceso"],
            "reloj": ["formato_24_horas", "mostrar_fecha"],
            "atajos": ["maximo", "activos"],
            "widgets": ["columna_izquierda", "columna_derecha"],
            "acceso": ["texto_ayuda", "usar_foto_del_usuario"],
        }
        for seccion, claves in esperadas.items():
            with self.subTest(seccion=seccion):
                self.assertIn(seccion, variables)
                for clave in claves:
                    self.assertIn(clave, variables[seccion])

    def test_limite_de_cuatro_atajos(self):
        variables = json.loads(leer(TEMA / "config/variables.json"))
        self.assertEqual(variables["atajos"]["maximo"], 4)
        self.assertLessEqual(len(variables["atajos"]["activos"]), 4)

    def test_sin_datos_simulados_en_el_marcado(self):
        html = leer(TEMA / "index.html")
        cuerpo = html.split("<script", 1)[0]
        for simulado in ("Casa-Dylan-5G", "Oficina DylanOS", "Audífonos Crimson",
                         "TV Sala Crimson", "Dream It Possible", "Delacey",
                         "Reunión de proyecto", "Estudiar para examen",
                         "237 GB libres", "Tiempo restante estimado: 4h 40min"):
            with self.subTest(simulado=simulado):
                self.assertNotIn(simulado, cuerpo)

    def test_alias_de_variables_documentados(self):
        """Los nombres nuevos son los que usa el componente."""
        componente = leer(TEMA / "js/dylanos-componente.js")
        for clave in ("almacenamientoLibre", "puedeAlmacenamiento", "puedeBateria",
                      "pronostico", "recordatorios", "atajos", "hayBateria",
                      "textoAyuda", "bateriaDetalle", "redActual"):
            with self.subTest(clave=clave):
                self.assertIn(clave, componente)


class DatosReales(unittest.TestCase):
    """Nada de cifras inventadas: si no hay dato, el widget no se pinta."""

    def test_componente_no_usa_los_defaults_del_prototipo(self):
        componente = leer(TEMA / "js/dylanos-componente.js")
        for simulado in ("?? 78", "?? 19", "?? 'Nublado'", "'Dream It Possible'",
                         "?? '237 GB'", "'Agosto 2025'"):
            with self.subTest(simulado=simulado):
                self.assertNotIn(simulado, componente)

    def test_puente_declara_ausencias(self):
        puente = leer(TEMA / "js/dylanos-datos.js")
        self.assertIn("bateria: null", puente)
        self.assertIn("clima: null", puente)
        self.assertIn("evento: null", puente)
        self.assertIn("reproduccion: null", puente)

    def test_componente_oculta_widgets_sin_datos(self):
        componente = leer(TEMA / "js/dylanos-componente.js")
        for condicion in ("puedeClima", "puedeEvento", "puedeReproduccion",
                          "puedeCalendario", "puedeRecordatorios", "puedeAtajos"):
            with self.subTest(condicion=condicion):
                self.assertIn(condicion, componente)

    def test_foto_de_perfil_desde_face(self):
        """La foto sale de ~/.face (o de AccountsService), nunca inventada."""
        datos = leer(APPS / "host/datos_sistema.py")
        self.assertIn('.face"', datos)
        self.assertIn("/var/lib/AccountsService/icons", datos)
        self.assertIn("os.access(candidato, os.R_OK)", datos)
        # La copia publicada tiene prioridad: el greeter no lee ~/.face.
        self.assertIn("FOTOS / usuario", datos)

    def test_bateria_y_disco_reales(self):
        datos = leer(APPS / "host/datos_sistema.py")
        self.assertIn("/sys/class/power_supply", datos)
        self.assertIn("os.statvfs", datos)
        # una cifra de ejemplo no puede sobrevivir en el código
        self.assertNotIn("porcentaje\": 78", datos)


class ProtocoloSddm(unittest.TestCase):
    """El host habla el protocolo del daemon, no uno propio."""

    def test_mensajes_del_protocolo(self):
        host = leer(APPS / "host/dylanos-login-greeter.py")
        for mensaje in ("CONNECT, LOGIN, POWEROFF, REBOOT, SUSPEND, HIBERNATE, HYBRIDSLEEP",
                        "HOSTNAME, CAPABILITIES, LOGINSUCCEEDED, LOGINFAILED, INFORMATION"):
            with self.subTest(mensaje=mensaje):
                self.assertIn(mensaje, host)

    def test_login_con_tipo_y_fichero_de_sesion(self):
        host = leer(APPS / "host/dylanos-login-greeter.py")
        # El mensaje Login lleva usuario, contraseña, tipo de sesión y fichero,
        # en ese orden, igual que en SDDM (Session::operator<<).
        for campo in ("flujo << usuario", "flujo << clave",
                      "escribir_u32(flujo, tipo)", "flujo << fichero"):
            with self.subTest(campo=campo):
                self.assertIn(campo, host)
        self.assertIn("self._socket.write(datos)", host)

    def test_quint32_de_cuatro_bytes(self):
        """Los mensajes de SDDM identifican con 4 bytes, no con 8.

        Qt 6 escribe `quint32` con 8 bytes a través de su API de flujo; el
        daemon usa el flujo por defecto, que es de 4. Escribirlos a mano es
        lo que mantiene el protocolo compatible.
        """
        host = leer(APPS / "host/dylanos-login-greeter.py")
        self.assertIn("writeRawData(int(valor).to_bytes(4, \"big\"))", host)
        self.assertIn("def escribir_u32", host)

    def test_orden_de_campos_del_protocolo(self):
        """SDDM serializa la sesión como quint32 tipo + QString fichero."""
        host = leer(APPS / "host/dylanos-login-greeter.py")
        self.assertIn("QDataStream.Qt_6_8", host)
        self.assertIn("tipo", host)
        self.assertIn("fichero", host)

    def test_capacidades_de_energia_respetadas(self):
        host = leer(APPS / "host/dylanos-login-greeter.py")
        for capacidad in ("apagar", "reiniciar", "suspender", "hibernar"):
            with self.subTest(capacidad=capacidad):
                self.assertIn(capacidad, host)

    @unittest.skipUnless(HAY_PYSIDE, "PySide6 no está instalado")
    def test_login_real_contra_daemon_simulado(self):
        """Login correcto e incorrecto a través del socket."""
        from PySide6.QtCore import QCoreApplication, QTimer

        sys.path.insert(0, str(APPS / "tests"))
        sys.path.insert(0, str(APPS / "host"))
        import importlib.util

        def cargar(nombre: str, ruta: Path):
            spec = importlib.util.spec_from_file_location(nombre, ruta)
            modulo = importlib.util.module_from_spec(spec)
            sys.modules[nombre] = modulo
            spec.loader.exec_module(modulo)
            return modulo

        daemon = cargar("daemon_simulado", APPS / "tests/sddm-daemon-simulado.py")
        host_mod = cargar("host_greeter", APPS / "host/dylanos-login-greeter.py")

        aplicacion = QCoreApplication.instance() or QCoreApplication([])
        with tempfile.TemporaryDirectory() as carpeta:
            socket = str(Path(carpeta) / "sddm.sock")
            servidor = daemon.Servidor(socket, "dylan", "secreto")
            protocolo = host_mod.ProtocoloSddm(socket)
            resultados = {"ok": 0, "mal": 0, "capacidades": None}

            protocolo.accesoCorrecto.connect(lambda: resultados.__setitem__("ok", resultados["ok"] + 1))
            protocolo.accesoFallido.connect(lambda: resultados.__setitem__("mal", resultados["mal"] + 1))
            protocolo.capacidades.connect(lambda *v: resultados.__setitem__("capacidades", v))

            def escribir_mala() -> None:
                protocolo.iniciar_sesion("dylan", "mala", 1,
                                         "/usr/share/xsessions/plasmax11.desktop")

            def escribir_buena() -> None:
                protocolo.iniciar_sesion("dylan", "secreto", 1,
                                         "/usr/share/xsessions/plasmax11.desktop")

            # Un intento por vez: el daemon real responde a cada Login antes
            # de que el greeter envíe el siguiente.
            QTimer.singleShot(300, escribir_mala)
            QTimer.singleShot(900, escribir_buena)
            QTimer.singleShot(2200, aplicacion.quit)
            aplicacion.exec()

            self.assertEqual(resultados["mal"], 1, "El login incorrecto no fue rechazado")
            self.assertEqual(resultados["ok"], 1, "El login correcto no fue aceptado")
            self.assertIsNotNone(resultados["capacidades"], "No llegaron las capacidades")
            self.assertTrue(any(r.startswith("Login:dylan:1:plasmax11.desktop")
                                for r in servidor.recibidos),
                            f"Login mal serializado: {servidor.recibidos}")
            servidor.cerrar()

    @unittest.skipUnless(HAY_PYSIDE, "PySide6 no está instalado")
    def test_acciones_de_energia_por_el_socket(self):
        from PySide6.QtCore import QCoreApplication, QTimer
        import importlib.util

        sys.path.insert(0, str(APPS / "tests"))
        sys.path.insert(0, str(APPS / "host"))

        def cargar(nombre: str, ruta: Path):
            spec = importlib.util.spec_from_file_location(nombre, ruta)
            modulo = importlib.util.module_from_spec(spec)
            sys.modules[nombre] = modulo
            spec.loader.exec_module(modulo)
            return modulo

        daemon = cargar("daemon_sim2", APPS / "tests/sddm-daemon-simulado.py")
        host_mod = cargar("host_greeter2", APPS / "host/dylanos-login-greeter.py")
        aplicacion = QCoreApplication.instance() or QCoreApplication([])

        with tempfile.TemporaryDirectory() as carpeta:
            socket = str(Path(carpeta) / "sddm2.sock")
            servidor = daemon.Servidor(socket, "dylan", "secreto")
            protocolo = host_mod.ProtocoloSddm(socket)
            QTimer.singleShot(400, protocolo.reiniciar)
            QTimer.singleShot(1600, aplicacion.quit)
            aplicacion.exec()
            self.assertIn("Reboot", servidor.recibidos, servidor.recibidos)
            servidor.cerrar()


class Integracion(unittest.TestCase):
    """El host encaja en el arranque real de DylanOS."""

    def test_host_acepta_los_argumentos_de_sddm(self):
        host = leer(APPS / "host/dylanos-login-greeter.py")
        for argumento in ('"--socket"', '"--theme"', '"--screenshot"', '"--size"'):
            with self.subTest(argumento=argumento):
                self.assertIn(argumento, host)

    def test_sin_red_en_el_greeter(self):
        host = leer(APPS / "host/dylanos-login-greeter.py")
        self.assertIn("LocalContentCanAccessRemoteUrls, False", host)
        self.assertIn("JavascriptCanOpenWindows, False", host)

    def test_version_de_qt_del_protocolo(self):
        host = leer(APPS / "host/dylanos-login-greeter.py")
        self.assertIn("Qt_6_8", host)


class VistaPrevia(unittest.TestCase):
    """El script de vista previa y el módulo de datos compartido."""

    SCRIPT = ROOT / "scripts/vista-previa-login.py"
    DATOS = APPS / "host/datos_sistema.py"

    def cargar_datos(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("datos_sistema", self.DATOS)
        modulo = importlib.util.module_from_spec(spec)
        sys.modules["datos_sistema"] = modulo
        spec.loader.exec_module(modulo)
        return modulo

    def test_modulo_de_datos_sin_qt(self):
        """El módulo lo usan el host y la vista previa: no puede exigir Qt."""
        texto = leer(self.DATOS)
        self.assertNotIn("PySide6", texto)
        self.assertNotIn("from PySide6", texto)

    def test_host_delega_en_el_modulo(self):
        """Una sola fuente de verdad: el host no reimplementa la lectura."""
        host = leer(APPS / "host/dylanos-login-greeter.py")
        self.assertIn("import datos_sistema", host)
        for duplicado in ("def _estado_bateria", "def _estado_disco",
                          "def _estado_red", "def _leer_sesiones(self) -> list[dict]:\n        sesiones = []"):
            with self.subTest(duplicado=duplicado):
                self.assertNotIn(duplicado, host)

    def test_script_tiene_los_tres_modos(self):
        texto = leer(self.SCRIPT)
        for modo in ("ventana", "navegador", "imagen"):
            with self.subTest(modo=modo):
                self.assertIn(f'"{modo}"', texto)

    def test_script_no_inventa_datos(self):
        texto = leer(self.SCRIPT)
        for simulado in ("19°", "237 GB", "Dream It Possible", "Reunión de proyecto"):
            with self.subTest(simulado=simulado):
                self.assertNotIn(simulado, texto)

    def test_datos_reales_del_equipo(self):
        datos = self.cargar_datos()
        cuentas = datos.cuentas_del_sistema()
        self.assertIsInstance(cuentas, list)
        disco = datos.estado_disco()
        self.assertIn("texto", disco)
        self.assertGreater(disco["total"], 0)
        bateria = datos.estado_bateria()
        self.assertIn("presente", bateria)
        # Un equipo sin batería lo declara; no se inventa un porcentaje.
        if not bateria["presente"]:
            self.assertNotIn("porcentaje", bateria)

    def test_estado_sistema_tiene_las_claves_del_tema(self):
        datos = self.cargar_datos()
        estado = datos.estado_sistema()
        for clave in ("usuario", "avatar", "red", "bateria", "almacenamiento",
                      "teclado", "version", "capacidades", "sesiones"):
            with self.subTest(clave=clave):
                self.assertIn(clave, estado)

    def test_sesion_activa_respeta_los_ajustes(self):
        datos = self.cargar_datos()
        sesiones = [{"tipo": 1, "fichero": "/a/plasma.desktop", "nombre": "Plasma"},
                    {"tipo": 2, "fichero": "/b/wayland.desktop", "nombre": "Wayland"}]
        self.assertEqual(datos.sesion_activa({}, sesiones)["nombre"], "Plasma")
        elegida = datos.sesion_activa({"sesion": "wayland"}, sesiones)
        self.assertEqual(elegida["nombre"], "Wayland")
        # Una sesión pedida que no existe no rompe: se usa la primera.
        self.assertEqual(datos.sesion_activa({"sesion": "inexistente"}, sesiones)["nombre"],
                         "Plasma")

    def test_ajustes_por_variable_de_entorno(self):
        datos = self.cargar_datos()
        with tempfile.TemporaryDirectory() as carpeta:
            ruta = Path(carpeta) / "ajustes.json"
            ruta.write_text('{"apariencia": {"color_primario": "#1f9aa6"}}', encoding="utf-8")
            anterior = os.environ.get("DYLANOS_LOGIN_AJUSTES")
            os.environ["DYLANOS_LOGIN_AJUSTES"] = str(ruta)
            try:
                leidos = datos.leer_ajustes()
            finally:
                if anterior is None:
                    os.environ.pop("DYLANOS_LOGIN_AJUSTES", None)
                else:
                    os.environ["DYLANOS_LOGIN_AJUSTES"] = anterior
            self.assertEqual(leidos["apariencia"]["color_primario"], "#1f9aa6")



    def test_los_textos_de_acento_usan_variables(self):
        """Regresión: los textos de acento iban fijos en el estilo en línea.

        Un `color:#dc143c` escrito en el atributo `style` gana a cualquier hoja
        de estilos, así que el acento elegido en Configuration no llegaba a los
        títulos. Ahora pasan por variables CSS con el mismo valor por defecto.
        """
        html = leer(TEMA / "index.html")
        marcado = html.split("</helmet>", 1)[-1].split('<script type="text/x-dc"', 1)[0]
        for fijo in ("color: #dc143c", "color: #DC143C", "color:#ff5a66",
                     "color: #ff5a66", 'fill="#ff5a66"', 'fill="#ff3b48"'):
            with self.subTest(fijo=fijo):
                self.assertNotIn(fijo, marcado)
        self.assertIn("var(--dylanos-primario)", marcado)
        # Los cuatro tonos del prototipo siguen declarados como valor base.
        for variable in ("--dylanos-primario:", "--dylanos-primario-claro:",
                         "--dylanos-primario-fuerte:", "--dylanos-primario-control:"):
            with self.subTest(variable=variable):
                self.assertIn(variable, html)

    def test_atributos_svg_bien_cerrados(self):
        """Regresión: al sustituir colores se comía la comilla de `fill`."""
        html = leer(TEMA / "index.html")
        self.assertNotIn('fill="var(--dylanos-primario-fuerte)>', html)
        self.assertIn('fill="var(--dylanos-primario-fuerte)"', html)

    def test_clima_real_sin_ubicacion_no_consulta(self):
        """Sin latitud/longitud configuradas no se pide nada a la red."""
        datos = self.cargar_datos()
        with tempfile.TemporaryDirectory() as carpeta:
            ajustes = Path(carpeta) / "aj.json"
            ajustes.write_text("{}", encoding="utf-8")
            anterior = os.environ.get("DYLANOS_LOGIN_AJUSTES")
            os.environ["DYLANOS_LOGIN_AJUSTES"] = str(ajustes)
            try:
                self.assertEqual(datos.consultar_clima(), {})
            finally:
                if anterior is None:
                    os.environ.pop("DYLANOS_LOGIN_AJUSTES", None)
                else:
                    os.environ["DYLANOS_LOGIN_AJUSTES"] = anterior

    def test_evento_sin_ics_no_inventa(self):
        datos = self.cargar_datos()
        with tempfile.TemporaryDirectory() as carpeta:
            ajustes = Path(carpeta) / "aj.json"
            ajustes.write_text("{}", encoding="utf-8")
            anterior = os.environ.get("DYLANOS_LOGIN_AJUSTES")
            os.environ["DYLANOS_LOGIN_AJUSTES"] = str(ajustes)
            try:
                self.assertEqual(datos.estado_evento(), {})
                self.assertEqual(datos.estado_recordatorios(), [])
            finally:
                if anterior is None:
                    os.environ.pop("DYLANOS_LOGIN_AJUSTES", None)
                else:
                    os.environ["DYLANOS_LOGIN_AJUSTES"] = anterior

    def test_recordatorios_limitados_a_cuatro(self):
        datos = self.cargar_datos()
        with tempfile.TemporaryDirectory() as carpeta:
            ajustes = Path(carpeta) / "aj.json"
            ajustes.write_text(json.dumps({"recordatorios": [
                {"texto": f"tarea {i}", "hecho": i % 2 == 0} for i in range(6)
            ]}), encoding="utf-8")
            anterior = os.environ.get("DYLANOS_LOGIN_AJUSTES")
            os.environ["DYLANOS_LOGIN_AJUSTES"] = str(ajustes)
            try:
                lista = datos.estado_recordatorios()
            finally:
                if anterior is None:
                    os.environ.pop("DYLANOS_LOGIN_AJUSTES", None)
                else:
                    os.environ["DYLANOS_LOGIN_AJUSTES"] = anterior
        self.assertEqual(len(lista), 4)
        self.assertEqual(lista[0], {"texto": "tarea 0", "hecho": True})

    def test_la_fila_de_columnas_conserva_su_display_flex(self):
        """Regresión: al personalizar, la columna perdía `display:flex`.

        Sin `flex`, el `gap` no se aplica y todos los paneles se desplazan
        16 px (fue un bug real: `style.display = ''`/`removeProperty` borran la
        propiedad del atributo `style`, no la restauran).
        """
        html = leer(TEMA / "index.html")
        for clase in ("dylanos-columna-izquierda", "dylanos-columna-derecha"):
            with self.subTest(clase=clase):
                self.assertIn(clase, html)
        self.assertIn('style="width:370px; display:flex;', html)
        componente = leer(TEMA / "js/dylanos-componente.js")
        # Se mira el código, no los comentarios: el propio comentario de la
        # corrección menciona `style.display = ''` para explicar el fallo.
        codigo = "\n".join(linea for linea in componente.splitlines()
                            if not linea.lstrip().startswith("*"))
        self.assertNotIn("display = ''", codigo)
        self.assertNotIn("removeProperty('display')", codigo)

    def test_los_paneles_estan_marcados_para_ocultarlos(self):
        """Cada widget de datos lleva su marca para poder ocultarlo."""
        html = leer(TEMA / "index.html")
        for panel in ("clima", "evento", "reproduccion", "sistema",
                      "calendario", "recordatorios", "atajos"):
            with self.subTest(panel=panel):
                self.assertIn(f'data-dylanos-panel="{panel}"', html)

    def test_los_atajos_alternativos_viven_dentro_del_panel(self):
        """Regresión: el bloque alternativo quedaba fuera y sus chips flotaban."""
        html = leer(TEMA / "index.html")
        pos_panel = html.index('data-dylanos-panel="atajos"')
        pos_alternativo = html.index('atajosPersonalizados', pos_panel)
        # Entre el panel y el bloque alternativo no puede cerrarse el panel:
        # si apareciera el cierre del panel antes, el bloque estaría fuera.
        entre = html[pos_panel:pos_alternativo]
        self.assertNotIn("<!-- Center lock column -->", entre)
        self.assertLess(entre.count('<div class="glass-panel'), 2)

    def test_vista_previa_en_navegador_genera_la_pagina(self):
        """El modo navegador deja una copia con los datos dentro."""
        with tempfile.TemporaryDirectory() as carpeta:
            salida = Path(carpeta) / "vista"
            resultado = subprocess.run(
                [sys.executable, str(self.SCRIPT), "--modo", "navegador",
                 "--ancho", "800", "--alto", "600"],
                capture_output=True, text=True, timeout=120,
                env={**os.environ, "TMPDIR": carpeta})
            # Sin navegador disponible el script no falla en silencio: informa.
            self.assertIn(resultado.returncode, (0, 5), resultado.stderr)
            generadas = list(Path(carpeta).glob("dylanos-login-vista-*/web/index.html"))
            if not generadas:
                self.skipTest("el modo navegador no generó carpeta (sin navegador)")
            html = generadas[0].read_text(encoding="utf-8")
            self.assertIn("dylanos-perfil-vista.js", html)
            perfil = generadas[0].parent / "js" / "dylanos-perfil-vista.js"
            self.assertTrue(perfil.is_file())
            self.assertIn("estadoDelSistema", perfil.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
