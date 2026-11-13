#!/usr/bin/env python3
"""Measure fresh-process startup and peak RSS of the current DylanOS apps.

Startup ends on the first Qt event-loop turn after QQmlApplicationEngine has
loaded a root object. This observes the real GUI readiness boundary without
changing the apps. Peak RSS is sampled from procfs until their existing
--smoke timers exit. The OS page cache is not flushed: these are fresh-process
measurements, not true cold-boot results.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import platform
import signal
import statistics
import subprocess
import sys
import tempfile
import time
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
APPS: dict[str, list[str]] = {
    "archivos": [str(ROOT / "apps/archivos/main.py"), "--smoke"],
    "dylanos-spotlight": [str(ROOT / "apps/dylanos-spotlight/main.py"), "--smoke"],
    "workspace": [str(ROOT / "apps/workspace/main.py"), "--page", "welcome", "--smoke"],
}


def percentile(values: list[float], percent: float) -> float:
    """Nearest-rank percentile, stable for small benchmark samples."""
    if not values:
        raise ValueError("percentile needs at least one value")
    if not 0 < percent <= 100:
        raise ValueError("percent must be in (0, 100]")
    ordered = sorted(values)
    rank = max(1, int((percent * len(ordered) + 99.999999) // 100))
    return ordered[rank - 1]


def qml_probe_source() -> str:
    """Create a sitecustomize hook that marks QML readiness on the Qt loop."""
    return '''\
import os
import time
from pathlib import Path
from PySide6.QtCore import QTimer
from PySide6.QtQml import QQmlApplicationEngine

_original_load = QQmlApplicationEngine.load
_marker = os.environ["DYLANOS_BENCHMARK_MARKER"]
_marked = False

def _mark_ready():
    global _marked
    if _marked:
        return
    _marked = True
    Path(_marker).write_text(str(time.monotonic_ns()), encoding="ascii")

def _load_with_probe(self, *args, **kwargs):
    result = _original_load(self, *args, **kwargs)
    if self.rootObjects():
        QTimer.singleShot(0, _mark_ready)
    return result

QQmlApplicationEngine.load = _load_with_probe
'''


def read_metric_kib(pid: int, metric: str) -> int:
    """Read RSS/HWM from procfs, returning zero after process exit."""
    try:
        with open(f"/proc/{pid}/status", encoding="ascii") as status:
            for line in status:
                if line.startswith(metric + ":"):
                    return int(line.split()[1])
    except (FileNotFoundError, ProcessLookupError, PermissionError, ValueError):
        pass
    return 0


def measure_once(name: str, command: list[str], probe_dir: Path, home: Path,
                 timeout: float, sample_interval: float) -> dict[str, Any]:
    marker = probe_dir / f"{name}-{time.time_ns()}.ready"
    env = os.environ.copy()
    env.update({
        "PYTHONPATH": str(probe_dir) + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else ""),
        "DYLANOS_BENCHMARK_MARKER": str(marker),
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "XDG_RUNTIME_DIR": str(home / ".runtime"),
        "QT_QPA_PLATFORM": "offscreen",
        "QT_QUICK_BACKEND": "software",
    })
    Path(env["XDG_RUNTIME_DIR"]).mkdir(parents=True, exist_ok=True)
    os.chmod(env["XDG_RUNTIME_DIR"], 0o700)
    stderr_path = probe_dir / f"{name}-{time.time_ns()}.stderr"
    started_ns = time.monotonic_ns()
    with stderr_path.open("wb") as stderr:
        proc = subprocess.Popen([sys.executable, *command], cwd=ROOT, env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                stderr=stderr, start_new_session=True)
        peak_rss = 0
        deadline = time.monotonic() + timeout
        ready_ns = None
        while time.monotonic() < deadline:
            peak_rss = max(peak_rss, read_metric_kib(proc.pid, "VmRSS"),
                           read_metric_kib(proc.pid, "VmHWM"))
            if marker.is_file():
                try:
                    ready_ns = int(marker.read_text(encoding="ascii"))
                    break
                except (OSError, ValueError):
                    pass
            if proc.poll() is not None:
                break
            time.sleep(sample_interval)
        if ready_ns is None:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGTERM)
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait()
            details = stderr_path.read_text(encoding="utf-8", errors="replace")[-4000:]
            reason = f"exited with status {proc.returncode}" if proc.returncode is not None else f"did not load QML within {timeout:g}s"
            raise RuntimeError(f"{name}: {reason}. stderr tail:\n{details}")

        startup_ms = (ready_ns - started_ns) / 1_000_000
        while proc.poll() is None and time.monotonic() < deadline:
            peak_rss = max(peak_rss, read_metric_kib(proc.pid, "VmRSS"),
                           read_metric_kib(proc.pid, "VmHWM"))
            time.sleep(sample_interval)
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
            details = stderr_path.read_text(encoding="utf-8", errors="replace")[-4000:]
            raise RuntimeError(f"{name}: smoke process did not exit within {timeout:g}s. stderr tail:\n{details}")
        peak_rss = max(peak_rss, read_metric_kib(proc.pid, "VmRSS"),
                       read_metric_kib(proc.pid, "VmHWM"))
        if proc.returncode != 0:
            details = stderr_path.read_text(encoding="utf-8", errors="replace")[-4000:]
            raise RuntimeError(f"{name}: smoke process exited {proc.returncode}. stderr tail:\n{details}")
    stderr_path.unlink(missing_ok=True)
    marker.unlink(missing_ok=True)
    if peak_rss <= 0:
        raise RuntimeError(f"{name}: procfs did not report RSS for the process")
    return {"startup_ms": round(startup_ms, 3), "peak_rss_kib": peak_rss}


def summarize(samples: list[dict[str, Any]]) -> dict[str, float]:
    if not samples:
        raise ValueError("at least one measured sample is required")
    starts = [float(sample["startup_ms"]) for sample in samples]
    rss = [int(sample["peak_rss_kib"]) for sample in samples]
    return {
        "startup_median_ms": round(statistics.median(starts), 3),
        "startup_p95_ms": round(percentile(starts, 95), 3),
        "peak_rss_median_kib": round(statistics.median(rss), 1),
        "peak_rss_max_kib": max(rss),
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Python apps startup and memory baseline",
        "",
        f"- Commit ejecutado: `{report.get('commit', 'unknown')}`",
        f"- Fuente de las apps medidas: `{report.get('app_source_commit', 'unknown')}`",
        f"- Date (UTC): `{report.get('date_utc', 'unknown')}`",
        f"- Python: `{report['python']}`",
        f"- PySide6: `{report['pyside6']}`; Qt: `{report['qt']}`",
        f"- Platform: `{report['platform']}`",
        f"- Samples per app: {report['iterations']} (after {report['warmups']} warm-up run(s))",
        "- Startup ends on the first Qt event-loop turn after QML loads with a root object.",
        "- Peak RSS is the maximum `VmHWM`/`VmRSS` sampled from `/proc` until the app's built-in smoke timer exits.",
        "- Each sample starts a fresh process with isolated temporary HOME and Qt offscreen/software rendering.",
        "- The OS page cache is not flushed; these are fresh-process measurements, not true cold-boot results.",
        "- `archivos` is its current launcher into Workspace's files page, not the retired prototype QML.",
        "",
        "| App | Startup median (ms) | Startup p95 (ms) | Peak RSS median (MiB) | Peak RSS max (MiB) |",
        "|---|---:|---:|---:|---:|",
    ]
    for name in ("archivos", "dylanos-spotlight", "workspace"):
        stats = report["apps"][name]["summary"]
        lines.append(
            f"| `{name}` | {stats['startup_median_ms']:.3f} | {stats['startup_p95_ms']:.3f} | "
            f"{stats['peak_rss_median_kib'] / 1024:.2f} | {stats['peak_rss_max_kib'] / 1024:.2f} |"
        )
    lines.extend(["", "Raw per-run values are in `apps-python-baseline.json`.", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--warmups", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--sample-interval", type=float, default=0.01)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    if args.iterations < 3 or args.warmups < 0 or args.timeout <= 0 or args.sample_interval <= 0:
        parser.error("iterations must be >=3, warmups >=0, timeout >0 and sample-interval >0")

    try:
        import PySide6
        from PySide6.QtCore import qVersion
    except ImportError as error:
        parser.error(f"PySide6 is required to measure the current apps: {error}")

    report: dict[str, Any] = {
        "commit": os.environ.get("GITHUB_SHA", "unknown"),
        "app_source_commit": os.environ.get("GITHUB_BASE_SHA", os.environ.get("GITHUB_SHA", "unknown")),
        "date_utc": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
        "python": sys.version.split()[0],
        "pyside6": PySide6.__version__,
        "qt": qVersion(),
        "platform": f"{platform.system()} {platform.release()} / {platform.machine()}",
        "iterations": args.iterations,
        "warmups": args.warmups,
        "apps": {},
    }
    with tempfile.TemporaryDirectory(prefix="dylanos-python-baseline-") as temporary:
        home_root = Path(temporary)
        probe_dir = home_root / "probe"
        probe_dir.mkdir()
        (probe_dir / "sitecustomize.py").write_text(qml_probe_source(), encoding="utf-8")
        for app_name, command in APPS.items():
            app_home = home_root / app_name
            app_home.mkdir()
            for _ in range(args.warmups):
                measure_once(app_name, command, probe_dir, app_home, args.timeout, args.sample_interval)
            samples = [measure_once(app_name, command, probe_dir, app_home, args.timeout, args.sample_interval)
                       for _ in range(args.iterations)]
            report["apps"][app_name] = {"samples": samples, "summary": summarize(samples)}
    markdown = render_markdown(report)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "apps-python-baseline.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (args.output_dir / "apps-python-baseline.md").write_text(markdown, encoding="utf-8")
    print(markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
