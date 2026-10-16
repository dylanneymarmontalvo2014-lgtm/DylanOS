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

### Scripts

- `scripts/build.sh`: prepara la configuración de Debian Live y construye una ISO híbrida x86_64.
- `scripts/iso.sh`: alias del proceso de construcción.
- `scripts/test.sh`: valida las listas de paquetes, recursos gráficos y estructura básica.

Consulta [la guía de construcción](docs/build.md) para instalar las dependencias y generar la ISO. `dylanos-info` muestra información básica del sistema instalado y `dylanos-wallpaper` aplica el fondo incluido en Plasma; ambos están descritos en [herramientas](docs/commands.md).

### Installer

Configuración del instalador Calamares.

---

## Objetivo

Crear una distribución Linux moderna, elegante y fácil de usar, inspirada en la experiencia de macOS sin perder la libertad y flexibilidad del ecosistema Linux.
