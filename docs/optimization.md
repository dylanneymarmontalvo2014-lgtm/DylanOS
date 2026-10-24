# Optimización de DylanOS e imagen ISO

## Objetivo y principio de seguridad

Reducir software que no aporta a la experiencia seleccionada sin eliminar
aplicaciones solicitadas, servicios necesarios, firmware, funciones del
instalador o componentes que aún tengan consumidores. La reducción debe ser
medible y pasar QA; un paquete no se quita solo por parecer grande o poco usado.

La raíz del sistema objetivo sigue siendo Debian 13 amd64. La compatibilidad de
otros sistemas anfitriones para compilar se gestiona aparte en
[build-hosts.md](build-hosts.md) y no cambia los paquetes incluidos en la ISO.

## Limpieza que ya realiza la construcción

`packages/default/packages.list` define la base funcional y las aplicaciones
predeterminadas. `scripts/build.sh`:

1. instala los paquetes de las listas por perfil;
2. compila e instala las aplicaciones propias;
3. purga las dependencias de desarrollo usadas solo para compilar la tienda;
4. elimina Dolphin, `dolphin-plugins` y KCalc, ya que DylanOS Explorer y la
   calculadora de DylanOS los sustituyen;
5. ejecuta `apt-get autoremove --purge` para retirar dependencias marcadas
   automáticamente que ya no necesite ningún paquete;
6. limpia la caché de APT antes de crear la ISO;
7. elimina los índices descargados de APT (`/var/lib/apt/lists/*`), que se
   regeneran con `apt-get update` cuando el usuario actualiza el sistema.

`--no-install-recommends` evita incluir paquetes recomendados que no estén
solicitados explícitamente o que no sean dependencias obligatorias. Los paquetes
enumerados en `packages/default/packages.list` continúan siendo explícitos y no
se eliminan por autoremove. El perfil `development` se conserva intacto; incluye
toolchain y herramientas para quien las necesita.

## Funciones que se conservan deliberadamente

No se eliminan del perfil base el navegador, DylanOS Console, herramientas de sistema,
red, sonido, Bluetooth, energía, utilidades de accesibilidad, firmware, runtime
de la tienda, componentes KDE/KIO usados por el explorador ni las herramientas
del instalador. Antes de proponer quitar cualquiera de esos paquetes hay que
identificar dependencias y probar las funciones afectadas en una ISO real.

Tampoco se cambia el fondo de pantalla ni el logo/identidad de DylanOS como
parte de esta optimización.

## Métricas reales del dashboard

El panel de escritorio muestra hora, calendario, RAM, CPU, espacio usado/total
del filesystem raíz y uptime con lecturas locales (`/proc` y `df`). No consulta
servicios remotos ni inventa valores. El widget pasa a 500 × 360 para acomodar
las métricas sin solaparlas. El primer render después de iniciar puede mostrar
la CPU como «leyendo…» hasta obtener dos muestras del contador.

## Comandos de validación

```bash
bash scripts/tests/test_packages.sh
python3 -m unittest scripts.tests.test_shell_contract
python3 -m unittest scripts.tests.test_desktop
make check PYTHON=.venv/bin/python
make build PROFILE=default
make iso
make test-iso
```

En hosts no Debian/Ubuntu, corre `make check`, `make build PROFILE=default`,
`make iso` y `make test-iso` dentro del builder según [build-hosts.md](build-hosts.md).
La prueba `make qemu-test` es una validación separada y solo debe darse por
completada cuando se ejecuta y se observa el escritorio en la VM. Los tests
estáticos y la construcción de ISO no prueban por sí solos el arranque.

## Cómo medir si la ISO se redujo

Antes y después de los cambios, registra:

- tamaño exacto de la ISO y checksum;
- cantidad de paquetes y tamaños (`dpkg-query` y `apt-get --no-install-recommends`);
- dependencias retiradas por `apt-get autoremove --purge` en el log;
- resultado de la batería de pruebas y de la instalación/arranque en VM.

Hasta disponer de builds comparables, no se debe afirmar un ahorro concreto de
megabytes. Las listas `packages/default/packages.list` y
`packages/development/packages.list` son el registro auditable de paquetes
explícitos; no retirar paquetes de esas listas sin documentar el motivo, el
reemplazo y las pruebas funcionales afectadas.

## Archivos modificados en la actualización del 2026-10-23

- `apps/com.dylanos.dashboard/contents/ui/main.qml`: CPU y disco locales, con
  barras de uso y una representación de 500 × 360.
- `themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js`: actualizar la geometría inicial del widget a 500 × 360 y conservar explícitamente la ruta/configuración del wallpaper existente.
- `scripts/build.sh`: no instalar recommends y retirar solo dependencias
  automáticas huérfanas después de las purgas existentes.
- `scripts/tests/test_packages.sh`: asegurar las opciones de optimización y las
  purgas de dependencias.
