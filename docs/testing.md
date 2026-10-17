# Pruebas y alcance de CI

Cada prueba cubre una parte del proyecto. Un resultado satisfactorio no debe interpretarse como prueba de una fase que el test no ejecuta.

## Comprobaciones locales

```bash
scripts/test.sh
shellcheck --severity=warning install-deps.sh scripts/*.sh
```

`scripts/test.sh` revisa sintaxis de scripts, opciones de ayuda y error de las utilidades, el comportamiento de autoinicio de bienvenida con un `kdialog` de prueba, listas de paquetes, recursos SVG/PNG y estructura de archivos. **No construye una ISO ni arranca una VM.**

ShellCheck analiza los scripts de shell con advertencias como nivel mínimo; la acción correspondiente usa la misma severidad.

## Flujos de GitHub Actions

| Workflow | Qué comprueba | Qué no demuestra |
|---|---|---|
| `Build validation` | Pruebas estáticas, resolución simulada de paquetes en Debian y construcción de la imagen Docker | Que la ISO se compile o arranque |
| `Shell lint` | ShellCheck en los scripts de shell | Comportamiento de escritorio o instalación |
| `Build and publish release ISO` | Con una etiqueta `v*`, construye la ISO de producción y publica la ISO amd64 y su checksum SHA-256 | Que la instalación esté certificada o que el hardware sea compatible |
| `Build ISO artifact (manual)` | Construye manualmente una ISO y la sube como artefacto descargable de Actions | Crear una GitHub Release pública |

La acción de publicación es la única que crea una Release automáticamente. El workflow manual existe para obtener un artefacto temporal; no se debe usar para publicar otra Release del mismo tag.

No hay un workflow QEMU automático en los PR: construir y probar una ISO completa resultaba demasiado lento para la CI normal. La prueba sigue disponible manualmente mediante `scripts/test-iso.sh`.

## Smoke test de una ISO

El script `scripts/test-iso.sh ruta/a/dylanos.iso` hace estas comprobaciones:

1. Inspecciona el catálogo El Torito.
2. Extrae `live/filesystem.squashfs` y comprueba la presencia de Calamares, su configuración y las herramientas de DylanOS.
3. Arranca la imagen en QEMU con BIOS y con firmware OVMF para UEFI.
4. Espera en el puerto serie el texto `Started sddm.service`.

El timeout por modo es de 900 segundos; puede ajustarse con `DYLANOS_QEMU_TIMEOUT` a un entero positivo. Se requieren `xorriso`, `squashfs-tools`, `qemu-system-x86_64` y firmware OVMF para la prueba UEFI. El script no construye la ISO: hay que generarla antes con consola serial habilitada, como se explica en [Construcción](build.md#validar-cambios-y-una-iso). Cada modo puede esperar hasta 15 minutos por el marcador de SDDM.

Llegar a SDDM valida un arranque de smoke test, no el uso interactivo del escritorio, la partición del disco ni el flujo de instalación de Calamares. La variante de prueba habilita consola serial y no es la ISO de producción que se publica.

## Instalación de Calamares

Para validar una instalación de extremo a extremo todavía hay que probar por separado una ISO de producción en una VM: iniciar el instalador, completar el particionado, instalar y arrancar el sistema instalado. Mientras esa prueba no se registre con sus resultados, la configuración solo acredita que los archivos y módulos están preparados.
