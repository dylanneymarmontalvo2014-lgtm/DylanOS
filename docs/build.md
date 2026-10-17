# Construir DylanOS

DylanOS usa Debian Live para generar una ISO híbrida de arranque para amd64.

## Dependencias del anfitrión

En Debian o Ubuntu, instala las herramientas de construcción incluidas en el proyecto:

```bash
sudo ./install-deps.sh
```

También puedes instalar manualmente `live-build`, `debootstrap`, `squashfs-tools` y `xorriso`. La construcción necesita privilegios de root y conexión a Internet para descargar los paquetes del sistema.

## Construir con Docker

El `Dockerfile` prepara el entorno de compilación; construir la imagen no genera todavía la ISO:

```bash
docker build --tag dylanos-builder .
```

Para ejecutar el `scripts/build.sh` existente y guardar los artefactos en `build/live-build/` del repositorio:

```bash
docker run --rm --privileged --volume "$PWD:/workspace" --workdir /workspace dylanos-builder
```

El contenedor necesita `--privileged` porque Debian Live usa operaciones de montaje y chroot durante la construcción. No se creó un segundo `build.sh`.

## Pruebas estáticas

Desde la raíz del repositorio:

```bash
scripts/test.sh
```

Estas pruebas comprueban la sintaxis de los scripts, las listas de paquetes, los SVG, los encabezados de los PNG y que las carpetas que antes tenían `.gitkeep` contengan archivos reales.

## Generar la ISO directamente en el anfitrión

```bash
sudo scripts/build.sh
```

El script usa Debian Stable y guarda la configuración de Debian Live y la ISO en `build/live-build/`. También puedes seleccionar otra suite o una ruta de trabajo distinta:

```bash
sudo DYLANOS_SUITE=stable DYLANOS_BUILD_DIR=/ruta/al/build scripts/build.sh
```

Las listas bajo `packages/` se convierten en listas de paquetes de Debian Live. Los recursos de `branding/`, `configs/`, `themes/` y `installer/calamares/` se copian a sus ubicaciones del sistema de destino durante la preparación.

## Alcance actual

La configuración prepara una ISO live con escritorio KDE, branding, listas de paquetes y configuración inicial de Calamares. La ISO no debe considerarse instalable o lista para distribuir hasta que se haya construido y probado el arranque y el flujo de instalación en una máquina virtual y en hardware compatible.
