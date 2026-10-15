# DylanOS Store (Qt 6 / QML)

Native migration of the React prototype in `../src` (which is kept untouched as visual reference).
C++17 + QML + CMake. No React, Electron or embedded browser. The data layer is a simulated backend:
**nothing is ever installed or removed on the host.**

## Requirements
Qt 6.5+ (developed on 6.8.3) with Quick, QuickControls2, Svg, Shapes, Test; CMake 3.21+; Ninja.

## Build and run
```sh
cmake -S . -B build -G Ninja -DCMAKE_PREFIX_PATH=/path/to/Qt/6.8.3/gcc_64
cmake --build build
./build/dylanos-store
ctest --test-dir build --output-on-failure
```
Headless hosts without GL headers: add `-DOpenGL_GL_PREFERENCE=LEGACY`, point `CMAKE_PREFIX_PATH`/`-I`/`-L` at stub GL headers, and run with `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software`.

## Developer screenshot CLI
`dylanos-store --screenshot out.png --size 1280x800 --view cat:dev --action install:godot --delay 800`
Views: home, cats, cat:ID, search, app:ID, library, updates, installed, states, settings.
Actions (closed list, no scripting): install:ID, update:ID, updateAll, offline, query:TEXT, open:OBJECTNAME.

## Layout
`src/services` backend interface + mock · `src/models` C++ models/controller · `src/qml/{theme,components,pages}` UI · `data/demo-apps.json` demo catalog · `tests/` Qt Test · `docs/`.
See `docs/ARCHITECTURE.md`, `docs/DESIGN_MAPPING.md`, `docs/PACKAGE_BACKEND.md`.

## Status
See "Known differences and pending work" in `docs/DESIGN_MAPPING.md`.
