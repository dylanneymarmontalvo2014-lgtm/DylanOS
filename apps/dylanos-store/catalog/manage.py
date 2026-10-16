#!/usr/bin/env python3
"""Gestión del catálogo editorial de DylanOS Store.

La tienda lee este catálogo SQL al arrancar (copia empaquetada) y luego
intenta refrescarlo desde GitHub, de modo que agregar o quitar apps NO
requiere compilar un nuevo ISO.

Para AGREGAR una app solo se necesitan dos datos:
  1. nombre del paquete  (p. ej. "krita" en apt, "org.mozilla.firefox" en flatpak)
  2. su gestor de paquetes ("apt" o "discover" = flatpak)

Todo lo demás (nombre visible, descripción, icono, categoría, versiones,
estado instalado…) lo autocompleta la tienda con lo encontrado en el
repositorio AppStream correspondiente.

Uso:
  python3 manage.py init                 # (re)crea la BD con el catálogo base
  python3 manage.py add                  # alta interactiva (paquete + gestor)
  python3 manage.py add PAQUETE GESTOR [ESTANTERÍA] [POSICIÓN]
  python3 manage.py list                 # muestra el catálogo por estantería
  python3 manage.py remove PAQUETE [ESTANTERÍA]
  python3 manage.py collections          # muestra las colecciones

Estanterías (shelf): featured, popular, essential, recommended.
Con "collection:Nombre" la app entra en la colección "Nombre" (ver tabla
collections). Los campos opcionales display_name y summary sobreescriben
lo autocompletado; en general conviene dejarlos vacíos.
"""
import sqlite3
import sys
from pathlib import Path

DB = Path(__file__).with_name("store.db")

SHELVES = ("featured", "popular", "essential", "recommended")
BACKENDS = {"apt": "apt", "discover": "flatpak", "flatpak": "flatpak"}

SCHEMA = """
CREATE TABLE IF NOT EXISTS apps (
    package      TEXT NOT NULL,
    backend      TEXT NOT NULL DEFAULT 'apt',
    shelf        TEXT NOT NULL DEFAULT 'featured',
    position     INTEGER NOT NULL DEFAULT 100,
    display_name TEXT,
    summary      TEXT,
    UNIQUE(package, backend, shelf)
);
CREATE TABLE IF NOT EXISTS collections (
    name     TEXT PRIMARY KEY,
    descr    TEXT NOT NULL DEFAULT '',
    position INTEGER NOT NULL DEFAULT 100
);
"""

BASE_CATALOG = [
    # (paquete, gestor, estantería, posición)
    ("krita", "apt", "featured", 1),
    ("blender", "apt", "featured", 2),
    ("gimp", "apt", "featured", 3),
    ("firefox-esr", "apt", "featured", 4),
    ("vlc", "apt", "featured", 5),
    ("firefox-esr", "apt", "popular", 1),
    ("vlc", "apt", "popular", 2),
    ("gimp", "apt", "popular", 3),
    ("libreoffice", "apt", "popular", 4),
    ("thunderbird", "apt", "popular", 5),
    ("krita", "apt", "popular", 6),
    ("inkscape", "apt", "popular", 7),
    ("kate", "apt", "essential", 1),
    ("konsole", "apt", "essential", 2),
    ("okular", "apt", "essential", 3),
    ("dolphin", "apt", "essential", 4),
    ("gwenview", "apt", "essential", 5),
    ("ark", "apt", "essential", 6),
    ("kdenlive", "apt", "recommended", 1),
    ("audacity", "apt", "recommended", 2),
    ("godot", "apt", "recommended", 3),
    ("inkscape", "apt", "recommended", 4),
    ("gwenview", "apt", "recommended", 5),
    ("okular", "apt", "recommended", 6),
    ("kate", "apt", "recommended", 7),
    ("blender", "apt", "recommended", 8),
    ("krita", "apt", "recommended", 9),
    ("libreoffice", "apt", "recommended", 10),
    ("vlc", "apt", "recommended", 11),
    ("thunderbird", "apt", "recommended", 12),
    ("krita", "apt", "collection:Para crear", 1),
    ("blender", "apt", "collection:Para crear", 2),
    ("gimp", "apt", "collection:Para crear", 3),
    ("inkscape", "apt", "collection:Para crear", 4),
    ("kdenlive", "apt", "collection:Para crear", 5),
    ("audacity", "apt", "collection:Para crear", 6),
    ("godot", "apt", "collection:Desarrollo y juegos", 1),
    ("kate", "apt", "collection:Desarrollo y juegos", 2),
    ("konsole", "apt", "collection:Desarrollo y juegos", 3),
    ("firefox-esr", "apt", "collection:Privacidad y comunicación", 1),
    ("thunderbird", "apt", "collection:Privacidad y comunicación", 2),
    ("keepassxc", "apt", "collection:Privacidad y comunicación", 3),
]

