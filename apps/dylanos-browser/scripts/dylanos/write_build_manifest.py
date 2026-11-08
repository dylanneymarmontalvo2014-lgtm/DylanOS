# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import argparse
import json
import platform
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = ROOT / "artifacts" / "bootstrap" / "environment.json"


def command_version(runner, command, root):
    result = runner(
        command,
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return "no disponible"
    return (result.stdout or result.stderr).splitlines()[0].strip()


def find_clang(which, home):
    path = which("clang")
    if path:
        return path
    candidate = Path(home) / ".mozbuild" / "clang" / "bin" / "clang"
    return str(candidate) if candidate.is_file() else None


def build_manifest(
    root=ROOT,
    *,
    runner=subprocess.run,
    which=shutil.which,
    disk_usage=shutil.disk_usage,
    now=lambda: datetime.now(timezone.utc),
    home=Path.home(),
):
    root = Path(root)
    upstream = json.loads(
        (root / "dylanos" / "upstream.json").read_text(encoding="utf-8")
    )
    package_lock = json.loads(
        (root / "package-lock.json").read_text(encoding="utf-8")
    )
    clang = find_clang(which, home)
    tools = {
        "node": command_version(runner, ["node", "--version"], root),
        "npm": command_version(runner, ["npm", "--version"], root),
        "python": command_version(runner, ["python3", "--version"], root),
        "rustc": command_version(runner, ["rustc", "--version"], root),
        "cargo": command_version(runner, ["cargo", "--version"], root),
        "clang": (
            command_version(runner, [clang, "--version"], root)
            if clang
            else "no disponible"
        ),
        "surfer": package_lock["packages"][
            "node_modules/@zen-browser/surfer"
        ]["version"],
    }
    usage = disk_usage(root)
    return {
        "schema_version": 1,
        "generated_at": now().isoformat(),
        "source": {
            "dylanos_browser_commit": command_version(
                runner, ["git", "rev-parse", "HEAD"], root
            ),
            "zen_repository": upstream["repository"],
            "zen_tag": upstream["tag"],
            "zen_commit": upstream["commit"],
            "firefox_version": upstream["firefox_version"],
        },
        "tools": tools,
        "system": {
            "platform": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
        },
        "disk": {
            "free_gib": round(usage.free / (1024**3), 1),
        },
    }


def write_manifest(output, manifest):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        f"{json.dumps(manifest, indent=2, sort_keys=True)}\n",
        encoding="utf-8",
    )


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Guarda la procedencia y el toolchain del build de DylanOS Browser."
    )
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--require-clang", action="store_true")
    arguments = parser.parse_args(argv)

    manifest = build_manifest(arguments.root)
    write_manifest(arguments.output, manifest)
    print(arguments.output)
    if arguments.require_clang and manifest["tools"]["clang"] == "no disponible":
        print("ERROR: clang no está disponible en PATH ni en ~/.mozbuild/clang/bin")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
