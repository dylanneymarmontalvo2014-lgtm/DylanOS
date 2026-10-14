# DylanOS — Mapa del Repositorio (memoria persistente)

Sistema operativo ligero basado en Debian + KDE Plasma, con identidad visual propia
(crimson #DC143C). Rama principal: **development**.

## Colores oficiales (branding/colors/dylanos.conf)

- DYLANOS_RED=#DC143C · BLACK=#0A0A0A · WHITE=#FFFFFF · GRAY=#1A1A1A · LIGHT_GRAY=#B3B3B3
- Gradientes UI habituales: primary `#e81740→#ad0a2a`, hover `#ff2a54→#c90e33`, down `#9c0b28→#7a051d`.
- Estética "liquid glass": bordes `#ff5274`/`#2e2736`, línea especular superior blanca translúcida.

## Estructura

- `apps/workspace/` — App QML/Python (PySide6) con 7 páginas: welcome, files, notes, store, dev, monitor, settings.
  - `main.py` (entry, acepta `--page`, `--smoke`, `--screenshot`, `--appearance`), `backend.py` (puente Qt), `core.py`.
  - `qml/`: Main.qml + páginas. Componentes de diseño: `Field.qml`, `ActionButton.qml` (primary=crimson), `Surface.qml` (tarjeta glass con gradiente según dark/light).
  - En el ISO se instala en `/usr/share/dylanos/workspace`; wrapper `/usr/bin/dylanos --page <key>` (lo genera `scripts/stage.py`).
- `apps/dylanos-app-center/` — Launcher fullscreen C++/QML (grid de apps instaladas, fondo carmesí humo, búsqueda píldora, puntos de paginación). Ejecutable `dylanos-app-center`.
- `apps/dylanos-spotlight/` — Búsqueda rápida (Python). `dylanos-spotlight`.
- `apps/com.dylanos.dock/` y `apps/com.dylanos.activeapp/` — Plasmoids Plasma.
- `apps/archivos/`, `apps/calculator/` — Apps propias adicionales.
- `branding/` — logo.png (instalado como `distributor-logo-dylanos`), colors/, wallpapers/, icons/.
- `themes/` — Plasma look-and-feel `org.dylanos.crimson`, aurorae, SDDM, GRUB, Plymouth, GTK DylanOS-Crimson(+Light), color-schemes.
- `configs/` — skel de Plasma, konsole (translúcido 0.82 + fastfetch), bashrc propio.
- `scripts/` — `build.sh`, `iso.sh`, `stage.py` (staging idempotente hacia root explícito), `check.sh` (QA total), `test_QEMU.sh`, `lib/`.
- `scripts/tests/` — unittest Python (test_*.py) + `test_packages.sh`. QA QML offscreen de las 7 páginas vía `main.py --page X --smoke` con `QT_QPA_PLATFORM=offscreen`.
- `installer/dylanos-installer/` — Instalador nativo Qt WebEngine (dist/ + backend/ + native/).
- `previews/` — Capturas de referencia de diseño (PNG, no incluir en lógica).
- `packages/{build,default,development,gaming,iot}` — Listas de paquetes del ISO.

## Store (DylanOS Store)

- Página `store` del Workspace = **DylanOS Store** (antes delegaba con nombre "Discover"; hoy 100% rebranding).
- Motor real: `plasma-discover` (visual rebranding only). `backend.action("store"|"updates")` y `backend.findSoftware(q)` lo lanzan; NUNCA mostrar el nombre "Discover/plasma-discover" al usuario.
- Logo: `branding/icons/dylanos-store.svg` (master) + PNG rasterizado en `apps/workspace/assets/dylanos-store.png` y `branding/icons/dylanos-store.png` (icono hicolor 512 en staging).
- Entrada desktop: `org.dylanos.store.desktop`, Name=DylanOS Store, Icon=dylanos-store (en `scripts/stage.py`).

## QA (ejecutar antes de entregar)

```bash
DYLANOS_PYTHON=/tmp/opencode/venv/bin/python bash scripts/check.sh
```

- Valida: bash -n de todos los .sh, shellcheck, test_packages.sh, unittest completo, compileall, staging (con desktop-file-validate) y carga QML offscreen de las 7 páginas (store incluida) + variante light.
- PySide6/psutil NO están en el python3 del sistema: usar venv (`/tmp/opencode/venv`) o instalar `python3-pyside6` + `python3-psutil` (los que usa el ISO: PySide6 6.8.2.1).
- Tests clave: `test_staging.py` (cuenta 8 desktop entries org.dylanos.*), `test_ui.py`, `test_workspace.py`, `test_backend.py`.
- `unittest discover` (la flag de CLI) aparece en docs históricos: NO es una referencia a KDE Discover; no tocar.

## Convenciones

- Comentarios y UI en español; código sin comentarios salvo los existentes.
- stage.py: staging SIEMPRE a un root explícito, idempotente (borra artefactos obsoletos).
- `previews/` y docs históricos (`docs/superpowers/`, `docs/*-2026-*.md`, `.superpowers/`) son registros: no reescribirlos.
- `.claude/worktrees/` es un worktree viejo (copia histórica): no editar.
