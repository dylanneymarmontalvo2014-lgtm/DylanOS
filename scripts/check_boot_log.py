#!/usr/bin/env python3
"""Recognize systemd boot milestones in a serial log, including ANSI-decorated output."""
import re
import sys
from pathlib import Path


def strip_terminal_sequences(text: str) -> str:
    # CSI (including SGR colors) and OSC sequences used by systemd/console.
    text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    return re.sub(r"\x1b\][^\x07]*(?:\x07|\x1b\\)", "", text)


def boot_milestones_reached(text: str) -> bool:
    clean = strip_terminal_sequences(text)
    return "Reached target graphical.target" in clean and "Started sddm.service" in clean


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Uso: check-boot-log.py RUTA_LOG")
    try:
        log = Path(sys.argv[1]).read_text(errors="replace")
    except OSError:
        raise SystemExit(1)
    raise SystemExit(0 if boot_milestones_reached(log) else 1)
