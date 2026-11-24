#!/usr/bin/env python3
"""Genera el index.html del tema desde el prototipo, con cambios verificados.

Las ediciones a mano sobre el HTML del prototipo son frágiles: un `</div>`
mal puesto descoloca todo el dibujo. Este script parte SIEMPRE del prototipo
original y aplica una lista cerrada de cambios, comprobando al final que el
número de etiquetas `<div>` sigue cuadrando. Así el tema se puede regenerar y
revisar sin sorpresas.

Uso:
  python3 scripts/lib/generar-tema-login.py            # regenera el tema
  python3 scripts/lib/generar-tema-login.py --check    # solo verifica
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROTOTIPO = ROOT / ".zwork/prototipo/index.html"
TEMA = ROOT / "themes/sddm/DylanOS-Crimson/web/index.html"

# --- piezas que se insertan ---------------------------------------------

FONT_Y_VARIABLES = """<style>
  /*
   * Inter va empaquetada: el login se dibuja antes de iniciar sesión, no hay
   * red garantizada y una hoja externa dejaría el tema con la fuente del
   * sistema (y otro dibujo). El woff2 es el mismo que servía Google Fonts.
   */
  @font-face{
    font-family:'Inter'; font-style:normal; font-weight:100 900; font-display:block;
    src:url('fonts/inter-latin.woff2') format('woff2');
  }
  :root{
    /*
     * El acento del prototipo, por nombre. Con estos valores el dibujo es el
     * original: los rgba(220,20,60,α) del prototipo se escriben como
     * rgba(var(--dylanos-primario-rgb),α), que con el triplete por defecto
     * produce exactamente el mismo color y el mismo alfa.
     */
    --dylanos-primario:#DC143C;
    --dylanos-primario-rgb:220,20,60;
    --dylanos-primario-hover:#ff2d3d;
    --crimson:var(--dylanos-primario);
    --black:#0A0A0A;
    --white:#FFFFFF;
    --gray:#1A1A1A;
    --light-gray:#B3B3B3;
  }
  /*
   * `--crimson` se redefine aquí: una propiedad personalizada que referencia a
   * otra se sustituye en el elemento donde se declara, así que si solo
   * estuviera en :root heredaría el carmesí ya calculado y el acento elegido
   * no llegaría a títulos ni iconos.
   */
  .theme-root{ --crimson:var(--dylanos-primario); }
  *{ box-sizing:border-box; }
"""

CAPA_PERSONALIZACION = """
  [data-hidden]{ display:none !important; }

  /*
   * Ajuste a la pantalla. El prototipo es un lienzo fijo de 1440×960; se
   * escala con transform (no con zoom, que reflowaría y movería las columnas)
   * y se centra. A 1440×960 el factor es 1 y no cambia un píxel.
   */
  #dylanos-fondo{
    position:fixed; inset:0; background:#000 center/cover no-repeat;
    background-image:url('assets/fondo-seleccionado.png');
    background-position:50% 30%;
  }
  #dylanos-escena{
    position:fixed; inset:0; display:flex; align-items:center; justify-content:center;
    overflow:hidden;
  }
  /* El lienzo no se encoge nunca: manda la escala del transform. */
  #dylanos-escena .theme-root{ transform-origin:center center; flex:0 0 auto; max-width:none; }

  /*
   * Capa de personalización. Inerte mientras el lienzo no lleve
   * data-dylanos="personalizado": sin personalizar no aplica ni una regla, y
   * el render es exactamente el del prototipo.
   *
   * `!important` es necesario: las columnas llevan `display:flex` en el
   * atributo style del prototipo, y un estilo en línea gana a cualquier hoja.
   */
  .theme-root[data-paneles="espejo"] #dylanos-columnas{ flex-direction:row-reverse !important; }
  .theme-root[data-paneles="solo-centro"] #dylanos-columna-izquierda,
  .theme-root[data-paneles="solo-centro"] #dylanos-columna-derecha{ display:none !important; }
  .theme-root[data-paneles="solo-centro"] #dylanos-columnas{ justify-content:center !important; }
  #dylanos-columna-centro{ width:420px; flex:0 0 auto; }

  /* Un widget que el usuario no elige no ocupa celda. */
  .theme-root #dylanos-columnas .glass-panel[data-oculto]{ display:none !important; }

  .theme-root[data-escala-reloj] #groupClock{
    transform:scale(var(--dylanos-reloj)); transform-origin:center top;
  }
  .theme-root[data-escala-acceso] #groupLogin{
    transform:scale(var(--dylanos-acceso)); transform-origin:center bottom;
  }

  /* Crimson Glass apagado: el mismo vidrio, sin desenfoque ni saturación. */
  .theme-root[data-glass="off"] .glass-panel{
    backdrop-filter:none !important; -webkit-backdrop-filter:none !important;
    background:linear-gradient(165deg, rgba(26,26,26,0.92) 0%, rgba(10,10,10,0.94) 100%);
  }

  /* Los derivados del acento, solo cuando hay personalización. */
  .theme-root[data-acento] .icon-btn.is-open{
    background:rgba(var(--dylanos-primario-rgb),0.22);
  }
  .theme-root[data-acento] .pw-input:focus{
    border-color:rgba(var(--dylanos-primario-rgb),0.65);
  }
  .theme-root[data-acento] .pw-input.is-error{
    border-color:rgba(var(--dylanos-primario-rgb),0.95);
    box-shadow:0 0 0 3px rgba(var(--dylanos-primario-rgb),0.28);
  }
  .theme-root[data-acento] .toggle.on{ background:var(--dylanos-primario); }
  .theme-root[data-acento] .unlock-btn:hover{ background:var(--dylanos-primario-hover); }

  /* Retrato real (~/.face) sobre la silueta: la silueta queda de respaldo. */
  .dylanos-retrato{
    position:absolute; inset:0; width:100%; height:100%; object-fit:cover;
    border-radius:50%;
  }
