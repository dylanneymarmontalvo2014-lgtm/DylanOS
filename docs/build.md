# Construir y publicar DylanOS

DylanOS usa Debian Live para preparar una ISO híbrida de arranque para `amd64`. El script principal es `scripts/build.sh`; `scripts/iso.sh` es un alias.

## Requisitos del anfitrión

En Debian o Ubuntu, instala las dependencias incluidas en el proyecto:

```bash
sudo ./install-deps.sh
```

El script instala `live-build`, `debootstrap`, `squashfs-tools` y `xorriso` mediante APT. La construcción requiere conexión a Internet y permisos de root para las operaciones de montaje y chroot de Debian Live.

## Construir directamente

Desde la raíz del repositorio:

```bash
sudo scripts/build.sh
```

El constructor usa Debian Stable, arquitectura amd64 y las áreas `main`, `contrib`, `non-free` y `non-free-firmware`. Guarda la configuración y los resultados en `build/live-build/`. Se pueden cambiar suite o directorio de trabajo:

```bash
sudo DYLANOS_SUITE=stable DYLANOS_BUILD_DIR=/ruta/al/build scripts/build.sh
```

Las cuatro listas bajo `packages/` se copian a la imagen en todas las compilaciones actuales; no son perfiles opcionales. Los recursos y las configuraciones de `branding/`, `configs/`, `themes/` e `installer/calamares/` se incorporan durante la preparación.

## Construir con Docker

Construir la imagen del constructor no construye la ISO:

```bash
docker build --tag dylanos-builder .
```

Después ejecuta el contenedor con el repositorio montado:

```bash
docker run --rm --privileged \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  dylanos-builder
```

`--privileged` es necesario para las operaciones de Debian Live. Los artefactos aparecen en `build/live-build/`; no se crea un segundo script de construcción.

## Validar cambios y una ISO

Las pruebas estáticas se ejecutan desde la raíz:

```bash
scripts/test.sh
shellcheck --severity=warning install-deps.sh scripts/*.sh
```

Para revisar una ISO ya construida, instala QEMU, OVMF, xorriso y squashfs-tools y ejecuta:

```bash
scripts/test-iso.sh build/live-build/ruta-a-la-iso.iso
```

El test inspecciona el catálogo de arranque, comprueba archivos del sistema live y arranca la imagen en BIOS y UEFI esperando que SDDM inicie. El ISO debe haberse construido con consola serial para que el test detecte el marcador de SDDM:

```bash
sudo env DYLANOS_SERIAL_CONSOLE=1 scripts/build.sh
iso="$(find build/live-build -maxdepth 1 -type f -name '*.iso' -print -quit)"
scripts/test-iso.sh "$iso"
```

El workflow automático de QEMU se retiró porque la construcción completa hacía demasiado lenta la CI de cada PR; estas pruebas quedan disponibles para ejecución manual. La consola serial es solo para smoke tests y no se habilita en la ISO de producción. Un resultado positivo no completa ni valida la instalación de Calamares.

Consulta [Pruebas y alcance de CI](testing.md) para conocer los límites de cada verificación.

## Publicar una versión

El workflow `Build and publish release ISO` es el único que publica Releases automáticamente. Al enviar al repositorio original una etiqueta que empiece con `v`, por ejemplo `v0.1.0`, compila la ISO de producción, crea la Release y adjunta el archivo amd64 y su checksum SHA-256:

```bash
git tag v0.1.0
git push origin v0.1.0
```

El workflow manual `Build ISO artifact (manual)` construye y sube un artefacto descargable de GitHub Actions; no crea una Release pública.

## Estado y precauciones

No se debe anunciar una ISO como probada, instalable o lista para uso diario hasta revisar los resultados del build, el arranque y una instalación de extremo a extremo en una VM. Las pruebas QEMU de arranque y las pruebas de instalación son etapas diferentes.
