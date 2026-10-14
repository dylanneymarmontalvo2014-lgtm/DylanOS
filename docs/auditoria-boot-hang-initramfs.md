# Auditoría: Cuelgue en arranque de la ISO de DylanOS (logo + spinner congelado)

**Fecha de auditoría:** 2026-10-11 (00:00–01:00)
**Rama:** `development` (HEAD: `80b8e7f`)
**Artefacto auditado:** `DylanOS-1.0-beta-amd64.iso` (construida 2026-10-10 23:32 desde `work/chroot` + `work/iso`)
**Método:** reproducción en QEMU (TCG) con consola serial + inspección estática del squashfs, initramfs y unidades systemd del chroot.

---

## 1. Resumen ejecutivo — LA CAUSA RAÍZ

**La ISO nunca ha arrancado.** El kernel entra en pánico (`Kernel panic - not syncing: Attempted to kill init!`) durante la fase initramfs, porque el `filesystem.squashfs` **no contiene los directorios `/dev`, `/proc`, `/sys`, `/run` y `/tmp`**.

El culpable es una línea de `scripts/iso.sh` que excluye esos directorios **completos** del squashfs:

```bash
# scripts/iso.sh, línea 21 (introducida en fc4c0bb, 2026-10-03)
sudo mksquashfs "$CHROOT" "$IMAGE/live/filesystem.squashfs.new" \
    -noappend -comp zstd -Xcompression-level 15 -processors 2 \
    -e dev proc sys run tmp          # ← BUG: elimina los directorios enteros
```

**El "círculo que gira y se detiene" que se ve en pantalla ES un kernel panic congelado debajo del splash de Plymouth.** Plymouth arranca en el initramfs, anima el spinner mientras live-boot monta el squashfs (~40–60 s) y, cuando `/init` muere, TODO el sistema se congela — incluida la animación. Como el GRUB de la ISO arranca con `quiet splash` y `timeout=0` sin opciones de diagnóstico, el panic queda completamente invisible para el usuario.

Ocurre **igual en QEMU y en hardware físico** porque es un fallo lógico del contenido de la ISO, no un problema de drivers, GPU, Plymouth ni SDDM.

---

## 2. Cadena causal completa (evidencia serial capturada)

Reproducción: QEMU 8.2.2 (TCG, `-cpu max`, 3 GB RAM) con kernel/initrd extraídos de la propia ISO y salida serial a archivo (`qemu-audit/bootB-serial.log`). El log muestra, en orden:

```
Begin: Mounting "/run/live/medium/live/filesystem.squashfs" on
        "/run/live/rootfs/filesystem.squashfs" via "/dev/loop0" ... done.
[  38.6] evm: overlay not supported
done.                                          ← el overlay SÍ se monta
Begin: Configuring fstab ... done.
Begin: Preconfiguring networking ... done.
Begin: Running /scripts/live-bottom ... done.
Begin: Running /scripts/init-bottom ... done.
mount: /root/dev:  mount point does not exist.   ← /root/dev NO EXISTE
mount: /root/run:  mount point does not exist.   ← /root/run NO EXISTE
mount: /root/sys:  mount point does not exist.   ← /root/sys NO EXISTE
mount: /root/proc: mount point does not exist.   ← /root/proc NO EXISTE
/init: line 340: can't open /root/dev/console: no such file
[  47.9] Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000100
```

El `/init` de initramfs-tools (extraído del initrd de la ISO) en sus líneas finales:

```sh
# Move virtual filesystems over to the real filesystem
mount -n -o move /sys ${rootmnt}/sys      # falla: ${rootmnt}/sys no existe
mount -n -o move /proc ${rootmnt}/proc    # falla: ${rootmnt}/proc no existe

# Chain to real filesystem
exec run-init ${drop_caps} "${rootmnt}" "${init}" "$@" \
     <"${rootmnt}/dev/console" >"${rootmnt}/dev/console" 2>&1
     # ↑ LÍNEA 340: la redirección falla porque /root/dev/console no existe.
     #   bash aborta el exec con exit 1 → PID 1 muere → KERNEL PANIC.
```

**Prueba definitiva contra el artefacto** — listado del directorio raíz del squashfs real de la ISO (`unsquashfs -ls`):

```
Presentes:   /bin /boot /etc /home /initrd.img /lib /media /mnt /opt
             /root /sbin /srv /usr /var /vmlinuz
AUSENTES:    /dev /proc /sys /run /tmp      ← el bug, en carne viva
```

---

## 3. Por qué los fixes anteriores no funcionaron