</style>"""

# (buscar, reemplazar) aplicados en orden sobre el HTML del prototipo.
CAMBIOS: list[tuple[str, str]] = [
    # --- fuente y acento -------------------------------------------------
    ("""<style>
  :root{
    --crimson:#DC143C;
    --black:#0A0A0A;
    --white:#FFFFFF;
    --gray:#1A1A1A;
    --light-gray:#B3B3B3;
  }
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap');
  *{ box-sizing:border-box; }
""", FONT_Y_VARIABLES),
    # --- capa de personalización al final de la hoja ---------------------
    ("  [data-hidden]{ display:none !important; }\n</style>", CAPA_PERSONALIZACION),
    # --- estructura: fondo, escena, ganchos de columnas -------------------
    ("""<body>

<div class="theme-root" id="themeRoot">

  <!-- Wallpaper: reemplazar assets/wallpaper.png por el fondo real -->
  <img class="cancel-invert" src="assets/wallpaper.png" alt="" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover; object-position:50% 30%;">""",
     """<body>

<!-- Fondo de pantalla detrás del lienzo; a 1440×960 el lienzo lo tapa entero. -->
<div id="dylanos-fondo"></div>
<div id="dylanos-escena">
<div class="theme-root" id="themeRoot">

  <!-- Fondo elegido en DylanOS Configuration (assets/fondo-seleccionado.png) -->
  <img class="cancel-invert" id="dylanos-wallpaper" src="assets/fondo-seleccionado.png" alt="" style="position:absolute; inset:0; width:100%; height:100%; object-fit:cover; object-position:50% 30%;">"""),
    ("""  <div style="position:relative; z-index:10; display:flex; align-items:flex-start; justify-content:space-between; padding:8px 36px 0; height:calc(960px - 80px);">

    <!-- Columna izquierda -->
    <div style="width:370px; display:flex; flex-direction:column; gap:16px;">""",
     """  <div id="dylanos-columnas" style="position:relative; z-index:10; display:flex; align-items:flex-start; justify-content:space-between; padding:8px 36px 0; height:calc(960px - 80px);">

    <!-- Columna izquierda -->
    <div id="dylanos-columna-izquierda" style="width:370px; display:flex; flex-direction:column; gap:16px;">"""),
    ("""    <!-- Columna central -->
    <div style="width:420px; height:858px; display:flex; flex-direction:column; align-items:center; justify-content:space-between;">""",
     """    <!-- Columna central -->
    <div id="dylanos-columna-centro" style="height:858px; display:flex; flex-direction:column; align-items:center; justify-content:space-between;">"""),
    ("""    <!-- Columna derecha -->
    <div style="width:370px; display:flex; flex-direction:column; gap:16px;">""",
     """    <!-- Columna derecha -->
    <div id="dylanos-columna-derecha" style="width:370px; display:flex; flex-direction:column; gap:16px;">"""),
    # --- cierre del lienzo y de la escena --------------------------------
    ("""</div>

<script src="script.js"></script>
</body>
</html>""",
     """</div>
</div>

<script src="js/dylanos-login.js"></script>
</body>
</html>"""),
    # --- retrato real ----------------------------------------------------
    ("""          <div style="position:relative; width:104px; height:104px; border-radius:50%; overflow:hidden; border:2.5px solid rgba(220,20,60,0.7); background:var(--gray); display:flex; align-items:center; justify-content:center;">
            <!-- Si hay foto real, poner <img class="cancel-invert" src="assets/avatar.png"> y quitar el SVG de abajo -->""",
     """          <div style="position:relative; width:104px; height:104px; border-radius:50%; overflow:hidden; border:2.5px solid rgba(var(--dylanos-primario-rgb),0.7); background:var(--gray); display:flex; align-items:center; justify-content:center;">
            <!-- Foto real de ~/.face; si no hay, queda la silueta de abajo. -->
            <img class="cancel-invert dylanos-retrato" id="dylanos-retrato" alt="" data-hidden>"""),
]

