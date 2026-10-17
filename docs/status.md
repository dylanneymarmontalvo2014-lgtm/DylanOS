# Estado del proyecto

DylanOS es una distribución **Alpha**. Esta página separa lo que el repositorio configura de lo que ya se ha verificado en una imagen arrancada o instalada.

## Implementado en el repositorio

- Constructor con Debian Live, suite `stable`, arquitectura `amd64` y componentes Debian `main`, `contrib`, `non-free` y `non-free-firmware`.
- Listas de paquetes para escritorio y utilidades (`default`), desarrollo, juegos e IoT. El script de construcción incorpora las cuatro listas a la misma imagen; aún no son perfiles opcionales.
- Ajustes iniciales de identidad del sistema, Bash, Zsh, GTK y KDE Plasma.
- Recursos de marca para el escritorio, GRUB y Plymouth, además de configuración de SDDM basada en Breeze.
- Utilidades locales `dylanos-info`, `dylanos-welcome` y `dylanos-wallpaper`.
- Configuración de Calamares, incluida la secuencia de módulos y el copiado del filesystem live.
- Flujos de CI para pruebas estáticas, ShellCheck, resolución simulada de paquetes, construcción de la imagen Docker, pruebas de arranque QEMU y publicación versionada.

## Verificación automatizada

- `scripts/test.sh` valida sintaxis, utilidades, listas de paquetes, recursos y estructura del repositorio.
- `shellcheck` revisa los scripts de shell.
- La simulación de APT comprueba que las listas sean resolubles en los repositorios configurados; no instala todos los paquetes en una imagen.
- La construcción de Docker valida el entorno del constructor, pero por sí sola no produce una ISO.
- `scripts/test-iso.sh` comprueba el catálogo de arranque, algunos archivos del filesystem live y que el sistema alcance SDDM en BIOS y UEFI cuando la prueba completa termina correctamente.

Consulta [Pruebas](testing.md) para los criterios exactos. El estado actual de los workflows debe confirmarse en GitHub Actions: la presencia de un workflow no demuestra que su última ejecución haya pasado.

## Límites que deben mantenerse visibles

- La configuración de Calamares **no equivale** a haber completado una instalación. La instalación de extremo a extremo en una VM sigue siendo una validación distinta.
- Un arranque hasta SDDM en QEMU no certifica compatibilidad con hardware físico, Wi-Fi, gráficos, suspensión ni todos los firmware.
- No se publican requisitos mínimos de hardware verificados ni una matriz de compatibilidad.
- No hay un diseño propio de panel o dock de Plasma declarado en `configs/`; el escritorio hereda la disposición de KDE/Debian.
- No se deben presentar la ISO, las actualizaciones entre versiones ni la seguridad del sistema como listas para producción sin pruebas dedicadas.

## Dónde comprobar descargas

Las versiones públicas se publican en [GitHub Releases](https://github.com/dylanneymarmontalvo2014-lgtm/DylanOS/releases). Si la página no contiene una versión con ISO y checksum, todavía no hay una imagen pública de DylanOS que se pueda tratar como release.
