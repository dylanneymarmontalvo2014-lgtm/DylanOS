#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PYTHON="${DYLANOS_PYTHON:-python3}"
bash -n init.sh
while IFS= read -r script; do bash -n "$script"; done < <(find scripts packages -name '*.sh' -type f)
shellcheck -x init.sh scripts/build.sh scripts/build-installer.sh scripts/iso.sh scripts/test.sh scripts/test-boot-qemu.sh scripts/check.sh scripts/lib/packages.sh packages/development/setup-repos.sh configs/bash/dylanos.bashrc configs/bash/dylanos-ghost.sh
make --no-print-directory --dry-run help installer check build iso test-iso qemu-test >/dev/null
make --no-print-directory --dry-run build PROFILE=minimal RESUME=1 >/dev/null
"$PYTHON" -c 'import yaml; config = yaml.safe_load(open("compose.yaml", encoding="utf-8")); assert config["services"]["builder"]["privileged"] is True'
bash scripts/build-installer.sh
bash scripts/tests/test_packages.sh
# Cada módulo de unittest corre en su propio proceso: las suites QML
# (workspace, app-center) comparten un solo QApplication y mezclarlas en un
# proceso único provocaba destrucciones fuera de fase (segfault intermitente).
for t in scripts/tests/test_*.py; do
    echo "── unittest $(basename "$t" .py)"
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$PYTHON" -m unittest "scripts.tests.$(basename "$t" .py)"
done
"$PYTHON" -m compileall -q apps/workspace scripts/stage.py scripts/check_boot_log.py scripts/lib/generate-theme.py
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
"$PYTHON" scripts/stage.py "$staging/root"
find "$staging/root/usr/share/applications" -name '*.desktop' -exec desktop-file-validate '{}' +
if "$PYTHON" -c 'import PySide6, psutil' 2>/dev/null; then
    mkdir -p "$staging/home" "$staging/config" "$staging/data" "$staging/runtime"
    chmod 700 "$staging/runtime"
    for page in welcome files notes dev monitor settings; do
        if ! HOME="$staging/home" XDG_CONFIG_HOME="$staging/config" XDG_DATA_HOME="$staging/data" XDG_RUNTIME_DIR="$staging/runtime" \
            QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
            "$PYTHON" apps/workspace/main.py --page "$page" --smoke 2>"$staging/$page.log"; then
            echo "Falló la carga QML de la página $page:" >&2
            cat "$staging/$page.log" >&2
            exit 1
        fi
        if [[ -s "$staging/$page.log" ]]; then cat "$staging/$page.log" >&2; exit 1; fi
    done
    if ! HOME="$staging/home" XDG_CONFIG_HOME="$staging/config" XDG_DATA_HOME="$staging/data" XDG_RUNTIME_DIR="$staging/runtime" \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        "$PYTHON" apps/workspace/main.py --page settings --appearance light --smoke 2>"$staging/light.log"; then
        echo "Falló la carga QML de la variante clara:" >&2
        cat "$staging/light.log" >&2
        exit 1
    fi
    if [[ -s "$staging/light.log" ]]; then cat "$staging/light.log" >&2; exit 1; fi
else
    echo 'PySide6/psutil ausentes: no se ejecutó QA QML. Instala las dependencias para verificar la interfaz.' >&2
    exit 1
fi
echo 'Comprobaciones de código, datos, staging y carga QML: OK'
