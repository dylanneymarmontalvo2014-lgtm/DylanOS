# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import argparse
import configparser
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DIST = ROOT / "engine" / "obj-x86_64-pc-linux-gnu" / "dist" / "bin"
DEFAULT_RESULTS = ROOT / "artifacts" / "phase-2" / "smoke.json"
FORBIDDEN_UPDATE_HOST = "updates.zen-browser.app"


def validate_product_installation(dist_dir):
    dist_dir = Path(dist_dir)
    binary = dist_dir / "dylanos-browser"
    assert binary.is_file(), f"Falta el binario {binary}"
    assert os.access(binary, os.X_OK), f"El binario no es ejecutable: {binary}"

    parser = configparser.ConfigParser(interpolation=None)
    ini_path = dist_dir / "application.ini"
    assert ini_path.is_file(), f"Falta {ini_path}"
    parser.read(ini_path, encoding="utf-8")
    identity = dict(parser["App"])
    expected = {
        "Vendor": "DylanOS",
        "Name": "DylanOSBrowser",
        "RemotingName": "dylanos-browser",
        "CodeName": "DylanOS Browser",
        "Profile": "dylanos-browser",
    }
    for key, value in expected.items():
        actual = identity.get(key.lower())
        assert actual == value, (
            f"Identidad App.{key} inválida: "
            f"{actual!r}, esperado {value!r}"
        )
    return dict(expected)


def validate_http_log(log_path):
    log_path = Path(log_path)
    content = log_path.read_text(encoding="utf-8", errors="replace")
    assert FORBIDDEN_UPDATE_HOST not in content, (
        f"El navegador intentó contactar {FORBIDDEN_UPDATE_HOST}"
    )


