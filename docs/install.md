# Instalación y pruebas de DylanOS

Esta guía recoge el proceso de arranque, instalación y validación del sistema tal como está integrado en el repositorio actual de DylanOS Crimson.

## Requisitos

Consulta la [matriz detallada de hosts de compilación](build-hosts.md) para sistemas compatibles, rutas de compilación, confirmación de cambios y límites.

- Host `x86_64`/`amd64`. El modo nativo usa Debian/Ubuntu; el modo Docker requiere Linux, Docker Engine y Compose v2. El builder Docker necesita modo privilegiado para preparar el `chroot`.
- Al menos 25 GB de espacio libre para la imagen y el chroot.
- Acceso a `sudo` solo si la preparación necesita privilegios y no se ejecuta como root.
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

Para medir el arranque desde CI o un host con QEMU y xorriso instalados:

```bash
bash scripts/test-boot-qemu.sh
```

La prueba usa el kernel e initramfs de la ISO, captura la consola serial y
registra el tiempo desde el inicio del kernel hasta `graphical.target` y el
servicio SDDM. Es una medida del arranque live hasta el servicio de login; no
certifica por sí sola que el greeter se haya renderizado o que una sesión haya
terminado de cargar. El límite por defecto es 420 segundos y se puede cambiar
con `DYLANOS_QEMU_BOOT_TIMEOUT`.

## Primer uso del escritorio

Tras iniciar la sesión live, abre el instalador solo si vas a instalar en una VM o en un disco elegido deliberadamente. Para explorar el sistema sin instalar: el Workspace está en el menú; el buscador Spotlight abre con `Ctrl+Espacio`; el Dashboard está en el escritorio; y el Centro de Control se abre desde su icono en la barra superior. El comando `about` muestra los mantenedores registrados.

La [guía de uso y estado](guia-de-uso.md) enumera las apps, comandos, widgets, perfiles y límites conocidos (incluidos controles que aún son visuales y filtros de búsqueda incompletos). No trates los previews ni animaciones de fallback como prueba de operación real.

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

## Publicación por etiqueta de versión

Al crear una etiqueta válida `vMAJOR.MINOR.PATCH` (opcionalmente con sufijo
`-rc.1`), el workflow de release ejecuta las comprobaciones del proyecto,
construye el sistema, crea `DylanOS-MAJOR.MINOR.PATCH-amd64.iso`, valida el
checksum/estructura y hace el smoke-test de arranque live en QEMU. Solo después
publica una GitHub Release con la ISO y su `.sha256`. La versión se refleja en
`/etc/os-release`, `/etc/dylanos-release`, el nombre ISO, `.disk/info` y el
menú GRUB. Un fallo en cualquier prueba previa bloquea la publicación.

La etiqueta de release debe apuntar al commit que se quiere publicar; una
validación satisfactoria no acredita una instalación en disco o una sesión
gráfica visual, que requieren QA aparte. Los builds manuales conservan
`1.0-beta` como valor por defecto; para producir otro artefacto local, usa
`DYLANOS_VERSION=2.4.1 bash scripts/build.sh --version=2.4.1` y después
`sudo DYLANOS_VERSION=2.4.1 bash scripts/iso.sh 2.4.1`.

## Preparar dependencias y validar

Desde la raíz del repo, ejecuta `./init.sh` (o `bash init.sh`). Los puntos de entrada `init.sh`, `scripts/build.sh`, `scripts/check.sh`, `scripts/test-build-host.sh`, `scripts/iso.sh` y `scripts/test.sh` están marcados como ejecutables en Git. Debian/Ubuntu usan dependencias nativas; los demás Linux amd64 usan el builder Docker. Si falta Docker/Compose v2, la instalación automática se ofrece solo en Arch y derivados, Fedora, RHEL/CentOS/Rocky/AlmaLinux, openSUSE y Alpine. En otros Linux configura el engine y Compose v2 manualmente. Se acepta el plugin `docker compose` o el ejecutable standalone `docker-compose` de versión 2; Compose v1 no sirve. El script muestra el plan y solicita confirmación antes de instalar paquetes, configurar repositorios, iniciar servicios o construir la imagen. `--yes` omite el diálogo, así que úsalo solo para cambios previamente aprobados.