BASE_COLLECTIONS = [
    ("Para crear", "Dibujo, modelado, vídeo y audio", 1),
    ("Desarrollo y juegos", "Editores, terminal y motores de juego", 2),
    ("Privacidad y comunicación", "Navega, escribe y protege tus claves", 3),
]


def connect():
    db = sqlite3.connect(DB)
    db.executescript(SCHEMA)
    return db


def init():
    db = connect()
    db.execute("DELETE FROM apps")
    db.execute("DELETE FROM collections")
    db.executemany("INSERT OR REPLACE INTO apps(package, backend, shelf, position) VALUES (?,?,?,?)", BASE_CATALOG)
    db.executemany("INSERT OR REPLACE INTO collections(name, descr, position) VALUES (?,?,?)", BASE_COLLECTIONS)
    db.commit()
    print(f"Catálogo base creado: {DB} ({len(BASE_CATALOG)} entradas)")


def ask(label, default=""):
    value = input(f"{label} [{'{'+default+'}' if default else ''}]: ").strip()
    return value or default


def add(package=None, backend=None, shelf=None, position=100):
    if not package:
        package = ask("Nombre del paquete (ej. krita o org.mozilla.firefox)")
        if not package:
            sys.exit("El nombre del paquete es obligatorio.")
    if backend not in BACKENDS:
        backend = ask("Gestor de paquetes: apt o discover", "apt").lower()
    if backend not in BACKENDS:
        sys.exit("Gestor no válido: usa 'apt' o 'discover'.")
    if not shelf:
        shelf = ask("Estantería: featured, popular, essential, recommended o collection:Nombre", "featured")
    if not position or position is True:
        position = ask("Posición (número, menor = antes)", "100")
    db = connect()
    db.execute("INSERT OR REPLACE INTO apps(package, backend, shelf, position) VALUES (?,?,?,?)",
               (package, BACKENDS[backend], shelf, int(position)))
    if shelf.startswith("collection:"):
        name = shelf.split(":", 1)[1]
        db.execute("INSERT OR IGNORE INTO collections(name, descr, position) VALUES (?,?,100)", (name, ""))
    db.commit()
    print(f"Añadido: {package} ({backend}) → {shelf}")
    print("El resto de datos (nombre, descripción, icono, versión) se autocompleta en la tienda.")
    print("Recuerda hacer commit y push de apps/dylanos-store/catalog/store.db.")


def remove(package, shelf=None):
    db = connect()
    if shelf:
        db.execute("DELETE FROM apps WHERE package=? AND shelf=?", (package, shelf))
    else:
        db.execute("DELETE FROM apps WHERE package=?", (package,))
    db.commit()
    print(f"Eliminado: {package}" + (f" de {shelf}" if shelf else " (todas las estanterías)"))


def listing():
    db = connect()
    for shelf, in db.execute("SELECT DISTINCT shelf FROM apps ORDER BY shelf"):
        print(f"\n[{shelf}]")
        for pkg, backend, pos, name, summary in db.execute(
                "SELECT package, backend, position, display_name, summary FROM apps WHERE shelf=? ORDER BY position", (shelf,)):
            extra = f" — {name}" if name else ""
            extra += f" ({summary})" if summary else ""
            print(f"  {pos:>4}. {pkg} [{backend}]{extra}")
    print("\n[Colecciones]")
    for name, descr, pos in db.execute("SELECT name, descr, position FROM collections ORDER BY position"):
        print(f"  {pos:>4}. {name} — {descr}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "init":
        init()
    elif cmd == "add":
        add(*sys.argv[2:])
    elif cmd == "remove":
        remove(*sys.argv[2:])
    elif cmd in ("list", "collections", ""):
        listing()
    else:
        sys.exit(__doc__)
