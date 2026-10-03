# Diseño: DylanOS Tahoe

**Fecha:** 2026-10-03  
**Estado:** propuesta para revisión  
**Alcance:** primera versión completa del lenguaje visual de DylanOS

## 1. Objetivo

Crear una identidad visual propia para DylanOS inspirada en la experiencia visual de macOS Tahoe, sin copiar assets propietarios de Apple. La primera versión cubrirá escritorio KDE Plasma, aplicaciones GTK, decoración de ventanas, pantalla de inicio de sesión SDDM, GRUB y Plymouth.

El resultado debe conservar la identidad de DylanOS, ser instalable desde la ISO, construible offline una vez que los assets libres estén vendoreados y mantener separadas las responsabilidades de branding, temas, configuración y construcción.

## 2. Decisiones aprobadas

- **Dock:** no se agrega dock en esta fase. El escritorio tendrá un único panel superior estilo barra de menús.
- **Variantes:** se entregan Light y Dark; Dark es la variante predeterminada.
- **Assets:** iconos y cursores libres se vendorean en el repositorio, conservando sus licencias y créditos.
- **Arquitectura visual:** tema nativo de Plasma 6, decoración Aurorae y configuración propia; no se adopta WhiteSur completo ni hacks frágiles de terceros.
- **Boot:** se cubren escritorio, GTK, SDDM, GRUB y Plymouth.
- **Dock propio:** `apps/com.dylanos.dock/` queda desacoplado y fuera de este sub-proyecto.

## 3. Arquitectura de archivos

```text
themes/
├── plasma/DylanOS-Tahoe/        # Plasma desktop theme y SVGs
├── aurorae/DylanOS-Tahoe/       # decoración de ventanas
├── lookandfeel/DylanOS-Tahoe/   # paquete que integra la experiencia Plasma
├── colors/                      # esquemas Light y Dark
├── icons/WhiteSur-Dark/         # asset libre vendoreado + licencia
├── cursors/McMojave-Dark/       # asset libre vendoreado + licencia
├── gtk/DylanOS-Tahoe/           # configuración GTK
├── grub/DylanOS-Grub/           # tema de arranque GRUB
├── plymouth/DylanOS-Plymouth/   # splash Plymouth
└── sddm/DylanOS-SDDM/           # evolución del tema existente

configs/plasma/skel/             # configuración heredada por usuarios nuevos
branding/wallpapers/             # wallpapers originales Light y Dark
docs/licenses/                   # créditos y licencias de assets externos
scripts/lib/wallpaper-gen.py     # generación reproducible de wallpapers
```

Los nombres exactos de archivos internos de Plasma 6, Aurorae y Plymouth se validarán durante la planificación contra la versión de Debian Stable objetivo. No se asumirá compatibilidad con formatos de Plasma 5 sin comprobarla.

## 4. Lenguaje visual

### 4.1 Tokens

| Token | Dark | Light |
|---|---|---|
| Fondo base | `#0A0A0A` | `#F5F5F7` |
| Acento DylanOS | `#E50914` | `#E50914` |
| Panel | negro translúcido, aproximadamente 75% | blanco translúcido, aproximadamente 65% |
| Semáforo cerrar | `#FF5F57` | `#FF5F57` |
| Semáforo minimizar | `#FEBC2E` | `#FEBC2E` |
| Semáforo maximizar | `#28C840` | `#28C840` |
| Tipografía | Inter | Inter |

El blur y la translucidez dependerán de las capacidades de KWin y deberán tener un fallback legible si los efectos están desactivados o el hardware no los soporta.

### 4.2 Ventanas y panel

- Los botones de ventana se ubicarán a la izquierda.
- La decoración tendrá esquinas redondeadas y titlebar translúcida.
- El panel superior será único y contendrá menú de aplicación a la izquierda, además de bandeja y reloj a la derecha.
- No se instalará ni activará un dock inferior.

### 4.3 Wallpapers

Se generarán wallpapers originales mediante un proceso reproducible, con gradientes y formas abstractas inspiradas en paisajes de luz y agua, sin usar imágenes de Apple. Habrá una variante Dark y una Light. El script y sus entradas deberán permitir regenerarlos sin depender de una CDN durante el build.