```bash
bash init.sh
```

En Debian/Ubuntu, corre las comprobaciones con el entorno Python creado por el inicializador:

```bash
make check PYTHON=.venv/bin/python
```

En otras distribuciones Linux, ejecuta la QA dentro del builder con el Compose que tengas instalado:

```bash
docker compose run --rm builder make check
# O si usas Compose v2 standalone:
docker-compose run --rm builder make check
```

Este comando valida la base del proyecto con sintaxis, comprobaciones de shell y validaciones de staging/QML según el estado actual del repo. La detección de distribución se puede probar sin privilegios con `bash scripts/test-build-host.sh`; ese test no instala Docker ni prueba los repositorios de paquetes.

## Construcción del ISO

```bash
./scripts/build.sh
bash scripts/iso.sh
```

El proceso de build usa `scripts/build.sh` y `scripts/stage.py` para preparar el contenido del sistema, con salida en `work/chroot` y `work/iso`.
El frontend del instalador se construye en una copia temporal aislada: `npm ci` no opera sobre `installer/dylanos-installer/node_modules` del checkout, que puede contener enlaces heredados con propietario root de compilaciones antiguas. El `dist` resultante también se guarda temporalmente y se copia al chroot solo tras validar que `index.html` existe y no está vacío. No es necesario borrar ni cambiar propietario a `node_modules` del repositorio.
No ejecutes `build.sh` con `sudo`: el script solicita privilegios solo cuando entra al
chroot. Si `work/chroot` ya existe, continúa de forma explícita con
`./scripts/build.sh --resume`; nunca se sobrescribe automáticamente.

## Límites de compatibilidad y verificación

La matriz describe los caminos implementados, no certifica una compilación de extremo a extremo en cada distro. La instalación de paquetes depende de la versión del sistema, repositorios configurados, disponibilidad de los paquetes y de que Docker Engine y un Compose v2 (plugin o standalone) funcionen. El script comprueba que Compose v2 quede disponible tras la instalación, pero no valida todas las versiones de Docker ni todas las combinaciones de kernel/runtime. `init.sh` no se ejecuta en Windows o macOS; Docker Desktop puede ser una alternativa manual, no un soporte nativo verificado. No hay soporte para hosts no amd64. Los tests del repositorio verifican la sintaxis y la clasificación de hosts en mocks/casos puros, no descargan repositorios ni arrancan el builder en cada sistema listado.

La lista de archivos y el comportamiento de cada cambio de compatibilidad se documentan en [build-hosts.md](build-hosts.md).

## Documentación relacionada

- [architecture.md](architecture.md)
- [roadmap.md](roadmap.md)
- [contributing.md](contributing.md)

### Si aparece «Permiso denegado» en `work/build.lock`

El build y la generación de ISO comparten un lock en `${TMPDIR:-/tmp}`, fuera
del checkout. El archivo se crea legible para el usuario que compila y se abre
en modo lectura para que siga funcionando si lo creó la fase root; el directorio `work/`
ya no necesita `work/build.lock`. Antes de elevar privilegios, `build.sh`
verifica que `work/` pertenezca al usuario y, si es necesario, corrige solo el
propietario de ese directorio; no cambia recursivamente el chroot ni sus
artefactos. Actualiza el checkout antes de volver a ejecutar
`./scripts/build.sh`.

### Store vacía o Explorer no abre

La Store necesita el índice AppStream de los repositorios para convertir las
entradas editoriales en aplicaciones instalables. El build ahora ejecuta
`appstreamcli refresh-cache --force` antes de quitar las listas APT, conservando
la caché usada por libdiscover. DylanOS Explorer importa `QtQuick.Shapes`; el
paquete QML `qml6-module-qtquick-shapes` debe estar presente en el sistema
instalado aunque no sea dependencia del binario ELF.
