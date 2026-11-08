# DylanOS Gaming

DylanOS Gaming es un conjunto opcional para el usuario. Su catálogo, perfiles
declarativos y ajustes se instalan desde DylanOS Configuration; los accesos
rápidos están en el Centro de Control. No cambia el perfil de construcción del
ISO y no reemplaza componentes del escritorio.

## Arquitectura

- `packages/gaming/catalog.json` define las 20 aplicaciones, el método de
  instalación, arquitectura, requisitos y tamaño estimado.
- `packages/gaming/profiles/` contiene Gaming Balanced, Performance,
  Competitive, Streaming y Emulation.
- `GamingService` ejecuta instalaciones Debian por PackageKit y aplicaciones
  Flatpak con instalación `--user` desde el remoto oficial Flathub. Los IDs y
  métodos salen del catálogo incluido; la interfaz no acepta comandos externos.
  La misma página permite actualizar o quitar cada entrada y reintentar una
  instalación fallida.
- Las preferencias y el respaldo de reversión se guardan en
  `~/.local/state/dylanos/gaming/backup.json`; el registro de acciones se guarda
  en `gaming.log`.
- Los controles rápidos llaman modos de línea de comandos limitados de
  `dylanos-configuration`. El comando de estado devuelve JSON para que el Centro
  de Control refleje el mismo perfil.
- El helper de Polkit acepta únicamente governors conocidos, restauración de
  rutas `scaling_governor` y acciones de ZRAM. No administra controladores,
  firmware, GRUB ni particiones.

## Catálogo y compatibilidad

El catálogo contiene Steam, Lutris, Heroic, Bottles, Wine, ProtonUp-Qt, GameHub,
MangoHud, GOverlay, GameMode, Gamescope, OBS Studio, Discord, Prism Launcher,
Dolphin Emulator, RPCS3, PCSX2, RetroArch, Protontricks y CoreCtrl.

Los paquetes Debian se instalan mediante PackageKit. Heroic, Bottles,
ProtonUp-Qt, GameHub, Discord, Prism Launcher, RPCS3, PCSX2 y Protontricks usan
Flatpak de Flathub por usuario. Gamescope está disponible en Debian 13
Backports; no se agrega ese repositorio automáticamente y la entrada queda
marcada no disponible si el binario no existe. No se usan repositorios de
terceros para APT.

Steam y Wine de 32 bits pueden requerir la arquitectura `i386`. Al instalar una
entrada marcada, el helper la habilita con autorización y actualiza índices
APT. La arquitectura queda habilitada si se quitan esas aplicaciones porque
puede ser compartida por otros paquetes del usuario; el desinstalador no la
deshabilita a ciegas.

La disponibilidad de un paquete no garantiza compatibilidad con cada GPU. La
página detecta arquitectura, CPU, memoria, GPU/controlador, OpenGL, Vulkan,
espacio libre y herramientas instaladas. RPCS3 requiere arquitectura x86_64 y
al menos 8 GB recomendados; CoreCtrl solo está orientado a AMD. No se reemplaza
ningún controlador.

`size_mb` es una estimación para orientar la selección; no es una cotización de
APT/Flatpak. El gestor de paquetes resuelve dependencias y muestra su propio
resumen antes de confirmar cambios privilegiados.

## Perfiles y reversión

Cada perfil configura el perfil de energía, los valores de entorno para juegos
nuevos, el preset de MangoHud y, para Streaming, crea un perfil OBS inicial si
no existe. Competitive y Streaming solicitan No molestar durante la sesión de
Configuration; los accesos rápidos del Centro de Control aplican además su
estado de No molestar y lo liberan al cambiar de perfil o restaurar.

La primera activación guarda los archivos previos, perfil de energía y
governors por CPU. `Restaurar` devuelve los archivos y valores respaldados y
borra el estado Gaming activo. Los valores de entorno no modifican procesos que
ya estaban abiertos. Para usar GameMode, el usuario debe configurar cada juego
para iniciarse con `gamemoderun`; aplicar el perfil no lo añade automáticamente.
El perfil tampoco eleva prioridades ni detiene servicios en segundo plano.

## Desarrollo y mantenimiento

`scripts/stage.py` instala el catálogo, los perfiles, el helper y la política de
Polkit en un root de staging explícito. El staging es idempotente. La lista
`packages/gaming/packages.list` es una base de paquetes para un conjunto Gaming;
no se suma al ISO por defecto. El paquete `flatpak` ya forma parte de la base de
DylanOS.

Para comprobar el catálogo: debe tener exactamente 20 IDs únicos y cada método
APT debe declarar nombres de paquete, mientras cada método Flatpak debe declarar
un ID de aplicación y el remoto `flathub`. No instalar aplicaciones en la
máquina de desarrollo como parte de QA.

Limitaciones actuales: el perfil no monitoriza procesos de juegos para cambiar
automáticamente al iniciar/cerrar un juego; la detección de GPU se basa en DRM,
`glxinfo` y `vulkaninfo`; las estimaciones de tamaño no reemplazan la resolución
real del gestor de paquetes. El catálogo informa Gamescope de Backports sin
habilitar Backports por cuenta propia.
