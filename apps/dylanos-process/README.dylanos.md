# DylanOS Process

DylanOS Process es la adaptación de identidad de Plasma System Monitor 6.3.6. Conserva los modelos de procesos, sensores, páginas configurables, gráficos y operaciones de señales de KSysGuard; no utiliza datos simulados ni sustituye `ksystemstats`.

## Seguridad

Las acciones de finalizar proceso solicitan confirmación siempre. La preferencia upstream para omitir el diálogo se deshabilitó en esta compilación. Las señales se envían mediante `ProcessController` de KDE y los permisos siguen siendo los del usuario de la sesión; la aplicación no eleva privilegios.

## Integración y compilación

El paquete runtime `plasma-systemmonitor` permanece instalado en DylanOS para aportar `ksystemstats`, libksysguard y los módulos de ejecución. Este fork produce el binario separado `dylanos-process` y el desktop ID `org.dylanos.process`; no sobrescribe `/usr/bin/plasma-systemmonitor` ni sus archivos de paquete.

La compilación oficial de DylanOS se ejecuta desde `scripts/build.sh` en el chroot Debian 13. Para compilar en un entorno Debian 13 con las dependencias KDE/Qt de `CMakeLists.txt`:

```bash
cmake -S apps/dylanos-process -B build/dylanos-process -GNinja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build/dylanos-process --parallel 4
sudo cmake --install build/dylanos-process
```

## Procedencia y licencia

Código adaptado desde KDE `plasma-systemmonitor`, upstream https://invent.kde.org/plasma/plasma-systemmonitor, rama `Plasma/6.3`, commit `be4f1594995698cac59959b8baa4421f435a1015` (versión 6.3.6). Se conservan los avisos SPDX/copyright por archivo, los textos de licencia y las traducciones upstream. La licencia del código es `GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL`; algunos componentes están bajo LGPL según sus propios encabezados.