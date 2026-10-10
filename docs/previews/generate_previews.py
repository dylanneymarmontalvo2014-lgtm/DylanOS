#!/usr/bin/env python3
"""Genera previews del shell de DylanOS 1.0 Beta."""
from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).parent
W, H = 1440, 900
BLACK = "#050505"
BLACK2 = "#111111"
BLACK3 = "#1B1B1B"
WHITE = "#F7F7F7"
MUTED = "#A8A8A8"
RED = "#E50914"
RED_DARK = "#8C070E"
GRAY = "#D6D6D6"
WALLPAPER = "dylanos-wallpaper.png"


def e(v):
    return escape(str(v))


def t(x, y, value, size=16, color=WHITE, weight=400, anchor="start"):
    return f'<text x="{x}" y="{y}" fill="{color}" font-family="Inter,Arial,sans-serif" font-size="{size}px" font-weight="{weight}" text-anchor="{anchor}">{e(value)}</text>'


def r(x, y, w, h, fill=BLACK2, radius=18, stroke="none", opacity=1):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" opacity="{opacity}"/>'


def c(x, y, radius, fill):
    return f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}"/>'


def base(body, title="DylanOS", light=False, dock=True, show_sidebar=True):
    bg = "#EEEEEE" if light else BLACK
    top = "#F7F7F7" if light else "#101010"
    fg = "#121212" if light else WHITE
    muted = "#666666" if light else MUTED
    wallpaper = f'''<rect width="{W}" height="{H}" fill="{bg}"/>
    <image href="{WALLPAPER}" x="0" y="0" width="{W}" height="{H}" preserveAspectRatio="xMidYMid slice" opacity=".94"/>
    <rect width="{W}" height="{H}" fill="{WHITE if light else BLACK}" opacity="{.54 if light else .34}"/>'''
    menu = f'''{r(0,0,W, thirty:=34, top,0,opacity=.94)}{t(22,23,"DylanOS",13,fg,700)}{t(108,23,"Archivo",13,fg,500)}{t(165,23,"Edición",13,fg,500)}{t(218,23,"Ver",13,fg,500)}{t(258,23,"Ventana",13,fg,500)}{t(W-22,23,"Wi‑Fi   03 oct  ·  10:42",13,fg,500,"end")}'''
    sidebar = f'{r(24,58,178,720,"#171717" if not light else "#FFFFFF",22,opacity=.88)}{c(61,101,21,RED)}{t(61,109,"D",20,WHITE,750,"middle")}{t(96,106,"DylanOS",16,fg,700)}{t(48,171,"Favoritos",11,muted,700)}{t(48,208,"⌂  Escritorio",14,fg,550)}{t(48,248,"▣  Aplicaciones",14,fg,550)}{t(48,288,"▤  Documentos",14,fg,550)}{t(48,328,"⇩  Descargas",14,fg,550)}{t(48,390,"Ubicaciones",11,muted,700)}{t(48,430,"◉  DylanOS",14,fg,550)}{t(48,470,"▰  Proyectos",14,fg,550)}' if show_sidebar else ''
    dock_markup = ''
    if dock:
        dock_markup = f'{r(475,805,490,70,"#161616" if not light else "#FFFFFF",24,stroke="#444444" if not light else "#D0D0D0",opacity=.92)}'
        for i, (x, color, label) in enumerate([(515,RED,"D"),(573,WHITE,"F"),(631,GRAY,"⌘"),(689,RED,"⌁"),(747,WHITE,"▣"),(805,GRAY,"C"),(863,WHITE,"⌕"),(921,RED,"⚙")]):
            dock_markup += f'{r(x,821,42,42,"#050505" if not light else "#202020",12,stroke="#4D4D4D")}{t(x+21,850,label,20,color,700,"middle")}'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><defs><filter id="shadow"><feDropShadow dx="0" dy="18" stdDeviation="20" flood-opacity=".45"/></filter></defs>{wallpaper}{body}{menu}{sidebar}{dock_markup}</svg>'''


def window(x, y, w, h, title, body, light=False):
    fill = "#F7F7F7" if light else "#171717"
    fg = "#111111" if light else WHITE
    stroke = "#D2D2D2" if light else "#393939"
    return f'{r(x,y,w,h,fill,18,stroke)}{c(x+25,y+25,6,"#FF5F57")}{c(x+47,y+25,6,"#FEBC2E")}{c(x+69,y+25,6,"#28C840")}{t(x+w/2,y+30,title,13,fg,600,"middle")}{body}'


def icon(x, y, label, glyph, color=RED, light=False):
    return f'{r(x,y,74,74,"#050505",20,stroke="#444444")}{t(x+37,y+48,glyph,32,color,750,"middle")}{t(x+37,y+98,label,11,WHITE if not light else "#111111",550,"middle")}'


def desktop(light=False):
    fg = "#111111" if light else WHITE
    body = f'''{window(310,120,820,560,"Escritorio",f'{t(350,195,"Aplicaciones",26,fg,700)}{t(350,232,"Tus herramientas, siempre a mano.",14,"#777777" if light else MUTED)}{icon(360,290,"Archivos","▤",WHITE,light)}{icon(470,290,"VSCodium","⌘",RED,light)}{icon(580,290,"Terminal",">_",WHITE,light)}{icon(690,290,"Control","⚙",RED,light)}{icon(800,290,"Calcular","＋",WHITE,light)}{icon(910,290,"Tienda","◈",RED,light)}{r(350,445,710,1,"#D3D3D3" if light else "#353535",0)}{t(350,492,"DylanOS 1.0 Beta",20,fg,650)}{t(350,525,"Una experiencia de escritorio limpia, rápida y bajo tu control.",14,"#777777" if light else MUTED)}',light)}'''
    return base(body,"DylanOS",light,show_sidebar=False)


def app(kind, light=False):
    fg = "#111111" if light else WHITE
    muted = "#666666" if light else MUTED
    titles = {"control":"Centro de control","store":"Centro de aplicaciones","files":"Archivos","monitor":"Monitor del sistema","dev":"VSCodium"}
    title = titles[kind]
    if kind == "control":
        inner = f'{t(380,214,"Centro de control",25,fg,700)}{t(380,248,"Preferencias del sistema",14,muted)}{r(380,285,180,310,"#ECECEC" if light else BLACK3,14)}{t(404,324,"Red e Internet",14,RED,600)}{t(404,366,"Apariencia",14,fg,550)}{t(404,408,"Usuarios",14,fg,550)}{t(404,450,"Actualizaciones",14,fg,550)}{t(404,492,"Privacidad",14,fg,550)}{r(600,285,460,310,"#FFFFFF" if light else BLACK3,14)}{t(635,326,"Apariencia",19,fg,650)}{t(635,366,"Modo del sistema",14,muted)}{r(635,390,170,82,BLACK,18,stroke="#444444")}{t(720,440,"Dark",15,WHITE,600,"middle")}{r(830,390,170,82,"#F1F1F1",18,stroke="#C8C8C8")}{t(915,440,"Light",15,"#111111",600,"middle")}{t(635,520,"Logo DylanOS",14,muted)}{c(980,514,18,RED)}{t(635,560,"El rojo DylanOS se mantiene en ambos temas.",13,muted)}'
    elif kind == "store":
        inner = f'{t(380,214,"Centro de aplicaciones",25,fg,700)}{t(380,248,"Descubre software para tu sistema.",14,muted)}{r(380,280,680,48,"#E9E9E9" if light else BLACK3,14)}{t(406,311,"⌕   Buscar aplicaciones",14,muted)}{icon(400,370,"VSCodium","⌘",RED,light)}{icon(530,370,"Git","◆",WHITE,light)}{icon(660,370,"Python","Py",RED,light)}{icon(790,370,"Node.js","JS",WHITE,light)}{t(400,530,"Recomendadas para desarrollo",16,fg,650)}{t(400,560,"Instala herramientas verificadas con un clic.",13,muted)}'
    elif kind == "files":
        inner = f'{t(380,214,"Archivos",25,fg,700)}{t(380,248,"Tus documentos y proyectos.",14,muted)}{r(380,280,680,330,"#FFFFFF" if light else BLACK3,14)}{t(412,320,"Proyectos",16,fg,650)}{t(412,366,"▰   dylanos-control-center",14,fg,550)}{t(412,410,"▰   website",14,fg,550)}{t(412,454,"▰   calculator",14,fg,550)}{t(412,498,"▰   notas.md",14,fg,550)}'
    elif kind == "monitor":
        inner = f'{t(380,214,"Monitor del sistema",25,fg,700)}{t(380,248,"Rendimiento en tiempo real",14,muted)}{r(380,285,200,100,"#FFFFFF" if light else BLACK3,14)}{t(408,320,"CPU",13,muted)}{t(408,360,"18%",27,fg,700)}{r(610,285,200,100,"#FFFFFF" if light else BLACK3,14)}{t(638,320,"Memoria",13,muted)}{t(638,360,"6.2 GB",27,fg,700)}{r(840,285,200,100,"#FFFFFF" if light else BLACK3,14)}{t(868,320,"Disco",13,muted)}{t(868,360,"42%",27,fg,700)}{t(380,450,"Procesos activos",16,fg,650)}{t(380,492,"kwin_wayland",14,fg)}{t(740,492,"2.4%",14,muted)}{t(380,530,"codium",14,fg)}{t(740,530,"1.8%",14,muted)}'
    else:
        inner = f'{t(380,214,"VSCodium",25,fg,700)}{t(380,248,"Entorno de desarrollo DylanOS",14,muted)}{r(380,280,680,330,"#0B0B0B",14)}{t(414,326,"$ git status",14,"#F0F0F0",500)}{t(414,362,"On branch development",14,"#BBBBBB",500)}{t(414,398,"working tree clean",14,RED,600)}{t(414,462,"$ python3 --version",14,"#F0F0F0",500)}{t(414,498,"Python 3.x · Node.js · C/C++",14,"#BBBBBB",500)}{t(414,570,"$ _",14,RED,500)}'
    return base(window(310,120,820,560,title,inner,light),title,light)


def sddm():
    body = f'''{r(320,112,800,620,"#0B0B0B",22,stroke="#3A3A3A")}{c(720,260,58,RED)}{t(720,280,"D",51,WHITE,750,"middle")}{t(720,368,"Ing. Dylan",22,WHITE,650,"middle")}{t(720,401,"DylanOS 1.0 Beta",14,MUTED,500,"middle")}{r(560,450,320,46,"#1A1A1A",12,stroke="#454545")}{t(584,479,"Contraseña",14,MUTED)}{r(560,520,320,46,RED,12)}{t(720,549,"Iniciar sesión",14,WHITE,650,"middle")}{t(720,620,"Suspender     Reiniciar     Apagar",13,MUTED,500,"middle")}'''
    return base(body,"Inicio de sesión",False,False)


def calamares():
    # Vista neutra: se conserva la interfaz estándar de Calamares.
    body = f'''{r(250,80,940,700,"#F4F4F4",4,stroke="#BDBDBD")}{r(250,80,940,54,"#E5E5E5",0)}{t(280,115,"Calamares",18,"#222222",600)}{t(1155,115,"DylanOS 1.0 Beta",13,"#444444",500,"end")}{r(250,134,210,646,"#E9E9E9",0)}{t(278,178,"Idioma",14,"#333333",550)}{t(278,222,"Ubicación",14,"#333333",550)}{t(278,266,"Teclado",14,"#333333",550)}{t(278,310,"Particiones",14,"#333333",550)}{t(278,354,"Usuarios",14,"#333333",550)}{t(278,398,"Resumen",14,"#333333",550)}{t(520,195,"Bienvenido al instalador de Calamares",25,"#222222",600)}{t(520,236,"Instalador estándar de Debian, integrado en DylanOS.",14,"#555555")}{r(520,292,560,188,"#FFFFFF",3,stroke="#D0D0D0")}{t(550,332,"Configuración de instalación",17,"#222222",600)}{t(550,372,"Idioma: Español",14,"#555555")}{t(550,408,"Teclado: Español latinoamericano",14,"#555555")}{t(550,444,"Disco: seleccionar durante la instalación",14,"#555555")}{r(940,708,190,42,"#D9D9D9",3,stroke="#AFAFAF")}{t(1035,735,"Siguiente",14,"#222222",600,"middle")}'''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><rect width="{W}" height="{H}" fill="#D8D8D8"/>{body}</svg>'


def boot(name):
    body = f'''<rect width="{W}" height="{H}" fill="{BLACK}"/><path d="M0 740 C300 580 500 820 760 650 S1150 430 1440 570 L1440 900 L0 900Z" fill="{RED_DARK}"/><circle cx="720" cy="350" r="104" fill="{RED}"/><text x="720" y="386" fill="{WHITE}" font-family="Inter,Arial" font-size="92" font-weight="750" text-anchor="middle">D</text>{t(720,530,"DylanOS",38,WHITE,700,"middle")}{t(720,570,"1.0 Beta",17,MUTED,500,"middle")}{t(720,700,name,14,MUTED,500,"middle")}'''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{body}</svg>'


files = {
    "01-escritorio-dark": desktop(False), "02-escritorio-light": desktop(True),
    "03-control": app("control"), "04-store": app("store"), "05-files": app("files"),
    "06-monitor": app("monitor"), "07-dev": app("dev"), "08-calamares": calamares(),
    "09-sddm": sddm(), "10-grub": boot("GRUB · arranque del sistema"),
    "11-plymouth": boot("Plymouth · iniciando DylanOS"),
}
for name, content in files.items():
    (OUT / f"{name}.svg").write_text(content, encoding="utf-8")

index = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><rect width="{W}" height="{H}" fill="{BLACK}"/><path d="M0 760 C300 560 500 840 800 620 S1170 410 1440 560 L1440 900 L0 900Z" fill="{RED_DARK}"/><rect x="90" y="94" width="1260" height="650" rx="30" fill="#111111" stroke="#3A3A3A"/><circle cx="148" cy="160" r="28" fill="{RED}"/><text x="148" y="170" fill="{WHITE}" font-family="Inter,Arial" font-size="26" font-weight="750" text-anchor="middle">D</text>{t(202,170,"DylanOS 1.0 Beta",34,WHITE,700)}{t(202,210,"Propuesta visual · 100% DylanOS",16,MUTED)}{t(150,310,"Rojo",18,WHITE,600)}{t(520,310,"Negro",18,WHITE,600)}{t(890,310,"Blanco",18,WHITE,600)}{r(150,340,250,150,RED,28)}{r(520,340,250,150,BLACK,28,stroke="#555555")}{r(890,340,250,150,WHITE,28)}{t(275,425,"#E50914",18,WHITE,650,"middle")}{t(645,425,"#050505",18,WHITE,650,"middle")}{t(1015,425,"#F7F7F7",18,BLACK,650,"middle")}{t(150,620,"Barra superior · ventanas flotantes · dock inferior",17,WHITE,550)}{t(150,660,"Calamares se conserva estándar: solo reemplaza el instalador Debian.",15,MUTED,500)}</svg>'''
(OUT / "00-indice.svg").write_text(index, encoding="utf-8")
