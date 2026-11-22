#!/usr/bin/env python3
"""Extrae el prototipo "DylanOS Login Manager" a un tema SDDM servible.

El prototipo es un HTML empaquetado: un manifiesto con los assets en base64,
una plantilla con el marcado y los estilos, y el runtime que monta el
componente. Este script separa el paquete en ficheros con nombres
semánticos, sin tocar el marcado ni los estilos: la única diferencia con el
original son las rutas de los recursos, que pasan de UUID a ruta local.

El resultado se verifica con `scripts/tests/test_login_manager.py`, que exige
que el HTML (fuera del bloque de datos) y los estilos sigan siendo idénticos
al original y que las capturas coincidan píxel a píxel.
"""
from __future__ import annotations

import argparse
import base64
import gzip
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SALIDA = ROOT / "themes/sddm/DylanOS-Crimson/web"

# Nombres estables de los assets del prototipo. El UUID es el identificador
# del paquete original; el nombre semántico es el que usa el tema.
ASSETS = {
    "9b8aeba1-4bbd-40fc-b97b-d21b53873c0b": ("assets/fondo-seleccionado.png", "image/png"),
    "f3f2f3af-3aed-4d75-8fb5-a8ce1f3b9bd7": ("assets/logo-dylanos.png", "image/png"),
    "542ec6bb-939a-4430-9977-2208a4c2fd20": ("vendor/dc-runtime.js", "text/javascript"),
    "2e01558d-ff3f-4f62-b342-871eb2436a98": ("vendor/react.production.min.js", "text/javascript"),
    "2afc9e47-bab9-4ff5-994f-fa3cbf27c585": ("vendor/react-dom.production.min.js", "text/javascript"),
    "72aaae2e-5a5e-45a6-b22d-8b075863ec5b": ("fonts/inter-latin.woff2", "font/woff2"),
}

# Sustituciones en la cabecera: el runtime carga React desde un CDN y el
# prototipo pide 36 subconjuntos de Inter a Google. Un greeter no tiene red
# (y no debe pedirla), así que se sirven los mismos bytes en local.
CABECERA = """<script src="vendor/react.production.min.js"></script>
<script src="vendor/react-dom.production.min.js"></script>
<script src="vendor/dc-runtime.js"></script>"""


def leer_paquete(origen: Path) -> tuple[dict, str, str]:
    texto = origen.read_text(encoding="utf-8")

    def bloque(tipo: str) -> str:
        patron = r'<script type="%s">\s*(.*?)\s*</script>' % re.escape(tipo)
        hallado = re.search(patron, texto, re.S)
        if not hallado:
            raise SystemExit(f"El paquete no contiene el bloque {tipo}")
        return hallado.group(1)

    manifiesto = json.loads(bloque("__bundler/manifest"))
    plantilla = json.loads(bloque("__bundler/template"))
    return manifiesto, plantilla, texto


def escribir_assets(manifiesto: dict, destino: Path) -> dict[str, str]:
    huellas = {}
    for uuid, (ruta, tipo) in ASSETS.items():
        datos = base64.b64decode(manifiesto[uuid]["data"])
        if manifiesto[uuid].get("compressed"):
            try:
                datos = gzip.decompress(datos)
            except OSError:
                pass
        archivo = destino / ruta
        archivo.parent.mkdir(parents=True, exist_ok=True)
        archivo.write_bytes(datos)
        huellas[ruta] = hashlib.sha256(datos).hexdigest()
        if manifiesto[uuid]["mime"] not in (tipo, "text/javascript"):
            raise SystemExit(f"MIME inesperado para {uuid}: {manifiesto[uuid]['mime']}")
    return huellas


def localizar_fuentes(plantilla: str) -> str:
    """Sirve en local la tipografía Inter que usa el texto latino.

    El paquete incluye el woff2 del subconjunto latino (idéntico byte a byte
    al que servía Google) y usa ese mismo archivo para los seis pesos. Los
    demás @font-face solo cubren alfabetos cirílico, griego y vietnamita:
    se retiran para que el greeter no pida nada a la red, y esos caracteres
    pasan a resolverse con las fuentes del sistema. El texto latino se
    rasteriza con los mismos bytes, así que no cambia ni un píxel.
    """
    def conservar(bloque: re.Match[str]) -> str:
        cuerpo = bloque.group(0)
        if "fonts.gstatic.com" in cuerpo:
            return ""
        return cuerpo.replace(
            'url("72aaae2e-5a5e-45a6-b22d-8b075863ec5b")',
            'url("fonts/inter-latin.woff2")')

    return re.sub(r"@font-face\s*\{.*?\}", conservar, plantilla, flags=re.S)


def construir_html(plantilla: str) -> str:
    html = plantilla
    html = html.replace('<script src="542ec6bb-939a-4430-9977-2208a4c2fd20"></script>', CABECERA)
    html = html.replace('src="9b8aeba1-4bbd-40fc-b97b-d21b53873c0b"', 'src="assets/fondo-seleccionado.png"')
    html = html.replace('src="f3f2f3af-3aed-4d75-8fb5-a8ce1f3b9bd7"', 'src="assets/logo-dylanos.png"')
    # El puente de datos se carga antes que el runtime para que el componente
    # ya encuentre los valores reales cuando evalúe su clase.
    html = html.replace("</head>", '<script src="js/dylanos-datos.js"></script>\n</head>')
    return html


def main() -> int:
    parser = argparse.ArgumentParser(description="Extrae el prototipo del login manager")
    parser.add_argument("origen", type=Path, help="HTML empaquetado del prototipo")
    parser.add_argument("--destino", type=Path, default=SALIDA)
    args = parser.parse_args()

    manifiesto, plantilla, _ = leer_paquete(args.origen)
    destino = args.destino
    destino.mkdir(parents=True, exist_ok=True)

    huellas = escribir_assets(manifiesto, destino)
    html = construir_html(localizar_fuentes(plantilla))
    (destino / "index.html").write_text(html, encoding="utf-8")

    # Copia del original: la usan el test de fidelidad y quien audite el tema.
    referencia = destino / "origen"
    referencia.mkdir(exist_ok=True)
    (referencia / "plantilla.html").write_text(plantilla, encoding="utf-8")

    registro = {
        "origen": args.origen.name,
        "plantilla_sha256": hashlib.sha256(plantilla.encode("utf-8")).hexdigest(),
        "html_sha256": hashlib.sha256(html.encode("utf-8")).hexdigest(),
        "recursos": huellas,
    }
    (destino / "procedencia.json").write_text(
        json.dumps(registro, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Extraído en {destino.relative_to(ROOT)} ({len(huellas)} recursos)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
