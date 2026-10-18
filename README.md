# DylanOS Crimson 1.0

DylanOS es un entorno de escritorio basado en Debian 13 (trixie), KDE Plasma 6 y Qt 6, con una identidad visual propia marcada por la paleta Crimson: rojo intenso, negro profundo y superficies de vidrio sutil. El proyecto combina un escritorio Plasma personalizado, aplicaciones nativas y un flujo de instalación y gestión de software propio.

## Estado actual

- Base del sistema: Debian 13 (trixie) amd64
- Escritorio: KDE Plasma 6
- Tecnología base: Qt 6 / QML / KWin
- Identidad visual: DylanOS Crimson
- Instalador: propio, dentro de `installer/dylanos-installer`
- Explorador: DylanOS Explorer
- Tienda: DylanOS Store
- Shell de trabajo: `apps/workspace`

## Qué incluye

- `apps/workspace`: centro de trabajo con páginas de bienvenida, archivos, notas, desarrollo, monitor y ajustes.
- `apps/dylanos-explorer`: gestor de archivos nativo basado en el motor de Dolphin/KIO.
- `apps/dylanos-store`: tienda nativa de DylanOS para software, actualizaciones y catálogo.
- `apps/dylanos-app-center`: lanzador de apps instaladas.
- `apps/dylanos-spotlight`: búsqueda rápida del sistema.
- `themes/`: look and feel, SDDM, GRUB, Plymouth, GTK y aurorae.
- `branding/`: logo, pintura, wallpapers e iconografía.
- `configs/`: perfiles de usuario, Konsole, bash, zsh y defaults del sistema.
- `scripts/`: build, staging, QA y validación del sistema.

## Diseño visual

La identidad oficial de DylanOS Crash/Crimson se define con estos valores:

- DylanOS Red: `#DC143C`
- DylanOS Black: `#0A0A0A`
- DylanOS White: `#FFFFFF`
- DylanOS Gray: `#1A1A1A`
- DylanOS Light Gray: `#B3B3B3`

La referencia visual principal está en `branding/` y en los temas bajo `themes/`.

## Inicio rápido

Para probar la app de escritorio localmente con el entorno de desarrollo del proyecto:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r apps/workspace/requirements-dev.txt
python apps/workspace/main.py
```

Para validar la base del proyecto con las comprobaciones del repositorio:

```bash
DYLANOS_PYTHON="$PWD/.venv/bin/python" bash scripts/check.sh
```

Las pruebas del repositorio requieren dependencias como `shellcheck` y `desktop-file-validate` disponibles en el sistema.

## Construcción de la ISO

En un host Debian/Ubuntu amd64 con acceso a `sudo` y espacio suficiente:

```bash
sudo apt install debootstrap gnupg squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools
bash scripts/build.sh
bash scripts/iso.sh
bash scripts/test.sh
```

El flujo de build está centrado en `scripts/build.sh` y `scripts/stage.py`, y se apoya en `work/chroot` y `work/iso` para no mezclar lo generado con el repositorio fuente.

## Documentación del proyecto

- [docs/README.md](docs/README.md): índice de la documentación.
- [docs/install.md](docs/install.md): instalación, pruebas y arranque live.
- [docs/architecture.md](docs/architecture.md): arquitectura y principios de diseño.
- [docs/roadmap.md](docs/roadmap.md): hoja de ruta.
- [docs/contributing.md](docs/contributing.md): flujo de contribución.
- [docs/auditoria-*-2026-*.md](docs): informes históricos y de depuración archivados.

## Estructura del repositorio

```text
DylanOS/
├── apps/
├── branding/
├── configs/
├── docs/
├── installer/
├── packages/
├── scripts/
├── themes/
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
└── work/
```

## Licencia

El código fuente del repositorio se distribuye bajo la GNU General Public License v3.0 o posterior, salvo que un archivo concreto indique otra cosa. Los recursos de branding, temas e iconos se mantienen dentro de la misma licencia del repositorio a menos que exista una nota específica en un archivo o conjunto de archivos.

## Contribución

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) para el flujo de trabajo, estándares y validación recomendada antes de enviar cambios.

## Nota

Los informes técnicos y auditorías antiguas siguen conservados en `docs/` como referencia histórica y no deben tratarse como documentación activa del proyecto.