# Identificadores de los widgets del prototipo: (comentario, id).
WIDGETS = [
    ("Clima", "clima"),
    ("Próximo evento", "proximo-evento"),
    ("En reproducción", "reproduccion"),
    ("Sistema", "sistema"),
    ("Calendario", "calendario"),
    ("Recordatorios", "recordatorios"),
    ("Atajos", "atajos"),
]

# Atajos del prototipo: (id del botón, identificador de catálogo).
ATAJOS = [
    ("chipTheme", "tema"),
    ("chipDnd", "no-molestar"),
    ("chipWifi", "wifi"),
    ("chipBt", "bluetooth"),
]


def transformar(html: str) -> str:
    for buscar, reemplazar in CAMBIOS:
        if buscar not in html:
            raise SystemExit(f"No se encontró en el prototipo:\n{buscar[:120]!r}")
        html = html.replace(buscar, reemplazar, 1)

    # Los rgba del acento pasan a la variable (mismo color por defecto).
    html = re.sub(r"rgba\(220,\s*20,\s*60,\s*([0-9.]+)\)",
                  r"rgba(var(--dylanos-primario-rgb),\1)", html)
    html = html.replace("background:#ff2d3d;", "background:var(--dylanos-primario-hover);")

    # Identificador de cada tarjeta y de cada atajo.
    for comentario, ident in WIDGETS:
        buscar = f'<!-- {comentario} -->\n      <div class="glass-panel" style="border-radius:18px; padding:18px;">'
        reemplazar = (f'<!-- {comentario} -->\n'
                      f'      <div class="glass-panel" id="dylanos-widget-{ident}" '
                      f'style="border-radius:18px; padding:18px;">')
        if buscar not in html:
            raise SystemExit(f"No se encontró la tarjeta «{comentario}»")
        html = html.replace(buscar, reemplazar, 1)

    for boton, ident in ATAJOS:
        if f'id="{boton}"' not in html:
            raise SystemExit(f"No se encontró el atajo {boton}")
        html = html.replace(f'id="{boton}"', f'id="{boton}" data-atajo="{ident}"', 1)

    return html


def comprobar(html: str) -> None:
    """El HTML tiene que seguir cuadrado: mismo número de <div> y </div>."""
    if html.count("<div") != html.count("</div>"):
        raise SystemExit(f"Etiquetas descompensadas: {html.count('<div')} <div> "
                         f"frente a {html.count('</div>')} </div>")
    for pieza in ("id=\"dylanos-columnas\"", "id=\"dylanos-columna-izquierda\"",
                  "id=\"dylanos-columna-centro\"", "id=\"dylanos-columna-derecha\"",
                  "id=\"dylanos-escena\"", "js/dylanos-login.js",
                  "fonts/inter-latin.woff2"):
        if pieza not in html:
            raise SystemExit(f"Falta en el tema: {pieza}")
    if "assets/wallpaper.png" in html or "script.js" in html:
        raise SystemExit("El tema conserva rutas del prototipo sin migrar")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true",
                        help="no escribe: comprueba que el tema está al día")
    parser.add_argument("--prototipo", type=Path, default=PROTOTIPO)
    parser.add_argument("--salida", type=Path, default=TEMA)
    args = parser.parse_args(argv)

    if not args.prototipo.is_file():
        print(f"No se encontró el prototipo en {args.prototipo}", file=sys.stderr)
        return 2

    original = args.prototipo.read_text(encoding="utf-8")
    generado = transformar(original)
    comprobar(generado)

    if args.check:
        actual = args.salida.read_text(encoding="utf-8") if args.salida.is_file() else ""
        if actual != generado:
            print(f"{args.salida} no coincide con el prototipo transformado", file=sys.stderr)
            return 1
        print("El tema está al día")
        return 0

    args.salida.parent.mkdir(parents=True, exist_ok=True)
    args.salida.write_text(generado, encoding="utf-8")
    # El prototipo vive en .zwork; se conserva una copia junto al tema para
    # poder regenerar sin depender de la carpeta de trabajo.
    respaldo = args.salida.parent / "origen" / "index.html"
    if args.prototipo.resolve() != respaldo.resolve():
        respaldo.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args.prototipo, respaldo)
    print(f"Escrito {args.salida} ({len(generado)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
