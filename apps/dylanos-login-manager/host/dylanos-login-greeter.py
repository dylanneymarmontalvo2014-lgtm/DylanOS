#!/usr/bin/env python3
"""DylanOS Login Manager: host del greeter.

SDDM no permite configurar otro binario de greeter, y su greeter QML no puede
inicializar QtWebEngine (el motor aborta con «must be called from the Qt gui
thread» porque se crea después de QGuiApplication). Para que el prototipo HTML
sea el login real sin reescribirlo, este proceso ocupa el lugar del greeter:

  * se lanza con los mismos argumentos que `sddm-greeter-qt6`;
  * habla el mismo protocolo (QLocalSocket + QDataStream) con el daemon de
    SDDM, así que la autenticación es PAM real y las acciones de energía son
    las de SDDM;
  * dibuja el tema en un QWebEngineView a pantalla completa.

Protocolo (SDDM 0.21, src/common/Messages.h):
  greeter → daemon: Connect(0), Login(1), PowerOff(2), Reboot(3), Suspend(4),
                    Hibernate(5), HybridSleep(6)
  daemon → greeter: HostName(0), Capabilities(1), LoginSucceeded(2),
                    LoginFailed(3), InformationMessage(4)
  Login: usuario (QString), contraseña (QString), sesión (quint32 tipo +
         QString fichero)

Además acepta un modo `--preview` que dibuja el tema sin daemon, para QA y
para la vista previa de DylanOS Configuration.
"""
from __future__ import annotations

import json
import os
import signal
import sys
from pathlib import Path

# Los datos del sistema viven en un módulo sin Qt: lo comparten el host, la
# vista previa y los tests, así que no puede haber dos lecturas distintas.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import datos_sistema  # noqa: E402

from PySide6.QtCore import (QByteArray, QCoreApplication, QDataStream, QIODevice,
                            QObject, QTimer, QUrl, Qt, Signal, Slot)
from PySide6.QtGui import QGuiApplication
from PySide6.QtWidgets import QApplication
from PySide6.QtWebChannel import QWebChannel

# WebEngine debe inicializarse antes de crear la aplicación: registra el
# contexto OpenGL compartido que necesita el compositor de Chromium.
from PySide6.QtWebEngineCore import (QWebEnginePage, QWebEngineProfile,
                                     QWebEngineScript, QWebEngineSettings)
from PySide6.QtWebEngineWidgets import QWebEngineView

TEMA_POR_DEFECTO = Path("/usr/share/sddm/themes/DylanOS-Crimson")
AJUSTES = Path("/etc/dylanos/login-manager.json")


def ruta_tema(argumentos: list[str]) -> Path:
    for i, arg in enumerate(argumentos):
        if arg == "--theme" and i + 1 < len(argumentos):
            return Path(argumentos[i + 1])
        if arg.startswith("--theme="):
            return Path(arg.split("=", 1)[1])
    return TEMA_POR_DEFECTO


def ruta_socket(argumentos: list[str]) -> str:
    for i, arg in enumerate(argumentos):
        if arg == "--socket" and i + 1 < len(argumentos):
            return argumentos[i + 1]
        if arg.startswith("--socket="):
            return arg.split("=", 1)[1]
    return ""


def escribir_u32(flujo: "QDataStream", valor: int) -> None:
    """Escribe un quint32 de 4 bytes, como los mensajes del daemon de SDDM.

    Qt 6 escribe `quint32` a través de su API pública con 8 bytes cuando se
    pide la versión extendida del flujo; el daemon de SDDM usa el flujo por
    defecto, que es de 4 bytes big-endian. La única forma estable de
    garantizar el mismo formato es escribir los cuatro bytes a mano.
    """
    flujo.writeRawData(int(valor).to_bytes(4, "big"))


