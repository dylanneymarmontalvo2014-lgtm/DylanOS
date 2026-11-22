#!/bin/bash
# Test Greeter del DylanOS Login Manager (host HTML) contra un daemon simulado.
#
# SDDM lanza su greeter con `--socket <nombre>`; el host de DylanOS habla el
# mismo protocolo. Aquí se levanta un daemon que imita a SDDM, se arranca el
# host con los mismos argumentos y se comprueba:
#   - que conecta y recibe capacidades y nombre de equipo,
#   - que el login correcto se acepta y el incorrecto se rechaza,
#   - que una acción de energía llega al daemon,
#   - que la captura del tema se genera.
#
# Uso: scripts/test-greeter-host.sh [salida]
# Requiere PySide6 y QtWebEngine (los del ISO); se ejecuta dentro del chroot.
set -u
ROOT=$(cd "${0%/*}/.." && pwd)
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export HOME=${TMPDIR:-/tmp}/greeter-host
export QT_QPA_PLATFORM=offscreen
export QTWEBENGINE_DISABLE_SANDBOX=1
export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu --single-process --disable-dev-shm-usage"

salida=${1:-$ROOT/artifacts/sddm-qa}
tema=$ROOT/themes/sddm/DylanOS-Crimson/web
host=$ROOT/apps/dylanos-login-manager/host/dylanos-login-greeter.py
daemon=$ROOT/apps/dylanos-login-manager/tests/sddm-daemon-simulado.py
python=${DYLANOS_PYTHON:-/usr/bin/python3}

mkdir -p "$salida" "$HOME"
socket="$salida/sddm-test.sock"
rm -f "$socket"

echo "=== 1. daemon simulado"
"$python" "$daemon" --socket "$socket" --usuario dylan --clave secreto --segundos 40 \
    > "$salida/daemon.log" 2>&1 &
pid_daemon=$!
sleep 1

echo "=== 2. host del greeter (--socket, --theme, --size)"
timeout 14 "$python" "$host" --socket "$socket" --theme "$tema" \
    --size 1440x960 --screenshot "$salida/host.png" \
    > "$salida/host.log" 2>&1
echo "host exit=$?"

echo "=== 3. mensajes recibidos por el daemon"
cat "$salida/daemon.log"

echo "=== 4. ciclo de autenticación (login válido e inválido)"
"$python" - "$socket" "$ROOT" <<'PY'
import importlib.util
import sys
from PySide6.QtCore import QCoreApplication, QTimer

raiz, socket = sys.argv[2], sys.argv[1]
spec = importlib.util.spec_from_file_location(
    "host_greeter", raiz + "/apps/dylanos-login-manager/host/dylanos-login-greeter.py")
host = importlib.util.module_from_spec(spec)
sys.modules["host_greeter"] = host
spec.loader.exec_module(host)

aplicacion = QCoreApplication([])
protocolo = host.ProtocoloSddm(socket)
resultados = {"ok": 0, "mal": 0, "capacidades": None}
protocolo.accesoCorrecto.connect(lambda: resultados.__setitem__("ok", resultados["ok"] + 1))
protocolo.accesoFallido.connect(lambda: resultados.__setitem__("mal", resultados["mal"] + 1))
protocolo.capacidades.connect(lambda *v: resultados.__setitem__("capacidades", v))

QTimer.singleShot(600, lambda: protocolo.iniciar_sesion(
    "dylan", "incorrecta", 1, "/usr/share/xsessions/plasmax11.desktop"))
QTimer.singleShot(1300, lambda: protocolo.iniciar_sesion(
    "dylan", "secreto", 1, "/usr/share/xsessions/plasmax11.desktop"))
QTimer.singleShot(1900, protocolo.reiniciar)
QTimer.singleShot(2500, aplicacion.quit)
aplicacion.exec()

print("capacidades:", resultados["capacidades"])
print("login válido aceptado:", "OK" if resultados["ok"] == 1 else f"FALLO ({resultados['ok']})")
print("login inválido rechazado:", "OK" if resultados["mal"] == 1 else f"FALLO ({resultados['mal']})")
sys.exit(0 if resultados["ok"] == 1 and resultados["mal"] == 1 else 1)
PY
estado_auth=$?

wait $pid_daemon 2>/dev/null

echo "=== 5. errores de JavaScript en el host"
if grep -qE '^js: (Uncaught|TypeError|ReferenceError)' "$salida/host.log"; then
    grep -E '^js: (Uncaught|TypeError|ReferenceError)' "$salida/host.log" | head -5
    estado_js=1
else
    echo "OK: sin errores de JavaScript"
    estado_js=0
fi

echo "=== 6. captura"
if [ -s "$salida/host.png" ]; then
    echo "OK: $salida/host.png ($(stat -c%s "$salida/host.png") bytes)"
    estado_captura=0
else
    echo "SIN CAPTURA"
    estado_captura=1
fi

echo "=== resultado"
if [ "$estado_auth" -eq 0 ] && [ "$estado_js" -eq 0 ] && [ "$estado_captura" -eq 0 ]; then
    echo "OK: el host del login funciona contra el protocolo de SDDM"
    exit 0
fi
echo "FALLO: revisa los pasos anteriores"
exit 1
