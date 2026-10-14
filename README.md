# DylanOS 1.0 Beta

Distribución de escritorio basada en **Debian 13 (trixie), KDE Plasma 6 y Qt 6**,
con una apariencia Crimson inspirada en Tahoe: barra superior de menús y estado,
dock inferior flotante, controles de ventana a la izquierda y temas GTK/Qt claros
y oscuros. El fondo predeterminado es `branding/wallpapers/dylanos-default.png`.

## Aplicaciones

- **Aplicaciones DylanOS independientes**: Bienvenida, Notas, Desarrollo, Monitor,
  Software y Ajustes; comparten componentes y abren ventanas separadas. Monitor
  muestra historial de CPU/RAM y búsqueda de procesos; Desarrollo ofrece plantillas
  Python, web y C++. Las notas existentes en SQLite conservan su ubicación.
- **Archivos**: Dolphin es el explorador predeterminado. El explorador propio
  preexistente sigue disponible con `dylanos --page files`.
- **Calculadora**: aplicación Qt nativa con teclado y manejo de errores.
- **App Center**: lanzador de aplicaciones instaladas mediante los servicios de KDE.
- Firefox ESR, Dolphin, Konsole, Kate, LibreOffice, Thunderbird, Okular, VLC,
  Elisa, Gwenview, Ark, Spectacle, Kamoso, monitor de KDE y Kup. El software se
  instala desde DylanOS Store.
- Perfil de desarrollo: VSCodium, Git, Python/venv, Node/npm, GCC, CMake,
  Ninja, GDB, Podman, SSH, ripgrep y ShellCheck.

DylanOS Store gestiona las instalaciones y actualizaciones. Ajustes abre
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

## Renovación visual de octubre de 2026

La auditoría y los módulos modificados están en
[el informe de escritorio](docs/auditoria-escritorio-2026-10-11.md).
El instalador es completamente propio (`installer/dylanos-installer`): la
interfaz del prototipo Figma se muestra en una ventana nativa de escritorio
(Qt WebEngine, sin navegador externo) sobre un backend REST que detecta
hardware y discos reales, particiona con parted, extrae el squashfs y
configura usuario, idioma, teclado y GRUB. Calamares quedó eliminado de la
imagen y del repositorio.
El splash de sesión es propio y separado de Plymouth.
El terminal usa Konsole translúcido con perfil DylanOS, fastfetch con logo
propio y un prompt Crimson con separadores, tips y sugerencias de comandos.

El nuevo layout se aplica a perfiles nuevos. No se borran los paneles de cuentas
existentes: se puede elegir DylanOS Crimson en Preferencias → Tema global y
aplicar su distribución de escritorio expresamente.
