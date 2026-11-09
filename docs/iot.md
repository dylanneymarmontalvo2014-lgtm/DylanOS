# DylanOS IoT

El paquete IoT tiene dos usos separados:

- `bash scripts/build.sh --iot` crea una imagen de sistema con la lista Debian de `packages/iot/packages.list`.
- El perfil de usuario se administra desde DylanOS Configuration → **IoT & Embedded Systems**. Su catálogo y perfiles se entregan desde `/usr/share/dylanos/iot/`; las preferencias se guardan en `~/.config/dylanos/iot.conf` y el respaldo reversible en `~/.local/state/dylanos/iot/backup.json`.

## Catálogo

`packages/iot/catalog.json` es la fuente única de los veinte elementos. Declara el tipo (gráfico, CLI, extensión o servicio), método de instalación, fuente y limitaciones conocidas. Los programas Debian se indican como APT de trixie; las aplicaciones externas no se descargan ni ejecutan desde el catálogo. PlatformIO se integra mediante la extensión oficial de VS Code. ESP-IDF recomienda Espressif Installation Manager (EIM). Arduino IDE 2 no es el paquete `arduino` de Debian: ese paquete sigue en la rama IDE 1.8.19.

| Herramienta | Tipo | Método declarado en el catálogo | Compatibilidad resumida |
|---|---|---|---|
| Arduino IDE 2 | GUI | AppImage/archivo oficial | No es el IDE 1.8.19 de APT; Linux x86-64 |
| Visual Studio Code | GUI | APT `code` del origen Microsoft existente | Reutiliza el repo oficial ya configurado |
| PlatformIO | Extensión GUI | Marketplace oficial para VS Code | Requiere `python3-venv`; toolchains bajo demanda |
| ESP-IDF | Toolchain CLI | EIM de Espressif | Descarga toolchains por target; sin repo añadido automáticamente |
| Thonny | GUI | APT `thonny` | Disponible en trixie; requiere firmware compatible para MicroPython |
| KiCad | GUI | APT `kicad` | Disponible en trixie |
| FreeCAD | GUI | APT `freecad` | Disponible en trixie; aceleración 3D depende del equipo |
| OpenSCAD | GUI | APT `openscad` | Disponible en trixie |
| Node-RED | Servicio web | Método oficial del proyecto/Node.js | Opcional; no se inicia automáticamente |
| Eclipse Mosquitto | Servicio y CLI | APT `mosquitto`, `mosquitto-clients` | Servicio opcional, detenido por defecto |
| MQTT Explorer | GUI | Distribución Linux del proyecto | No hay paquete APT trixie identificado; revisar artefacto y arquitectura |
| Home Assistant | Servicio web | Instancia externa existente | Core/Supervised ya no soportados; local oficial requiere HA OS o contenedor |
| Wireshark | GUI | APT `wireshark` | Captura requiere permisos; no se otorgan automáticamente |
| PulseView | GUI | APT `pulseview` | Requiere analizador lógico soportado para captura |
| sigrok | CLI | APT `sigrok-cli` | Requiere hardware para captura |
| OpenOCD | CLI | APT `openocd` | Requiere adaptador JTAG/SWD compatible |
| avrdude | CLI | APT `avrdude` | Requiere placa o programador compatible |
| esptool | CLI | APT `esptool` | Flasheo solo manual; requiere ESP y puerto accesible |
| Minicom | CLI | APT `minicom` | Requiere permisos en el puerto serie |
| Tio | CLI | APT `tio` | Requiere permisos en el puerto serie |

Node-RED y Mosquitto son componentes opcionales. El gestor no inicia daemons. Home Assistant se limita a una instancia existente: sus rutas oficiales para Linux requieren Home Assistant OS o un contenedor y ya no soporta Core/Supervised instalados como servicios del host. DylanOS no automatiza imágenes, VMs ni contenedores. El estado mostrado es una prueba TCP a `localhost` en los puertos habituales; no autentica ni identifica el servicio que escucha.

## Perfiles

Los cinco JSON en `packages/iot/profiles/` asocian recomendaciones con IDs del catálogo: IoT Development, Robotics Engineering, Electronics Design, Home Automation y Embedded Systems. DylanOS Configuration permite elegir uno, activar/desactivar la preferencia global y restaurar el valor guardado antes de la primera activación. Desactivar el perfil conserva proyectos y no desinstala paquetes.

## Inventario actual

El servicio lista enlaces físicos en `/dev/serial/by-id` y nodos `/dev/ttyACM*`, `/dev/ttyUSB*` y `/dev/ttyAMA*` visibles, deduplica puertos y lee fabricante/modelo desde sysfs cuando el controlador los publica. Muestra velocidades habituales sugeridas. No abre puertos ni ejecuta un monitor serie. I²C, SPI, BLE, Wi-Fi, UART y TCP requieren enumeración específica; la lista serial no afirma descubrirlos todos.

Control Center muestra el número de puertos observados y el alcance TCP local de MQTT. No cambia perfiles ni controla servicios desde el panel.

## Seguridad y límites

- No se conceden permisos, grupos ni reglas udev automáticamente.
- No se flashea ni modifica firmware desde la interfaz.
- No se exponen brokers a redes externas; el sondeo solo consulta loopback.
- No se almacenan credenciales.
- Catálogo externo: aún requiere flujo de instalación verificado con PackageKit/Store y validación de firmas/hash antes de automatizar descargas. Las entradas que dependen de fuentes externas se informan como método externo.
- Las operaciones completas de compilación, carga, REPL MicroPython, conexiones MQTT autenticadas, control de instancias Node-RED/Home Assistant y notificaciones de hardware están pendientes; no se representan como disponibles.

## Validación

`python3 scripts/tests/test_iot.py` valida exactamente veinte IDs, los cinco perfiles y el staging idempotente. Para compilar Configuration en el host:

```sh
cmake -S apps/dylanos-configuration -B /tmp/dylanos-iot-build -GNinja
cmake --build /tmp/dylanos-iot-build -j2
QT_QPA_PLATFORM=offscreen /tmp/dylanos-iot-build/dylanos-configuration --page iot --smoke
```
