#!/usr/bin/env python3
"""Mide recursos reales de aplicaciones o del sistema mediante procfs."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import platform
import shlex
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import time
from typing import Any, Iterable


def _fields(text: str) -> dict[str, list[str]]:
    result = {}
    for line in text.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            result[key] = value.split()
    return result


def _kib(fields: dict[str, list[str]], key: str, default: int = 0) -> int:
    try:
        return int(fields[key][0])
    except (KeyError, IndexError, ValueError):
        return default


def parse_status(text: str) -> dict[str, Any]:
    fields = _fields(text)
    return {
        "name": " ".join(fields.get("Name", ["desconocido"])),
        "ppid": _kib(fields, "PPid"),
        "rss_kib": _kib(fields, "VmRSS"),
        "swap_kib": _kib(fields, "VmSwap"),
    }


def parse_smaps_rollup(text: str) -> int | None:
    fields = _fields(text)
    return _kib(fields, "Pss") if "Pss" in fields else None


def parse_io(text: str) -> dict[str, int]:
    fields = _fields(text)
    return {"read_bytes": _kib(fields, "read_bytes"), "write_bytes": _kib(fields, "write_bytes")}


def parse_stat(text: str) -> dict[str, int]:
    closing = text.rfind(")")
    if closing < 0:
        raise ValueError("stat sin nombre de proceso terminado")
    fields = text[closing + 1:].split()
    if len(fields) < 13:
        raise ValueError("stat incompleto")
    return {"ppid": int(fields[1]), "cpu_ticks": int(fields[11]) + int(fields[12])}


def parse_meminfo(text: str) -> dict[str, int]:
    fields = _fields(text)
    total = _kib(fields, "MemTotal")
    available = _kib(fields, "MemAvailable")
    swap_total = _kib(fields, "SwapTotal")
    swap_free = _kib(fields, "SwapFree")
    return {
        "memory_total_kib": total,
        "memory_available_kib": available,
        "memory_used_kib": max(0, total - available),
        "swap_total_kib": swap_total,
        "swap_free_kib": swap_free,
        "swap_used_kib": max(0, swap_total - swap_free),
    }


def parse_cpu_stat(text: str) -> dict[str, int]:
    fields = text.split()
    if not fields or fields[0] != "cpu" or len(fields) < 6:
        raise ValueError("línea CPU global ausente")
    values = [int(value) for value in fields[1:]]
    return {"total_ticks": sum(values), "idle_ticks": values[3] + values[4]}


def parse_diskstat(text: str) -> dict[str, Any]:
    fields = text.split()
    if len(fields) < 10:
        raise ValueError("diskstat incompleto")
    return {
        "device": fields[2],
        "read_bytes": int(fields[5]) * 512,
        "write_bytes": int(fields[9]) * 512,
    }


def parse_fdinfo_engines(text: str) -> dict[str, int]:
    """Extrae los nanosegundos por motor DRM que publica el kernel en fdinfo."""
    engines: dict[str, int] = {}
    for line in text.splitlines():
        key, separator, value = line.partition(":")
        if not separator or not key.startswith("drm-engine-"):
            continue
        parts = value.split()
        if not parts:
            continue
        try:
            engines[key] = int(parts[0])
        except ValueError:
            continue
    return engines


class Procfs:
    def __init__(self, root: Path = Path("/proc")):
        self.root = root

    def _read(self, pid: int, name: str) -> str:
        return (self.root / str(pid) / name).read_text(encoding="utf-8", errors="replace")

    def process(self, pid: int) -> dict[str, Any]:
        process = {"pid": pid, **parse_status(self._read(pid, "status")), **parse_stat(self._read(pid, "stat"))}
        try:
            process.update(parse_io(self._read(pid, "io")))
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            process.update({"read_bytes": None, "write_bytes": None})
        try:
            process["pss_kib"] = parse_smaps_rollup(self._read(pid, "smaps_rollup"))
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            process["pss_kib"] = None
        return process

    def processes(self) -> dict[int, dict[str, Any]]:
        result = {}
        for entry in self.root.iterdir():
            if not entry.name.isdigit():
                continue
            try:
                process = self.process(int(entry.name))
            except (FileNotFoundError, PermissionError, ProcessLookupError, ValueError):
                continue
            result[process["pid"]] = process
        return result

    def gpu_engines(self, pid: int) -> dict[str, int] | None:
        """Suma los contadores DRM de todos los descriptores del proceso."""
        try:
            entries = list((self.root / str(pid) / "fdinfo").iterdir())
        except (FileNotFoundError, PermissionError, NotADirectoryError, ProcessLookupError):
            return None
        engines: dict[str, int] = {}
        for entry in entries:
            try:
                text = entry.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for engine, nanoseconds in parse_fdinfo_engines(text).items():
                engines[engine] = engines.get(engine, 0) + nanoseconds
        return engines or None

    def meminfo(self) -> dict[str, int]:
        return parse_meminfo((self.root / "meminfo").read_text(encoding="utf-8"))

    def cpu_stat(self) -> dict[str, int]:
        with (self.root / "stat").open(encoding="utf-8") as source:
            return parse_cpu_stat(source.readline())

    def diskstats(self) -> dict[str, dict[str, Any]]:
        result = {}
        for line in (self.root / "diskstats").read_text(encoding="utf-8").splitlines():
            try:
                item = parse_diskstat(line)
            except ValueError:
                continue
            fields = line.split()
            if (self.root / "sys/dev/block" / f"{fields[0]}:{fields[1]}" / "partition").exists():
                continue
            result[item["device"]] = item
        return result


def tree_pids(processes: dict[int, dict[str, Any]], root_pid: int) -> set[int]:
    if root_pid not in processes:
        return set()
    selected = {root_pid}
    changed = True
    while changed:
        changed = False
        for pid, process in processes.items():
            if pid not in selected and process["ppid"] in selected:
                selected.add(pid)
                changed = True
    return selected


def aggregate_processes(processes: dict[int, dict[str, Any]], pids: Iterable[int]) -> dict[str, Any]:
    selected = [processes[pid] for pid in pids if pid in processes]
    result: dict[str, Any] = {"process_count": len(selected)}
    for key in ("rss_kib", "swap_kib", "cpu_ticks", "read_bytes", "write_bytes"):
        values = [process[key] for process in selected]
        result[key] = sum(values) if all(value is not None for value in values) else None
    pss = [process["pss_kib"] for process in selected]
    result["pss_kib"] = sum(pss) if all(value is not None for value in pss) else None
    return result


def cpu_percentages(delta_ticks: int, elapsed_s: float, ticks_per_second: int, cpu_count: int) -> tuple[float, float]:
    if elapsed_s <= 0 or ticks_per_second <= 0 or cpu_count <= 0:
        return 0.0, 0.0
    one_core = max(0.0, delta_ticks) * 100.0 / ticks_per_second / elapsed_s
    return round(one_core, 3), round(one_core / cpu_count, 3)


def _mean_max(samples: list[dict[str, Any]], key: str) -> tuple[float | None, float | None]:
    values = [float(sample[key]) for sample in samples if sample.get(key) is not None]
    if not values:
        return None, None
    return round(statistics.mean(values), 3), round(max(values), 3)


class ApplicationSampler:
    def __init__(self, procfs: Procfs, root_pid: int, ticks_per_second: int, cpu_count: int):
        self.procfs = procfs
        self.root_pid = root_pid
        self.ticks_per_second = ticks_per_second
        self.cpu_count = cpu_count
        self.previous: dict[int, dict[str, Any]] = {}
        self.previous_time: float | None = None
        self.previous_gpu: dict[int, dict[str, int]] | None = None
        self.child_pids: set[int] = set()
        self.process_names: dict[int, str] = {}

    def _delta(self, current: dict[int, dict[str, Any]], key: str) -> int | None:
        total = 0
        for pid, process in current.items():
            if pid not in self.previous:
                continue
            before = self.previous[pid].get(key)
            after = process.get(key)
            if before is None or after is None:
                return None
            total += max(0, after - before)
        return total

    def _gpu_delta(self, pids: set[int], elapsed: float) -> float | None:
        """Uso de GPU por proceso a partir de los contadores DRM del kernel."""
        reader = getattr(self.procfs, "gpu_engines", None)
        if reader is None:
            return None
        current = {pid: engines for pid in pids if (engines := reader(pid))}
        previous = self.previous_gpu
        self.previous_gpu = current
        if previous is None or elapsed <= 0 or not current:
            return None
        per_engine: dict[str, int] = {}
        for pid, engines in current.items():
            before = previous.get(pid)
            if not before:
                continue
            for engine, nanoseconds in engines.items():
                if engine in before:
                    per_engine[engine] = per_engine.get(engine, 0) + max(0, nanoseconds - before[engine])
        if not per_engine:
            return None
        busiest = max(per_engine.values())
        return round(busiest / (elapsed * 1_000_000_000) * 100.0, 3)

    def sample(self, now: float) -> dict[str, Any]:
        processes = self.procfs.processes()
        pids = tree_pids(processes, self.root_pid)
        current = {pid: processes[pid] for pid in pids}
        aggregate = aggregate_processes(processes, pids)
        elapsed = 0.0 if self.previous_time is None else max(0.0, now - self.previous_time)
        ticks = self._delta(current, "cpu_ticks")
        read = self._delta(current, "read_bytes")
        write = self._delta(current, "write_bytes")
        gpu_percent = self._gpu_delta(pids, elapsed)
        if self.previous_time is None:
            cpu = system_cpu = read_rate = write_rate = None
        else:
            cpu, system_cpu = cpu_percentages(ticks or 0, elapsed, self.ticks_per_second, self.cpu_count)
            read_rate = round(read / elapsed, 3) if read is not None and elapsed > 0 else None
            write_rate = round(write / elapsed, 3) if write is not None and elapsed > 0 else None
        self.child_pids.update(pids - {self.root_pid})
        self.process_names.update({pid: process["name"] for pid, process in current.items()})
        self.previous = current
        self.previous_time = now
        return {
            "timestamp_s": round(now, 6), "elapsed_s": round(elapsed, 6),
            "process_count": aggregate["process_count"], "rss_kib": aggregate["rss_kib"],
            "pss_kib": aggregate["pss_kib"], "swap_kib": aggregate["swap_kib"],
            "cpu_percent": cpu, "cpu_system_percent": system_cpu,
            "gpu_percent": gpu_percent,
            "read_bytes_per_second": read_rate, "write_bytes_per_second": write_rate,
        }


class GpuSampler:
    """Lee el uso de GPU de fuentes reales del sistema, sin estimaciones."""

    def __init__(self, drm_root: Path = Path("/sys/class/drm"), runner=subprocess.run):
        self.drm_root = drm_root
        self.runner = runner
        self.busy_files = sorted(drm_root.glob("card*/device/gpu_busy_percent"))
        self.nvidia_smi = None if self.busy_files else shutil.which("nvidia-smi")

    @property
    def available(self) -> bool:
        return bool(self.busy_files or self.nvidia_smi)

    def percent(self) -> float | None:
        values: list[float] = []
        for path in self.busy_files:
            try:
                values.append(float(path.read_text(encoding="utf-8").strip()))
            except (OSError, ValueError):
                continue
        if values:
            return round(max(values), 3)
        if not self.nvidia_smi:
            return None
        try:
            result = self.runner(
                [self.nvidia_smi, "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=2, check=False,
            )
        except (OSError, subprocess.SubprocessError):
            return None
        for line in result.stdout.splitlines():
            try:
                values.append(float(line.strip()))
            except ValueError:
                continue
        return round(max(values), 3) if values else None


class SystemSampler:
    def __init__(self, procfs: Procfs, gpu: "GpuSampler | None" = None):
        self.procfs = procfs
        self.gpu = gpu
        self.previous_cpu: dict[str, int] | None = None
        self.previous_disk: dict[str, dict[str, Any]] | None = None
        self.previous_time: float | None = None

    def sample(self, now: float) -> dict[str, Any]:
        memory = self.procfs.meminfo()
        cpu = self.procfs.cpu_stat()
        disk = self.procfs.diskstats()
        gpu_percent = self.gpu.percent() if self.gpu is not None else None
        elapsed = 0.0 if self.previous_time is None else max(0.0, now - self.previous_time)
        cpu_percent = read_rate = write_rate = None
        if self.previous_cpu is not None and elapsed > 0:
            total = max(0, cpu["total_ticks"] - self.previous_cpu["total_ticks"])
            idle = max(0, cpu["idle_ticks"] - self.previous_cpu["idle_ticks"])
            cpu_percent = round(max(0, total - idle) * 100.0 / total, 3) if total else 0.0
        if self.previous_disk is not None and elapsed > 0:
            read = write = 0
            for device, counters in disk.items():
                if device not in self.previous_disk:
                    continue
                read += max(0, counters["read_bytes"] - self.previous_disk[device]["read_bytes"])
                write += max(0, counters["write_bytes"] - self.previous_disk[device]["write_bytes"])
            read_rate = round(read / elapsed, 3)
            write_rate = round(write / elapsed, 3)
        self.previous_cpu = cpu
        self.previous_disk = disk
        self.previous_time = now
        return {
            "timestamp_s": round(now, 6), "elapsed_s": round(elapsed, 6), **memory,
            "cpu_system_percent": cpu_percent,
            "gpu_system_percent": gpu_percent,
            "read_bytes_per_second": read_rate, "write_bytes_per_second": write_rate,
        }


def summarize(samples: list[dict[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    memory = ("rss_kib", "memory_used_kib", "pss_kib", "swap_kib", "swap_used_kib")
    for source, prefix in (("rss_kib", "ram_rss"), ("memory_used_kib", "ram_used"),
                           ("pss_kib", "ram_pss"), ("swap_kib", "swap"),
                           ("swap_used_kib", "swap_system"),
                           ("cpu_percent", "cpu"), ("cpu_system_percent", "cpu_system"),
                           ("gpu_percent", "gpu"), ("gpu_system_percent", "gpu_system"),
                           ("read_bytes_per_second", "disk_read"),
                           ("write_bytes_per_second", "disk_write")):
        average, maximum = _mean_max(samples, source)
        if not any(source in sample for sample in samples):
            continue
        suffix = "kib" if source in memory else "bytes_per_second" if source.endswith("bytes_per_second") else "percent"
        result[f"{prefix}_average_{suffix}"] = average
        result[f"{prefix}_max_{suffix}"] = maximum
    counts = [int(sample["process_count"]) for sample in samples if sample.get("process_count") is not None]
    result["processes_max"] = max(counts, default=0)
    return result


def _limit(value: Any, limit: float, unit: str) -> dict[str, Any]:
    if value is None:
        return {"status": "unknown", "value": None, "limit": limit, "unit": unit}
    return {"status": "pass" if value <= limit else "fail", "value": value, "limit": limit, "unit": unit}


def evaluate_budget(summary: dict[str, Any], mode: str) -> dict[str, Any]:
    if mode not in ("application", "system"):
        raise ValueError("modo de presupuesto desconocido")
    ram_limit = 200 * 1024 if mode == "application" else 300 * 1024
    ram_value = summary.get("ram_rss_max_kib" if mode == "application" else "ram_used_max_kib")
    if mode == "system" and ram_value is None:
        ram_value = summary.get("ram_rss_max_kib")
    checks = {
        "ram_rss_max" if mode == "application" else "ram_used_max": _limit(ram_value, ram_limit, "KiB"),
        "cpu_average": _limit(summary.get("cpu_system_average_percent"), 3.0, "%"),
        "cpu_max": _limit(summary.get("cpu_system_max_percent"), 3.0, "%"),
        "gpu": _limit(summary.get("gpu_system_max_percent" if mode == "system" else "gpu_max_percent"),
                      3.0 if mode == "system" else 1.0, "%"),
    }
    swap = summary.get("swap_system_max_kib" if mode == "system" else "swap_max_kib")
    checks["swap"] = {"status": "unknown" if swap is None else "pass" if swap == 0 else "warning",
                      "value": swap, "limit": 0, "unit": "KiB"}
    for key in ("ui_response", "frame_pacing"):
        checks[key] = {"status": "unknown", "value": None, "reason": "Sonda de UI no ejecutada"}
    failed = any(check["status"] == "fail" for check in checks.values())
    incomplete = any(check["status"] in ("unknown", "warning") for check in checks.values())
    return {
        "measured_within_limits": not failed,
        "status": "fail" if failed else "incomplete" if incomplete else "pass",
        "checks": checks,
    }


def _shown(value: Any) -> str:
    return "No disponible" if value is None else str(value)


def render_markdown(report: dict[str, Any]) -> str:
    summary = report["summary"]
    budget = report["budget"]
    status = {"incomplete": "incompleto", "fail": "fuera de límite", "pass": "aprobado"}[budget["status"]]
    lines = [
        f"# Benchmark de recursos: {report['name']}", "",
        f"- Fecha UTC: `{report['date_utc']}`",
        f"- Modo: `{report['mode']}`; duración: {report['duration_s']} s",
        f"- Plataforma: `{report['environment']['platform']}`",
        f"- CPU: `{report['environment']['cpu_model']}` ({report['environment']['cpu_count']} CPUs lógicas)",
        f"- Estado del contrato: **{status}**; una métrica ausente no se considera aprobada.",
    ]
    if report.get("command"):
        lines.append(f"- Comando: `{shlex.join(report['command'])}`")
    lines.extend(["", "| Métrica | Promedio | Máximo |", "|---|---:|---:|"])
    rows = (
        ("RAM RSS (KiB)", "ram_rss_average_kib", "ram_rss_max_kib"),
        ("RAM usada (KiB)", "ram_used_average_kib", "ram_used_max_kib"),
        ("RAM PSS (KiB)", "ram_pss_average_kib", "ram_pss_max_kib"),
        ("Swap (KiB)", "swap_average_kib", "swap_max_kib"),
        ("CPU, un núcleo (%)", "cpu_average_percent", "cpu_max_percent"),
        ("CPU, equipo completo (%)", "cpu_system_average_percent", "cpu_system_max_percent"),
        ("Disco leído (B/s)", "disk_read_average_bytes_per_second", "disk_read_max_bytes_per_second"),
        ("Disco escrito (B/s)", "disk_write_average_bytes_per_second", "disk_write_max_bytes_per_second"),
        ("Procesos", "processes_max", "processes_max"),
    )
    for label, average, maximum in rows:
        if average in summary or maximum in summary:
            lines.append(f"| {label} | {_shown(summary.get(average))} | {_shown(summary.get(maximum))} |")
    lines.extend(["", "## Métricas no disponibles", ""])
    for name, reason in report.get("unavailable", {}).items():
        lines.append(f"- **{name}**: {reason}.")
    lines.extend(["", "Las cifras no certifican GPU, respuesta de UI ni 60 FPS sin sus sondas específicas.", ""])
    return "\n".join(lines)


def environment() -> dict[str, Any]:
    cpu_model = "desconocido"
    try:
        for line in Path("/proc/cpuinfo").read_text(encoding="utf-8", errors="replace").splitlines():
            key, separator, value = line.partition(":")
            if separator and key.strip() in ("model name", "Hardware") and value.strip():
                cpu_model = value.strip()
                break
    except OSError:
        pass
    if cpu_model == "desconocido":
        cpu_model = platform.processor() or "desconocido"
    return {
        "platform": platform.platform(),
        "cpu_model": cpu_model,
        "cpu_count": os.cpu_count() or 1,
        "python": sys.version.split()[0],
    }


def _process_name(procfs: Procfs, pid: int) -> str:
    try:
        return procfs.process(pid)["name"]
    except (FileNotFoundError, PermissionError, ProcessLookupError, ValueError):
        return f"pid {pid}"


def _terminate(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    try:
        os.killpg(os.getpgid(process.pid), signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        return
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            return
        process.wait(timeout=5)


def _collect(sampler, duration: float, interval: float, warmup: float, stop=None) -> tuple[list[dict[str, Any]], float]:
    start = time.monotonic()
    samples: list[dict[str, Any]] = []
    while True:
        now = time.monotonic()
        sample = sampler.sample(now)
        if now - start >= warmup:
            samples.append(sample)
        elapsed = now - start
        if elapsed >= duration or (stop is not None and stop()):
            break
        time.sleep(min(interval, max(0.0, duration - elapsed)))
    return samples, time.monotonic() - start


def _unavailable(summary: dict[str, Any], mode: str) -> dict[str, str]:
    reasons = {
        "ui_response": "Requiere una sonda dentro de una sesión gráfica real",
        "frame_pacing": "Requiere una sonda dentro de una sesión gráfica real",
    }
    key = "gpu_system_max_percent" if mode == "system" else "gpu_max_percent"
    if summary.get(key) is None:
        reasons["gpu"] = "Sin contador legible: gpu_busy_percent, nvidia-smi o fdinfo DRM"
    return reasons


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Mide RAM, CPU, GPU, swap y disco reales de una app o del sistema.",
        epilog="Ejemplo: resource_benchmark.py --name app --duration 15 --output out.json -- app --smoke",
    )
    parser.add_argument("--name", help="Nombre del informe (por defecto el del ejecutable o «sistema»)")
    parser.add_argument("--mode", choices=("application", "system"), help="Modo; se deduce del comando o --pid")
    parser.add_argument("--duration", type=float, default=10.0, help="Segundos medidos (por defecto 10)")
    parser.add_argument("--interval", type=float, default=0.5, help="Segundos entre muestras (por defecto 0,5)")
    parser.add_argument("--warmup", type=float, default=0.0, help="Segundos iniciales descartados del resumen")
    parser.add_argument("--pid", type=int, help="Mide un proceso ya en ejecución sin terminarlo")
    parser.add_argument("--output", type=Path, help="Escribe el JSON aquí y el Markdown junto a él")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Comando a medir; sepáralo con --")
    args = parser.parse_args(argv)

    command = list(args.command)
    if command and command[0] == "--":
        command = command[1:]
    if args.duration <= 0 or args.interval <= 0 or args.warmup < 0:
        parser.error("--duration y --interval deben ser > 0; --warmup no puede ser negativo")
    if args.pid is not None and command:
        parser.error("--pid y un comando son excluyentes")
    mode = args.mode or ("application" if (command or args.pid is not None) else "system")
    if mode == "application" and not command and args.pid is None:
        parser.error("el modo aplicación requiere un comando o --pid")
    if mode == "system" and (command or args.pid is not None):
        parser.error("el modo sistema no acepta comando ni --pid")

    procfs = Procfs()
    cpu_count = os.cpu_count() or 1
    ticks_per_second = os.sysconf("SC_CLK_TCK")
    process: subprocess.Popen | None = None
    sampler: ApplicationSampler | SystemSampler
    try:
        if mode == "application":
            if command:
                process = subprocess.Popen(command, start_new_session=True)
                root_pid = process.pid
                name = args.name or Path(command[0]).name
            else:
                root_pid = args.pid
                name = args.name or _process_name(procfs, root_pid)
            sampler = ApplicationSampler(procfs, root_pid, ticks_per_second, cpu_count)
            stop = (lambda: process is not None and process.poll() is not None)
        else:
            sampler = SystemSampler(procfs, GpuSampler())
            name = args.name or "sistema"
            stop = None
        samples, elapsed = _collect(sampler, args.duration, args.interval, args.warmup, stop)
    finally:
        if process is not None:
            _terminate(process)

    summary = summarize(samples)
    children: list[str] = []
    if mode == "application":
        children = sorted({
            sampler.process_names.get(pid, f"pid {pid}")
            for pid in sampler.child_pids
        })
    report: dict[str, Any] = {
        "name": name,
        "mode": mode,
        "command": command or None,
        "date_utc": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
        "duration_s": round(elapsed, 3),
        "environment": environment(),
        "summary": summary,
        "children_observed": children,
        "samples": samples,
        "budget": evaluate_budget(summary, mode),
        "unavailable": _unavailable(summary, mode),
    }
    markdown = render_markdown(report)
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        args.output.with_suffix(".md").write_text(markdown, encoding="utf-8")
    print(markdown)
    return 1 if report["budget"]["status"] == "fail" else 0


if __name__ == "__main__":
    raise SystemExit(main())

