# Documentación de DylanOS

Este directorio reúne la documentación activa y útil del proyecto DylanOS Crimson 1.0, junto con informes históricos y auditorías archivadas que sirven como contexto técnico del desarrollo.

## Índice rápido

- [install.md](install.md): instalación, arranque live y validación.
- [optimization.md](optimization.md): estrategia y verificación de optimización del sistema/ISO.
- [architecture.md](architecture.md): arquitectura y principios del proyecto.
- [dylanos-shell.md](dylanos-shell.md): dashboard, Control Center y DylanOS Console.
- [guia-de-uso.md](guia-de-uso.md): catálogo de comandos, apps y widgets, límites conocidos y precauciones del instalador.
- [apps/workspace/README.md](../apps/workspace/README.md): páginas y datos locales del Workspace.
- [apps/dylanos-spotlight/README.md](../apps/dylanos-spotlight/README.md): búsqueda real y filtros pendientes.
- [apps/dylanos-app-center/README.md](../apps/dylanos-app-center/README.md): enumeración y lanzamiento de aplicaciones.
- [apps/dylanos-store/README.md](../apps/dylanos-store/README.md): uso vigente de la tienda y dependencias de sus operaciones.
- [apps/calculator/README.md](../apps/calculator/README.md): uso y punto de entrada de Calculator.
- [apps/com.dylanos.dashboard/README.md](../apps/com.dylanos.dashboard/README.md): calendario y métricas locales del widget.
- [apps/dylanos-control-center/README.md](../apps/dylanos-control-center/README.md): funciones, servicios requeridos y QA del centro de control.
- [apps/com.dylanos.activeapp/README.md](../apps/com.dylanos.activeapp/README.md): plasmoid de aplicación activa.
- [apps/com.dylanos.search/README.md](../apps/com.dylanos.search/README.md): botón de búsqueda de Spotlight.
- [apps/com.dylanos.dock/README.md](../apps/com.dylanos.dock/README.md): configuración y zoom progresivo del dock predeterminado.
- [installer/dylanos-installer/docs/README.md](../installer/dylanos-installer/docs/README.md): backend, API y diferencia entre vista previa e instalación real.
- [MAINTAINERS.txt](../MAINTAINERS.txt): mantenedores y responsabilidades.

## Última revisión de documentación

La guía de uso resume el estado visible de comandos, aplicaciones, widgets y
perfiles. Los documentos detallados de cada componente siguen siendo la fuente
principal de sus opciones y pruebas. Las páginas bajo `*-2026-*`, auditorías y
bitácoras se conservan como registros fechados; no sustituyen las guías activas.

Notas de estado que conviene leer antes de presentar el sistema como terminado:

- Spotlight muestra categorías de Archivos y Calcular, pero su backend aún no
  implementa el indexado de archivos recientes ni un flujo completo para esos
  filtros; su contador visual de archivos no es una medición real y la creación del resultado web referencia `urllib.parse` sin importar `urllib`.
- El frontend del instalador conserva datos de respaldo y una ruta de progreso
  simulada cuando falla la API. Solo la ruta backend root + disco válido instala
  en un destino real; los controles manuales de particionado visibles no están
  conectados a edición real de particiones.
- Las pruebas estáticas, de staging y CI no equivalen a render gráfico de Plasma,
  arranque completo, instalación de disco ni validación en hardware. Consulta
  `install.md` para los hitos de QA pertinentes.

Al modificar comandos, controles o perfiles, actualizar la guía de uso, los
README de componente pertinentes y este índice en el mismo cambio. La suite
`scripts/tests/test_documentation.py` comprueba que las guías activas estén
indexadas, que no se reintroduzcan dos afirmaciones retiradas y que sus enlaces
relativos resuelvan; no valida la exactitud funcional del código ni los informes
históricos completos.

- [roadmap.md](roadmap.md): hoja de ruta y evolución del sistema.
- [contributing.md](contributing.md): flujo de colaboración y estándares.
- [auditoria-boot-hang-initramfs.md](auditoria-boot-hang-initramfs.md): informe histórico de boot y initramfs.
- [auditoria-diseno-tahoe-crimson.md](auditoria-diseno-tahoe-crimson.md): referencia histórica de diseño.
- [auditoria-escritorio-2026-10-11.md](auditoria-escritorio-2026-10-11.md): informe de escritorio y ajustes visuales.
- [solucion-boot-hang-y-grub.md](solucion-boot-hang-y-grub.md): documentación técnica sobre arranque y GRUB.
- [correcciones-live-x11-instalador-appcenter-2026-10-13.md](correcciones-live-x11-instalador-appcenter-2026-10-13.md): correcciones y ajustes de la live session.
- [crimson-1.0-handover-log.md](crimson-1.0-handover-log.md): bitácora de entrega del proyecto.

## Normativa de uso

- La documentación activa se encuentra en [README.md](../README.md), [guia-de-uso.md](guia-de-uso.md), [install.md](install.md), [architecture.md](architecture.md), [roadmap.md](roadmap.md) y [contributing.md](contributing.md).
- Los informes de auditoría y correcciones son materiales históricos y deben tratarse como referencia, no como guía de uso principal.
- Si se modifica la infraestructura del sistema, es recomendable revisar primero la documentación activa y luego comprobar el estado de los informes históricos relacionados.
