#!/usr/bin/env python3
"""Genera capturas del login con un perfil de datos, para medir fidelidad.

Abre el tema en Chromium (Playwright), inyecta el perfil como
`window.DYLANOS_LOGIN` —igual que hace el host real por QWebChannel— y guarda
un PNG del tamaño exacto del lienzo del prototipo. Se usa en los tests y para
regenerar los artefactos de QA.

Uso:
  python3 scripts/lib/capturar-login.py --salida login.png
  python3 scripts/lib/capturar-login.py --perfil perfil.json --salida login.png
  python3 scripts/lib/capturar-login.py --variante sencilla --salida 3-widgets.png
  python3 scripts/lib/capturar-login.py --ancho 1920 --alto 1080 --salida fhd.png
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMA = ROOT / "themes/sddm/DylanOS-Crimson/web"
PERFIL_PROTOTIPO = ROOT / "artifacts/login-manager-qa/captura/perfil-prototipo.json"

# Variantes de composición: lo que pide el usuario en tres pasos.
VARIANTES = {
    "completa": {
        "widgets": {
            "izquierda": ["clima", "proximo-evento", "reproduccion", "sistema"],
            "derecha": ["calendario", "recordatorios", "atajos"],
        },
        "atajos": ["tema", "no-molestar", "wifi", "bluetooth"],
        "posicion_paneles": "clasica",
    },
    "sencilla": {
        "widgets": {"izquierda": ["sistema"], "derecha": ["calendario", "atajos"]},
        "atajos": ["tema", "no-molestar", "wifi"],
        "posicion_paneles": "clasica",
    },
    "minima": {
        "widgets": {"izquierda": [], "derecha": []},
        "atajos": [],
        "posicion_paneles": "solo-centro",
    },
}

# Ejecuta el tema con el perfil inyectado. El host real hace lo mismo, pero por
# QWebChannel; aquí basta con el objeto global para poder medir en Chromium.
# El perfil se asigna a window.__PERFIL__ antes de este bloque: sustituir la
# expresión entera dejaría `window.{...}` y el script no compilaría.
ARRANQUE = """
(function () {
  const perfil = window.__PERFIL__;
  window.DYLANOS_LOGIN = {
    iniciar: function () { return perfil.datos; },
    alCambiarEstado: function () {},
    entrar: function () { return false; },
    accion: function () {},
    guardarPreferencia: function () {},
    ordenar: function () {}
  };
})();
"""


def perfil_de_variante(nombre: str) -> dict:
    """Perfil del prototipo adaptado a una de las tres variantes."""
    base = json.loads(PERFIL_PROTOTIPO.read_text(encoding="utf-8"))
    datos = dict(base["datos"])
    variante = VARIANTES[nombre]
    datos["Atajos"] = variante["atajos"]
    datos["PosicionPaneles"] = variante["posicion_paneles"]
    datos["Widgets"] = variante["widgets"]
    datos["_variante"] = nombre
    return {"personalizado": nombre != "completa", "datos": datos}


def cargar_perfil(ruta: Path | None, variante: str | None) -> dict:
    if ruta is not None:
        return json.loads(ruta.read_text(encoding="utf-8"))
    if variante is not None:
        return perfil_de_variante(variante)
    base = json.loads(PERFIL_PROTOTIPO.read_text(encoding="utf-8"))
    # El perfil del prototipo no declara selección: se usan los 7 widgets del
    # prototipo, que es justo lo que reproduce el dibujo original.
    base["datos"].setdefault("Widgets", VARIANTES["completa"]["widgets"])
    return base


def capturar(tema: Path, salida: Path, perfil: dict, ancho: int, alto: int) -> int:
    from playwright.sync_api import sync_playwright

    indice = (tema / "index.html").resolve()
    if not indice.is_file():
        print(f"No se encontró el tema en {indice}", file=sys.stderr)
        return 2

    guion = ("window.__PERFIL__ = " + json.dumps(perfil, ensure_ascii=False) + ";\n"
             + ARRANQUE)
    salida.parent.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as playwright:
        navegador = playwright.chromium.launch()
        pagina = navegador.new_page(viewport={"width": ancho, "height": alto},
                                    device_scale_factor=1)
        pagina.add_init_script(guion)
        pagina.goto(indice.as_uri())
        pagina.wait_for_function("document.documentElement.dataset.listo === '1'",
                                 timeout=15000)
        # Las animaciones de entrada del prototipo duran 160 ms: se espera a que
        # terminen para que la captura sea reproducible.
        pagina.wait_for_timeout(600)
        pagina.screenshot(path=str(salida))
        navegador.close()
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--salida", type=Path, required=True)
    parser.add_argument("--perfil", type=Path)
    parser.add_argument("--variante", choices=sorted(VARIANTES))
    parser.add_argument("--tema", type=Path, default=TEMA)
    parser.add_argument("--ancho", type=int, default=1440)
    parser.add_argument("--alto", type=int, default=960)
    args = parser.parse_args(argv)

    if args.perfil and args.variante:
        parser.error("usa --perfil o --variante, no los dos")

    perfil = cargar_perfil(args.perfil, args.variante)
    return capturar(args.tema, args.salida, perfil, args.ancho, args.alto)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