class LectorBinario:
    """Lector de mensajes con búfer para un socket local.

    QDataStream sobre un socket lee lo que haya: con menos de cuatro bytes el
    identificador queda en 0 y 0 es justo `Connect`. Eso producía un bucle de
    conexiones (y un login que nunca se procesaba). Aquí solo se consume un
    mensaje cuando está completo.
    """

    def __init__(self, socket):
        self._socket = socket
        self._datos = bytearray()

    def recibir(self) -> None:
        while self._socket.bytesAvailable() > 0:
            trozo = bytes(self._socket.read(4096))
            if not trozo:
                break
            self._datos.extend(trozo)

    def u32(self):
        """quint32 de 4 bytes big-endian, o None si no ha llegado entero."""
        if len(self._datos) < 4:
            return None
        valor = int.from_bytes(bytes(self._datos[:4]), "big")
        del self._datos[:4]
        return valor

    def cadena(self):
        """QString completo, o None si faltan bytes.

        La longitud que precede al texto son bytes UTF-16 (no caracteres):
        «dylan» llega como 0x0A = 10 bytes.
        """
        if len(self._datos) < 4:
            return None
        largo = int.from_bytes(bytes(self._datos[:4]), "big")
        if largo == 0xFFFFFFFF:
            del self._datos[:4]
            return ""
        if len(self._datos) < 4 + largo:
            return None
        texto = bytes(self._datos[4:4 + largo]).decode("utf-16-be")
        del self._datos[:4 + largo]
        return texto


class ProtocoloSddm(QObject):
    """Cliente del protocolo de SDDM.

    Envía Connect/Login/acciones de energía y traduce las respuestas del
    daemon en señales Qt. El daemon autentica con PAM: aquí no se valida nada
    por cuenta propia.
    """

    capacidades = Signal(bool, bool, bool, bool, bool)
    nombreEquipo = Signal(str)
    accesoCorrecto = Signal()
    accesoFallido = Signal()
    mensaje = Signal(str)
    desconectado = Signal()
    conectado = Signal(bool)

    CONNECT, LOGIN, POWEROFF, REBOOT, SUSPEND, HIBERNATE, HYBRIDSLEEP = range(7)
    HOSTNAME, CAPABILITIES, LOGINSUCCEEDED, LOGINFAILED, INFORMATION = range(5)

    def __init__(self, nombre_socket: str, parent: QObject | None = None):
        super().__init__(parent)
        from PySide6.QtNetwork import QLocalSocket

        self._socket = QLocalSocket(self)
        self._lector = LectorBinario(self._socket)

        self._socket.connected.connect(self._al_conectar)
        self._socket.disconnected.connect(self.desconectado)
        self._socket.readyRead.connect(self._leer)
        if not nombre_socket:
            QTimer.singleShot(0, lambda: self.conectado.emit(False))
            return
        self._socket.connectToServer(nombre_socket)

    def _volcar(self) -> None:
        """Entrega lo escrito al otro extremo.

        `flush()` no vacía el búfer interno del socket local en todos los
        casos: sin `waitForBytesWritten` el mensaje puede quedarse esperando y
        el daemon lo recibe tarde o nunca.
        """
        self._socket.flush()
        self._socket.waitForBytesWritten(50)

    def _al_conectar(self) -> None:
        self._escribir(self.CONNECT)
        self.conectado.emit(True)

    def _escribir(self, mensaje: int) -> None:
        # QDataStream mantiene su propio búfer: se construye el mensaje y se
        # envía como bytes, para que el daemon reciba exactamente uno.
        datos = QByteArray()
        flujo = QDataStream(datos, QIODevice.OpenModeFlag.WriteOnly)
        flujo.setVersion(QDataStream.Qt_6_8)
        escribir_u32(flujo, mensaje)
        self._socket.write(datos)
        self._volcar()

    def iniciar_sesion(self, usuario: str, clave: str, tipo: int, fichero: str) -> None:
        datos = QByteArray()
        flujo = QDataStream(datos, QIODevice.OpenModeFlag.WriteOnly)
        flujo.setVersion(QDataStream.Qt_6_8)
        escribir_u32(flujo, self.LOGIN)
        flujo << usuario
        flujo << clave
        escribir_u32(flujo, tipo)
        flujo << fichero
        self._socket.write(datos)
        self._volcar()

    @Slot()
    def apagar(self) -> None:
        self._accion(self.POWEROFF)

    @Slot()
    def reiniciar(self) -> None:
        self._accion(self.REBOOT)

    @Slot()
    def suspender(self) -> None:
        self._accion(self.SUSPEND)

    @Slot()
    def hibernar(self) -> None:
        self._accion(self.HIBERNATE)

    def _accion(self, mensaje: int) -> None:
        self._escribir(mensaje)

    def _leer(self) -> None:
        # Un mensaje completo por vuelta; si faltan bytes, se espera.
        self._lector.recibir()
        while True:
            mensaje = self._lector.u32()
            if mensaje is None:
                return
            if mensaje == self.CAPABILITIES:
                valor = self._lector.u32()
                if valor is None:
                    return
                self.capacidades.emit(bool(valor & 0x1), bool(valor & 0x2),
                                      bool(valor & 0x4), bool(valor & 0x8),
                                      bool(valor & 0x10))
            elif mensaje == self.HOSTNAME:
                equipo = self._lector.cadena()
                if equipo is None:
                    return
                self.nombreEquipo.emit(equipo)
            elif mensaje == self.LOGINSUCCEEDED:
                self.accesoCorrecto.emit()
            elif mensaje == self.LOGINFAILED:
                self.accesoFallido.emit()
            elif mensaje == self.INFORMATION:
                texto = self._lector.cadena()
                if texto is None:
                    return
                self.mensaje.emit(texto)
            else:
                return


