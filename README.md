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

Define las aplicaciones instaladas por defecto.

### Configs

Almacena la configuración predeterminada del sistema.

### Scripts

Contiene los scripts para:

- Construcción de la ISO.
- Pruebas.
- Limpieza.
- Publicación.

### Installer

Configuración del instalador Calamares.

---

## Objetivo

Crear una distribución Linux moderna, elegante y fácil de usar, inspirada en la experiencia de macOS sin perder la libertad y flexibilidad del ecosistema Linux.s