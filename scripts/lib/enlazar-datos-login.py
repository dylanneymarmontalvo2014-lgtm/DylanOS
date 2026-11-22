#!/usr/bin/env python3
"""Enlaza el prototipo del login manager con datos reales sin tocar su gráfica.

El prototipo ya está parametrizado: sus textos y sus tres listas (pronóstico,
recordatorios, atajos) se alimentan de props. Este script hace el enlace
mínimo necesario para que esas props sean datos reales:

- Renombra las variables del prototipo a nombres con significado para el
  usuario (`{{storageFree}}` → `{{almacenamientoLibre}}`, `r.label` →
  `r.texto`…). Los estilos y las etiquetas no se tocan.
- Envuelve en `sc-if` los widgets que pueden no tener datos, para que se
  oculten en lugar de mostrar cifras inventadas.
- Añade un bloque alternativo de atajos, invisible con la configuración por
  defecto, que permite al usuario elegir sus cuatro atajos entre el catálogo.

Con la configuración por defecto el DOM resultante es el mismo del prototipo:
el test de fidelidad exige diff 0 contra la captura de referencia.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMA = ROOT / "themes/sddm/DylanOS-Crimson/web"


CAPA_VISUAL = """<style data-dylanos-visual>
  /*
   * Capa de personalización. Está inerte mientras el tema no tenga la marca
   * `data-dylanos="personalizado"` en `.theme-root`: sin personalización no
   * aplica ni una regla y el render es exactamente el del prototipo.
   */
  /* Valores por defecto = los del prototipo: sin personalización no cambia
     ni un píxel, pero el acento puede gobernar todos estos textos. */
  .theme-root {
    --dylanos-primario: #dc143c;
    --dylanos-primario-claro: #ff5a66;
    --dylanos-primario-fuerte: #ff3b48;
    --dylanos-primario-control: #e11d2a;
    --dylanos-primario-hover: #ff2d3d;
  }
  .theme-root[data-escala-reloj] .dylanos-reloj-bloque {
    transform: scale(var(--dylanos-reloj));
    transform-origin: center top;
  }
  .theme-root[data-escala-acceso] .dylanos-acceso-bloque {
    transform: scale(var(--dylanos-acceso));
    transform-origin: center bottom;
  }
  .theme-root[data-glass="off"] .glass-panel {
    backdrop-filter: none !important;
    -webkit-backdrop-filter: none !important;
    background: linear-gradient(165deg, rgba(24,14,15,0.92) 0%, rgba(12,8,9,0.94) 100%);
  }
  .theme-root[data-paleta] .icon-btn.is-open {
    background: color-mix(in srgb, var(--dylanos-primario) 22%, transparent);
    color: var(--dylanos-primario-claro);
  }
  .theme-root[data-paleta] .pw-input:focus {
    border-color: color-mix(in srgb, var(--dylanos-primario) 65%, transparent);
  }
  .theme-root[data-paleta] .pw-input.is-error {
    border-color: var(--dylanos-primario-claro);
    box-shadow: 0 0 0 3px color-mix(in srgb, var(--dylanos-primario) 28%, transparent);
  }
  .theme-root[data-paleta] .toggle.on { background: var(--dylanos-primario); }
  .theme-root[data-paleta] .dylanos-titulo { color: var(--dylanos-primario); }
  .dylanos-chip {
    width: auto; height: auto; flex-direction: column; gap: 8px;
    padding: 14px 0; border-radius: 14px; background: rgba(255,255,255,0.05);
  }
  .dylanos-chip.activo {
    background: color-mix(in srgb, var(--dylanos-primario) 20%, transparent);
    color: var(--dylanos-primario-claro);
  }
  .dylanos-casilla {
    width: 16px; height: 16px; border-radius: 50%; flex: 0 0 auto;
    display: flex; align-items: center; justify-content: center;
  }
