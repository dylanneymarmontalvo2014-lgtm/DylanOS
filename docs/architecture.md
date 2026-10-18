# Arquitectura de DylanOS

DylanOS Crimson 1.0 está pensado como una distribución basada en Debian 13 con un escritorio Plasma 6 y una capa visual propia. La arquitectura no busca reemplazar toda la base del sistema, sino ofrecer un conjunto de aplicaciones y recursos nativos que encajen con el estilo propio de DylanOS.

## Capas del sistema

### 1. Base del sistema

- Debian 13 (trixie)
- KDE Plasma 6
- Qt 6 y QML
- KWin y servicios del sistema de KDE

### 2. Shell de trabajo

La capa interactiva del usuario vive en `apps/workspace`, con una lógica de backend y una interfaz QML organizada en páginas. Su intención es ofrecer un centro de trabajo con navegación clara y el mismo estilo visual de DylanOS.

### 3. Explorador de archivos

`apps/dylanos-explorer` implementa la capa de navegación y gestión de archivos del sistema. Se apoya en el motor KIO/Dolphin para conservar compatibilidad con el sistema de archivos y protocolos de KDE.

### 4. Store

`apps/dylanos-store` es la aplicación de software nativa del proyecto. Gestiona catálogo, estado de instalación y actualización del sistema con una experiencia no basada en la marca de KDE Discover.

### 5. Installer

El flujo de instalación del proyecto se aloja en `installer/dylanos-installer`. La intención es permitir una instalación propia del sistema, con una experiencia de preparación del sistema separada de la sesión live.

### 6. Identidad visual

La capa visual del sistema está en `branding/` y `themes/`, con el color principal DylanOS Crimson, fondos, iconos y perfiles gráficos del escritorio.

## Principios arquitectónicos

- Mantener la capa visual separada del sistema base.
- Dar prioridad a aplicaciones propias cuando el comportamiento real del escritorio lo requiere.
- Mantener scripts de staging y build explícitos y reproducibles.
- No depender de soluciones de terceros cuando el proyecto ya aporta una implementación propia.

## Datos y persistencia

La shell de trabajo y las apps nativas usan almacenamiento local para notas, ajustes y flujo de usuario. El objetivo es conservar la experiencia del sistema sin depender de un backend externo.

## Operaciones privilegiadas

Las tareas que requieren privilegios de sistema, como instalación, cambios de sistema o gestión de dispositivos, se gestionan a través del flujo ordenado del sistema y de los scripts del repositorio, no por rutas o comandos inseguros en la interfaz del usuario.

## Limitaciones conocidas

- El proyecto se encuentra en un estado de desarrollo real y activo.
- La documentación histórica en `docs/` debe considerarse de referencia y no como documento vivo del proyecto.
- El objetivo principal es establecer una base estable y coherente para la 1.0 Crimson.
