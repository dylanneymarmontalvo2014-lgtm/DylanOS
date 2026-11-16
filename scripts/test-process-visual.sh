#!/usr/bin/env bash
# Build and launch DylanOS Process directly; this does not build a DylanOS ISO.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VISUAL_DIR="${DYLANOS_PROCESS_VISUAL_DIR:-$ROOT/work/process-visual}"
BUILD_DIR="${DYLANOS_PROCESS_BUILD_DIR:-$VISUAL_DIR/build}"
PREFIX="${DYLANOS_PROCESS_INSTALL_PREFIX:-$VISUAL_DIR/install}"
BINARY="${DYLANOS_PROCESS_BINARY:-$PREFIX/bin/dylanos-process}"
SCREENSHOT=""
CAPTURE_DELAY="${DYLANOS_PROCESS_CAPTURE_DELAY:-3}"
BUILD=true
BUILD_ONLY=false
BUILD_ONLY_SET=false
NO_BUILD_SET=false

usage() {
    cat <<'EOF'
Uso: scripts/test-process-visual.sh [opciones]

Construye solo la app DylanOS Process (CMake) y la ejecuta directamente en
la sesión gráfica actual, abriendo la página Processes. No construye una ISO.

Opciones:
  --build-only          Configura, compila e instala la app sin abrir la GUI.
  --no-build            Abre una compilación ya instalada, sin ejecutar CMake.
  --screenshot RUTA     Al iniciar la GUI, guarda una captura de su ventana.
  --capture-delay SEG   Espera antes de capturar (por defecto: 3 segundos).
  --build-dir RUTA      Directorio de build (por defecto: work/process-visual/build).
  --install-prefix RUTA Prefijo local (por defecto: work/process-visual/install).
  -h, --help            Muestra esta ayuda.

La app usa una carpeta de configuración separada en work/process-visual/config;
si existe, copia kdeglobals para heredar la paleta KDE actual sin cambiar los
ajustes normales de DylanOS Process.

Requisitos para compilar: CMake, Ninja y las dependencias KDE/Qt indicadas por
apps/dylanos-process/CMakeLists.txt. Para mostrar la GUI se requiere una sesión
X11 o Wayland; la captura usa Spectacle, gnome-screenshot o ImageMagick + xdotool.
EOF
}

