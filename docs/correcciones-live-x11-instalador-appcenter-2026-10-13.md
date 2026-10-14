# Correcciones: sesión live (X11), instalador, App Center y barra superior

**Fecha:** 2026-10-13
**Relacionado con:** [auditoría de escritorio](auditoria-escritorio-2026-10-11.md),
[crimson-1.0-handover-log](crimson-1.0-handover-log.md).

Este documento registra los cambios aplicados sobre el árbol de fuentes
(unidad `development`) para (1) convertir el arranque en una **sesión live de
vista previa con escritorio Plasma/X11** donde el instalador es un ejecutable
del escritorio y del menú, y (2) corregir la **detección de hardware/discos del
instalador propio** y varios defectos de interfaz.

> Recordatorio: la ISO existente no incorpora cambios del árbol de fuentes
> hasta reconstruirla (`scripts/build.sh` + `scripts/iso.sh`).

## 1. Decisión de arranque (opción A)

La ISO arranca al **escritorio live en X11** (SDDM → `plasmax11.desktop`,
autologin del usuario `dylan` de live-config). El instalador oficial
(`/usr/bin/dylanos-installer`) queda:

- como **ejecutable en el escritorio** (`~/Desktop/instalar-dylanos.desktop` y
  `~/Escritorio/instalar-dylanos.desktop`), con permisos `0o755` para que Plasma
  lo trate como lanzador de confianza;
- como **entrada del menú** (`/usr/share/applications/dylanos-installer.desktop`).

**Se elimina** `/etc/xdg/autostart/dylanos-installer.desktop`: el instalador ya
**no se abre solo** al iniciar sesión. El usuario previsualiza DylanOS y abre la
instalación cuando quiere.

### Por qué el lanzador se escribe en dos carpetas

Plasma muestra los iconos de `XDG_DESKTOP_DIR`, que `xdg-user-dirs` traduce según
el idioma. Como la sesión live arranca en español (`locales=es_ES.UTF-8`), la
carpeta puede ser `~/Escritorio` en vez de `~/Desktop`. El staging escribe el
lanzador en **ambas** para que el icono aparezca en cualquiera de los dos casos.

### Archivos

| Archivo | Cambio |
| --- | --- |
| `scripts/stage.py` | Instala el lanzador en `~/Desktop` y `~/Escritorio`; **elimina** la entrada de autostart. |
| `scripts/iso.sh` | Menú GRUB: «Sesión live (probar o instalar)» y «Sesión live, gráficos seguros»; comentarios actualizados. |
| `docs/install.md` | Instrucciones ajustadas (sin autostart). |
| `scripts/tests/test_staging.py` | Exige el lanzador en ambas carpetas y la **ausencia** del autostart. |

## 2. Instalador propio: detección robusta de componentes

`installer/dylanos-installer/backend/server.py`. Los "errores raros" venían de
suposiciones frágiles sobre la salida de `lsblk`/`df`:

- `lsblk -J` puede devolver `MOUNTPOINTS` **como lista** (util-linux ≥ 2.37) o
  `MOUNTPOINT` como cadena; el código usaba `mountpoint` y podía acabar con una
  lista, rompiendo `shlex.quote` y mostrando montajes incorrectos.
- Los tamaños se convertían con `int(dev["size"])` sin tolerar cadenas/`None`.
- `df -BG /` en el medio live mide el **overlay/tmpfs en RAM**, no el disco
  físico, así que "Almacenamiento" engañaba al instalador.
- Un disco sin particiones se mostraba como "Espacio sin asignar" ocupando el
  disco completo (confuso).

### Correcciones

- Helpers nuevos: `_safe_int`, `_first_mountpoint`, `_run_lsblk`,
  `lsblk_devices` (prueba `MOUNTPOINTS` → `MOUNTPOINT` → conjunto reducido),
  `_is_real_disk` (descarta loop, zram, sr, ram, fd y dm) y
  `real_storage_summary`.
- `real_storage_summary()` suma los **discos reales** y calcula el espacio libre
  como `disco − particiones`; solo recurre a `df -BG /` si `lsblk` no responde
  (validando que los valores sean numéricos).
