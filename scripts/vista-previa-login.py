#!/usr/bin/env python3
"""Vista previa del DylanOS Login Manager.

Muestra cómo queda la pantalla de acceso con la configuración actual y los
datos reales de este equipo, sin reiniciar ni bloquear la sesión.

Tres modos, en este orden de preferencia:

  ventana   El propio login (QtWebEngine) en una ventana. Es lo más fiel: es
            el mismo motor que se usa al arrancar. Necesita PySide6.
  navegador Abre el tema en el navegador del sistema con los datos ya
            inyectados. Sirve para cualquier equipo sin dependencias.
  imagen    Guarda un PNG de la vista previa y termina. Útil por SSH o para
            adjuntarlo en un informe.

Ejemplos:

  python3 scripts/vista-previa-login.py
  python3 scripts/vista-previa-login.py --modo imagen --salida /tmp/login.png
  python3 scripts/vista-previa-login.py --ajustes /tmp/prueba.json --ancho 1920 --alto 1080
  python3 scripts/vista-previa-login.py --tema themes/sddm/DylanOS-Crimson/web
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import webbrowser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMA_POR_DEFECTO = ROOT / "themes/sddm/DylanOS-Crimson/web"
HOST = ROOT / "apps/dylanos-login-manager/host"
DATOS = HOST / "datos_sistema.py"


def cargar_datos():
    """Carga el módulo de datos del sistema (no necesita Qt)."""
    sys.path.insert(0, str(HOST))
    import datos_sistema  # noqa: PLC0415
    return datos_sistema


def hay_qt() -> bool:
    try:
        import PySide6  # noqa: F401, PLC0415
        return True
    except ImportError:
        return False


def navegadores_disponibles() -> list[str]:
    candidatos = ["xdg-open", "firefox", "firefox-esr", "brave-browser",
                  "google-chrome", "chromium", "epiphany"]
    return [c for c in candidatos if shutil.which(c)]


# --- modo imagen ---------------------------------------------------------

def generar_imagen(tema: Path, salida: Path, ancho: int, alto: int,
                   ajustes: Path | None) -> int:
    """Pide al host del greeter una captura del tema."""
    host = HOST / "dylanos-login-greeter.py"
    if not host.is_file():
        print(f"No se encontró el host del login en {host}", file=sys.stderr)
        return 2

    entorno = os.environ.copy()
    entorno.setdefault("QT_QPA_PLATFORM", "offscreen")
    entorno.setdefault("QTWEBENGINE_DISABLE_SANDBOX", "1")
    entorno.setdefault("QTWEBENGINE_CHROMIUM_FLAGS",
                       "--no-sandbox --disable-gpu --single-process")
    if ajustes:
        entorno["DYLANOS_LOGIN_AJUSTES"] = str(ajustes.resolve())

    orden = [sys.executable, str(host), "--preview", "--theme", str(tema),
             "--screenshot", str(salida), "--size", f"{ancho}x{alto}"]
    try:
        resultado = subprocess.run(orden, env=entorno, capture_output=True,
                                   text=True, timeout=90, check=False)
    except (OSError, subprocess.SubprocessError) as error:
        print(f"No se pudo ejecutar la vista previa: {error}", file=sys.stderr)
        return 3

    if salida.is_file() and salida.stat().st_size > 0:
        print(f"Captura guardada en {salida}")
        return 0

    print("La captura no se generó.", file=sys.stderr)
    errores = [linea for linea in resultado.stderr.splitlines()
               if "js:" in linea or "Error" in linea]
    for linea in errores[:8]:
        print(f"  {linea}", file=sys.stderr)
    if not hay_qt():
        print("Falta PySide6: instala python3-pyside6.qtwebenginewidgets "
              "o usa --modo navegador.", file=sys.stderr)
    return 4


# --- modo ventana --------------------------------------------------------

def abrir_ventana(tema: Path, ancho: int, alto: int, ajustes: Path | None) -> int:
    """Abre el login real en una ventana normal (no a pantalla completa)."""
    host = HOST / "dylanos-login-greeter.py"
    entorno = os.environ.copy()
    if ajustes:
        entorno["DYLANOS_LOGIN_AJUSTES"] = str(ajustes.resolve())
    # Sin QT_QPA_PLATFORM: se usa la sesión gráfica real del usuario.
    entorno.pop("QT_QPA_PLATFORM", None)
    orden = [sys.executable, str(host), "--preview", "--theme", str(tema),
             "--size", f"{ancho}x{alto}"]
    print("Abriendo la vista previa en una ventana… (ciérrala para terminar)")
    try:
        return subprocess.call(orden, env=entorno)
    except OSError as error:
        print(f"No se pudo abrir la ventana: {error}", file=sys.stderr)
        return 3


# --- modo navegador ------------------------------------------------------

def configuracion_efectiva(datos, tema: Path, ajustes: Path | None) -> dict:
    """Configuración que se va a dibujar.

    Si el equipo todavía no tiene `/etc/dylanos/login-manager.json` (nadie ha
    personalizado el login), se usa la plantilla del tema: así la vista previa
    muestra el login por defecto, no un tema sin configuración.
    """
    if ajustes is not None:
        return json.loads(Path(ajustes).read_text(encoding="utf-8"))
    del_sistema = datos.leer_ajustes()
    if del_sistema:
        return del_sistema
    plantilla = tema / "config" / "variables.json"
    try:
        return json.loads(plantilla.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def generar_pagina(tema: Path, ajustes: Path | None) -> Path:
    """Escribe una copia del tema con los datos de este equipo dentro.

    El tema carga `js/dylanos-perfil-prototipo.js` solo para las capturas de
    fidelidad; aquí se genera un perfil con los datos reales y se inyecta
    antes del documento, igual que hace el host.
    """
    datos = cargar_datos()
    estado = datos.estado_sistema()
    configuracion = configuracion_efectiva(datos, tema, ajustes)

    carpeta = Path(tempfile.mkdtemp(prefix="dylanos-login-vista-"))
    destino = carpeta / "web"
    shutil.copytree(tema, destino, symlinks=False)

    perfil = (
        "window.DYLANOS_LOGIN_PERFIL = {\n"
        f"  configuracion: function () {{ return {json.dumps(configuracion, ensure_ascii=False)}; }},\n"
        f"  estadoDelSistema: function () {{ return {json.dumps(estado, ensure_ascii=False)}; }},\n"
        "  alCambiarEstado: function () {},\n"
        "  entrar: function () { return false; },\n"
        "  accion: function () {},\n"
        "  guardarPreferencia: function () {},\n"
        "  ordenar: function () {}\n"
        "};\n"
    )
    (destino / "js" / "dylanos-perfil-vista.js").write_text(perfil, encoding="utf-8")

    indice = destino / "index.html"
    html = indice.read_text(encoding="utf-8")
    html = html.replace('<script src="js/dylanos-datos.js"></script>',
                        '<script src="js/dylanos-datos.js"></script>\n'
                        '<script src="js/dylanos-perfil-vista.js"></script>')
    indice.write_text(html, encoding="utf-8")
    return indice


def abrir_navegador(indice: Path, ancho: int, alto: int) -> int:
    navegadores = navegadores_disponibles()
    if not navegadores:
        print("No hay navegador disponible. Usa --modo imagen.", file=sys.stderr)
        print(f"El tema con tus datos está en: {indice}", file=sys.stderr)
        return 5

    url = indice.as_uri()
    # Los navegadores basados en Firefox/Chromium aceptan el tamaño de ventana
    # por línea de órdenes; se prefiere uno concreto para poder fijarlo.
    for nombre in ("firefox", "firefox-esr", "brave-browser", "google-chrome",
                   "chromium", "epiphany"):
        if not shutil.which(nombre):
            continue
        if nombre.startswith("firefox"):
            orden = [nombre, "--new-window", f"--width={ancho}", f"--height={alto}", url]
        elif nombre == "epiphany":
            orden = [nombre, url]
        else:
            orden = [nombre, f"--window-size={ancho},{alto}", "--new-window", url]
        print(f"Abriendo la vista previa en {nombre}…")
        try:
            subprocess.Popen(orden, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
            return 0
        except OSError:
            continue

    print("Abriendo con el navegador predeterminado…")
    if webbrowser.open(url):
        return 0
    print(f"Abre esta ruta a mano: {indice}", file=sys.stderr)
    return 5


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Ver cómo queda el DylanOS Login Manager con tus datos.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__)
    parser.add_argument("--modo", choices=["auto", "ventana", "navegador", "imagen"],
                        default="auto",
                        help="auto elige ventana o navegador según lo disponible")
    parser.add_argument("--salida", type=Path,
                        help="PNG de destino en modo imagen")
    parser.add_argument("--ancho", type=int, default=1440, help="ancho en píxeles")
    parser.add_argument("--alto", type=int, default=960, help="alto en píxeles")
    parser.add_argument("--ajustes", type=Path,
                        help="usar otra configuración en vez de /etc/dylanos/login-manager.json")
    parser.add_argument("--tema", type=Path, default=TEMA_POR_DEFECTO,
                        help="carpeta del tema (por defecto, el del repositorio)")
    parser.add_argument("--datos", action="store_true",
                        help="mostrar los datos que se van a dibujar y salir")
    args = parser.parse_args()

    tema = args.tema.resolve()
    if not (tema / "index.html").is_file():
        print(f"No hay tema en {tema}", file=sys.stderr)
        return 2
    if args.ajustes and not args.ajustes.is_file():
        print(f"No existe el fichero de ajustes: {args.ajustes}", file=sys.stderr)
        return 2

    if args.datos:
        datos = cargar_datos()
        estado = datos.estado_sistema()
        resumen = {clave: estado[clave] for clave in
                   ("usuario", "equipo", "avatar", "bateria", "almacenamiento",
                    "red", "capacidades", "version")}
        print(json.dumps(resumen, indent=2, ensure_ascii=False))
        return 0

    modo = args.modo
    if modo == "auto":
        modo = "ventana" if hay_qt() else "navegador"
        if modo == "navegador" and not navegadores_disponibles():
            modo = "imagen"
        print(f"Modo elegido: {modo}")

    if modo == "imagen":
        salida = args.salida or (Path.cwd() / "login-dylanos.png")
        return generar_imagen(tema, salida, args.ancho, args.alto, args.ajustes)
    if modo == "ventana":
        if not hay_qt():
            print("Falta PySide6 para la ventana. Usa --modo navegador o --modo imagen.",
                  file=sys.stderr)
            return 2
        return abrir_ventana(tema, args.ancho, args.alto, args.ajustes)

    indice = generar_pagina(tema, args.ajustes)
    return abrir_navegador(indice, args.ancho, args.alto)


if __name__ == "__main__":
    raise SystemExit(main())
