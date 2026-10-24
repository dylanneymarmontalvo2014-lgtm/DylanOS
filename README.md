# DylanOS Alpha

<p align="center">
	<img src="branding/logo.svg" alt="Logotipo de DylanOS" width="112">
</p>

<p align="center">
	<strong>Una distribución Linux basada en Debian Live y KDE Plasma.</strong><br>
	Debian Stable · amd64 · versión Alpha
</p>

<p align="center">
	<a href="docs/install.md">Probar e instalar</a> ·
	<a href="docs/build.md">Construir</a> ·
	<a href="docs/architecture.md">Arquitectura</a> ·
	<a href="docs/roadmap.md">Roadmap</a> ·
	<a href="docs/contributing.md">Contribuir</a>
</p>

> [!CAUTION]
> DylanOS está en fase Alpha. La configuración de Calamares y un arranque de prueba no certifican una instalación completa ni compatibilidad con hardware. Prueba en una máquina virtual y respalda tus datos antes de instalar.

## Qué incluye

DylanOS usa Debian Live para construir una imagen `amd64` con KDE Plasma, SDDM, GRUB, Plymouth y Calamares. El repositorio añade configuraciones y recursos propios, y tres utilidades locales: diagnóstico (`dylanos-info`), bienvenida (`dylanos-welcome`) y aplicación manual del wallpaper (`dylanos-wallpaper`).

Las listas de paquetes están separadas en `default`, `development`, `gaming` e `iot`, pero **las cuatro se incluyen en cada build actual**; todavía no son perfiles seleccionables. La apariencia se apoya en Breeze y en los temas/configuraciones de este repositorio. La [guía de identidad visual](docs/desktop.md) documenta los colores presentes en esos recursos.

La presencia de estos componentes en el código no significa que todas las funciones se hayan validado en una ISO. Consulta [estado del proyecto](docs/status.md) y [alcance de las pruebas](docs/testing.md).

## Construir desde Debian o Ubuntu

Se necesita `amd64`, conexión a Internet y privilegios de administrador para las operaciones de Debian Live. Instala las herramientas requeridas y construye desde la raíz del checkout:

```bash
sudo ./install-deps.sh
sudo scripts/build.sh
```

El script de dependencias usa APT. La ISO y los archivos de trabajo quedan en `build/live-build/`. Puedes cambiar la suite o el directorio de build mediante `DYLANOS_SUITE` y `DYLANOS_BUILD_DIR`; los detalles están en [Construcción](docs/build.md).

## Construir con Docker

En un host Linux `amd64` con Docker Engine, construye el contenedor y ejecuta el constructor con el checkout montado:

```bash
docker build --tag dylanos-builder .
docker run --rm --privileged \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  dylanos-builder
```

El contenedor necesita modo privilegiado para las operaciones de Debian Live. Usa este método solo con código de confianza. Los archivos de build pueden quedar propiedad de `root`.

## Comprobar cambios y probar una ISO

Las pruebas estáticas no construyen ni arrancan una ISO:

```bash
scripts/test.sh
```

ShellCheck es una comprobación adicional (`shellcheck --severity=warning install-deps.sh scripts/*.sh`). Para el smoke test de BIOS y UEFI, primero construye una imagen con la consola serial activada y luego prueba el archivo generado:

```bash
sudo env DYLANOS_SERIAL_CONSOLE=1 scripts/build.sh
iso="$(find build/live-build -maxdepth 1 -type f -name '*.iso' -print -quit)"
scripts/test-iso.sh "$iso"
```

Se requieren `xorriso`, `squashfs-tools`, `qemu-system-x86_64` y firmware OVMF. El smoke test espera que el sistema llegue a SDDM; **no completa la instalación de Calamares**. Revisa [Pruebas y alcance de CI](docs/testing.md).

## Obtener una ISO

Consulta la [página de GitHub Releases](https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS/releases). Una Release de producción con etiqueta `v*` adjunta la ISO amd64 y su checksum SHA-256. Sigue [la guía de descarga y prueba](docs/install.md) y verifica el checksum antes de iniciar.

## Documentación

- [Descargar y probar DylanOS](docs/install.md)
- [Construir DylanOS](docs/build.md)
- [Arquitectura](docs/architecture.md)
- [Identidad visual y escritorio](docs/desktop.md)
- [Herramientas incluidas](docs/commands.md)
- [Pruebas y alcance de CI](docs/testing.md)
- [Estado del proyecto](docs/status.md)
- [Roadmap](docs/roadmap.md)
- [Licencia](LICENSE)
