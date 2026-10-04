"""Filesystem services for DylanOS. No shell commands or GUI dependencies."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import uuid


def safe_name(name):
    if not name.strip() or name in (".", "..") or "/" in name or "\0" in name:
        raise ValueError("Escribe un nombre válido, sin barras.")
    return name


def human_size(value):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024 or unit == "TB":
            return f"{value:.1f} {unit}"
        value /= 1024


def list_folder(path, hidden=False):
    result = []
    with os.scandir(path) as entries:
        for entry in entries:
            if not hidden and entry.name.startswith("."):
                continue
            try:
                stat = entry.stat(follow_symlinks=False)
                folder = entry.is_dir()
                result.append(dict(name=entry.name, path=entry.path, folder=folder,
                                   link=entry.is_symlink(), size="Carpeta" if folder else human_size(stat.st_size),
                                   modified=datetime.fromtimestamp(stat.st_mtime).strftime("%d %b %Y · %H:%M"),
                                   kind="folder" if folder else (Path(entry.name).suffix[1:].upper() or "Archivo")))
            except FileNotFoundError:
                continue
    return sorted(result, key=lambda item: (not item["folder"], item["name"].casefold()))


def copy_entry(source, directory):
    source, directory = Path(source), Path(directory)
    if source.is_dir() and (directory.resolve() == source.resolve() or source.resolve() in directory.resolve().parents):
        raise ValueError("No puedes copiar una carpeta dentro de sí misma.")
    target = directory / source.name
    if target.exists() or target.is_symlink():
        raise FileExistsError("Ya existe un elemento con ese nombre. No se sobrescribió.")
    # Reserve the destination exclusively, including for symlinks and files.
    if source.is_symlink():
        target.symlink_to(os.readlink(source))
    elif source.is_dir():
        shutil.copytree(source, target, symlinks=True)
    else:
        with source.open("rb") as incoming, target.open("xb") as outgoing:
            shutil.copyfileobj(incoming, outgoing)
        shutil.copystat(source, target)
    return target


class Notes:
    """SQLite gives atomic saves and safe concurrent app instances."""
    def __init__(self, directory):
        import sqlite3
        directory = Path(directory)
        directory.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(directory / "notes.sqlite3")
        self.db.execute("CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, title TEXT, body TEXT, updated TEXT)")
        self.db.commit()

    def all(self):
        return [dict(id=row[0], title=row[1], body=row[2], updated=row[3])
                for row in self.db.execute("SELECT * FROM notes ORDER BY updated DESC")]

    def save(self, note_id, title, body):
        note_id = note_id or uuid.uuid4().hex
        with self.db:
            self.db.execute("INSERT INTO notes VALUES (?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET title=excluded.title, body=excluded.body, updated=excluded.updated",
                            (note_id, title.strip() or "Sin título", body, datetime.now(timezone.utc).isoformat()))
        return note_id

    def delete(self, note_id):
        with self.db:
            self.db.execute("DELETE FROM notes WHERE id = ?", (note_id,))


TEMPLATES = {
    "Python": {
        "main.py": 'def main():\n    print("Hola, DylanOS")\n\n\nif __name__ == "__main__":\n    main()\n',
        "README.md": "# Proyecto Python\n\n```sh\npython3 -m venv .venv\n. .venv/bin/activate\npython3 main.py\n```\n",
        ".gitignore": ".venv/\n__pycache__/\n*.pyc\n.env\n",
    },
    "Web": {
        "index.html": '<!doctype html>\n<html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Mi proyecto</title><link rel="stylesheet" href="style.css"><main><h1>Hola, DylanOS.</h1><p>Tu próxima idea empieza aquí.</p></main></html>\n',
        "style.css": "body { font: 18px system-ui; background: #15151b; color: #f5f5f7; margin: 12vw; } h1 { font-size: clamp(2rem, 7vw, 5rem); letter-spacing: -.05em; }\n",
        "README.md": "# Proyecto web\n\nEjecuta `python3 -m http.server 8000 --bind 127.0.0.1` y abre http://localhost:8000.\n",
        ".gitignore": "node_modules/\n.env\ndist/\n",
    },
    "C++": {
        "main.cpp": '#include <iostream>\nint main() { std::cout << "Hola, DylanOS\\n"; }\n',
        "CMakeLists.txt": "cmake_minimum_required(VERSION 3.20)\nproject(hello LANGUAGES CXX)\nset(CMAKE_CXX_STANDARD 17)\nadd_executable(hello main.cpp)\n",
        "README.md": "# Proyecto C++\n\n```sh\ncmake -S . -B build\ncmake --build build\n./build/hello\n```\n",
        ".gitignore": "build/\n.env\n",
    },
}


def create_project(parent, name, template):
    safe_name(name)
    if not re.fullmatch(r"[\w.-]+", name, re.UNICODE) or name.startswith("."):
        raise ValueError("Usa letras, números, guiones o puntos; empieza con una letra o número.")
    if template not in TEMPLATES:
        raise ValueError("Plantilla desconocida.")
    parent = Path(parent).expanduser().resolve()
    parent.mkdir(parents=True, exist_ok=True)
    target = parent / name
    target.mkdir()  # exclusive; never reuse an existing project
    try:
        for filename, content in TEMPLATES[template].items():
            (target / filename).write_text(content, encoding="utf-8")
    except Exception:
        shutil.rmtree(target)
        raise
    return target