- `scripts/tests/test_shell_contract.py` y `scripts/tests/test_desktop.py`:
  comprobar las nuevas métricas reales y el tamaño del widget.
- `docs/dylanos-shell.md`, `docs/README.md`, `README.md`: registro del diseño,
  índice y accesos a la documentación.
- `docs/optimization.md`: política, límites, comandos y métricas para comparar
  builds.

## Corrección de compilación validada en CI

El build necesita `desktop-file-utils` únicamente para generar la caché de aplicaciones de escritorio. Se instala temporalmente antes de `update-desktop-database` y se purga inmediatamente, antes de `autoremove`; no se conserva como paquete del sistema final. La batería de paquetes comprueba que exista tanto la instalación como la purga.

## Última medición disponible

La build automatizada `40030658295`, asociada al commit `98170f33566808ca5f9f5dc92c5468b6e174d166`, terminó con éxito en sus pasos `build`, `iso`, `test` y carga del artefacto. GitHub publicó `DylanOS-1.0-beta-amd64` con tamaño registrado de **2,268,807,947 bytes**. El run comprobó la estructura/checksum según `scripts/test.sh`; **no ejecutó QEMU ni valida el arranque o la sesión gráfica**.

Como referencia, otro artefacto anterior (`40024259258`, commit `1e1323bf1d912583b209bdfb2111ea1a24b3230a`) registró 3,195,313,060 bytes. Son builds de commits distintos y no hay una comparación controlada de manifiestos/logs de paquetes que permita atribuir la diferencia a `--no-install-recommends` o `autoremove`; por eso no se presenta como ahorro causado por la optimización. La nueva build del commit que corrige el cálculo de CPU debe medirse por separado cuando termine.

## Limpieza de índices APT (2026-10-24)

El build ejecuta `rm -rf /var/lib/apt/lists/*` al final del chroot, después de completar instalaciones, purgas y `autoremove`. Se retiran solo índices de repositorio descargados: APT los reconstruye en la próxima actualización mediante `apt-get update`; no son paquetes ni datos del usuario. La prueba `scripts/tests/test_packages.sh` verifica que la operación exista y ocurra después de `autoremove`. El ahorro exacto queda pendiente de medir con la nueva ISO; `apt-get clean` y esta limpieza actúan sobre datos distintos.

## Aceleración de compilación de ISO (2026-10-24)

- `scripts/build.sh` concatena las listas explícitas de cada perfil y las instala en una transacción APT, evitando resolver/configurar por separado cada lista. Mantiene los mismos paquetes declarados y `--no-install-recommends`.
- Las cuatro aplicaciones C++ compilan con hasta 4 trabajos (o menos si hay menos núcleos). Puede limitarse con `DYLANOS_BUILD_JOBS=2 bash scripts/build.sh` o `make build BUILD_JOBS=2`; el script limita valores superiores a los núcleos disponibles. Usa un valor menor si el host tiene poca memoria.
- `make iso-validated PROFILE=development` ejecuta en secuencia build, generación de ISO y validación de estructura/checksum. `RESUME=1` reanuda un chroot existente.
- La aceleración es una optimización esperada, no una cifra de tiempo garantizada: se debe comparar con builds del mismo runner y perfil. La ejecución de `scripts/build.sh`, `scripts/iso.sh` y `scripts/test.sh` también depende de CI.

### Qué se quita para reducir la imagen

- Se purgan `dolphin`, `dolphin-plugins` y `kcalc`; sus funciones se cubren con DylanOS Explorer y DylanOS Calculator.
- Se purgan los paquetes `-dev` usados exclusivamente para compilar DylanOS Store: `libflatpak-dev`, `libostree-dev`, `libappstreamqt-dev`, `libpackagekitqt6-dev`, `qcoro-qt6-dev`, `kirigami-addons-dev`, `libkirigami-dev`, `libkf6xmlgui-dev`, `libkf6idletime-dev`, `libkf6statusnotifieritem-dev`, `libkf6notifications-dev`, `libkf6crash-dev`, `libkf6dbusaddons-dev`, `libkf6archive-dev`, `qt6-svg-dev`, `libkf6iconthemes-dev` y `libkf6auth-dev`.
- `desktop-file-utils` se instala solo temporalmente para generar la caché de aplicaciones y se purga inmediatamente.
- `apt-get autoremove --purge` quita solo dependencias marcadas automáticas que ya no necesita ningún paquete explícito.
- `apt-get clean` borra archivos de paquetes descargados; `rm -rf /var/lib/apt/lists/*` borra índices de repositorio que se regeneran con `apt-get update`. Ninguno de esos dos pasos desinstala aplicaciones.
- No se borran las aplicaciones explícitas del perfil base, el navegador, la pila de red/sonido/Bluetooth, firmware, tienda/runtime, KIO ni componentes necesarios del instalador. El wallpaper permanece intacto.
