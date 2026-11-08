# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import argparse
import re
import shutil
import subprocess
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REQUIRED_COMMANDS = (
    "git",
    "npm",
    "cargo",
    "rustc",
    "cmake",
    "ninja",
    "pkg-config",
    "tar",
    "xz",
    "make",
    "python3",
)


@dataclass(frozen=True)
class Check:
    name: str
    ok: bool
    detail: str


def linux_memory_info(path=Path("/proc/meminfo")):
    if not path.is_file():
        return None
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition(":")
        if separator and key in {"MemTotal", "SwapTotal"}:
            values[key] = int(value.split()[0]) * 1024
    if "MemTotal" not in values or "SwapTotal" not in values:
        return None
    return values["MemTotal"], values["SwapTotal"]


def command_output(runner, command):
    result = runner(
        command,
        check=False,
        capture_output=True,
        text=True,
    )
    return result.returncode, (result.stdout or result.stderr).strip()


def check_environment(
    root,
    *,
    runner=subprocess.run,
    which=shutil.which,
    disk_usage=shutil.disk_usage,
    memory_info=linux_memory_info,
    min_free_gib=30,
    min_total_memory_gib=16,
    required_commands=REQUIRED_COMMANDS,
):
    root = Path(root)
    checks = []

    expected_node = (root / ".nvmrc").read_text(encoding="utf-8").strip()
    node_code, node_output = command_output(runner, ["node", "--version"])
    node_match = re.search(r"v?(\d+)", node_output)
    node_ok = (
        node_code == 0
        and node_match is not None
        and node_match.group(1) == expected_node
    )
    checks.append(
        Check(
            "Node.js",
            node_ok,
            f"Node.js {expected_node} requerido; detectado: {node_output or 'no disponible'}",
        )
    )

    python_code, python_output = command_output(runner, ["python3", "--version"])
    python_match = re.search(r"Python (\d+)\.(\d+)", python_output)
    python_ok = (
        python_code == 0
        and python_match is not None
        and tuple(map(int, python_match.groups())) >= (3, 11)
    )
    checks.append(
        Check(
            "Python",
            python_ok,
            f"Python 3.11 o posterior requerido; detectado: {python_output or 'no disponible'}",
        )
    )

    toolchain = tomllib.loads(
        (root / "rust-toolchain.toml").read_text(encoding="utf-8")
    )
    expected_rust = toolchain["toolchain"]["channel"]
    rust_code, rust_output = command_output(runner, ["rustc", "--version"])
    rust_match = re.search(r"rustc (\d+\.\d+\.\d+)", rust_output)
    rust_ok = (
        rust_code == 0
        and rust_match is not None
        and rust_match.group(1) == expected_rust
    )
    checks.append(
        Check(
            "Rust",
            rust_ok,
            f"Rust {expected_rust} requerido; detectado: {rust_output or 'no disponible'}",
        )
    )

    free_gib = disk_usage(root).free / (1024**3)
    checks.append(
        Check(
            "Espacio libre",
            free_gib >= min_free_gib,
            f"{min_free_gib} GiB libres requeridos; detectados: {free_gib:.1f} GiB",
        )
    )

    memory = memory_info()
    if memory is not None:
        ram_bytes, swap_bytes = memory
        total_memory_gib = (ram_bytes + swap_bytes) / (1024**3)
        checks.append(
            Check(
                "Memoria de build",
                total_memory_gib >= min_total_memory_gib,
                f"{min_total_memory_gib} GiB de RAM+swap requeridos; "
                f"detectados: {total_memory_gib:.1f} GiB",
            )
        )

    for command in required_commands:
        path = which(command)
        checks.append(
            Check(
                f"Herramienta {command}",
                path is not None,
                f"Herramienta requerida {command}: {path or 'no encontrada en PATH'}",
            )
        )

    return checks


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Valida el entorno antes del bootstrap de DylanOS Browser."
    )
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--min-free-gib", type=int, default=30)
    parser.add_argument("--min-total-memory-gib", type=int, default=16)
    arguments = parser.parse_args(argv)

    checks = check_environment(
        arguments.root,
        min_free_gib=arguments.min_free_gib,
        min_total_memory_gib=arguments.min_total_memory_gib,
    )
    for check in checks:
        marker = "OK" if check.ok else "ERROR"
        print(f"[{marker}] {check.detail}")
    return 0 if all(check.ok for check in checks) else 1


if __name__ == "__main__":
    sys.exit(main())
