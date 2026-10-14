# Instalación y pruebas de DylanOS 1.0 Beta

## Primero en una máquina virtual

Verifica el SHA-256 y usa una VM con 4 GB de RAM, 2 CPU y un disco virtual de 32 GB.
No uses tu disco físico para la primera prueba. La imagen ofrece arranque BIOS y
UEFI sin Secure Boot. No se anuncia soporte de Secure Boot hasta validarlo.

```sh
bash scripts/test.sh
qemu-img create -f qcow2 work/dylanos-test.qcow2 32G
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -cdrom DylanOS-1.0-beta-amd64.iso -boot d \
  -drive file=work/dylanos-test.qcow2,format=qcow2 -vga virtio
```

Sin `/dev/kvm`, quita `-enable-kvm`; la emulación será bastante más lenta.
Para UEFI usa una copia escribible de OVMF_VARS y OVMF_CODE de tu distribución.

Selecciona «DylanOS 1.0 Beta — Sesión live (probar o instalar)». El modo live
arranca el escritorio Plasma en X11 con el usuario `dylan`, creado por
live-config, con entrada automática. Si solicitas autenticación en la sesión
live, la contraseña predeterminada de live-config es `live`. Esta cuenta
temporal no sustituye al usuario que crearás en el instalador de DylanOS.

El instalador oficial aparece como ejecutable en el escritorio (`~/Desktop` y
`~/Escritorio`, porque el nombre de la carpeta depende del idioma) y en el menú
de aplicaciones. **No se abre solo**: la sesión live es un escritorio de vista
previa para que pruebes DylanOS y lances la instalación cuando quieras. Revisa
su resumen antes de confirmar el particionado del disco virtual.

## Comprobaciones de aceptación

1. Arrancar por BIOS y UEFI; comprobar el menú y el splash.
2. Verificar panel superior, menú global, ventanas, iconos y fondo con un usuario nuevo.
3. Abrir todas las apps propias desde el menú; probar claro y oscuro.
4. Crear/copiar/renombrar un archivo, enviarlo a papelera y recuperarlo en Dolphin.
5. Crear una nota, cerrar la app y comprobar que permanece al abrirla.
6. Crear proyectos Python/web/C++; abrirlos en editor/terminal y ejecutarlos.
7. Probar DylanOS Store, actualizaciones, Wi-Fi, Bluetooth, audio, suspensión y pantalla.
8. Instalar en el disco virtual, reiniciar sin la ISO y verificar la cuenta creada.
9. Repetir red/audio/suspensión en los equipos físicos que se vayan a soportar.

Una carga QML o un checksum correcto no sustituyen estas pruebas.

## Desarrollo local

`bash scripts/check.sh` comprueba sintaxis, ShellCheck, parser de paquetes,
operaciones de datos, puente Qt, calculadora y persistencia desde QML, staging y
carga de cada pantalla. Define `DYLANOS_PYTHON` para usar tu entorno virtual.

```sh
python3 scripts/stage.py /tmp/dylanos-stage
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  .venv/bin/python apps/workspace/main.py --page dev --screenshot /tmp/desarrollo.png
```

Para regenerar los fondos y SVG propios: `.venv/bin/python scripts/lib/generate-theme.py`.
La compilación se puede retomar con `bash scripts/build.sh --resume`.
