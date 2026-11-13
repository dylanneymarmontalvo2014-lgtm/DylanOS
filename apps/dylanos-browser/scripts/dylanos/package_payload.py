# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DIST = ROOT / "engine" / "obj-x86_64-pc-linux-gnu" / "dist" / "bin"
DEFAULT_OUTPUT = ROOT / "artifacts" / "phase-2" / "package"
MANIFEST_NAME = "payload-manifest.json"
WRAPPER = "#!/bin/sh\nexec /usr/lib/dylanos-browser/dylanos-browser \"$@\"\n"
EXPECTED_IDENTITY = {
    "Vendor": "DylanOS",
    "Name": "DylanOSBrowser",
    "RemotingName": "dylanos-browser",
    "CodeName": "DylanOS Browser",
    "Profile": "dylanos-browser",
}


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_identity(dist_dir):
    dist_dir = Path(dist_dir)
    binary = dist_dir / "dylanos-browser"
    if not binary.is_file() or not os.access(binary, os.X_OK):
        raise ValueError(f"Falta el binario real ejecutable dylanos-browser en {dist_dir}")
    application_ini = dist_dir / "application.ini"
    if not application_ini.is_file():
        raise ValueError(f"Falta {application_ini}")
    parser = configparser.ConfigParser(interpolation=None)
    parser.read(application_ini, encoding="utf-8")
    if "App" not in parser:
        raise ValueError(f"Falta la sección App en {application_ini}")
    for key, expected in EXPECTED_IDENTITY.items():
        actual = parser.get("App", key, fallback=None)
        if actual != expected:
            raise ValueError(
                f"Identidad App.{key} inválida: {actual!r}; se esperaba {expected!r}"
            )


def file_inventory(payload_dir):
    payload_dir = Path(payload_dir).resolve()
    inventory = {}
    for path in sorted(payload_dir.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(payload_dir).as_posix()
        if relative == MANIFEST_NAME:
            continue
        metadata = path.lstat()
        if stat.S_ISLNK(metadata.st_mode):
            target = os.readlink(path)
            try:
                resolved = path.resolve(strict=True)
                resolved.relative_to(payload_dir)
            except (FileNotFoundError, RuntimeError, ValueError) as error:
                raise ValueError(
                    f"Enlace simbólico inseguro en el payload: {relative} -> {target}"
                ) from error
            inventory[relative] = {
                "type": "symlink",
                "target": target,
            }
        elif stat.S_ISDIR(metadata.st_mode):
            continue
        elif stat.S_ISREG(metadata.st_mode):
            inventory[relative] = {
                "type": "file",
                "mode": stat.S_IMODE(metadata.st_mode),
                "size_bytes": metadata.st_size,
                "sha256": sha256_file(path),
            }
        else:
            raise ValueError(f"Tipo de archivo no soportado en payload: {relative}")
    return inventory


def prepare_payload(dist_dir, output_dir, source_commit):
    dist_dir = Path(dist_dir).resolve()
    output_dir = Path(output_dir).resolve()
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise ValueError("source_commit debe ser un SHA-1 Git completo de 40 caracteres")
    validate_identity(dist_dir)
    if (
        output_dir == Path("/")
        or output_dir == dist_dir
        or output_dir in dist_dir.parents
        or dist_dir in output_dir.parents
    ):
        raise ValueError("La salida del payload debe ser un directorio independiente")
    if output_dir.exists():
        shutil.rmtree(output_dir)
    runtime = output_dir / "usr/lib/dylanos-browser"
    try:
        shutil.copytree(dist_dir, runtime, symlinks=False)
    except (OSError, shutil.Error) as error:
        if output_dir.exists():
            shutil.rmtree(output_dir)
        raise ValueError(
            f"No se pudo materializar un enlace del runtime de DylanOS Browser: {error}"
        ) from error
    wrapper = output_dir / "usr/bin/dylanos-browser"
    wrapper.parent.mkdir(parents=True, exist_ok=True)
    wrapper.write_text(WRAPPER, encoding="utf-8")
    wrapper.chmod(0o755)
    manifest = {
        "schema_version": 1,
        "mode": "candidate",
        "source_commit": source_commit,
        "binary": "usr/lib/dylanos-browser/dylanos-browser",
        "desktop_id": "org.dylanos.browser.desktop",
        "files": file_inventory(output_dir),
    }
    (output_dir / MANIFEST_NAME).write_text(
        f"{json.dumps(manifest, indent=2, sort_keys=True)}\n",
        encoding="utf-8",
    )
    verify_payload(output_dir)
    return manifest


def verify_payload(payload_dir):
    payload_dir = Path(payload_dir).resolve()
    manifest_path = payload_dir / MANIFEST_NAME
    if not manifest_path.is_file():
        raise ValueError(
            f"No se puede empaquetar: falta el payload real de dylanos-browser "
            f"({manifest_path})"
        )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1 or manifest.get("mode") != "candidate":
        raise ValueError("El manifiesto no corresponde a un build candidate")
    if manifest.get("desktop_id") != "org.dylanos.browser.desktop":
        raise ValueError("El desktop ID del payload no es org.dylanos.browser.desktop")
    if manifest.get("binary") != "usr/lib/dylanos-browser/dylanos-browser":
        raise ValueError("La ruta del binario del payload no es la canónica")
    if not re.fullmatch(r"[0-9a-f]{40}", str(manifest.get("source_commit", ""))):
        raise ValueError("El manifiesto no contiene un commit fuente Git válido")
    expected_files = manifest.get("files")
    if not isinstance(expected_files, dict):
        raise ValueError("El manifiesto no contiene el inventario de archivos")
    actual_files = file_inventory(payload_dir)
    if set(actual_files) != set(expected_files):
        missing = sorted(set(expected_files) - set(actual_files))
        extra = sorted(set(actual_files) - set(expected_files))
        raise ValueError(f"Inventario del payload distinto; faltan={missing}, sobran={extra}")
    for relative, expected in expected_files.items():
        actual = actual_files[relative]
        if actual.get("type") != expected.get("type"):
            raise ValueError(f"Tipo de archivo distinto en {relative}")
        if actual["type"] == "file" and actual.get("sha256") != expected.get("sha256"):
            raise ValueError(f"SHA-256 inválido en {relative}")
        if actual != expected:
            raise ValueError(f"Metadatos distintos en {relative}")
    wrapper = payload_dir / "usr/bin/dylanos-browser"
    if wrapper.read_text(encoding="utf-8") != WRAPPER or not os.access(wrapper, os.X_OK):
        raise ValueError("El wrapper dylanos-browser no es el canónico ejecutable")
    validate_identity(payload_dir / "usr/lib/dylanos-browser")
    return manifest


def git_commit():
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ValueError(result.stderr.strip() or "No se pudo leer el commit fuente")
    return result.stdout.strip()


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Prepara y verifica el payload Debian de DylanOS Browser."
    )
    commands = parser.add_subparsers(dest="command", required=True)
    prepare = commands.add_parser("prepare")
    prepare.add_argument("--dist", type=Path, default=DEFAULT_DIST)
    prepare.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    prepare.add_argument("--source-commit")
    verify = commands.add_parser("verify")
    verify.add_argument("--payload", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "prepare":
            manifest = prepare_payload(
                arguments.dist,
                arguments.output,
                arguments.source_commit or git_commit(),
            )
            print(f"Payload candidate preparado: {arguments.output}")
        else:
            manifest = verify_payload(arguments.payload)
            print(f"Payload candidate verificado: {arguments.payload}")
        print(f"Fuente: {manifest['source_commit']}")
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
