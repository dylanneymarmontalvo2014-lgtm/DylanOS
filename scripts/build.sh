# Estructura de Paquetes y Perfiles de DylanOS

Este directorio define los conjuntos de paquetes Debian que componen los distintos perfiles de DylanOS:

## Perfiles Activos en Construcción

- **`build/`**: Dependencias y herramientas exclusivas para el proceso de compilación (`packages.list`). Se instalan en el chroot para compilar los binarios nativos de DylanOS y son purgadas al final de `scripts/build.sh` para no engordar la ISO final.
- **`default/`**: Perfil base (`PROFILE=minimal`). Contiene la base mínima del sistema operativo (KDE Plasma 6, SDDM con tema Crimson, utilidades del sistema y aplicaciones oficiales de DylanOS).
- **`development/`**: Perfil predeterminado (`PROFILE=development`). Incluye el entorno de desarrollo con Visual Studio Code (repo oficial configurado mediante `setup-repos.sh`), toolchains y utilidades.
- **`iot/`**: Perfil especializado de IoT/embebidos, seleccionable con `bash scripts/build.sh --iot`. Añade Arduino IDE y toolchain AVR, depuración/flasheo para OpenOCD/ESP/STM32, utilidades MQTT/CAN, serial, I2C/GPIO y análisis lógico. No se mezcla con `development`; parte de la base común `default` + dependencias de build.

## Perfiles reservados

- **`gaming/`**: reservado para una futura versión.

