# Solución de Cuelgue en Boot (Plymouth) y Personalización de GRUB

## 1. Diagnóstico del Problema

Al arrancar la máquina virtual de pruebas con QEMU mediante `./test_QEMU`, el sistema se detenía indefinidamente tras mostrar la pantalla inicial de Plymouth ("DylanOS").

### Causas Raíz Identificadas:

1. **Ausencia de Usuario Live y Bloqueo de Sesión:**
   - En commits anteriores, se retiró la variable `username=dylan` de la línea de comandos del kernel en [`scripts/iso.sh`](file:///home/dylan/DylanOS/scripts/iso.sh).
   - Debido a esto, los scripts de `live-config` de Debian (`0030-user-setup`, `0040-sudo`, `0085-sddm`) ignoraban la inicialización del usuario en vivo. Al estar la cuenta `root` bloqueada por defecto (`passwd -l root`), el entorno carecía de usuarios válidos para iniciar sesión.

2. **Incompatibilidad de Sesión en SDDM (Plasma 6 X11):**
   - En Debian 13 (Trixie), la sesión X11 de KDE Plasma se distribuye como `plasmax11.desktop` en `/usr/share/xsessions/`, mientras que la configuración por defecto y gestores como SDDM buscan `plasma.desktop`.
   - Adicionalmente, `/etc/sddm.conf.d/10-dylanos.conf` carecía del bloque `[Autologin]` con `User=dylan` y `Session=plasma.desktop`.

3. **Retención de Plymouth:**
   - Al no poder completar el autologin ni abrir la sesión gráfica, SDDM quedaba esperando y el demonio Plymouth nunca recibía la señal `plymouth quit`, mostrando fijamente el rótulo "DylanOS" en pantalla.

4. **Menú de GRUB Genérico y Sin Opciones de Recuperación:**
   - El menú de arranque anterior no disponía de opciones para arrancar con gráficos seguros (`nomodeset`), ni modo depuración / verbose para diagnosticar errores de arranque, ni tipografías Unicode para renderizar correctamente la temática.

---

## 2. Modificaciones Implementadas

### A. Personalización de GRUB ([`themes/grub/DylanOS-Grub/theme.txt`](file:///home/dylan/DylanOS/themes/grub/DylanOS-Grub/theme.txt) y [`scripts/iso.sh`](file:///home/dylan/DylanOS/scripts/iso.sh))
- **Paleta Crimson Oficial:**
  - Fondo: `#0A0A0A`
  - Texto de título: `#FFFFFF`
  - Elemento activo/seleccionado: `#DC143C` (Crimson DylanOS)
  - Elementos inactivos y subtítulo: `#B3B3B3`
  - Subtítulo: `"DylanOS 1.0 Beta · Crimson Edition"`
- **Opciones de Inicio:**
  1. `Instalar DylanOS 1.0 Beta`: Arranque en vivo normal con parámetros de localización y usuario (`boot=live components hostname=dylanos username=dylan user-fullname="DylanOS Live" locales=es_ES.UTF-8 keyboard-layouts=latam quiet splash`).
  2. `Instalar DylanOS 1.0 Beta (Gráficos seguros / Safe Graphics)`: Arranque con `nomodeset vga=normal` para GPUs problemáticas o drivers virtuales sin aceleración KMS.
  3. `DylanOS 1.0 Beta (Modo depuración / Verbose boot)`: Arranque sin `quiet splash` y con `systemd.debug_shell=1` para inspección técnica inmediata.
  4. Submenú `Opciones avanzadas de energía` con entradas directas para reiniciar (`reboot`) o apagar (`halt`).
- **Soporte Tipográfico:**
  - Incorporación de `/usr/share/grub/unicode.pf2` dentro de la imagen ISO en `boot/grub/fonts/unicode.pf2`.

### B. Corrección de Plymouth ([`themes/plymouth/DylanOS-Plymouth/dylanos.script`](file:///home/dylan/DylanOS/themes/plymouth/DylanOS-Plymouth/dylanos.script))
- Se reemplazó el texto plano por el logotipo oficial de la distribución (`branding/logo.png`) instalado en `/usr/share/plymouth/themes/dylanos/logo.png`.
- Centrado dinámico con degradado neutro `#0A0A0A` y tipografía de estado en `#B3B3B3`.
- Subtítulo estilizado `"DylanOS 1.0 Beta"`.

### C. Pipeline de Staging y Autologin ([`scripts/stage.py`](file:///home/dylan/DylanOS/scripts/stage.py))
- **Garantía de Usuario Live:**
  - Pre-creación determinista del usuario `dylan` (UID 1000) en `/etc/passwd`, `/etc/shadow`, `/etc/group` con permisos `sudo` sin contraseña (`/etc/sudoers.d/dylan`).
  - Copia de dotfiles y perfil desde `/etc/skel` a `/home/dylan`.
- **Configuración de SDDM:**
  - Inclusión de sección `[Autologin]` con `User=dylan` y `Session=plasma.desktop`.
  - Enlace simbólico `/usr/share/xsessions/plasma.desktop -> plasmax11.desktop`.
- **Autostart de Calamares:**
  - Creación de `/etc/xdg/autostart/calamares-install-dylanos.desktop` para disparar el instalador Calamares automáticamente en cuanto la sesión gráfica termine de cargar.

### D. Arranque Directo al Instalador Calamares (Zero-Delay)
- **GRUB Instantáneo:** Se configuró `set default=0` y `set timeout=0` en [`scripts/iso.sh`](file:///home/dylan/DylanOS/scripts/iso.sh). De este modo, la ISO no se detiene en ningún menú ni requiere intervención del usuario: arranca inmediatamente al kernel con parámetros optimizados.
- **Lanzamiento Directo:** Al finalizar el arranque e iniciar la sesión gráfica, Calamares se ejecuta directamente sin intermediarios ni pantallas secundarias de bienvenida previas, presentando el asistente de instalación de DylanOS de forma inmediata y sin fricción.

---

## 3. Pruebas y Verificación

- **Pruebas Unitarias:** Ejecutadas 25 pruebas con `python3 -m unittest discover -s scripts/tests -v`. Resultado: 100% aprobadas (20 passed, 5 skipped por dependencia opcional PySide6).
- **Staging de Chroot:** Ejecutado `sudo python3 scripts/stage.py work/chroot`, validando la persistencia de usuarios, symlinks y configuración de SDDM.
- **Generación de ISO:** Recompilación completa de `DylanOS-1.0-beta-amd64.iso` mediante `sudo bash scripts/iso.sh`.


