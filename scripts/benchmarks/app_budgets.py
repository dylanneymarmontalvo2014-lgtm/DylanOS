#!/usr/bin/env python3
"""Mide el presupuesto de recursos de las aplicaciones oficiales de DylanOS.

Ejecuta el arnés `resource_benchmark.py` una vez por aplicación, agrega los
resultados y escribe JSON + Markdown. Está pensado para correr en una sesión
instalada; con `--offscreen` usa Qt sin pantalla (no mide GPU ni FPS).
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any

BENCHMARK = Path(__file__).resolve().with_name("resource_benchmark.py")

# Comandos reales del ecosistema oficial. `dylanos` es el wrapper del Workspace;
# el resto son binarios instalados por sus paquetes.
APPS: dict[str, list[str]] = {
    "configuration": ["dylanos-configuration", "--page", "system"],
    "explorer": ["dylanos-explorer"],
    "calculator": ["dylanos-calculator"],
    "app-center": ["dylanos-app-center"],
    "spotlight": ["dylanos-spotlight"],
    "workspace": ["dylanos", "--page", "welcome"],
    "store": ["dylanos-store"],
    "process": ["dylanos-process"],
}

STATUS_LABEL = {
    "pass": "aprobado",
    "incomplete": "incompleto",
    "fail": "fuera de límite",
}


def summarize_report(report: dict[str, Any]) -> dict[str, Any]:
    """Reduce el informe del arnés a las columnas del presupuesto."""
    summary = report["summary"]

    def mib(key: str) -> float | None:
        value = summary.get(key)
        return None if value is None else round(float(value) / 1024, 2)

    return {
        "name": report["name"],
        "ram_rss_mib": mib("ram_rss_max_kib"),
        "ram_pss_mib": mib("ram_pss_max_kib"),
        "cpu_average_percent": summary.get("cpu_system_average_percent"),
        "cpu_max_percent": summary.get("cpu_system_max_percent"),
        "gpu_max_percent": summary.get("gpu_max_percent"),
        "processes_max": summary.get("processes_max"),
        "status": report["budget"]["status"],
    }


def render_markdown(entries: dict[str, dict[str, Any]]) -> str:
    lines = [
        "# Presupuesto de recursos de las apps oficiales",
        "",
        "| Aplicación | RAM RSS máx (MiB) | RAM PSS máx (MiB) | CPU media | CPU máx | GPU máx | Procesos | Estado |",
        "|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for name in sorted(entries):
        entry = entries[name]
        if "error" in entry:
            lines.append(f"| `{name}` | — | — | — | — | — | — | no disponible: {entry['error']} |")
            continue
        row = summarize_report(entry["report"])
        def shown(value: Any, suffix: str = "") -> str:
            return "—" if value is None else f"{value}{suffix}"
        lines.append(
            f"| `{name}` | {shown(row['ram_rss_mib'])} | {shown(row['ram_pss_mib'])} | "
            f"{shown(row['cpu_average_percent'], ' %')} | {shown(row['cpu_max_percent'], ' %')} | "
            f"{shown(row['gpu_max_percent'], ' %')} | {shown(row['processes_max'])} | "
            f"{STATUS_LABEL.get(row['status'], row['status'])} |"
        )
    lines.extend([
        "",
        "Límites por aplicación: 200 MiB de RAM, 3 % de CPU normalizada y 1 % de GPU.",
        "Una métrica ausente deja el estado en «incompleto»; no se considera aprobada.",
        "DylanOS Browser queda excluido de este presupuesto.",
        "",
    ])
    return "\n".join(lines)


def _run_app(name: str, command: list[str], args: argparse.Namespace, output: Path,
             environment: dict[str, str]) -> dict[str, Any]:
    executable = shutil.which(command[0])
    if executable is None:
        return {"command": command, "error": f"{command[0]} no está instalado"}
    report_path = output / f"{name}.json"
    invocation = [
        sys.executable, str(BENCHMARK), "--name", name,
        "--duration", str(args.duration), "--interval", str(args.interval),
        "--warmup", str(args.warmup), "--output", str(report_path), "--",
        executable, *command[1:],
    ]
    completed = subprocess.run(invocation, capture_output=True, text=True, env=environment)
    if not report_path.is_file():
        detail = (completed.stderr or completed.stdout).strip().splitlines()
        return {"command": command, "error": detail[-1] if detail else f"código {completed.returncode}"}
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if completed.returncode not in (0, 1):
        return {"command": command, "report": report,
                "error": (completed.stderr or "").strip().splitlines()[-1:] or ["fallo"]}
    if report["summary"].get("processes_max", 0) == 0:
        return {"command": command,
                "error": "el proceso terminó antes de la primera muestra"}
    return {"command": command, "report": report}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", action="append", choices=sorted(APPS),
                        help="Mide solo esta app (repetible); por defecto todas")
    parser.add_argument("--duration", type=float, default=15.0)
    parser.add_argument("--warmup", type=float, default=5.0)
    parser.add_argument("--interval", type=float, default=0.5)
    parser.add_argument("--output-dir", type=Path, default=Path("benchmark-results/apps"))
    parser.add_argument("--offscreen", action="store_true",
                        help="Ejecuta las apps con Qt offscreen y renderizado por software")
    args = parser.parse_args(argv)
    if args.duration <= 0 or args.interval <= 0 or args.warmup < 0:
        parser.error("--duration y --interval deben ser > 0; --warmup no puede ser negativo")

    environment = dict(os.environ)
    if args.offscreen:
        environment["QT_QPA_PLATFORM"] = "offscreen"
        environment["QT_QUICK_BACKEND"] = "software"

    args.output_dir.mkdir(parents=True, exist_ok=True)
    selected = args.app or sorted(APPS)
    entries: dict[str, dict[str, Any]] = {}
    for name in selected:
        entries[name] = _run_app(name, APPS[name], args, args.output_dir, environment)

    report = {
        "date_utc": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        "duration_s": args.duration,
        "warmup_s": args.warmup,
        "offscreen": args.offscreen,
        "environment": {
            "platform": sys.platform,
            "python": sys.version.split()[0],
        },
        "apps": entries,
    }
    markdown = render_markdown(entries)
    (args.output_dir / "apps-budget.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (args.output_dir / "apps-budget.md").write_text(markdown + "\n", encoding="utf-8")
    print(markdown)

    failed = any(
        entry.get("report", {}).get("budget", {}).get("status") == "fail"
        for entry in entries.values()
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