</style>
"""


def exigir(html: str, texto: str) -> None:
    if texto not in html:
        raise SystemExit(f"No se encontró en el prototipo: {texto[:70]!r}")


def insertar_capa(html: str) -> str:
    if "data-dylanos-visual" in html:
        return html
    exigir(html, "</helmet>")
    return html.replace("</helmet>", CAPA_VISUAL + "</helmet>")


def fin_de_bloque(html: str, inicio: int) -> int:
    """Índice del `</div>` que cierra el bloque abierto en `inicio`.

    Recorre etiquetas reales en orden, no subcadenas: `<div` también aparece
    dentro de `<divisor>` u otros nombres, y contar por prefijo cerraba
    bloques antes de tiempo (el panel de atajos perdía su contenido).
    """
    apertura = html.index("<div", inicio)
    profundidad = 0
    patron = re.compile(r"<(/?)div\b", re.I)
    for hallado in patron.finditer(html, apertura):
        if hallado.group(1):
            if profundidad == 0:
                return hallado.start()
            profundidad -= 1
        else:
            profundidad += 1
    raise SystemExit("Bloque sin cierre")


def condicionar(html: str, comentario: str, condicion: str) -> str:
    """Envuelve el widget en `sc-if` para que se oculte si le faltan datos."""
    apertura = f'{comentario}\n      <div class="glass-panel"'
    envuelto = f'{comentario}\n      <sc-if value="{{{{{condicion}}}}}"><div class="glass-panel"'
    if envuelto in html:
        return html
    exigir(html, apertura)
    html = html.replace(apertura, envuelto)
    inicio = html.index(envuelto)
    cierre = fin_de_bloque(html, inicio + len(envuelto))
    fin = cierre + len("</div>")
    return html[:fin] + "</sc-if>" + html[fin:]


def renombrar(html: str) -> str:
    """Nombres con significado. Solo identificadores, jamás estilos."""
    pares = [
        ("{{storageFree}} libres", "{{almacenamientoLibre}}"),
        ("<button class=\"toggle on\" aria-label=\"Activar Wi-Fi\"></button>",
         "<button class=\"toggle {{wifiEncendidoClass}}\" aria-label=\"Activar Wi-Fi\"></button>"),
        ("<span style=\"font-size:13.5px;\">Casa-Dylan-5G</span>",
         "<span style=\"font-size:13.5px;\">{{redActual}}</span>"),
        ("<span style=\"font-size:11px; color:#ff5a66;\">Conectado</span>",
         "<span style=\"font-size:11px; color:var(--dylanos-primario-claro);\">Conectado</span>"),
        ("<button class=\"toggle on\" aria-label=\"Activar Bluetooth\"></button>",
         "<button class=\"toggle {{btEncendidoClass}}\" aria-label=\"Activar Bluetooth\"></button>"),
        ("<span style=\"font-size:13.5px;\">Audífonos Crimson</span>",
         "<span style=\"font-size:13.5px;\">{{btDispositivo}}</span>"),
        ("<span style=\"font-size:13.5px; color:rgba(255,255,255,.75);\">TV Sala Crimson</span>",
         "<span style=\"font-size:13.5px; color:rgba(255,255,255,.75);\">{{pantalla}}</span>"),
        ("Tiempo restante estimado: 4h 40min", "{{bateriaDetalle}}"),
        ("Usa tu huella o presiona cualquier tecla para desbloquear", "{{textoAyuda}}"),
        # claves de datos del prototipo → nombres del sistema
        ("list=\"{{forecast}}\" as=\"day\"", "list=\"{{pronostico}}\" as=\"day\""),
        ("{{day.label}}", "{{day.dia}}"),
        ("{{day.hi}}", "{{day.max}}"),
        ("{{day.lo}}", "{{day.min}}"),
        ("list=\"{{reminders}}\" as=\"r\"", "list=\"{{recordatorios}}\" as=\"r\""),
        ("{{r.ringColor}}", "{{r.colorBorde}}"),
        ("{{r.fill}}", "{{r.colorFondo}}"),
        ("{{r.textColor}}", "{{r.colorTexto}}"),
        ("{{r.label}}", "{{r.texto}}"),
        ("<sc-if value=\"{{r.done}}\" hint-placeholder-val=\"{{false}}\">",
         "<sc-if value=\"{{r.hecho}}\" hint-placeholder-val=\"{{false}}\">"),
    ]
    for viejo, nuevo in pares:
        if nuevo in html:
            continue
        exigir(html, viejo)
        html = html.replace(viejo, nuevo)
    return html


def color_titulos(html: str) -> str:
    """Marca los títulos de panel para poder recolorearlos.

    El color literal del prototipo se queda como está: solo se añade la clase
    que permite el cambio cuando el usuario elige un acento distinto.
    """
    viejo = ('<div style="font-size: 12px; font-weight: 600; color: #dc143c; '
             'text-transform: uppercase; letter-spacing: .06em; margin-bottom: 12px">')
    nuevo = ('<div class="dylanos-titulo" style="font-size: 12px; font-weight: 600; color: #dc143c; '
             'text-transform: uppercase; letter-spacing: .06em; margin-bottom: 12px">')
    if nuevo in html:
        return html
    exigir(html, viejo)
    return html.replace(viejo, nuevo)


def atajos_alternativos(html: str) -> str:
    """Bloque de atajos elegidos por el usuario.

    Los cuatro botones del prototipo se conservan literales (son los atajos por
    defecto y su dibujo debe quedar idéntico). Cuando el usuario elige otros,
    se ocultan esos y se pinta esta lista; con la configuración por defecto
    `atajosPersonalizados` es falso y el DOM no cambia.

    La lista se ancla al grid de atajos del prototipo por su atributo `style`
    exacto, que es único, en lugar de contar etiquetas: contar `<div` fallaba
    porque los estilos en línea también contienen la cadena `<div` en algunos
    valores, y el bloque acababa fuera del panel.
    """
    if "atajosPersonalizados" in html:
        return html

    grid = '<div style="display:grid; grid-template-columns:repeat(2,1fr); gap:10px;">'
    inicio = html.index("<!-- Shortcuts -->")
    pos_grid = html.index(grid, inicio)
    fin_grid = html.index("</div>\n      </div>", pos_grid) + len("</div>")

    bloque = (
        '\n      <sc-if value="{{atajosPersonalizados}}">\n'
        '        <div style="display:grid; grid-template-columns:repeat(2,1fr); gap:10px;">\n'
        '          <sc-for list="{{atajos}}" as="a" hint-placeholder-count="4">\n'
        '            <button class="icon-btn dylanos-chip {{a.clase}}" aria-label="{{a.nombre}}" sc-camel-on-click="{{a.accion}}">\n'
        '              <svg width="18" height="18" sc-camel-view-box="0 0 24 24" fill="none">'
        '<path d="{{a.trazo}}" fill="{{a.relleno}}" stroke="{{a.colorTrazo}}" '
        'stroke-width="{{a.grosor}}" stroke-linecap="round" stroke-linejoin="round"></path></svg>\n'
        '              <span style="font-size:11.5px;">{{a.nombre}}</span>\n'
        '            </button>\n'
        '          </sc-for>\n'
        '        </div>\n'
        '      </sc-if>'
    )
    html = (html[:pos_grid] + '<sc-if value="{{atajosDelPrototipo}}">'
            + html[pos_grid:fin_grid] + '</sc-if>'
            + bloque + html[fin_grid:])
    return html


def marcar_paneles(html: str) -> str:
    """Marca cada panel de datos para poder ocultarlos por configuración.

    Los paneles son los widgets de información (clima, evento, reproducción,
    sistema, calendario, recordatorios, atajos). Se anclan por su comentario
    en el prototipo, que es lo único estable: la estructura de columnas del
    diseño original no es un árbol y algunos paneles van dentro de un `sc-if`.
    """
    anclas = [
        ("<!-- Weather -->", "clima"),
        ("<!-- Next event -->", "evento"),
        ("<!-- Now playing -->", "reproduccion"),
        ("<!-- System -->", "sistema"),
        ("<!-- Calendar -->", "calendario"),
        ("<!-- Reminders -->", "recordatorios"),
        ("<!-- Shortcuts -->", "atajos"),
    ]
    for comentario, identificador in anclas:
        if f'data-dylanos-panel="{identificador}"' in html:
            continue
        pos = html.find(comentario)
        if pos < 0:
            continue
        # Se busca la primera etiqueta `glass-panel` después del comentario y
        # se le añaden la clase y el identificador sin tocar el resto.
        patron = re.compile(r'<div class="glass-panel([^"]*)"')
        hallado = patron.search(html, pos)
        if not hallado:
            continue
        marca = (f'<div class="glass-panel dylanos-panel{hallado.group(1)}" '
                 f'data-dylanos-panel="{identificador}"')
        html = html[:hallado.start()] + marca + html[hallado.end():]
    return html


def solo_marcado(html: str) -> str:
    """Devuelve el marcado del tema, sin CSS ni scripts.

    Los nombres de clase también aparecen en la capa de personalización (que
    se inserta en `<helmet>`), así que buscar en el documento entero daba
    falsos positivos: el código creía que los marcadores ya estaban puestos.
    """
    cuerpo = html.split("</helmet>", 1)[-1]
    return cuerpo.split('<script type="text/x-dc"', 1)[0]


def marcar(html: str) -> str:
    """Añade los marcadores que permiten personalizar la composición.

    - `dylanos-reloj-bloque` y `dylanos-acceso-bloque` para escalarlos.
    - `dylanos-columna-izquierda` / `-derecha` para poder ocultarlas y cambiar
      la distribución desde Configuration.

    Las clases solo se añaden al marcado: los estilos del prototipo siguen
    intactos, y sin personalización no se aplica ninguna regla.
    """
    viejo = '<!-- Group: clock -->\n      <div style="display:flex; flex-direction:column; align-items:center;">'
    nuevo = ('<!-- Group: clock -->\n      <div class="dylanos-reloj-bloque" '
             'style="display:flex; flex-direction:column; align-items:center;">')
    if "dylanos-reloj-bloque" not in solo_marcado(html):
        exigir(html, viejo)
        html = html.replace(viejo, nuevo)

    if "dylanos-columna-izquierda" not in solo_marcado(html):
        izq = '<!-- Left column -->\n    <div style="width:370px;'
        exigir(html, izq)
        html = html.replace(
            izq, '<!-- Left column -->\n    <div class="dylanos-columna-izquierda" style="width:370px;', 1)

    if "dylanos-columna-derecha" not in solo_marcado(html):
        der = '<!-- Right column -->\n    <div style="width:420px;'
        exigir(html, der)
        html = html.replace(
            der, '<!-- Right column -->\n    <div class="dylanos-columna-derecha" style="width:420px;', 1)

    if "dylanos-acceso-bloque" not in solo_marcado(html):
        # El bloque de acceso es el contenedor del avatar y del campo de
        # contraseña. Se busca su etiqueta completa y se le añade la clase
        # sin tocar ningún atributo existente.
        pos = html.index('<!-- Group: login -->')
        patron = re.compile(r'<div style="display:flex; flex-direction:column; align-items:center;[^"]*"')
        hallado = patron.search(html, pos)
        if not hallado:
            raise SystemExit("No se encontró el bloque de acceso")
        etiqueta = hallado.group(0)
        nueva = '<div class="dylanos-acceso-bloque" ' + etiqueta[len('<div '):]
        html = html[:hallado.start()] + nueva + html[hallado.end():]
    return html


def acentos_a_variables(html: str) -> str:
    """Convierte los colores de acento del prototipo en variables CSS.

    El prototipo lleva el crimson escrito directamente en los estilos en
    línea, y un estilo en línea gana siempre a la hoja de estilos: por eso, al
    cambiar el acento, los títulos seguían en rojo. Aquí cada valor pasa a
    `var(--dylanos-…)`, con el mismo color por defecto, de modo que el dibujo
    original no cambia pero el acento puede gobernarlos todos.

    Tres familias, las que usa el prototipo:
      --dylanos-primario        #dc143c  títulos, cifras y marca
      --dylanos-primario-claro  #ff5a66  iconos y estados activos
      --dylanos-primario-fuerte #ff3b48  anillo de batería, progreso y «OS»

    Las comillas forman parte de la sustitución: quitarlas cerraba mal el
    atributo (`fill="var(...)>`), y el SVG dejaba de pintarse.
    """
    sustituciones = [
        # estilo en línea (con y sin espacio tras los dos puntos)
        ("color: #dc143c", "color: var(--dylanos-primario)"),
        ("color: #DC143C", "color: var(--dylanos-primario)"),
        ("color:#dc143c", "color:var(--dylanos-primario)"),
        ("color: #ff5a66", "color: var(--dylanos-primario-claro)"),
        ("color:#ff5a66", "color:var(--dylanos-primario-claro)"),
        ("color:#ff3b48", "color:var(--dylanos-primario-fuerte)"),
        ("background:#ff3b48", "background:var(--dylanos-primario-fuerte)"),
        # atributos SVG: la comilla de cierre es obligatoria
        ('fill="#ff5a66"', 'fill="var(--dylanos-primario-claro)"'),
        ('fill="#ff3b48"', 'fill="var(--dylanos-primario-fuerte)"'),
        ('stroke="#ff3b48"', 'stroke="var(--dylanos-primario-fuerte)"'),
    ]
    for viejo, nuevo_valor in sustituciones:
        html = html.replace(viejo, nuevo_valor)
    return html


def sistema_condicional(html: str) -> str:
    """Batería y almacenamiento se muestran solo si existen de verdad.

    El prototipo pinta la fila de batería con su anillo y la de almacenamiento
    debajo. En un equipo de escritorio no hay batería; en un arranque sin
    montajes puede faltar el dato de disco. Cada fila se condiciona por
    separado y, con ambos datos, el DOM coincide con el prototipo.
    """
    if "puedeBateria" in html:
        return html
    viejo = '''        <div class="widget-row" style="gap:16px;">
          <div style="position:relative; width:58px; height:58px; flex-shrink:0;">'''
    nuevo = '''        <div class="widget-row" style="gap:16px;">
          <sc-if value="{{puedeBateria}}">
          <div style="position:relative; width:58px; height:58px; flex-shrink:0;">'''
    exigir(html, viejo)
    html = html.replace(viejo, nuevo)

    cierre_anillo = '''            <div style="position:absolute; inset:0; display:flex; align-items:center; justify-content:center; font-size:14px; font-weight:700;">{{batteryPercent}}%</div>
          </div>
'''
    exigir(html, cierre_anillo)
    html = html.replace(cierre_anillo, cierre_anillo + '          </sc-if>\n')

    texto_bateria = '''            <div style="font-size:13.5px; font-weight:600;">Batería</div>
            <div style="font-size:12px; color:rgba(255,255,255,.5); margin-bottom:8px;">{{batteryPercent}}% restante</div>
'''
    exigir(html, texto_bateria)
    html = html.replace(texto_bateria,
                        '            <sc-if value="{{puedeBateria}}">\n' + texto_bateria
                        + '            </sc-if>\n')

    texto_almacenamiento = '''            <div style="font-size:13.5px; font-weight:600;">Almacenamiento</div>
            <div style="font-size:12px; color:rgba(255,255,255,.5);">{{storageFree}} libres</div>
'''
    exigir(html, texto_almacenamiento)
    html = html.replace(texto_almacenamiento,
                        '            <sc-if value="{{puedeAlmacenamiento}}">\n' + texto_almacenamiento
                        + '            </sc-if>\n')
    return html


def bateria_condicional(html: str) -> str:
    """El botón de batería solo existe si el equipo tiene batería.

    El prototipo dibuja un 78% fijo; en un equipo de escritorio eso sería una
    cifra inventada. Con batería real, el DOM es el del prototipo.
    """
    if "hayBateria" in html:
        return html
    viejo = ('      <!-- Battery -->\n'
             '      <div style="position:relative;">\n'
             '        <button class="icon-btn {{batteryOpenClass}}"')
    nuevo = ('      <!-- Battery -->\n'
             '      <sc-if value="{{hayBateria}}">\n'
             '      <div style="position:relative;">\n'
             '        <button class="icon-btn {{batteryOpenClass}}"')
    exigir(html, viejo)
    html = html.replace(viejo, nuevo)

    # El botón cierra antes del separador de la barra superior.
    cierre = ('        </sc-if>\n'
              '      </div>\n')
    marca = '      <span style="width:1px; height:16px; background:rgba(255,255,255,0.12); margin:0 4px;"></span>'
    pos = html.index(marca)
    previo = html.rindex(cierre, 0, pos)
    html = html[:previo] + '        </sc-if>\n      </div></sc-if>\n' + html[previo + len(cierre):]
    return html


def instalar_componente(html: str, tema: Path) -> str:
    """Sustituye el script del componente por el de datos reales.

    El marcado y los estilos se quedan como están: lo único que cambia es el
    código que alimenta las props.
    """
    componente = (tema / "js/dylanos-componente.js").read_text(encoding="utf-8")
    patron = re.compile(r'<script type="text/x-dc"([^>]*)>.*?</script>', re.S)
    hallado = patron.search(html)
    if not hallado:
        raise SystemExit("No se encontró el script del componente")
    if "iconoDe" in html and "DylanOSDatos" in html:
        return html
    nuevo = '<script type="text/x-dc"' + hallado.group(1) + '>\n' + componente + '</script>'
    return html[:hallado.start()] + nuevo + html[hallado.end():]


def main() -> int:
    parser = argparse.ArgumentParser(description="Datos reales del login manager")
    parser.add_argument("--tema", type=Path, default=TEMA)
    args = parser.parse_args()

    index = args.tema / "index.html"
    html = index.read_text(encoding="utf-8")
    original = html

    html = insertar_capa(html)
    html = color_titulos(html)
    html = acentos_a_variables(html)
    html = bateria_condicional(html)
    html = sistema_condicional(html)
    for comentario, condicion in [
        ("<!-- Weather -->", "puedeClima"),
        ("<!-- Next event -->", "puedeEvento"),
        ("<!-- Now playing -->", "puedeReproduccion"),
        ("<!-- Calendar -->", "puedeCalendario"),
        ("<!-- Reminders -->", "puedeRecordatorios"),
        ("<!-- Shortcuts -->", "puedeAtajos"),
    ]:
        html = condicionar(html, comentario, condicion)
    html = renombrar(html)
    html = atajos_alternativos(html)
    html = marcar(html)
    html = marcar_paneles(html)
    html = instalar_componente(html, args.tema)

    if html == original:
        print("Sin cambios")
        return 0
    index.write_text(html, encoding="utf-8")
    print(f"Enlazado {index.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
