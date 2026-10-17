# Arquitectura de DylanOS

## Plataforma de referencia

| Capa | Elección configurada |
|---|---|
| Distribución | Debian Stable / Debian Live |
| Arquitectura de imagen | `amd64` (x86_64) |
| Escritorio | KDE Plasma, con componentes Breeze |
| Inicio de sesión | SDDM |
| Instalador | Calamares |
| Arranque y splash | GRUB y Plymouth |
| Empaquetado | Listas APT incorporadas por `scripts/build.sh` |

Estas son las elecciones declaradas por los archivos de construcción; no constituyen una matriz de hardware certificado.

## Flujo de construcción

```text
packages/*/packages.list ─┐
configs/ + themes/ ───────┼─> scripts/build.sh ─> Debian Live ─> ISO híbrida amd64
branding/ ────────────────┤
installer/calamares/ ────┘
```

`build.sh` prepara `build/live-build/`, crea listas de paquetes de Debian Live, copia la identidad y las utilidades a `config/includes.chroot`, configura Calamares y ejecuta `lb build`. La compilación necesita root; Docker ejecuta el mismo script con los permisos de montaje requeridos por Debian Live. El detalle está en [Construir DylanOS](build.md).

El constructor incluye las cuatro categorías de paquetes en cada imagen actual: `default`, `development`, `gaming` e `iot`. No son opciones seleccionables ni perfiles de instalación separados todavía.

## Mapa por responsabilidad

| Ruta | Responsabilidad |
|---|---|
| `branding/` | Logo, icono, wallpaper y recursos de inicio |
| `configs/system/rootfs/` | Identidad instalada y comandos propios |
| `configs/bash/`, `configs/zsh/` | Defaults para usuarios nuevos |
| `configs/plasma/` | Tema KDE y entradas de bienvenida/autoinicio |
| `packages/` | Listas APT agrupadas por propósito |
| `themes/` | Ajustes de GTK, Plasma, SDDM y GRUB |
| `installer/calamares/` | Secuencia, módulo unpackfs y branding |
| `scripts/` | Construcción, pruebas estáticas y smoke test de ISO ejecutable manualmente |
| `.github/workflows/` | CI ligera, build manual de artefacto y publicación versionada |
| `docs/` | Guías y registro de límites conocidos |

## Configuración que llega al sistema

`configs/system/rootfs/` se copia al filesystem de la imagen. `configs/plasma/dylanos-welcome.desktop` registra la aplicación en el menú y `dylanos-welcome-autostart.desktop` la inicia una vez por usuario KDE. Las configuraciones de Bash/Zsh y `kdeglobals` se instalan en `/etc/skel` para cuentas nuevas.

Los temas de Plasma, GTK, SDDM, GRUB y Plymouth se instalan desde sus directorios respectivos. El wallpaper queda disponible para aplicación manual; no se modifica al iniciar sesión. El repositorio no declara una disposición propia de panel/dock de Plasma.

## Instalador

`installer/calamares/settings.conf` define las páginas y módulos de la secuencia; `modules/unpackfs.conf` instala el sistema live en el destino. Que estos archivos y el paquete `calamares` estén configurados no significa que se haya completado una instalación de punta a punta. Consulta [Estado del proyecto](status.md) y [Pruebas](testing.md).
