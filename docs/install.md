# Instalación y pruebas de DylanOS

Esta guía recoge el proceso de arranque, instalación y validación del sistema tal como está integrado en el repositorio actual de DylanOS Crimson.

## Requisitos

- Para construir la ISO de forma nativa: host Debian/Ubuntu amd64. Como alternativa, usa Docker Engine y Compose v2 en un host Linux amd64; el builder requiere modo privilegiado (ver [README](../README.md#construir-con-docker)).
- Al menos 25 GB de espacio libre para la imagen y el chroot.
- Acceso a `sudo`.
- Máquina virtual recomendada con 4 GB de RAM, 2 CPU y disco virtual de 32 GB para pruebas iniciales.

## Arranque live en máquina virtual

Para probar la ISO sin tocar el disco físico:

```bash
bash scripts/test.sh
qemu-img create -f qcow2 work/dylanos-test.qcow2 32G
qemu-system-x86_64 -enable-kvm -m 4096 -smp 2 \
  -cdrom DylanOS-1.0-beta-amd64.iso -boot d \
  -drive file=work/dylanos-test.qcow2,format=qcow2 -vga virtio
```

Si tu sistema no expone `/dev/kvm`, elimina `-enable-kvm`. La emulación será más lenta, pero funciona.

La sesión live debe arrancar con el entorno de DylanOS y mostrar la experiencia visual Crimson con el escritorio Plasma customizado. El instalador puede lanzarse desde el escritorio o desde el acceso del menú del sistema.

## Instalación desde el instalador propio

El flujo actual del proyecto usa el instalador incluido en `installer/dylanos-installer` y no depende de Calamares. Antes de confirmar la instalación, revisa:

- tipo de disco
- particionado elegido
- idioma y teclado
- nombre de usuario y contraseña
- arranque UEFI/BIOS del sistema

> La instalación afecta el disco destino y debe hacerse con precaución. Para la primera prueba, se recomienda una máquina virtual o un disco externo no crítico.

## Validación funcional mínima

1. Arrancar la ISO en BIOS y UEFI.
2. Verificar el escritorio, panel, tema y fondo Crimson.
3. Comprobar la apertura de `dylanos-explorer`, `dylanos-store`, workspace y app center.
4. Probar la creación, renombrado y borrado de archivos.
5. Verificar notas y persistencia del panel de trabajo.
6. Comprobar la instalación de software desde DylanOS Store.
7. Instalar en un disco virtual y reiniciar sin la ISO.
8. Repetir prueba de audio, Wi‑Fi, suspensión y pantalla en hardware real.

## Validación local del repositorio

Prepara las dependencias con el inicializador; revisa la lista y confirma solo si quieres instalarla:

```bash
bash init.sh
```

Si cancelas, no instala paquetes ni configura NodeSource. Al confirmar, también crea o actualiza `.venv` con las dependencias Python de desarrollo. Luego ejecuta las comprobaciones:

```bash
make check PYTHON=.venv/bin/python
```

Este comando valida la base del proyecto con sintaxis, comprobaciones de shell y validaciones de staging/QML según el estado actual del repo.

## Construcción del ISO

```bash
bash scripts/build.sh
bash scripts/iso.sh
```

El proceso de build usa `scripts/build.sh` y `scripts/stage.py` para preparar el contenido del sistema, con salida en `work/chroot` y `work/iso`.

## Documentación relacionada

- [architecture.md](architecture.md)
- [roadmap.md](roadmap.md)
- [contributing.md](contributing.md)
