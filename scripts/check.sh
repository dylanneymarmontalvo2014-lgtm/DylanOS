#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PYTHON="${DYLANOS_PYTHON:-python3}"
while IFS= read -r script; do bash -n "$script"; done < <(find scripts packages -name '*.sh' -type f)
shellcheck scripts/build.sh scripts/iso.sh scripts/test.sh scripts/check.sh scripts/lib/packages.sh packages/development/setup-repos.sh
bash scripts/tests/test_packages.sh
"$PYTHON" -m unittest discover -s scripts/tests -p 'test_*.py' -v
"$PYTHON" -m compileall -q apps/workspace scripts/stage.py scripts/lib/generate-theme.py
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
"$PYTHON" scripts/stage.py "$staging/root"
find "$staging/root/usr/share/applications" -name '*.desktop' -exec desktop-file-validate '{}' +
if "$PYTHON" -c 'import PySide6, psutil' 2>/dev/null; then
    mkdir -p "$staging/home" "$staging/config" "$staging/data" "$staging/runtime"
    chmod 700 "$staging/runtime"
    for page in welcome files notes dev monitor store settings; do
        HOME="$staging/home" XDG_CONFIG_HOME="$staging/config" XDG_DATA_HOME="$staging/data" XDG_RUNTIME_DIR="$staging/runtime" \
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        "$PYTHON" apps/workspace/main.py --page "$page" --smoke 2>"$staging/$page.log"
        if [[ -s "$staging/$page.log" ]]; then cat "$staging/$page.log"; exit 1; fi
    done
    HOME="$staging/home" XDG_CONFIG_HOME="$staging/config" XDG_DATA_HOME="$staging/data" XDG_RUNTIME_DIR="$staging/runtime" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    "$PYTHON" apps/workspace/main.py --page settings --appearance light --smoke 2>"$staging/light.log"
    if [[ -s "$staging/light.log" ]]; then cat "$staging/light.log"; exit 1; fi
else
    echo 'PySide6/psutil ausentes: no se ejecutó QA QML. Instala las dependencias para verificar la interfaz.' >&2
    exit 1
fi
echo 'Comprobaciones de código, datos, staging y carga QML: OK'