while (($#)); do
    case "$1" in
        --build-only) BUILD_ONLY=true; BUILD_ONLY_SET=true ;;
        --no-build) BUILD=false; NO_BUILD_SET=true ;;
        --screenshot)
            (($# >= 2)) || { echo "Falta la ruta después de --screenshot." >&2; exit 2; }
            SCREENSHOT="$2"
            shift
            ;;
        --capture-delay)
            (($# >= 2)) || { echo "Falta el valor después de --capture-delay." >&2; exit 2; }
            CAPTURE_DELAY="$2"
            shift
            ;;
        --build-dir)
            (($# >= 2)) || { echo "Falta la ruta después de --build-dir." >&2; exit 2; }
            BUILD_DIR="$2"
            shift
            ;;
        --install-prefix)
            (($# >= 2)) || { echo "Falta la ruta después de --install-prefix." >&2; exit 2; }
            PREFIX="$2"
            BINARY="$PREFIX/bin/dylanos-process"
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

[[ "$CAPTURE_DELAY" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "--capture-delay debe ser un número no negativo." >&2; exit 2; }
if [[ "$BUILD_ONLY_SET" == true && "$NO_BUILD_SET" == true ]]; then
    echo "--build-only y --no-build son incompatibles." >&2
    exit 2
fi

mkdir -p "$BUILD_DIR" "$PREFIX"

if [[ "$BUILD" == true ]]; then
    CMAKE="${DYLANOS_CMAKE:-cmake}"
    command -v "$CMAKE" >/dev/null 2>&1 || { echo "No se encontró CMake ($CMAKE)." >&2; exit 1; }
    command -v ninja >/dev/null 2>&1 || { echo "No se encontró Ninja; instálalo en el host para compilar la app, sin construir una ISO." >&2; exit 1; }
    "$CMAKE" -S "$ROOT/apps/dylanos-process" -B "$BUILD_DIR" -GNinja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_INSTALL_PREFIX="$PREFIX"
    "$CMAKE" --build "$BUILD_DIR" --parallel "${DYLANOS_BUILD_JOBS:-2}"
    "$CMAKE" --install "$BUILD_DIR"
fi

if [[ "$BUILD_ONLY" == true ]]; then
    echo "Build local de DylanOS Process listo: $PREFIX (no se generó ninguna ISO)."
    exit 0
fi

[[ -x "$BINARY" ]] || {
    echo "No encuentro el ejecutable: $BINARY" >&2
    echo "Ejecuta primero scripts/test-process-visual.sh o indica DYLANOS_PROCESS_BINARY." >&2
    exit 1
}
if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    echo "No hay una sesión gráfica X11/Wayland disponible. Ejecuta este comando desde el escritorio; no hace falta compilar una ISO." >&2
    exit 1
fi

if [[ -n "$SCREENSHOT" && "$SCREENSHOT" != /* ]]; then
    SCREENSHOT="$ROOT/$SCREENSHOT"
fi
if [[ -n "$SCREENSHOT" ]]; then
    mkdir -p "$(dirname "$SCREENSHOT")"
fi

# Keep the app's own settings in a disposable preview profile while reading the
# user's current KDE palette (DylanOSDark/DylanOSLight) from kdeglobals.
CONFIG_DIR="$VISUAL_DIR/config"
DATA_DIR="$VISUAL_DIR/data"
CACHE_DIR="$VISUAL_DIR/cache"
mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR"
SOURCE_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals"
if [[ -f "$SOURCE_CONFIG" ]]; then
    cp "$SOURCE_CONFIG" "$CONFIG_DIR/kdeglobals"
fi
export XDG_CONFIG_HOME="$CONFIG_DIR"
export XDG_DATA_HOME="$DATA_DIR"
export XDG_CACHE_HOME="$CACHE_DIR"
export XDG_DATA_DIRS="$PREFIX/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Expose QML modules, Qt plugins and libraries installed into the isolated prefix.
QML_PATHS=()
PLUGIN_PATHS=()
LIBRARY_PATHS=()
for libroot in "$PREFIX/lib" "$PREFIX/lib64"; do
    [[ -d "$libroot" ]] || continue
    while IFS= read -r path; do QML_PATHS+=("$path"); done < <(find "$libroot" -type d -path '*/qt6/qml' -print 2>/dev/null)
    while IFS= read -r path; do PLUGIN_PATHS+=("$path"); done < <(find "$libroot" -type d -path '*/qt6/plugins' -print 2>/dev/null)
    while IFS= read -r path; do LIBRARY_PATHS+=("$path"); done < <(find "$libroot" -type f \( -name '*.so' -o -name '*.so.*' \) -printf '%h\n' 2>/dev/null | sort -u)
done
join_paths() { local IFS=:; printf '%s' "$*"; }
if ((${#QML_PATHS[@]})); then
    QML_IMPORT_PATH="$(join_paths "${QML_PATHS[@]}")"
    export QML2_IMPORT_PATH="$QML_IMPORT_PATH${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
fi
if ((${#PLUGIN_PATHS[@]})); then
    QT_PLUGIN_PATH_VALUE="$(join_paths "${PLUGIN_PATHS[@]}")"
    export QT_PLUGIN_PATH="$QT_PLUGIN_PATH_VALUE${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
fi
if ((${#LIBRARY_PATHS[@]})); then
    LIBRARY_PATH="$(join_paths "${LIBRARY_PATHS[@]}")"
    export LD_LIBRARY_PATH="$LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

if [[ -z "$SCREENSHOT" ]]; then
    echo "Abriendo DylanOS Process en la página Processes. Cierra la ventana para terminar."
    "$BINARY" --page-id processes
    exit $?
fi

APP_PID=""
cleanup() {
    if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
        kill "$APP_PID" 2>/dev/null || true
        wait "$APP_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM
# An isolated session bus prevents the app's single-instance activation from
# handing the screenshot request to an already-running window on another page.
if command -v dbus-run-session >/dev/null 2>&1; then
    dbus-run-session -- "$BINARY" --page-id processes &
else
    "$BINARY" --page-id processes &
fi
APP_PID=$!
sleep "$CAPTURE_DELAY"

if command -v xdotool >/dev/null 2>&1 && command -v import >/dev/null 2>&1; then
    WINDOW_ID="$(xdotool search --onlyvisible --name 'DylanOS Process|Processes|System Monitor' | tail -n 1 || true)"
    if [[ -n "$WINDOW_ID" ]]; then
        xdotool windowactivate --sync "$WINDOW_ID" || true
        import -window "$WINDOW_ID" "$SCREENSHOT"
    elif command -v spectacle >/dev/null 2>&1; then
        spectacle --background --nonotify --activewindow --output "$SCREENSHOT"
    elif command -v gnome-screenshot >/dev/null 2>&1; then
        gnome-screenshot --window --file "$SCREENSHOT"
    else
        echo "No se encontró la ventana de DylanOS Process para capturarla." >&2
        exit 1
    fi
elif command -v spectacle >/dev/null 2>&1; then
    spectacle --background --nonotify --activewindow --output "$SCREENSHOT"
elif command -v gnome-screenshot >/dev/null 2>&1; then
    gnome-screenshot --window --file "$SCREENSHOT"
else
    echo "La app quedó abierta, pero no hay capturador compatible. Instala/usa Spectacle, gnome-screenshot o ImageMagick + xdotool, o ejecuta sin --screenshot." >&2
    exit 1
fi
[[ -s "$SCREENSHOT" ]] || { echo "El capturador no produjo la imagen: $SCREENSHOT" >&2; exit 1; }
echo "Captura de DylanOS Process guardada en: $SCREENSHOT"
wait "$APP_PID"
