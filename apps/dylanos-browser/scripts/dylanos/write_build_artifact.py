# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OBJDIR = ROOT / "engine" / "obj-x86_64-pc-linux-gnu"


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def collect_build_artifact(
    *,
    mode,
    binary,
    mozconfig,
    log,
    elapsed_seconds,
    runner=subprocess.run,
    root=ROOT,
    now=lambda: datetime.now(timezone.utc),
):
    binary = Path(binary)
    mozconfig = Path(mozconfig)
    log = Path(log)
    for path in (binary, mozconfig, log):
        if not path.is_file():
            raise FileNotFoundError(path)
    commit = runner(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if commit.returncode != 0:
        raise RuntimeError(commit.stderr.strip() or "No se pudo leer el commit")
    return {
        "schema_version": 1,
        "generated_at": now().isoformat(),
        "mode": mode,
        "elapsed_seconds": elapsed_seconds,
        "source_commit": commit.stdout.strip(),
        "binary": {
            "path": str(binary),
            "size_bytes": binary.stat().st_size,
            "sha256": sha256_file(binary),
        },
        "mozconfig": {
            "path": str(mozconfig),
            "sha256": sha256_file(mozconfig),
        },
        "log": {
            "path": str(log),
            "sha256": sha256_file(log),
        },
    }


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Registra hashes, tamaño y duración de un build de DylanOS Browser."
    )
    parser.add_argument("--mode", choices=("diagnostic", "candidate"), required=True)
    parser.add_argument("--elapsed-seconds", type=int, required=True)
    parser.add_argument(
        "--binary", type=Path, default=DEFAULT_OBJDIR / "dist" / "bin" / "dylanos-browser"
    )
    parser.add_argument("--mozconfig", type=Path, default=ROOT / "engine" / "mozconfig")
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args(argv)
    manifest = collect_build_artifact(
        mode=arguments.mode,
        binary=arguments.binary,
        mozconfig=arguments.mozconfig,
        log=arguments.log,
        elapsed_seconds=arguments.elapsed_seconds,
    )
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(
        f"{json.dumps(manifest, indent=2, sort_keys=True)}\n",
        encoding="utf-8",
    )
    print(arguments.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