El fallo ocurre **antes de que systemd arranque siquiera**. Todo lo que se tocó en commits anteriores son etapas posteriores del arranque que jamás se alcanzaron:

| Commit | Qué intentó | Por qué no pudo funcionar |
|---|---|---|
| `94faffc` | "Corregir cuelgue de Plymouth", usuario live, GRUB de 3 entradas | El splash se congelaba por el panic, no por Plymouth. Luego `573264f` además eliminó las entradas de diagnóstico del GRUB. |
| `b9b4612` | Forzar sesión X11 (`plasmax11`) en SDDM, permisos de `/home/dylan`, parchear hook `0085-sddm` de live-config | SDDM nunca llegó a ejecutarse. (Estos cambios siguen siendo correctos para cuando el boot pase del initramfs.) |
| `80b8e7f` | Spinner animado + drop-in de SDDM con `ExecStartPre=plymouth quit` + habilitar sddm en `graphical.target.wants` | Idem: systemd nunca llegó a `graphical.target`. |

El commit que introdujo el bug es **`fc4c0bb` (2026-10-03)** — verificado con `git log -S '-e dev proc sys run tmp'`. Desde entonces, toda ISO generada con `scripts/iso.sh` está rota de la misma forma.

Hallazgo colateral del mismo commit: la línea era "correcta en apariencia" (los chroots no deben incluir mounts de `dev/proc/sys`), pero la sintaxis correcta excluye el **contenido**, no los **directorios**. Debian live-build no excluye esos directorios en absoluto: los desmonta antes de `mksquashfs` y los directorios vacíos entran en la imagen — el runtime los necesita como puntos de montaje.

---

## 4. El fix exacto (un solo cambio en `scripts/iso.sh`)

Cambiar la invocación de `mksquashfs` para excluir solo el **contenido** de los directorios virtuales, conservando los directorios vacíos:

```diff
-    sudo mksquashfs "$CHROOT" "$IMAGE/live/filesystem.squashfs.new" -noappend -comp zstd -Xcompression-level 15 -processors 2 -e dev proc sys run tmp
+    sudo mksquashfs "$CHROOT" "$IMAGE/live/filesystem.squashfs.new" -noappend -comp zstd -Xcompression-level 15 -processors 2 -wildcards -e 'dev/*' 'proc/*' 'sys/*' 'run/*' 'tmp/*'
```

Notas:
- `-wildcards` es obligatorio para que mksquashfs interprete los patrones `dir/*`.
- `'dev/*'` excluye recursivamente el contenido de `dev` pero **conserva el directorio** `dev` (vacío) en la imagen. Igual para los demás.
- `run` y `tmp` no se montan durante el build; excluir su contenido evita empaquetar residuos del build.
- **NO añadir** `boot` a las exclusiones: el comentario de `iso.sh` lo explica (el sistema instalado necesita su propio kernel en `/boot`).

Tras el cambio hay que regenerar la ISO completa:

```bash
sudo bash scripts/iso.sh
```

(`mksquashfs` con zstd-15 y `-processors 2` tarda; es un proceso largo, dejarlo correr en foreground o con `nohup`.)

**Este fix ya está aplicado en el árbol de trabajo** (ver §7, estado).

---

## 5. Plan de verificación (para el LLM que continúe)

1. **Rebuild de la ISO** con el fix de §4 (`sudo bash scripts/iso.sh`).
2. **Boot de verificación con serial** (reproduce el método de esta auditoría, sin tocar la ISO):
   ```bash
   DIR=$(mktemp -d)
   qemu-system-x86_64 -machine pc,accel=tcg -cpu max -m 3072 -smp 2 \
     -kernel work/iso/live/vmlinuz -initrd work/iso/live/initrd.img \
     -append 'boot=live components hostname=dylanos username=dylan user-fullname="DylanOS Live" locales=es_ES.UTF-8 keyboard-layouts=latam plymouth.enable=0 console=tty0 console=ttyS0 systemd.show_status=1' \
     -cdrom DylanOS-1.0-beta-amd64.iso \
     -vga virtio -display none -usb -device usb-tablet \
     -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
     -chardev socket,id=ser0,path=$DIR/serial.sock,server=on,wait=off,logfile=$DIR/serial.log \
     -serial chardev:ser0 -no-reboot
   ```
   - **Éxito esperado:** ya NO aparece `Kernel panic`. Deben verse `Reached target Basic System/Multi-User/Graphical`, el arranque de `sddm.service` y (con la VGA visible) el greeter/sesión.
   - Con serial se puede además iniciar sesión como `dylan` (contraseña vacía o `live`, ver §6-4) y ejecutar `journalctl -b`, `systemctl status sddm`, etc.