class Puente(QObject):
    """Objeto expuesto al HTML por QWebChannel.

    Es la única superficie que el tema puede tocar: consultar estado, pedir el
    login y ejecutar acciones permitidas. No expone el sistema de ficheros ni
    comandos.
    """

    estadoCambiado = Signal(str)

    def __init__(self, host: "Host"):
        super().__init__()
        self._host = host

    # --- estado ---------------------------------------------------------

    @Slot(result=str)
    def config(self) -> str:
        return json.dumps(self._host.ajustes, ensure_ascii=False)

    @Slot(result=str)
    def estado(self) -> str:
        return json.dumps(self._host.datos_tema(), ensure_ascii=False)

    @Slot(result=str)
    def usuarios(self) -> str:
        return json.dumps(self._host.cuentas, ensure_ascii=False)

    @Slot(str, result=str)
    def foto(self, usuario: str) -> str:
        return datos_sistema.foto_del_usuario(usuario)

    # --- acciones -------------------------------------------------------

    @Slot(str, str, result=bool)
    def entrar(self, usuario: str, clave: str) -> bool:
        if not usuario or not self._host.protocolo:
            return False
        sesion = self._host.sesion_activa()
        self._host.usuario_actual = usuario
        self._host.protocolo.iniciar_sesion(usuario, clave, sesion["tipo"], sesion["fichero"])
        return True

    @Slot(str)
    def accion(self, nombre: str) -> None:
        protocolo = self._host.protocolo
        if not protocolo:
            return
        acciones = {
            "apagar": protocolo.apagar,
            "reiniciar": protocolo.reiniciar,
            "suspender": protocolo.suspender,
            "hibernar": protocolo.hibernar,
        }
        if nombre in acciones:
            acciones[nombre]()

    @Slot(str)
    def guardarPreferencia(self, datos: str) -> None:
        self._host.guardar_preferencia(datos)

    @Slot(str)
    def ordenar(self, datos: str) -> None:
        self._host.ordenar_red(datos)


class Pagina(QWebEnginePage):
    """Página del tema que reporta los errores de JavaScript a stderr.

    Sin esto, un fallo en el componente deja el tema a medio pintar y no hay
    forma de saber por qué: QWebEngine descarta los mensajes de consola.
    """

    def javaScriptConsoleMessage(self, nivel, mensaje, linea, fuente):
        print(f"js: {mensaje} ({Path(fuente).name}:{linea})", file=sys.stderr)


