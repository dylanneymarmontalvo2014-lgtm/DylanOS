# Changelog

Todos los cambios relevantes de DylanOS se registran en este archivo. La intención es mantener un histórico claro de la evolución del escritorio, el branding y la plataforma de instalación.

## [Unreleased] - development

### Añadido

- Comando `about`, generado por staging y conectado a `MAINTAINERS.txt`.
- Calendario interactivo del Dashboard, silencio de audio en el Centro de Control y guía de uso/capacidades de las aplicaciones.
- Documentación de componentes Workspace, Spotlight, App Center y Calculator; se precisan las limitaciones reales del instalador y las categorías incompletas de Spotlight.
- Control de volumen y silencio del micrófono predeterminado en el Centro de Control mediante `pactl`, con estado no disponible cuando no hay fuente de entrada.
- Dashboard 0.3.0: porcentajes claros y barras Crimson con animación suave y descripciones accesibles para RAM, CPU y filesystem raíz.
- Dashboard 0.3.1: estados de hoy/selección accesibles y transiciones suaves del calendario.

### Cambiado

- El índice de documentación enlaza las nuevas guías y diferencia las guías activas de los informes históricos.

## [1.0.0-crimson] - 2026-10-18

### Añadido

- Identidad visual DylanOS Crimson consolidada en el repositorio.
- Documentación principal reescrita para reflejar el estado real del proyecto.
- Arquitectura del sistema con shell de trabajo, explorador, tienda y instalador propios.
- Estructura de documentación con índice operativo en `docs/`.

### Cambiado

- Se eliminó la ambigüedad entre la documentación histórica y la documentación activa.
- Se actualizó la referencia a aplicaciones y sectores del sistema para alinearlos con `dylanos-store`, `dylanos-explorer` y `installer/dylanos-installer`.
- Se reforzó la consistencia visual y de marca con los colores oficiales y la referencia Crimson.

### Corregido

- Enlaces y referencias rotos en la documentación principal.
- Descripciones obsoletas que hablaban de soluciones antiguas o de componentes ya no vigentes.

## [0.1.0-alpha] - En desarrollo inicial

### Añadido

- Creación del repositorio oficial.
- Estructura base del proyecto.
- Primeros recursos de documentación.
- Diseño visual de escritorio y flujo de construcción al inicio del proyecto.