- `get_real_disks()` normaliza tamaños y montajes, añade «Espacio libre» **solo
  si queda espacio sin asignar**, y devuelve un marcador (nunca excepción) si no
  hay discos, para que la interfaz muestre el aviso de detección.
- La forma del JSON **no cambia** (`device`, `size`, `sizeGB`, `model`,
  `partitions[]`, `used`, `color`), así que la interfaz React precompilada
  (`dist/`) sigue funcionando sin recompilar.

### Tests

`scripts/tests/test_installer_backend.py` cubre el contrato existente (claves,
filtrado de loop/zram/cdrom, fallback, GPU, RAM, locales) — 19 pruebas en verde.

## 3. App Center (`apps/dylanos-app-center`)

- **Desplazamiento por teclado.** Se añadió `revealCell(index)`: al mover la
  selección (flechas, AvPág/RePág, cambio de página) el `Flickable` se desplaza
  para mantener visible la celda enfocada. Antes, en pantallas pequeñas el foco
  se salía de la vista. Se conecta con
  `onCurrentIndexChanged: window.revealCell(currentIndex)`.
- **Logo.** Icono propio definido por diseño: fondo partido en dos franjas
  (izquierda **DylanOS Crimson** `#DC143C`, derecha **DylanOS Black** `#0A0A0A`)
  con el logotipo oficial de DylanOS centrado y esquinas redondeadas. El
  lanzador usa `Icon=dylanos-app-center`; el PNG de 512×512 se genera a partir
  de `branding/logo.png`.
- Regresión estática en `scripts/tests/test_app_center.py`
  (`test_keyboard_navigation_keeps_focus_visible` y la comprobación de `Icon`).

## 4. Barra superior, dock, pager y botones

Estos puntos ya habían sido corregidos en el árbol de trabajo; se verifica su
contrato con `scripts/tests/test_desktop.py`, que ejecuta el layout de Plasma con
Node.js y comprueba:

- **Dos paneles**: barra superior de menús (no flotante, sin autoocultado) y dock
  inferior flotante centrado con `dodgewindows`.
- **Sin cambiador de escritorios**: el layout **nunca** añade
  `org.kde.plasma.pager`.
- **Orden que evita solapes**: `kickoff` (logo) → `com.dylanos.activeapp`
  (nombre de app activa) → `org.kde.plasma.appmenu` (menús de acción) →
  `panelspacer` → `systemtray` → reloj. El separador elástico va **después** del
  menú, de modo que el nombre y sus botones de acción permanecen juntos y no
  cruzan el logotipo.
- El widget `com.dylanos.activeapp` usa `clip: true` y ancho máximo para no
  invadir el menú.

Además, en `apps/workspace/qml/SettingsPage.qml` la etiqueta `host · kernel`
gana `elide`/`fillWidth` para que no empuje el botón de acción sobre el logotipo
de la fila.

## 5. Verificación

```sh
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
# o la batería completa, incluidos staging, shellcheck y carga QML:
bash scripts/check.sh
```

La ISO se valida con `bash scripts/iso.sh` + `bash scripts/test.sh` y la QA en
máquina virtual (`scripts/test_QEMU.sh`). Una carga QML o un checksum correctos
**no sustituyen** las pruebas de arranque, red, audio y suspensión en VM/hardware.

## 6. Supuestos y límites

- El icono del App Center es el diseño de dos franjas (roja a la izquierda,
  negra a la derecha) con el logotipo DylanOS; se genera desde `branding/logo.png`
  y CMake lo instala como `dylanos-app-center` en hicolor 512×512.
- `real_storage_summary()` describe la capacidad del **conjunto de discos**
  (no del disco seleccionado en el particionado, que se muestra aparte).
- El layout de Plasma se aplica a **perfiles nuevos**; no se borran
  configuraciones existentes de usuarios.

## 7. Ronda 2 (13-oct): GRUB, barra superior, dock y ventana del instalador

Bugs reportados tras compilar la primera ISO corregida.

### 7.1 GRUB fallaba al final de la instalación

