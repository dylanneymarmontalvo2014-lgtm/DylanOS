#!/usr/bin/env python3
"""Instalador nativo de DylanOS.

El instalador es una aplicación de escritorio propia: una ventana Qt WebEngine
con su icono, título y entrada de escritorio que muestra la interfaz React del
instalador servida por el backend REST local. No se abre ningún navegador
externo (nada de Firefox ni xdg-open).

La ventana se abre en modo normal con la barra de título del sistema, que
aporta los botones de menú (minimizar, maximizar/ajustar tamaño y cerrar) y
permite redimensionar. La barra decorativa de la interfaz React se oculta
para no duplicar esos controles.

Uso:
    dylanos-installer              # ventana con botones de menú (medio live)
    dylanos-installer --fullscreen # pantalla completa tipo quiosco (opcional)
    dylanos-installer --smoke      # valida que la interfaz carga y sale (QA)
"""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

BACKEND = Path(__file__).resolve().parents[1] / "backend" / "server.py"
PORT = 8088
URL = f"http://127.0.0.1:{PORT}"
# Ruta compartida con el backend (que puede ejecutarse como root) para poder
# cerrar la ventana cuando la interfaz pide reiniciar o salir.
PID_FILE = Path("/tmp/dylanos-installer-gui.pid")


def port_open(port=PORT, host="127.0.0.1", timeout=0.4):
    """True si el backend ya está escuchando en el puerto indicado."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(timeout)
        return sock.connect_ex((host, port)) == 0


def launch_backend(port=PORT, timeout=25.0):
    """Arranca el backend REST local si no está activo; devuelve el proceso.

    Reutiliza un backend ya en marcha (por ejemplo lanzado por el arranque de
    la sesión live) y devuelve None en ese caso.
    """
    if port_open(port):
        return None
    if not BACKEND.is_file():
        raise SystemExit(f"Backend del instalador no encontrado: {BACKEND}")
    if os.geteuid() == 0:
        command = ["/usr/bin/python3", str(BACKEND)]
    elif subprocess.run(["sudo", "-n", "true"], capture_output=True).returncode == 0:
        command = ["sudo", "-n", "/usr/bin/python3", str(BACKEND)]
    else:
        command = ["/usr/bin/python3", str(BACKEND)]
    process = subprocess.Popen(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if port_open(port):
            return process
        if process.poll() is not None:
            raise SystemExit("El backend del instalador terminó de forma inesperada.")
        time.sleep(0.2)
    process.terminate()
    raise SystemExit("El backend del instalador no respondió a tiempo.")


def write_pid_file():
    """Registra el PID de la ventana para que el backend pueda cerrarla."""
    try:
        PID_FILE.parent.mkdir(parents=True, exist_ok=True)
        PID_FILE.write_text(f"{os.getpid()}\n", encoding="utf-8")
    except OSError:
        pass


def clear_pid_file():
    try:
        if PID_FILE.read_text(encoding="utf-8").strip() == str(os.getpid()):
            PID_FILE.unlink()
    except OSError:
        pass


def main():
    parser = argparse.ArgumentParser(description="Instalador nativo de DylanOS")
    parser.add_argument("--url", default=URL, help=f"Interfaz a mostrar (por defecto {URL})")
    parser.add_argument("--windowed", action="store_true", help="Ventana normal (ya es el comportamiento por defecto)")
    parser.add_argument("--fullscreen", action="store_true", help="Pantalla completa tipo quiosco (oculta los botones de menú del sistema)")
    parser.add_argument("--width", type=int, default=1180)
    parser.add_argument("--height", type=int, default=780)
    parser.add_argument("--smoke", action="store_true", help="Comprueba que la interfaz carga y sale (QA)")
    parser.add_argument("--screenshot", type=Path, help="Guarda una captura de la ventana (QA)")
    parser.add_argument("--timeout", type=float, default=45.0, help="Espera máxima de la interfaz (QA)")
    args = parser.parse_args()

    backend_process = launch_backend()
    write_pid_file()

    from PySide6.QtCore import QTimer, Qt, QUrl
    from PySide6.QtGui import QIcon
    from PySide6.QtWebEngineCore import QWebEngineSettings
    from PySide6.QtWebEngineWidgets import QWebEngineView
    from PySide6.QtWidgets import QApplication

    # Qt WebEngine necesita contextos OpenGL compartidos antes de crear la app.
    QApplication.setAttribute(Qt.ApplicationAttribute.AA_ShareOpenGLContexts)
    app = QApplication(sys.argv)
    app.setOrganizationName("DylanOS")
    app.setApplicationName("dylanos-installer")
    app.setApplicationDisplayName("Instalar DylanOS")
    app.setDesktopFileName("dylanos-installer")
    icon = QIcon.fromTheme("distributor-logo-dylanos")
    app.setWindowIcon(icon)

    class InstallerView(QWebEngineView):
        """Ventana del instalador; Esc abandona la pantalla completa."""

        def keyPressEvent(self, event):
            if event.key() == Qt.Key.Key_Escape and self.isFullScreen():
                self.showNormal()
                return
            super().keyPressEvent(event)

        def closeEvent(self, event):
            super().closeEvent(event)
            app.quit()

    view = InstallerView()
    view.setWindowTitle("Instalar DylanOS")
    view.setWindowIcon(icon)
    view.setMinimumSize(900, 600)
    view.resize(args.width, args.height)

    settings = view.page().settings()
    settings.setAttribute(QWebEngineSettings.WebAttribute.ScrollAnimatorEnabled, True)
    settings.setAttribute(QWebEngineSettings.WebAttribute.LocalContentCanAccessRemoteUrls, True)
    # Sin menú contextual del navegador: la ventana es una app de escritorio.
    view.setContextMenuPolicy(Qt.ContextMenuPolicy.NoContextMenu)

    def fail(code, message):
        print(message, file=sys.stderr, flush=True)
        clear_pid_file()
        app.exit(code)

    def quit_now(*_):
        app.quit()

    import signal
    signal.signal(signal.SIGTERM, lambda *_: QTimer.singleShot(0, quit_now))
    signal.signal(signal.SIGINT, lambda *_: QTimer.singleShot(0, quit_now))

    if args.smoke or args.screenshot:
        def validate(ok):
            if not ok:
                fail(4, "El instalador no pudo cargar la interfaz en la ventana nativa.")
                return

            def finish(components):
                count = int(components or 0)
                if count <= 0:
                    fail(5, "La interfaz del instalador está vacía.")
                    return

                def done():
                    print(f"Instalador nativo OK: ventana Qt WebEngine con {count} componentes en pantalla.")
                    clear_pid_file()
                    app.exit(0)

                if args.screenshot:
                    def grab():
                        args.screenshot.parent.mkdir(parents=True, exist_ok=True)
                        if not view.grab().save(str(args.screenshot)):
                            fail(2, "No se pudo guardar la captura de la ventana.")
                            return
                        done()

                    # Espera a que el compositor pinte la interfaz antes de capturar.
                    QTimer.singleShot(1500, grab)
                    return
                done()

            view.page().runJavaScript(
                "document.querySelector('#root') ? document.querySelector('#root').children.length : 0",
                finish,
            )

        view.loadFinished.connect(validate)
        QTimer.singleShot(int(args.timeout * 1000), lambda: fail(6, "Tiempo de espera agotado al cargar el instalador."))

    # La interfaz React dibuja en su parte superior una barra decorativa con
    # botones de ventana falsos; la ventana nativa ya tiene minimizar,
    # maximizar/ajustar tamaño y cerrar en su barra de título, así que se
    # oculta esa barra para no duplicar controles.
    def hide_decoration_buttons(ok):
        if not ok:
            return
        view.page().runJavaScript(
            "(function(){var bar=document.querySelector('#root > div > div');"
            "if(bar&&bar.querySelector('button[title=\"Cerrar\"]')){bar.style.display='none';}})();"
        )

    view.loadFinished.connect(hide_decoration_buttons)
    view.load(QUrl(args.url))
    view.show()
    # Ventana normal por defecto: la barra de título del sistema aporta los
    # botones de menú (minimizar, maximizar y cerrar) y permite redimensionar.
    # --fullscreen es opcional, solo para modo quiosco.
    if args.fullscreen:
        view.showFullScreen()

    result = app.exec()
    clear_pid_file()
    if backend_process is not None and backend_process.poll() is None:
        backend_process.terminate()
        try:
            backend_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            backend_process.kill()
    del view
    return result


if __name__ == "__main__":
    sys.exit(main())