3. **Boot normal (fidelidad)**: `./test_QEMU` sin parámetros — debe aparecer SDDM/Calamares en lugar del spinner congelado.
4. **USB en hardware físico** (el fallo era idéntico; el fix también debe serlo).

---

## 6. Hallazgos secundarios (no bloquean el boot, pero conviene saberlos)

1. **El chroot se editó a mano después del último `stage.py`** — el `override.conf` de SDDM en `work/chroot` (mtime 2026-10-10 21:56) contiene `After=plymouth-quit.service`, mientras que `scripts/stage.py` en HEAD escribe `After=plymouth-start.service`. La ISO actual contiene el estado manual, no el del repo. **Regla de oro: nunca editar `work/chroot` a mano; siempre regenerar con `sudo python3 scripts/stage.py work/chroot`** (es idempotente) y después `iso.sh`.
2. **GRUB sin salida de diagnóstico**: `573264f` dejó `set timeout=0` con una única entrada `quiet splash`. El doc `docs/solucion-boot-hang-y-grub.md` describía 3 entradas (normal / safe graphics `nomodeset` / verbose sin `quiet splash` con `systemd.debug_shell=1`) que fueron eliminadas. **Restaurarlas** — sin ellas, cualquier fallo de boot futuro vuelve a ser invisible. Mínimo recomendado: una entrada "Modo seguro/verbose".
3. **`UMASK=0077` en `/etc/initramfs-tools/conf.d/dylanos-permissions`** (stage.py): endurece los permisos de los archivos dentro del initrd. Es benigno en runtime (todo corre como root), pero documentado aquí para que no sorprenda en auditorías futuras.
4. **Contraseña del usuario live**: stage.py pre-crea `dylan` con password vacío; live-config (`username=dylan` en cmdline) puede reconfigurarla a `live` según los hooks presentes. Para autologin de SDDM es irrelevante, pero tenerlo presente para login por serial.
5. **Residuos menores en el squashfs**: los symlinks `/initrd.img`, `/initrd.img.old`, `/vmlinuz`, `/vmlinuz.old` quedan empaquetados en la raíz de la imagen (herencia de `/boot` dentro del chroot). Inofensivos; el instalador de Calamares los sobreescribe en el sistema instalado.
6. **`evm: overlay not supported`** en el log serial: mensaje informativo del kernel sobre xattrs EVM sobre overlayfs. NO es el problema; no perseguirlo.
7. El hook `0085-sddm` de live-config **sobreescribe `/etc/sddm.conf` completo** en cada arranque, pero `10-dylanos.conf` (conf.d) prevalece en las claves que define. Configuración actual coherente.

---

## 7. Estado al cierre de esta auditoría

- ✅ Causa raíz identificada y **verificada por reproducción** (kernel panic a los ~48 s en initramfs). Log serial completo preservado en `artifacts/boot-panic-serial-evidence.log` (509 líneas, ISO rota de referencia).
- ✅ Fix mínimo aplicado en `scripts/iso.sh` (excluir contenido, no directorios).
- ⏳ **Pendiente por el siguiente ingeniero/LLM:** regenerar ISO (`sudo bash scripts/iso.sh`), ejecutar la verificación de §5 y, si aparece un nuevo síntoma más adelante en el arranque (SDDM/sesión X11), tratarlo como problema NUEVO — los hallazgos de §6-1 y los fixes de `b9b4612`/`80b8e7f` son entonces relevantes y ya están en el repo.
- El directorio `work/` contiene `build.lock` (lock vacío, sin proceso activo de build) y `build-complete` — el chroot está íntegro y solo falta re-empaquetar.

## 8. Comandos de depuración útiles (recetas probadas)

```bash
# Listar contenido de un initramfs
lsinitramfs work/iso/live/initrd.img | grep -i plymouth

# Extraer /init de un initramfs Debian (zstd/cpio multi-segment)
unmkinitramfs work/iso/live/initrd.img /tmp/initrd-x && less /tmp/initrd-x/main/init

# Listar directorio raíz de un squashfs
unsquashfs -ls work/iso/live/filesystem.squashfs | grep -oE '^squashfs-root/[a-z.]+/?$' | sort -u

# Boot de diagnóstico con serial (ver §5) — captura TODO el arranque en texto
```

---

*Auditoría realizada siguiendo el método de debugging sistemático (fase 1: causa raíz con evidencia, antes de cualquier fix). Cualquier LLM que continúe: empieza por §7 y §5.*