`installer/dylanos-installer/backend/server.py`. Dos causas reales:

1. **`grub-install --target=i386-pc` exige una partición BIOS boot en GPT.**
   El particionado automático creaba GPT con solo ESP + raíz, así que la vía
   BIOS siempre fallaba. Ahora el esquema automático es: **1)** ESP 512 MiB
   (`esp on`), **2)** BIOS boot 1 MiB (`bios_grub on`), **3)** raíz ext4
   (`auto_root` pasa de `p2` a `p3`).
2. **`/sys` se montaba con `--bind`**: efivarfs (que vive en un submontaje de
   `/sys`) no quedaba visible dentro del chroot y `grub-install` UEFI fallaba
   al escribir el NVRAM. Ahora `/dev` y `/sys` se montan con `--rbind` +
   `--make-rslave`, y `/proc` con `mount -t proc`. Además los montajes usan
   `run_cmd`: un fallo da un error claro aquí en vez de un GRUB roto después.

La fase 4 dejó de ser «todo o nada»: UEFI reintenta **NVRAM → `--no-nvram` →
`--removable`**; la vía BIOS se intenta siempre y, si UEFI ya quedó instalada,
un fallo de BIOS **no aborta** la instalación. Solo se lanza error si ambas
fallan, con el detalle de cada intento (nuevo helper `run_capture`).
`update-grub` sigue siendo obligatorio (sin `grub.cfg` no arranca).

### 7.2 El nombre de la app activa se veía a medias (una letra)

`apps/com.dylanos.activeapp/contents/ui/main.qml`: el applet declaraba
`Layout.minimumWidth: 16`, así que cuando el panel apretaba el espacio
(`appmenu` puede ser voraz) colapsaba hasta 16 px y, con `clip: true`, solo se
veía la primera letra. Ahora `Layout.minimumWidth: Layout.preferredWidth`: el
título nunca se encoge por debajo de lo que pide.

### 7.3 Dock inferior: apps fijadas

`themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js`.
Orden pedido y aplicado: **explorador de archivos** (`org.kde.dolphin.desktop`),
**Firefox** (`firefox-esr.desktop`), **VSCodium** (`codium.desktop`),
**App Center** (`dylanos-app-center.desktop`), **Ajustes DylanOS**
(`org.dylanos.settings.desktop`) y **Calculadora** (`org.dylanos.calculator.desktop`).
Se quitan `korganizer` y `konsole`.

### 7.4 App Center: logo de dos franjas

Definición de diseño pedida: fondo partido en dos franjas — **izquierda roja**
(`#DC143C`) y **derecha negra** (`#0A0A0A`) — con el logotipo de DylanOS
centrado. Se regeneró `apps/dylanos-app-center/icons/dylanos-app-center.png`
(512×512, esquinas redondeadas, generado desde `branding/logo.png` con un
contorno blanco suave para que el logo se lea sobre la franja roja) y el
lanzador vuelve a usar `Icon=dylanos-app-center`.

### 7.5 Instalador con botones de menú

`installer/dylanos-installer/native/main.py`: la ventana ya **no** abre a
pantalla completa. Abre como ventana normal con la **barra de título del
sistema** → minimizar, maximizar/ajustar tamaño, cerrar y redimensionar
(mínimo 900×600, por defecto 1180×780). `--fullscreen` queda como opcional de
quiosco. La barrita decorativa con botones «falsos» de la interfaz React se
oculta tras la carga para no duplicar controles; la salida con confirmación
sigue disponible con el botón «Cancelar» de cada pantalla.

### 7.6 Pruebas nuevas

- `scripts/tests/test_installer_backend.py` → `GrubRobustnessTest`
  (`run_capture`, rbind de `/sys`, partición BIOS boot, reintentos UEFI).
- `scripts/tests/test_staging.py` → ancho mínimo del applet de app activa y
  ventana del instalador con `--fullscreen` opcional.
- `scripts/tests/test_desktop.py` → las 6 apps fijadas del dock, en orden y
  sin extras (`pins.length === 6`).
- `scripts/tests/test_app_center.py` → `Icon=dylanos-app-center`.
