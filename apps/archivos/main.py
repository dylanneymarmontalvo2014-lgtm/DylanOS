#!/usr/bin/env python3
"""Launcher de Archivos; la implementación real vive en Workspace."""
import runpy
import sys
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent


def main():
    workspace = APP_DIR.parent / "workspace"
    sys.path.insert(0, str(workspace))
    sys.argv[1:1] = ["--page", "files"]
    runpy.run_path(str(workspace / "main.py"), run_name="__main__")


if __name__ == "__main__":
    main()
