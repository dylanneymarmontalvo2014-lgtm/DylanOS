#!/usr/bin/env python3
"""Genera el andamiaje de un widget de DylanOS Widgets.

Cada plasmoid es autocontenido: necesita su metadata.json, su representación y
una copia de la librería común en contents/ui/lib. Copiar a mano invitaba a
que las copias divergieran (el test lo detectó una vez), así que el andamiaje
se genera con este script y las copias se sincronizan desde la fuente única.

Uso:
    python3 scripts/new-widget.py <sufijo> <Nombre> <applet-id> [categoría]

Ejemplo:
    python3 scripts/new-widget.py battery Batería com.dylanos.widgets.battery
"""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "apps/dylanos-widgets-lib"
VENDORED_FILES = ("WidgetTokens.js", "WidgetData.js", "WidgetCalc.js",
                  "WidgetCard.qml", "WidgetHeader.qml", "WidgetShell.qml",
                  "WidgetMeter.qml")
QMLDIR = "".join(
    "%s 1.0 %s\n" % (name[:-4].replace(".js", "Data"), name)
    for name in VENDORED_FILES if name.endswith(".qml")
)


def create(suffix, display_name, applet_id, category="Utilities", icon="preferences-other"):
    app = ROOT / "apps" / ("dylanos-widgets-" + suffix)
    ui = app / "contents" / "ui"
    lib = ui / "lib"
    lib.mkdir(parents=True, exist_ok=True)

    metadata = {
        "KPackageStructure": "Plasma/Applet",
        "KPlugin": {
            "Authors": [{"Name": "DylanOS Team"}],
            "Category": category,
            "Description": "DylanOS Widgets: %s" % display_name,
            "Description[es]": "DylanOS Widgets: %s" % display_name,
            "Icon": icon,
            "Id": applet_id,
            "Name": "DylanOS %s" % display_name,
            "Name[es]": "%s DylanOS" % display_name,
            "ServiceTypes": ["Plasma/Applet"],
            "Version": "1.0.0",
        },
        "X-Plasma-API-Minimum-Version": "6.0",
    }
    (app / "metadata.json").write_text(
        json.dumps(metadata, indent=4, ensure_ascii=False) + "\n", encoding="utf-8")

    for name in VENDORED_FILES:
        shutil.copy2(LIB / name, lib / name)
    (lib / "qmldir").write_text(QMLDIR, encoding="utf-8")
    return app


def sync_library():
    """Reinstala la librería común en todos los plasmoides existentes."""
    count = 0
    for app in sorted(ROOT.glob("apps/dylanos-widgets-*")):
        base = app / "contents" / "ui" / "lib"
        if not base.is_dir():
            continue
        for name in VENDORED_FILES:
            shutil.copy2(LIB / name, base / name)
        (base / "qmldir").write_text(QMLDIR, encoding="utf-8")
        count += 1
    # La galería también es un consumidor de la librería.
    gallery = ROOT / "apps/dylanos-widgets/qml/lib"
    if gallery.is_dir():
        for name in VENDORED_FILES:
            shutil.copy2(LIB / name, gallery / name)
        (gallery / "qmldir").write_text(QMLDIR, encoding="utf-8")
        count += 1
    return count


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--sync":
        print("Sincronizados %d paquetes" % sync_library())
        sys.exit(0)
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    suffix, name, applet = sys.argv[1], sys.argv[2], sys.argv[3]
    category = sys.argv[4] if len(sys.argv) > 4 else "Utilities"
    icon = sys.argv[5] if len(sys.argv) > 5 else "preferences-other"
    print(create(suffix, name, applet, category, icon))
