# Estructura de Paquetes y Perfiles de DylanOS

Este directorio define los conjuntos de paquetes Debian que componen los distintos perfiles de DylanOS:

## Perfiles Activos en Construcción

- **`build/`**: Dependencias y herramientas exclusivas para el proceso de compilación (`packages.list`). Se instalan en el chroot para compilar los binarios nativos de DylanOS y son purgadas al final de `scripts/build.sh` para no engordar la ISO final.
- **`default/`**: Perfil base (`PROFILE=minimal`). Contiene la base mínima del sistema operativo (KDE Plasma 6, SDDM con tema Crimson, utilidades del sistema y aplicaciones oficiales de DylanOS).
- **`development/`**: Perfil por defecto (`PROFILE=development`). Incluye el entorno de desarrollo completo con Visual Studio Code (repositorio oficial de Microsoft configurado mediante `setup-repos.sh`), herramientas de diagnóstico y dependencias de depuración.

## Perfiles Planificados en Hoja de Ruta (Roadmap)

- **`gaming/`**: Perfil especializado en gaming y entretenimiento (Steam, librerías de aceleración gráfica Vulkan/Mesa y capas de compatibilidad). Actualmente reservado para futuras versiones.
- **`iot/`**: Perfil ultraligero orientado a dispositivos embebidos y computación periférica (IoT). Actualmente reservado para futuras versiones.