class Host:
    """Estado compartido entre el puente, la vista y el protocolo."""

    def __init__(self, tema: Path, socket: str, previsualizar: bool = False):
        self.tema = tema
        self.ajustes = datos_sistema.leer_ajustes()
        self.catalog = datos_sistema.leer_catalogo()
        self.cuentas = datos_sistema.cuentas_del_sistema()
        self.sesiones = datos_sistema.sesiones_instaladas()
        self.protocolo: ProtocoloSddm | None = None
        self.capacidades = {"apagar": False, "reiniciar": False, "suspender": False,
                            "hibernar": False, "hibrido": False}
        self.equipo = ""
        self.usuario_actual = ""
        self.previsualizar = previsualizar
        if not previsualizar and socket:
            self.protocolo = ProtocoloSddm(socket)
            self.protocolo.capacidades.connect(self._al_capacidades)
            self.protocolo.nombreEquipo.connect(self._al_equipo)

    def _al_capacidades(self, apagar, reiniciar, suspender, hibernar, hibrido) -> None:
        self.capacidades = {"apagar": apagar, "reiniciar": reiniciar,
                            "suspender": suspender, "hibernar": hibernar,
                            "hibrido": hibrido}

    def _al_equipo(self, nombre: str) -> None:
        self.equipo = nombre

    def sesion_activa(self) -> dict:
        """Sesión preseleccionada: la de ajustes o la primera disponible."""
        return datos_sistema.sesion_activa(self.ajustes, self.sesiones)

    def usuario_predeterminado(self) -> str:
        return datos_sistema.usuario_predeterminado(self.ajustes, self.cuentas)

    # --- datos reales del sistema ---------------------------------------

    def estado_sistema(self) -> dict:
        usuario = self.usuario_actual or self.usuario_predeterminado()
        return datos_sistema.estado_sistema(usuario, self.equipo, self.capacidades)

    def datos_tema(self) -> dict:
        """Lo que dibuja el tema: estado real ya resuelto y presentación."""
        estado = self.estado_sistema()
        datos = datos_sistema.datos_para_tema(estado, self.ajustes)
        # Widgets y atajos elegidos en Configuration.
        seleccion = self.ajustes.get("widgets") or {}
        datos["Widgets"] = {
            "izquierda": seleccion.get("columna_izquierda") or [],
            "derecha": seleccion.get("columna_derecha") or [],
        }
        datos["Atajos"] = (self.ajustes.get("atajos") or {}).get("activos") or []
        datos["Personalizado"] = bool(self.ajustes.get("personalizado"))
        datos["UsuarioCuenta"] = estado.get("usuario", "")
        datos["Cuentas"] = estado.get("cuentas", [])
        datos["Sesiones"] = estado.get("sesiones", [])
        datos["Mensaje"] = self._mensaje_para(estado.get("usuario", ""))
        datos["Teclado"] = self._distribucion_teclado()
        datos["ZonasMundiales"] = self._zonas_mundiales()
        return datos

    def _mensaje_para(self, usuario: str) -> str:
        """Aviso del administrador dirigido a todas las cuentas o a una."""
        mensaje = self.ajustes.get("mensaje") or {}
        if not isinstance(mensaje, dict):
            return ""
        if mensaje.get("usuario") and mensaje.get("usuario") != usuario:
            return ""
        return str(mensaje.get("texto") or "")

    def _distribucion_teclado(self) -> str:
        try:
            for linea in Path("/etc/default/keyboard").read_text(encoding="utf-8").splitlines():
                if linea.startswith("XKBLAYOUT="):
                    return linea.split("=", 1)[1].strip().strip('"').upper()
        except OSError:
            pass
        return ""

    def _zonas_mundiales(self) -> list[dict]:
        """Horas reales de las zonas que el usuario haya configurado."""
        from datetime import datetime
        from zoneinfo import ZoneInfo

        zonas = (self.ajustes.get("reloj_mundial") or {}).get("zonas") or []
        resultado = []
        for zona in zonas[:4]:
            try:
                ciudad, nombre = str(zona).split("|", 1)
                hora = datetime.now(ZoneInfo(nombre)).strftime("%H:%M")
            except (ValueError, KeyError, OSError):
                continue
            resultado.append({"ciudad": ciudad, "hora": hora})
        return resultado

    def guardar_preferencia(self, datos: str) -> None:
        """Guarda una preferencia del usuario en su propio estado.

        El greeter corre como `sddm`: escribe con los permisos del usuario
        dueño del fichero si existe, y si no puede, no falla el login.
        """
        try:
            cambios = json.loads(datos)
        except ValueError:
            return
        usuario = self.usuario_actual or self.usuario_predeterminado()
        if not usuario:
            return
        try:
            import pwd
            casa = Path(pwd.getpwnam(usuario).pw_dir)
        except (KeyError, ImportError):
            return
        ruta = casa / ".local/state/dylanos/login-manager.json"
        actual: dict = {}
        try:
            actual = json.loads(ruta.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            pass
        actual.update(cambios)
        try:
            ruta.parent.mkdir(parents=True, exist_ok=True)
            ruta.write_text(json.dumps(actual, indent=2, ensure_ascii=False) + "\n",
                            encoding="utf-8")
        except OSError:
            pass

    def ordenar_red(self, datos: str) -> None:
        """Punto de entrada del helper privilegiado (Wi-Fi/Bluetooth).

        Sin el helper instalado no hace nada: nunca simula un cambio de red.
        """
        try:
            cambios = json.loads(datos)
        except ValueError:
            return
        helper = Path("/usr/lib/dylanos/dylanos-login-helper")
        if not helper.exists():
            return
        import subprocess
        peticion = {"wifi": cambios.get("wifi"), "bluetooth": cambios.get("bluetooth")}
        entorno = os.environ.copy()
        entorno.setdefault("XDG_RUNTIME_DIR", "/run/sddm")
        try:
            subprocess.run([str(helper), "red", json.dumps(peticion, ensure_ascii=False)],
                           check=False, timeout=15, env=entorno)
        except (OSError, subprocess.SubprocessError):
            pass


def main() -> int:
    argumentos = sys.argv[1:]
    previsualizar = "--preview" in argumentos
    capturar = None
    tamano = None
    for i, arg in enumerate(argumentos):
        if arg == "--screenshot" and i + 1 < len(argumentos):
            capturar = Path(argumentos[i + 1])
        if arg == "--size" and i + 1 < len(argumentos):
            try:
                ancho, alto = argumentos[i + 1].lower().split("x")
                tamano = (int(ancho), int(alto))
            except ValueError:
                print("Tamaño inválido: usa --size 1440x960", file=sys.stderr)
                return 2

    QCoreApplication.setAttribute(Qt.AA_ShareOpenGLContexts, True)
    # QWebEngineView es un QWidget: la aplicación debe ser QApplication, no
    # QGuiApplication. Se le pasan solo los argumentos propios, para que Qt no
    # interprete `--socket` ni `--theme` (son del greeter, no de Qt).
    aplicacion = QApplication([sys.argv[0]])
    aplicacion.setApplicationName("DylanOS Login Manager")
    aplicacion.setOrganizationName("DylanOS")
    aplicacion.setDesktopFileName("org.dylanos.login-manager")

    tema = ruta_tema(argumentos)
    indice = tema / "index.html"
    if not indice.is_file():
        print(f"No se encontró el tema en {indice}", file=sys.stderr)
        return 2

    host = Host(tema, ruta_socket(argumentos), previsualizar)
    puente = Puente(host)

    QWebEngineProfile.defaultProfile().setHttpUserAgent(
        "DylanOS Login Manager (QtWebEngine)")

    vista = QWebEngineView()
    vista.setPage(Pagina(vista))
    vista.setWindowFlags(Qt.FramelessWindowHint | Qt.Window)
    vista.setContextMenuPolicy(Qt.NoContextMenu)
    ajustes_vista = vista.settings()
    ajustes_vista.setAttribute(QWebEngineSettings.LocalContentCanAccessFileUrls, True)
    ajustes_vista.setAttribute(QWebEngineSettings.LocalContentCanAccessRemoteUrls, False)
    ajustes_vista.setAttribute(QWebEngineSettings.JavascriptCanOpenWindows, False)
    ajustes_vista.setAttribute(QWebEngineSettings.ErrorPageEnabled, False)
    ajustes_vista.setAttribute(QWebEngineSettings.ShowScrollBars, False)

    canal = QWebChannel(vista.page())
    canal.registerObject("dylanos", puente)
    vista.page().setWebChannel(canal)

    # El puente para el tema. Se instala ANTES del documento.
    #
    # Detalle importante de QWebChannel: los slots con valor de retorno son
    # ASÍNCRONOS desde JavaScript (necesitan un callback; sin él la llamada
    # devuelve undefined). Por eso el estado inicial se entrega como JSON
    # literal dentro del propio puente, y el canal solo se usa para acciones
    # (entrar, accion, preferencias) y para refrescar el estado con callback.
    datos_iniciales = json.dumps(host.datos_tema(), ensure_ascii=False)
    guion = """
(function () {
  var PERFIL = __DATOS_INICIALES__;
  // Sin puente Qt (por ejemplo, al abrir el HTML a mano) el tema se dibuja y
  // no ofrece autenticación: nunca finge un acceso.
  window.DYLANOS_LOGIN = {
    iniciar: function () { return PERFIL; },
    listo: true,
    alCambiarEstado: function (fn) { window.__dylanosAlCambiar = fn; },
    entrar: function (u, c) {
      try { return window.dylanos.entrar(u, c) === true; } catch (e) { return false; }
    },
    entrar: function (u, c) {
      try { return window.dylanos.entrar(u, c) === true; } catch (e) { return false; }
    },
    accion: function (n) { try { window.dylanos.accion(n); } catch (e) {} },
    guardarPreferencia: function (d) {
      try { window.dylanos.guardarPreferencia(d); } catch (e) {}
    },
    ordenar: function (d) { try { window.dylanos.ordenar(d); } catch (e) {} }
  };
  if (!window.qt || !window.qt.webChannelTransport) return;
  function conectar() {
    var s = document.createElement('script');
    s.src = 'qrc:///qtwebchannel/qwebchannel.js';
    s.onload = function () {
      new QWebChannel(window.qt.webChannelTransport, function (canal) {
        window.dylanos = canal.objects.dylanos;
        // El estado puede haber cambiado mientras se abría el canal: se pide
        // el real con callback (asíncrono) y se pinta en cuanto llega.
        if (window.dylanos && typeof window.dylanos.estado === 'function') {
          window.dylanos.estado(function (texto) {
            try {
              var datos = JSON.parse(texto);
              if (window.dylanosAplicarEstado) window.dylanosAplicarEstado(datos);
            } catch (e) {}
          });
        }
        if (window.__dylanosListo) window.__dylanosListo(window.dylanos);
      });
    };
    // En DocumentCreation todavía no hay <head>: se usa documentElement, que
    // siempre existe, para que el script no se pierda por un null.
    (document.head || document.documentElement).appendChild(s);
  }
  if (document.head) conectar();
  else document.addEventListener('DOMContentLoaded', conectar, { once: true });
})();
"""
    # El estado inicial va en el propio texto del script (objeto literal, no
    # una cadena): así el tema tiene los datos reales en su primera evaluación,
    # sin esperar al canal.
    guion = guion.replace("__DATOS_INICIALES__", datos_iniciales)
    inyectado = QWebEngineScript()
    inyectado.setName("dylanos-login-puente")
    inyectado.setSourceCode(guion)
    # DocumentCreation: el tema encuentra el puente al ejecutarse, sin esperar
    # a que cargue el canal (el objeto global existe desde el primer instante).
    inyectado.setInjectionPoint(QWebEngineScript.DocumentCreation)
    inyectado.setWorldId(QWebEngineScript.MainWorld)
    inyectado.setRunsOnSubFrames(False)
    vista.page().scripts().insert(inyectado)

    def al_cargar(ok: bool) -> None:
        if not ok:
            print("No se pudo cargar la interfaz del login", file=sys.stderr)
            aplicacion.exit(3)
    vista.loadFinished.connect(al_cargar)

    protocolo = host.protocolo
    if protocolo is not None:
        def empujar_estado() -> None:
            vista.page().runJavaScript(
                "window.dylanosAplicarEstado && window.dylanosAplicarEstado("
                + json.dumps(host.datos_tema(), ensure_ascii=False) + ")")
        protocolo.accesoCorrecto.connect(lambda: vista.page().runJavaScript(
            "window.dylanosAccesoCorrecto && window.dylanosAccesoCorrecto()"))
        protocolo.accesoFallido.connect(lambda: vista.page().runJavaScript(
            "window.dylanosAccesoFallido && window.dylanosAccesoFallido("
            + json.dumps("Contraseña incorrecta") + ")"))
        protocolo.mensaje.connect(lambda texto: vista.page().runJavaScript(
            "window.dylanosAccesoFallido && window.dylanosAccesoFallido("
            + json.dumps(texto, ensure_ascii=False) + ")"))
        protocolo.capacidades.connect(lambda *_: QTimer.singleShot(50, empujar_estado))
        protocolo.nombreEquipo.connect(lambda *_: QTimer.singleShot(50, empujar_estado))

    vista.load(QUrl.fromLocalFile(str(indice)))

    if tamano:
        # En QA (offscreen) no hay pantalla real: el tamaño se fija a mano.
        vista.setFixedSize(*tamano)
        vista.show()
    else:
        vista.showFullScreen()

    if capturar:
        def guardar() -> None:
            # grab() no devuelve píxeles en todos los backends sin GPU; se usa
            # el mismo camino que la vista previa (printToPdf → PNG) cuando
            # grab() sale en blanco.
            imagen = vista.grab()
            if imagen.isNull() or imagen.width() == 0:
                print("No se pudo capturar la vista del login", file=sys.stderr)
            imagen.save(str(capturar))
            aplicacion.quit()
        QTimer.singleShot(3000, guardar)

    # El reloj cambia sin intervención: el tema lo pinta, pero el estado
    # completo (batería, red, disco) se empuja cada 15 s.
    refresco = QTimer()
    refresco.setInterval(15000)
    refresco.timeout.connect(lambda: vista.page().runJavaScript(
        "window.dylanosAplicarEstado && window.dylanosAplicarEstado("
        + json.dumps(host.datos_tema(), ensure_ascii=False) + ")"))
    refresco.start()

    signal.signal(signal.SIGTERM, lambda *_: aplicacion.quit())
    return aplicacion.exec()


if __name__ == "__main__":
    raise SystemExit(main())
