# Arquitectura de DylanOS

## Base del sistema

- Distribución base: Debian Stable
- Arquitectura: x86_64
- Kernel: Linux
- Escritorio: KDE Plasma
- Gestor de inicio de sesión: SDDM
- Instalador: Calamares

---

## Componentes principales

### Branding

Contiene el logo, fondos de pantalla, iconos y recursos visuales de DylanOS.

### Themes

Incluye los temas de:

- Plasma
- GTK
- Qt
- SDDM
- GRUB
- Plymouth

### Packages

Define las aplicaciones instaladas por defecto en listas separadas para el escritorio, desarrollo, juegos e IoT.

### Configs

Almacena la configuración predeterminada del sistema.

### Scripts y entorno de construcción

- `install-deps.sh`: instala las dependencias necesarias en Debian o Ubuntu.
- `scripts/build.sh`: prepara Debian Live y construye una ISO híbrida x86_64.
- `scripts/iso.sh`: alias del proceso de construcción.
- `scripts/test.sh`: valida las listas de paquetes, recursos gráficos, utilidades y estructura básica.
- `scripts/test-iso.sh`: inspecciona una ISO y prueba su arranque BIOS/UEFI con QEMU.
- `.github/workflows/release-iso.yml`: construye y publica la ISO en GitHub Releases al enviar una etiqueta `v*`.
- `Dockerfile`: crea un entorno aislado para ejecutar el `scripts/build.sh` existente.

Consulta [la guía de construcción](docs/build.md) para instalar las dependencias, generar la ISO y probar su arranque. `dylanos-info --diagnose` ofrece comprobaciones locales de solo lectura; `dylanos-welcome` da acceso a diagnósticos, documentación e instalación. Ambos, junto con `dylanos-wallpaper`, están descritos en [herramientas](docs/commands.md).

### Installer

Configuración del instalador Calamares.

---

## Objetivo

Crear una distribución Linux moderna, elegante y fácil de usar, inspirada en la experiencia de macOS sin perder la libertad y flexibilidad del ecosistema Linux.