## 5. Configuración por defecto

`configs/plasma/skel/` se copiará a `/etc/skel/.config/` durante la construcción de la imagen. Incluirá, según los formatos validados para Plasma 6:

- `kwinrc`: decoración DylanOS, botones a la izquierda y efectos de blur cuando estén disponibles.
- `kdeglobals`: esquema de color, fuente Inter, tema de iconos y cursor.
- `plasmarc`: tema Plasma y paquete LookAndFeel.
- `plasma-org.kde.plasma.desktop-appletsrc`: panel superior único, menú, bandeja y reloj.

La configuración se probará con un usuario nuevo en una sesión Plasma limpia; no se modificarán configuraciones personales existentes durante el build.

## 6. Integración en la ISO

`packages/default/packages.list` incorporará las dependencias necesarias, incluyendo `fonts-inter` y `plymouth` cuando estén disponibles para la base Debian elegida. Cada dependencia se verificará en los repositorios objetivo antes de incorporarla.

`build.sh` deberá:

1. Instalar las dependencias declaradas.
2. Copiar cada tema a su ruta estándar bajo `/usr/share/`.
3. Instalar wallpapers y branding.
4. Copiar la configuración de `/etc/skel/`.
5. Integrar SDDM sin sobrescribir de forma silenciosa cambios de trabajo no relacionados.
6. Configurar GRUB y Plymouth solo en las rutas propias de la imagen construida.
7. Mantener la construcción repetible y fallar explícitamente si falta un asset requerido.

## 7. SDDM, GRUB y Plymouth

### SDDM

Se evolucionará el tema existente `themes/sddm/DylanOS-SDDM/` hacia una tarjeta de login glass centrada, con controles legibles y coherencia de colores con Dark/Light. Antes de modificar `Main.qml`, se debe preservar o integrar el trabajo local existente en `Main.qml`, `.bak` y `profile.png`; no se eliminarán archivos sin revisión explícita.

### GRUB

Se creará un tema propio con fondo Dark, logo DylanOS, entradas centradas y selección con acento rojo. La integración se limitará al árbol de la ISO y a la configuración necesaria para activar `GRUB_THEME`.

### Plymouth

Se creará un splash sencillo con logo DylanOS y spinner sobre fondo oscuro, usando un formato soportado por Debian Stable. Debe tener fallback textual o silencioso si Plymouth no está disponible.

## 8. Assets y licencias

WhiteSur-icons y McMojave se incluirán solo si sus versiones y licencias permiten la redistribución prevista. Cada directorio vendoreado conservará su `LICENSE`/`AUTHORS` original y se añadirá un inventario en `docs/licenses/` con fuente, versión o commit, licencia y cambios locales.

No se incluirán fondos, iconos, fuentes ni código extraído de macOS o de repositorios con licencias incompatibles.

## 9. Pruebas y aceptación

### Automatizadas

- Validación de sintaxis de scripts Bash y Python.
- Shellcheck para scripts Bash.
- Tests de estructura: metadata requerida, rutas de instalación y archivos de configuración.
- Tests de tokens: colores usados por Light/Dark existen y no quedan referencias rotas.
- Verificación de licencias para assets vendoreados.
- Build de staging sin ejecutar el build completo de ISO en cada cambio.

### Integración

- Construcción de chroot con `scripts/build.sh`.
- Comprobación de que los paquetes y temas existen en el chroot final.
- Usuario nuevo hereda la configuración Plasma.
- SDDM, GRUB y Plymouth tienen sus archivos en las rutas esperadas.

### QA visual

La aceptación estética final se hará arrancando la imagen en una VM QEMU/KVM. Se revisarán legibilidad, contraste, panel superior, decoración, login y secuencia de arranque en Light y Dark. La decisión visual final requiere aprobación humana de Ing.Dylan.

## 10. Fuera de alcance

- Implementar o integrar `apps/com.dylanos.dock/`.
- Copiar assets propietarios de Apple.
- Cambiar la arquitectura de Calamares.
- Rediseñar las aplicaciones QML existentes salvo ajustes mínimos necesarios para coherencia de branding.
- Garantizar que todas las aplicaciones de terceros soporten blur/transparencia; se aplicarán fallbacks.
