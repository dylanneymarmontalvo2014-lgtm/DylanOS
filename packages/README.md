# Estructura de Paquetes y Perfiles de DylanOS

Este directorio define los conjuntos de paquetes Debian que componen los distintos perfiles de DylanOS:

## Perfiles Activos en Construcción

- **`build/`**: Dependencias y herramientas exclusivas para el proceso de compilación (`packages.list`). Se instalan en el chroot para compilar los binarios nativos de DylanOS y son purgadas al final de `scripts/build.sh` para no engordar la ISO final.
- **`default/`**: Perfil base (`PROFILE=minimal`). Contiene la base mínima del sistema operativo (KDE Plasma 6, SDDM con tema Crimson, utilidades del sistema y aplicaciones oficiales de DylanOS).
- **`development/`**: Perfil predeterminado (`PROFILE=development`). Incluye el entorno de desarrollo con Visual Studio Code (repo oficial configurado mediante `setup-repos.sh`), toolchains y utilidades.
- **`iot/packages.list`**: selección de paquetes para construir una imagen especializada con `bash scripts/build.sh --iot`. No es el perfil de usuario ni implica que todos los componentes se inicien.

## Perfil de usuario

- **`gaming/`**: catálogo, perfiles declarativos, overlays y paquetes Debian
  opcionales de DylanOS Gaming. No se agrega al ISO base; se administra desde
  DylanOS Configuration y el Centro de Control. El `packages.list` describe
  dependencias del conjunto Gaming y no convierte el perfil en un perfil de
  construcción seleccionable.
- **`iot/catalog.json` y `iot/profiles/`**: catálogo de veinte herramientas y cinco perfiles de usuario, staged para DylanOS Configuration. Elegir un perfil guarda preferencias; no instala aplicaciones ni inicia servicios.
