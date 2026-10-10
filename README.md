# DylanOS 1.0 Beta

Distribución de escritorio basada en **Debian 13 (trixie), KDE Plasma 6 y Qt 6**,
con una apariencia propia inspirada en DylanOS Crimson. Barra superior, controles de
ventana a la izquierda, esquemas claro/oscuro y fondos originales.

## Aplicaciones

- **DylanOS Workspace**: bienvenida, Archivos, Notas, Desarrollo, Monitor,
  Software y Ajustes. Datos reales; notas locales en SQLite; operaciones de
  archivos en segundo plano; plantillas Python, web y C++.
- **Calculadora**: aplicación Qt nativa con teclado y manejo de errores.
- **App Center**: lanzador de aplicaciones instaladas mediante los servicios de KDE.
- Firefox ESR, Dolphin, Konsole, Kate, LibreOffice, Thunderbird, Okular, VLC,
  Elisa, Gwenview, Ark, Spectacle, Kamoso, Discover, monitor de KDE y Kup.
- Perfil de desarrollo: VSCodium, Git, Python/venv, Node/npm, GCC, CMake,
  Ninja, GDB, Podman, SSH, ripgrep y ShellCheck.

Software delega las instalaciones y actualizaciones en Discover. Ajustes abre
los módulos reales de Plasma. Las apps no simulan descargas ni controles de hardware.

## Ejecutar y comprobar las apps

```sh
python3 -m venv .venv
.venv/bin/pip install -r apps/workspace/requirements-dev.txt
.venv/bin/python apps/workspace/main.py
DYLANOS_PYTHON="$PWD/.venv/bin/python" bash scripts/check.sh
```

Los controles de escritorio requieren Plasma y sus paquetes. Archivos, Notas,
Monitor y las plantillas se pueden probar en otra distribución Linux con Qt 6.
`scripts/check.sh` necesita también `shellcheck` y `desktop-file-validate`.

## Construir la imagen

En un host Debian/Ubuntu amd64 con acceso a `sudo`, al menos 25 GB libres y conexión:

```sh
sudo apt install debootstrap gnupg squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools
bash scripts/build.sh
bash scripts/iso.sh
bash scripts/test.sh
```

Salida: `DylanOS-1.0-beta-amd64.iso` y su archivo `.sha256`. La construcción se
limita a `work/chroot`, en un espacio de montajes separado. No instala Plasma en
el host, no particiona discos y no borra una construcción anterior. `--resume`
continúa una existente; `--minimal` omite el grupo de desarrollo (las dependencias
de compilación de las apps siguen siendo necesarias).

La firma de Debian se comprueba con la clave de trixie incluida en `configs/keys`.
Los paquetes de Debian reciben actualizaciones de trixie, trixie-updates y
trixie-security; VSCodium usa su repositorio externo firmado. Se guarda el
inventario de versiones en `work/packages.manifest`. Las versiones APT no están
congeladas: esta es una construcción repetible, no una imagen idéntica byte a byte.

Consulta [instalación y QA](docs/install.md), [estado de la beta](docs/beta-status.md)
y [arquitectura](docs/architecture.md). Las imágenes de `docs/previews` anteriores
son propuestas; las capturas de verificación nuevas se guardan en `artifacts/`.
