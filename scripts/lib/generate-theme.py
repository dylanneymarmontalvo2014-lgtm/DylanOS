#!/usr/bin/env python3
"""Generate original, reproducible DylanOS assets. Requires Pillow only."""
from pathlib import Path
import json
import math
import shutil
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]


def write(path, text):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def wallpaper(light=False):
    w, h = 1920, 1200
    top, bottom = ((157, 188, 215), (239, 199, 205)) if light else ((16, 27, 49), (66, 33, 56))
    image = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(image)
    for y in range(h):
        f = y / h
        draw.line((0, y, w, y), fill=tuple(int(a * (1-f) + b*f) for a, b in zip(top, bottom)))
    colors = [(171, 114, 148), (209, 141, 152), (97, 116, 158), (62, 85, 125)] if light else [(79, 52, 85), (132, 66, 89), (48, 64, 99), (24, 40, 70)]
    for layer, color in enumerate(colors):
        points = [(0, h)]
        for x in range(0, w + 1, 3):
            y = h * (.34 + layer * .14) + math.sin(x/w * 4.1 + layer * .8) * 130 + math.cos(x/w * 2.8) * 65
            points.append((x, y))
        points.append((w, h))
        draw.polygon(points, fill=color)
        draw.line(points[1:-1], fill=tuple(min(255, c + 26) for c in color), width=3)
    image = image.filter(ImageFilter.GaussianBlur(1.5))
    directory = ROOT / "branding/wallpapers"
    directory.mkdir(parents=True, exist_ok=True)
    image.save(directory / ("DylanOS-Light.png" if light else "DylanOS-Dark.png"))


def colors(light=False):
    name = "DylanOSLight" if light else "DylanOSDark"
    bg, base, fg, muted = ((244,245,248), (255,255,255), (32,33,43), (99,104,121)) if light else ((30,30,32), (24,24,28), (241,241,246), (161,165,184))
    rgb = lambda value: ",".join(map(str, value))
    text = f"[General]\nName={name}\nColorScheme={name}\nshadeSortColumn=true\n\n"
    for group in ["Button", "Complementary", "Header", "Tooltip", "View", "Window", "Selection"]:
        selected = group == "Selection"
        background = (220,20,60) if selected else base if group in ["View", "Button"] else bg
        foreground = (255,255,255) if selected else fg
        text += f"[Colors:{group}]\nBackgroundNormal={rgb(background)}\nBackgroundAlternate={rgb(bg)}\nForegroundNormal={rgb(foreground)}\nForegroundInactive={rgb(muted)}\nForegroundActive=220,20,60\nForegroundLink=110,166,239\nForegroundVisited=180,145,215\nForegroundNegative=236,107,120\nForegroundNeutral=220,177,101\nForegroundPositive=112,187,153\nDecorationFocus=220,20,60\nDecorationHover=232,55,93\n\n"
    text += f"[WM]\nactiveBackground={rgb(bg)}\nactiveForeground={rgb(fg)}\ninactiveBackground={rgb(bg)}\ninactiveForeground={rgb(muted)}\n"
    write(f"themes/colors/{name}.colors", text)


def frame(color, prefix="", x=0, y=0, edge=8, size=64):
    parts = []
    coords = {"topleft":(x,y,edge,edge), "top":(x+edge,y,size,edge), "topright":(x+edge+size,y,edge,edge),
              "left":(x,y+edge,edge,size), "center":(x+edge,y+edge,size,size), "right":(x+edge+size,y+edge,edge,size),
              "bottomleft":(x,y+edge+size,edge,edge), "bottom":(x+edge,y+edge+size,size,edge), "bottomright":(x+edge+size,y+edge+size,edge,edge)}
    for name, (xx, yy, w, h) in coords.items():
        corner = {"topleft": f"M0,{edge} Q0,0 {edge},0 L{edge},{edge}Z",
                  "topright": f"M0,0 Q{edge},0 {edge},{edge} L0,{edge}Z",
                  "bottomleft": f"M0,0 Q0,{edge} {edge},{edge} L{edge},0Z",
                  "bottomright": f"M0,{edge} Q{edge},{edge} {edge},0 L0,0Z"}
        if name in corner:
            parts.append(f'<path id="{prefix}{name}" transform="translate({xx},{yy})" d="{corner[name]}" fill="{color}"/>')
        else:
            parts.append(f'<rect id="{prefix}{name}" x="{xx}" y="{yy}" width="{w}" height="{h}" fill="{color}"/>')
    return "".join(parts)