def run(command, *, env=None, timeout=30, check=True):
    return subprocess.run(
        [str(item) for item in command],
        env=env,
        check=check,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def visible_windows(pid):
    result = run(
        ["xdotool", "search", "--onlyvisible", "--pid", str(pid)],
        check=False,
    )
    if result.returncode != 0:
        return []
    return sorted({int(line) for line in result.stdout.splitlines() if line.strip()})


def wait_until(predicate, description, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.25)
    raise TimeoutError(f"Tiempo agotado esperando {description}")


def window_details(window_id):
    title = run(["xdotool", "getwindowname", str(window_id)]).stdout.strip()
    wm_class = run(["xprop", "-id", str(window_id), "WM_CLASS"]).stdout.strip()
    return {"id": window_id, "title": title, "wm_class": wm_class}


class SmokeHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        title = {
            "/": "DylanOS Smoke Main",
            "/new": "DylanOS Smoke New Window",
            "/private": "DylanOS Smoke Private",
        }.get(self.path, "DylanOS Smoke")
        payload = (
            "<!doctype html><meta charset='utf-8'>"
            f"<title>{title}</title><h1>{title}</h1>"
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, _format, *_args):
        return


def write_profile_preferences(profile):
    preferences = {
        "browser.shell.checkDefaultBrowser": False,
        "browser.startup.homepage_override.mstone": "ignore",
        "browser.tabs.warnOnClose": False,
        "browser.warnOnQuit": False,
        "datareporting.policy.dataSubmissionEnabled": False,
        "network.captive-portal-service.enabled": False,
        "network.connectivity-service.enabled": False,
    }
    lines = [
        f'user_pref("{key}", {json.dumps(value)});'
        for key, value in preferences.items()
    ]
    (profile / "user.js").write_text(f"{'\n'.join(lines)}\n", encoding="utf-8")


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def execute_smoke(dist_dir, results_path, timeout=45):
    dist_dir = Path(dist_dir).resolve()
    results_path = Path(results_path).resolve()
    identity = validate_product_installation(dist_dir)
    binary = dist_dir / "dylanos-browser"
    assert os.environ.get("DISPLAY"), "El smoke test requiere DISPLAY (usar Xvfb)"
    for command in ("xdotool", "xprop"):
        assert shutil.which(command), f"Falta la herramienta requerida: {command}"

    server = ThreadingHTTPServer(("127.0.0.1", 0), SmokeHandler)
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    base_url = f"http://127.0.0.1:{server.server_port}"
    started = time.monotonic()

    try:
        with tempfile.TemporaryDirectory(prefix="dylanos-browser-smoke-") as temp:
            temp_path = Path(temp)
            home = temp_path / "home"
            profile = temp_path / "profile"
            home.mkdir()
            profile.mkdir()
            write_profile_preferences(profile)
            http_log_prefix = temp_path / "http.log"
            stdout_path = temp_path / "browser.stdout.log"
            stderr_path = temp_path / "browser.stderr.log"
            env = os.environ.copy()
            env.update(
                {
                    "HOME": str(home),
                    "XDG_CACHE_HOME": str(home / ".cache"),
                    "XDG_CONFIG_HOME": str(home / ".config"),
                    "XDG_DATA_HOME": str(home / ".local" / "share"),
                    "MOZ_CRASHREPORTER_DISABLE": "1",
                    "MOZ_LOG": "nsHttp:5,timestamp",
                    "MOZ_LOG_FILE": str(http_log_prefix),
                }
            )
            with stdout_path.open("w", encoding="utf-8") as stdout, stderr_path.open(
                "w", encoding="utf-8"
            ) as stderr:
                process = subprocess.Popen(
                    [
                        str(binary),
                        "--profile",
                        str(profile),
                        "--new-instance",
                        base_url,
                    ],
                    env=env,
                    stdout=stdout,
                    stderr=stderr,
                    text=True,
                )
                try:
                    main_windows = wait_until(
                        lambda: visible_windows(process.pid),
                        "la ventana principal",
                        timeout,
                    )
                    main_details = [window_details(item) for item in main_windows]
                    assert any(
                        "DylanOS Smoke Main" in item["title"]
                        for item in main_details
                    ), "La URL local no apareció en la ventana principal"
                    assert all(
                        "dylanos" in item["wm_class"].lower()
                        and "zen" not in item["wm_class"].lower()
                        and "firefox" not in item["wm_class"].lower()
                        for item in main_details
                    ), f"WM_CLASS no pertenece a DylanOS: {main_details}"

                    run(
                        [
                            binary,
                            "--profile",
                            profile,
                            "--new-window",
                            f"{base_url}/new",
                        ],
                        env=env,
                        timeout=timeout,
                    )
                    new_windows = wait_until(
                        lambda: (
                            windows
                            if len(windows := visible_windows(process.pid))
                            > len(main_windows)
                            else None
                        ),
                        "una ventana nueva",
                        timeout,
                    )
                    run(
                        [
                            binary,
                            "--profile",
                            profile,
                            "--private-window",
                            f"{base_url}/private",
                        ],
                        env=env,
                        timeout=timeout,
                    )
                    private_windows = wait_until(
                        lambda: (
                            windows
                            if len(windows := visible_windows(process.pid))
                            > len(new_windows)
                            else None
                        ),
                        "una ventana privada",
                        timeout,
                    )
                    details = [window_details(item) for item in private_windows]
                    for window_id in reversed(private_windows):
                        run(
                            [
                                "xdotool",
                                "key",
                                "--window",
                                str(window_id),
                                "ctrl+shift+w",
                            ],
                            check=False,
                        )
                    return_code = process.wait(timeout=timeout)
                except Exception:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                    raise

            assert return_code == 0, f"Cierre anómalo del navegador: {return_code}"
            dumps = list(profile.glob("minidumps/*.dmp"))
            assert not dumps, f"El navegador generó crash dumps: {dumps}"
            log_files = sorted(temp_path.glob("http.log*"))
            assert log_files, "MOZ_LOG no generó evidencia HTTP"
            for log_file in log_files:
                validate_http_log(log_file)

            results = {
                "schema_version": 1,
                "binary": str(binary),
                "binary_sha256": sha256(binary),
                "binary_size_bytes": binary.stat().st_size,
                "duration_seconds": round(time.monotonic() - started, 2),
                "identity": identity,
                "window_count": len(details),
                "windows": details,
                "forbidden_update_host": FORBIDDEN_UPDATE_HOST,
                "forbidden_update_host_contacted": False,
                "return_code": return_code,
            }
            results_path.parent.mkdir(parents=True, exist_ok=True)
            results_path.write_text(
                f"{json.dumps(results, indent=2, sort_keys=True)}\n",
                encoding="utf-8",
            )
            return results
    finally:
        server.shutdown()
        server.server_close()


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Ejecuta smoke tests reales de DylanOS Browser bajo X11."
    )
    parser.add_argument("--dist-dir", type=Path, default=DEFAULT_DIST)
    parser.add_argument("--results", type=Path, default=DEFAULT_RESULTS)
    parser.add_argument("--timeout", type=int, default=45)
    arguments = parser.parse_args(argv)
    results = execute_smoke(
        arguments.dist_dir,
        arguments.results,
        timeout=arguments.timeout,
    )
    print(json.dumps(results, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