def main():
    for light in (False, True):
        wallpaper(light)
        colors(light)
    write("themes/plasma/DylanOS-Crimson/metadata.json", json.dumps({"KPlugin":{"Id":"DylanOS-Crimson", "Name":"DylanOS Crimson", "Version":"1.0.0", "License":"GPL-3.0-or-later", "Authors":[{"Name":"DylanOS"}]}}, indent=2))
    write("themes/plasma/DylanOS-Crimson/metadata.desktop", "[Desktop Entry]\nName=DylanOS Crimson\nX-KDE-PluginInfo-Name=DylanOS-Crimson\nX-KDE-PluginInfo-License=GPL-3.0-or-later\n\n[ContrastEffect]\nenabled=false\n\n[BlurBehindEffect]\nenabled=true\n")
    for element in ("widgets/panel-background", "dialogs/background"):
        write(f"themes/plasma/DylanOS-Crimson/{element}.svg", '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80">' + frame("#242429", edge=16, size=48) + '<rect id="hint-stretch-borders" width="1" height="1" fill="none"/><rect id="hint-apply-color-scheme" width="1" height="1" fill="none"/></svg>')
        write(f"themes/plasma/DylanOS-Crimson/translucent/{element}.svg", '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><g opacity="0.72">' + frame("#242429", edge=16, size=48) + '</g><rect id="hint-stretch-borders" width="1" height="1" fill="none"/><rect id="hint-apply-color-scheme" width="1" height="1" fill="none"/></svg>')
    aurora = "themes/aurorae/DylanOS-Crimson"
    write(f"{aurora}/metadata.desktop", "[Desktop Entry]\nName=DylanOS Crimson\nComment=Original DylanOS window decoration\nX-KDE-PluginInfo-Name=DylanOS-Crimson\nX-KDE-PluginInfo-Version=1.0\nX-KDE-PluginInfo-Author=DylanOS\nX-KDE-PluginInfo-License=GPL-3.0-or-later\n")
    write(f"{aurora}/DylanOS-Crimsonrc", "[General]\nShadow=false\nAnimation=120\nTitleAlignment=Center\nActiveTextColor=241,241,246\nInactiveTextColor=161,165,184\n\n[Layout]\nBorderLeft=4\nBorderRight=4\nBorderBottom=4\nBorderTop=0\nTitleEdgeTop=8\nTitleEdgeBottom=8\nTitleEdgeLeft=8\nTitleEdgeRight=8\nTitleBorderLeft=5\nTitleBorderRight=5\nButtonWidth=18\nButtonHeight=18\nButtonSpacing=7\nExplicitButtonSpacer=4\n")
    write(f"{aurora}/decoration.svg", '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="100"><g opacity="0.92">' + frame("#252529", "decoration-", edge=12, size=56) + frame("#202024", "decoration-inactive-", x=100, edge=12, size=56) + '</g>' + frame("#252529", "decoration-opaque-", x=200, edge=12, size=56) + frame("#202024", "decoration-opaque-inactive-", x=300, edge=12, size=56) + frame("white", "mask-", x=400, edge=12, size=56) + '</svg>')
    for name, color, glyph in [("close", "#ff5f57", "M6 6L12 12M12 6L6 12"), ("minimize", "#febc2e", "M5 9H13"), ("maximize", "#28c840", "M6 11V6H11M7 12H12V7"), ("restore", "#28c840", "M5 8H10V13H5Z")]:
        content = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="22">'
        for i, state in enumerate(["active", "hover", "pressed", "inactive"]):
            content += f'<g id="{state}-center" transform="translate({i*24},0)"><rect width="18" height="18" fill="none"/><circle cx="9" cy="9" r="7" fill="{color if state != "inactive" else "#6e7079"}"/>'
            if state in ("hover", "pressed"):
                content += f'<path d="{glyph}" fill="none" stroke="#3a2930" stroke-width="1.4"/>'
            content += '</g>'
        write(f"{aurora}/{name}.svg", content + '</svg>')
    light = ROOT / "themes/aurorae/DylanOS-Crimson-Light"
    light.mkdir(parents=True, exist_ok=True)
    for source in (ROOT / aurora).iterdir():
        filename = source.name.replace("DylanOS-Crimsonrc", "DylanOS-Crimson-Lightrc")
        content = source.read_text().replace("DylanOS-Crimson", "DylanOS-Crimson-Light").replace("Name=DylanOS Crimson", "Name=DylanOS Crimson Light")
        content = content.replace("#252529", "#eef0f6").replace("#202024", "#e8eaf0")
        content = content.replace("241,241,246", "32,33,43").replace("161,165,184", "99,104,121")
        (light / filename).write_text(content)


if __name__ == "__main__":
    main()
