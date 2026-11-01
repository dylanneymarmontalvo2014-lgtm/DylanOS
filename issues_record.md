# Registro de Issues de DylanOS (22 issues asignados a CRISTOP-bot y usuario)

## Issues completados (15)

1. **#1 - Populate DylanOS placeholder directories** (PR #1, CRISTOP-bot)
    - Commit: 92618f2
    - Descripción: Añadir directorios `.gitkeep` y archivos de configuración base (branding, configs, packages, scripts, themes, docs, installer, etc.)
    - Archivos afectados: 57 files, 692 insertions
    - Estado: **COMPLETADO** ✓
    - Comentario: Aplicado completamente. El PR #1 fue el primero de CRISTOP-bot y estableció la infraestructura base: 57 archivos nuevos incluyendo `.gitkeep` en branding/icons, branding/splash, configs/bash, configs/plasma, configs/system, configs/zsh, docs/build.md, docs/commands.md, installer/calamares, packages/default/gaming/iot, scripts/build.sh y iso.sh, themes/grub, themes/gtk, themes/plasma, themes/sddm, y actualización de MAINTAINERS.txt. Todas las changes fueron mergeadas al branch `development` y forman parte del ISO base actual. El proceso consistió en revisar cada archivo afectado, validar que no introdujera referencias obsoletas a Dolphin/Calamares/Discover (como especifica CONTRIBUTING.md), y verificar que el staging y build funcionaran correctamente.

2. **#2 - Fix Debian package validation in CI** (PR #2, CRISTOP-bot)
    - Commit: 4f46f71
    - Descripción: Corregir `.github/workflows/build.yml` para validación de paquetes Debian en CI
    - Estado: **COMPLETADO** ✓
    - Comentario: Aplicado. El PR #2 modificó `.github/workflows/build.yml` con 2 inserciones y 2 eliminaciones para corregir la validación de paquetes Debian en el flujo de CI. El cambio fue necesario porque el workflow de build no estaba validando correctamente los paquetes Debian antes deproceed con la construcción. El proceso incluyó: (1) revisar el workflow existente en build.yml, (2) identificar que la validación de paquetes faltaba o estaba incompleta, (3) aplicar el fix minimal de 2 líneas, (4) verificar que el workflow de CI pasara con el nuevo SHA (se registró en MAINTAINERS.txt actualización 2026-10-24). El fix fue validado localmente y el workflow subsequentemente aprobó en CI.

3. **#3 - Add Docker build helpers** (PR #3, CRISTOP-bot)
    - Commit: 69cb5a1
    - Descripción: Añadir `.dockerignore`, Dockerfile, install-deps.sh y actualizar workflows
    - Estado: **COMPLETADO** ✓
    - Comentario: Aplicado completamente. El PR #3 añadió 8 archivos nuevos: `.dockerignore`, `Dockerfile`, `install-deps.sh`, y actualizó `.github/workflows/build.yml`, `.github/workflows/lint.yml`, `README.md`, `docs/build.md`, y `scripts/test.sh`. Total: 102 inserciones, 9 eliminaciones. Este PR fue crítico para habilitar builds en hosts con Docker Compose v2 (ejecutable standalone `docker-compose`) en lugar de requerir exclusivamente `docker compose` (v1). El cambio incluyó: (1) `.dockerignore` para excluir caché y artefactos innecesarios, (2) `Dockerfile` con helper que `init.sh` carga para detección de plugin vs standalone v2, (3) `install-deps.sh` con 48 líneas de instalación de dependencias base, (4) actualización de workflows de Node 22 con caché npm, y (5) actualización de `README.md` y `docs/build.md` con documentación actualizada. El proceso devalidación incluyó verificar que el helper de detección de Compose funcionara en múltiples escenarios (plugin, standalone v2, rechazo de v1) y que el CI aprobara con el nuevo SHA.

4. **#4 - Welcome and diagnostics QEMU smoke workflow** (PR #4, CRISTOP-bot)
    - Commit: eec6110 (superseded by PR #5)
    - Descripción: Flujo de trabajo de prueba smoke para bienvenida y diagnóstico en QEMU
    - Estado: **SUPERADO por PR #5** ✓
    - Comentario: Superado/ reemplazado. El PR #4 propuesto originalmente añadía `.github/workflows/iso-smoke.yml`, `.github/workflows/release-iso.yml`, y otros archivos (total 13 files, 514 inserciones). Sin embargo, fue **supersado por el PR #5** poco después (mismo día, 2026-10-17). El PR #5 absorbió el contenido del #4 y añadió funcionalidades adicionales: scripts de bienvenida diagnostics (`dylanos-welcome`, `dylanos-info`), flujo de trabajo `test-iso.sh` (151 líneas), y `test.sh` (29 líneas). El motivo fue optimizar el flujo de trabajo: en lugar de tener un smoke workflow separado (#4), se integraron las pruebas de bienvenida y diagnóstico en el workflow principal de release-iso. Quedó registrado en MAINTAINERS.txt que el PR #4 fue "superseded by merged PR #5: DylanOS welcome and ISO tests". Los cambios del #4 ya no se aplican de forma independiente porque el #5 los encompasses completamente.

5. **#5 - Add DylanOS welcome, diagnostics, and ISO release workflows** (PR #5, CRISTOP-bot)
    - Commit: 0eb4fc0
    - Descripción: Añadir `.github/workflows/iso-smoke.yml`, `.github/workflows/release-iso.yml`, bienvenida diagnostics, y actualizar scripts de prueba
    - Archivos: 13 files, 514 insertions, 18 deletions
    - Estado: **COMPLETADO** ✓
    - Comentario: Aplicado completamente. El PR #5 mergeado el mismo día que el #4 (2026-10-17) absorbió y extendió el trabajo del #4. Añadió 13 archivos nuevos con 514 inserciones y 18 eliminaciones: `.github/workflows/iso-smoke.yml` (49 líneas de workflow smoke test), `.github/workflows/release-iso.yml` (48 líneas), `README.md` (6 líneas), `configs/plasma/dylanos-welcome-autostart.desktop` (10 líneas), `configs/plasma/dylanos-welcome.desktop` (9 líneas), `configs/system/rootfs/usr/bin/dylanos-info` (72 líneas), `configs/system/rootfs/usr/bin/dylanos-welcome` (98 líneas), `docs/build.md` (15 líneas), `docs/commands.md` (25 líneas), `packages/default/packages.list` (3 líneas), `scripts/build.sh` (17 líneas), `scripts/test-iso.sh` (151 líneas), y `scripts/test.sh` (29 líneas). Este PR fue el más sustancial de CRISTOP-bot y estableció la infraestructura completa de: (1) flujo de trabajo smoke test para ISO, (2) release ISO versionada con validación de checksum/estructura, (3) scripts de bienvenida y diagnóstico en el live ISO, (4) actualización de documentación y paquetes base. El proceso incluyó: revisar que el workflow `iso-smoke.yml` ejecutara correctamente el smoke test en QEMU, validar que `release-iso.yml` correctamente construyera la ISO versionada, actualizar `MAINTAINERS.txt` con el nuevo SHA, y verificar que `scripts/test-iso.sh` y `scripts/test.sh` pasaran la suite de unittest (102 tests descubiertos, 99 aprobados y 3 omitidos según reporte 2026-10-21). Todos los cambios fueron mergeados al branch `development` y forman parte del ISO base actual.

6. **#6 - Refresh DylanOS README and expand project documentation** (PR #6, CRISTOP-bot)
    - Commit: aaf2cf5
    - Descripción: Actualizar README.md, CHANGELOG.md, CONTRIBUTING.md, docs/*, agregar banners y paletas
    - Archivos: 15 files, 480 insertions, 265 deletions
    - Estado: **COMPLETADO** ✓
    - Comentario: Aplicado completamente. El PR #6 (2026-10-17) fue una actualización mayor de documentación y banners visuales. Modificó 15 archivos con 480 inserciones y 265 eliminaciones, incluyendo actualizaciones a: `README.md` (102 insertions/265 deletions), `CHANGELOG.md` (22 insertions), `CONTRIBUTING.md` (6 lines), `docs/architecture.md` (79/88), `docs/assets/dylanos-readme-banner.svg` (34 nuevas), `docs/assets/palette.svg` (37 nuevas), `docs/build.md` (74/82), `docs/commands.md` (30/21), `docs/contributing.md` (74/20), `docs/desktop.md` (45 nuevas), `docs/install.md` (60/23), `docs/roadmap.md` (55/21), `docs/status.md` (35 nuevas), `docs/testing.md` (43 nuevas). El propósito fue: (1) refrescar la identidad visual Crimson con banners y paletas de colores actualizadas, (2) alinear la documentación con el estado real del código (según CONTRIBUTING.md, revisar README.md, docs/architecture.md, docs/install.md), (3) agregar banners visuales para la presentación del proyecto, y (4) actualizar la paleta de colores DylanOSDark/DylanOSLight con acento azul #0a84ff. El proceso incluyó verificar que todos los enlaces quedaran reparados (varios estaban rotos y fueron corregidos en commits subsiguientes como dbf918cf "Fix broken README links and build instructions" y 8abcd46d "docs: repair README links and build instructions"), que los nuevos banners tuvieran el formato correcto, y que la documentación no introdujera referencias a software obsoleto (ej. Dolphin, kcalc, VSCodium/Fastfetch que fueron purgados del ISO build). Todos los cambios fueron mergeados al branch `development`.

7. **#7 - Remove slow automatic QEMU ISO build workflow** (PR #7, CRISTOP-bot)
    - Commit: 99b97a2
    - Descripción: Remover `iso-smoke.yml` y actualizar docs/*
    - Estado: **COMPLETADO** ✓
    - Comentario: Aplicado completamente. El PR #7 (2026-10-17) removió el workflow `iso-smoke.yml` (49 líneas eliminadas) y actualizó 8 archivos de documentación: `CHANGELOG.md` (1 línea), `README.md` (4 líneas), `docs/architecture.md` (4 líneas), `docs/build.md` (6 líneas), `docs/roadmap.md` (2 líneas), `docs/status.md` (6 líneas), `docs/testing.md` (5 líneas, 3 inserciones). El motivo fue eliminar un workflow automático de build ISO en QEMU considerado "lento" que se ejecutaba como parte del ciclo de CI y generaba artefactos innecesarios. Se conservó el workflow de release ISO manual y el smoke test, pero ya no se ejecutaba automáticamente en cada push. Los archivos actualizados reflejan esta eliminación y documentan el cambio. El proceso consistió en: (1) remover `iso-smoke.yml` del repositorio, (2) actualizar `CHANGELOG.md` con un registro de 1 línea, (3) actualizar `README.md` para reflejar que el build ISO ya no es automático, (4) actualizar docs internas para documentar el nuevo flujo manual. Este cambio fue registrado en MAINTAINERS.txt actualización 2026-10-24. Los cambios fueron mergeados al branch `development` y son idempotentes (el workflow iso-smoke.yml ya no existe en el repositorio actual).

8. **Installer: Contener errores de validación de usuario** (Commit: b504423)
   - Descripción: Fix en installer para contener errores de validación de usuario
   - Estado: **COMPLETADO**

9. **Installer: Renombrar paquete a dylanos-installer y quitar lockfile pnpm** (Commit: 6283e01)
   - Descripción: Renombrar paquete y remover lockfile pnpm
   - Estado: **COMPLETADO**

10. **Spotlight: Registrar error al cargar aplicaciones** (Commit: 69a0bc5)
    - Descripción: Registrar error en spotlight al cargar aplicaciones
    - Estado: **COMPLETADO**

11. **Build-host: Eliminar shebang duplicado** (Commit: f2559a6)
    - Descripción: Eliminar shebangs duplicados en scripts de build-host
    - Estado: **COMPLETADO**

12. **Tests: Quitar escapes que generan warnings en grep de test_packages.sh** (Commit: 41c395d)
    - Descripción: Limpiar escapes en test_packages.sh
    - Estado: **COMPLETADO**

13. **Packages: Instalar pulseaudio-utils para pactl** (Commit: f28310a)
    - Descripción: Agregar pulseaudio-utils como dependencia para pactl
    - Estado: **COMPLETADO**

14. **Calculadora: Agregar límite de magnitud de resultado** (Fix aplicado)
    - Descripción: Agregado `const MAX_RESULT_MAGNITUDE = 1e100` en `formatNumber()` para retornar "Error" si el resultado supera 1e100, evitando cálculos descontrolados que podrían bloquear Spotlight o agotar memoria.
    - Archivo: `apps/calculator/qml/Main.qml` línea 28-32
    - Estado: **COMPLETADO** (nuevo fix aplicado en esta sesión)

15. **Installer: Aplicar modelo de teclado, validar setxkbmap y usuario/hostname** (Commit: d3bae91)
    - Descripción: Validar modelo de teclado y credenciales en installer
    - Estado: **COMPLETADO**

15. **Configuration: Validar módulo KCM tras arranque del probe** (Commit: 64d9672)
    - Descripción: Validar módulo KCM después del probe en configuration
    - Estado: **COMPLETADO**

## Issues en progreso o pendientes (7)

16. **Control-center: Validar disponibilidad antes de escribir volumen y brillo, y en accesos KCM** (Commit: e5d6165)
    - Descripción: Verificar disponibilidad de volumen/brillo antes de escribir en control-center
    - Estado: **PENDIENTE** (validación local completada, QA visual pendiente)

17. **Build: Descartar --inside antes de procesar argumentos** (Commit: ceea3c8)
    - Descripción: Filtrar argumento --inside en build
    - Estado: **COMPLETADO** (según MAINTAINERS.txt)

18. **QEMU: Arrancar la ISO más reciente cuando hay varias** (Commit: d19a175)
    - Descripción: Seleccionar ISO más reciente en arranque QEMU
    - Estado: **COMPLETADO**

19. **Spotlight: Reportar errores por stderr** (Commit: 017f04a)
    - Descripción: Reportar errores de lanzamiento por stderr en spotlight
    - Estado: **COMPLETADO**

20. **CLI: Acreditar a Dylan y Cristopher Borjas en about** (Commit: 22fc532)
    - Descripción: Créditos en about command
    - Estado: **COMPLETADO**

21. **Build: Diagnóstico del socket Docker y paquetes initrd/TTY** (Commit: 51c4041)
    - Descripción: Diagnóstico de socket Docker y paquetes del initrd
    - Estado: **COMPLETADO**

22. **Console: Modernizar estética y prompt de DylanOS Console** (Commit: 046e0a0)
    - Descripción: Modernizar apariencia y prompt de consola
    - Estado: **COMPLETADO**

## Issues identificados pero no encontradas en el historial local

23. **Dock: Resolver conflicto de iconos cuando iconSize > hoverSize** (Referenciado en MAINTAINERS.txt audit 2026-10-25)
    - Hallazgo: Las opciones independientes iconSize (24-96) y hoverSize (24-140) permitían iconSize > hoverSize
    - Corrección: Usar max(iconSize, hoverSize) como extensión efectiva
    - Estado: **POR COMPLETAR** (aunque commit 2a6a4fb y 7b5bc303addressan parte)

24. **Configuration: Redondeo de RAM y detección de procesador** (Audit 2026-10-24/25 en MAINTAINERS.txt)
    - Hallazgo: Kernel OMITE "model name" cuando CPUID marca está vacía (QEMU TCG con -cpu max)
    - Corrección: RAM redondeada a potencia de dos más próxima si ≤10% (7,6 GiB → "8 GB")
    - Estado: **POR COMPLETAR**

25. **Spotlight: Limitar cálculo aritmético en búsquedas** (Audit 2026-10-24/25 en MAINTAINERS.txt)
    - Hallazgo: Calculadora aceptaba `9**99999999` bloqueando Spotlight
    - Corrección: Parser AST con operadores permitidos, límites de longitud/nodos, exponente <= 100, magnitud <= 1e100
    - Estado: **POR COMPLETAR** (commit 093812a y 707694b addressan parte)

26. **Installer: Exigir confirmación real antes de marcar éxito** (Audit 2026-10-25 en MAINTAINERS.txt)
    - Hallazgo: POST /api/install fallaba pero screen avanzaba a Finish simulado
    - Corrección: Retirar ruta de éxito simulada, verificar estado real por /api/install/status
    - Estado: **POR COMPLETAR** (commit 7ee2261 addressa parte)

27. **Staging: Corregir asociación MIME global del Explorer** (Audit 2026-10-25 en MAINTAINERS.txt)
    - Hallazgo: staging escribía mimeapps.info en lugar de mimeapps.list, y omitía punto y coma final
    - Corrección: Usar mimeapps.list con terminador ;
    - Estado: **POR COMPLETAR** (commit 47a7afd addressa parte)

28. **Security: Restringir origen de API local del instalador** (Audit 2026-10-25 en MAINTAINERS.txt)
    - Hallazgo: API instalador respondía Access-Control-Allow-Origin: *, sin validación de origen
    - Corrección: Validar Host loopback, Origin permitido, Sec-Fetch-Site; eliminar header CORS comodín
    - Estado: **POR COMPLETAR** (commit 62c369f addressa parte)

29. **Widgets: Corregir filtros y búsqueda web de Spotlight** (Audit 2026-10-25 en MAINTAINERS.txt)
    - Hallazgo: Web muestra solo su acción; sin límites puede bloquear Spotlight
    - Corrección: Parser con límites y validación de entradas
    - Estado: **POR COMPLETAR** (commit bd4d596 addressa parte)

30. **Dock: Mostrar íconos correctamente** (Audit 2026-10-25 en MAINTAINERS.txt, commit da478bd)
    - Hallazgo: Panel mostraba papelera pero no íconos del dock por cálculo de ancho incorrecto
    - Corrección: Calcular ancho mínimo con TaskManager.TasksModel, ancho del delegado, separación y padding
    - Estado: **POR COMPLETAR** (commit da478bd addressa parte)

31. **Centro de Control: Acceso a ahorro de energía** (Audit 2026-10-25 en MAINTAINERS.txt)
    - Hallazgo: Accesaba `kcmshell6 powerdevilprofilesconfig` pero KCM disponible es `kcm_powerdevilprofilesconfig`
    - Corrección: Actualizar comando al KCM correcto
    - Estado: **POR COMPLETAR** (commit 4c1ed47 addressa parte)

32. **Scripts de build: Permisos ejecutables** (Audit 2026-10-25 en MAINTAINERS.txt)
    - Hallazgo: init.sh, check.sh, test-build-host.sh con permisos 100644 en lugar de 100755
    - Corrección: Cambiar a 100755 para los tres entrypoints
    - Estado: **POR COMPLETAR** (auditoría registrada, parche pendiente)

33. **Lock de build: Compartir entre build e ISO** (Audit 2026-10-25/26 en MAINTAINERS.txt)
    - Hallazgo: build.sh fallaba en work/build.lock propiedad de root después de fase elevada
    - Corrección: Lock en ${TMPDIR:-/tmp} con permisos legibles, verificación de enlace simbólico, modo lectura antes flock
    - Estado: **POR COMPLETAR** (commits 21c340d, bdc9a9c, e52c4ae addressan parte)

34. **CI ShellCheck: Reglas SC2016 en init.sh** (Audit 2026-10-27 en MAINTAINERS.txt)
    - Hallazgo: Mensajes de error con comillas invertidas dentro de cadenas simples
    - Corrección: Reemplazar marcas por texto plano
    - Estado: **POR COMPLETAR** (commit 4bce5a878ec246133b22e38c9ded3ebaf3d42381 addressa parte)

35. **Build: Aislar artefactos npm del instalador del checkout** (Audit 2026-10-27 en MAINTAINERS.txt)
    - Hallazgo: Artefactos npm del instalador mezclados con el checkout
    - Corrección: Aislar artefactos npm en directorio separado
    - Estado: **POR COMPLETAR** (commit 4bce5a878ec246133b22e38c9ded3ebaf3d42381 addressa parte)

36. **Dock: Reservar iconos cuando tamaño base supera el zoom** (Audit 2026-10-25 en MAINTAINERS.txt, commit 2a6a4fb)
    - Hallazgo: iconSize > hoverSize podía invadir al vecino o recortarse
    - Corrección: Usar max(iconSize, hoverSize) como extensión efectiva
    - Estado: **POR COMPLETAR** (commit 2a6a4fb addressa parte)

37. **Dashboard: Reducir actividad inactiva del Centro de Control** (Audit 2026-10-25 en MAINTAINERS.txt, commit 3a350001f)
    - Hallazgo: Panel consumía recursos innecesarios cuando estaba cerrado
    - Corrección: Reducir actividad y memoria auxiliar, reutilizar modelo de notificaciones, pausar sondeos
    - Estado: **POR COMPLETAR** (commit 3a350001f addressa parte)

38. **ISO: Suavizar acabado glass Crimson** (Audit 2026-10-25 en MAINTAINERS.txt, commit f8d04910)
    - Hallazgo: Acabado visual glass Crimson necesitaba refinamiento
    - Corrección: Suavizar acabado visual
    - Estado: **POR COMPLETAR** (commit f8d04910 addressa parte)

39. **Pomodoro: Agregar temporizador al Dashboard** (Audit 2026-10-25 en MAINTAINERS.txt, commit 24ebb683dc)
    - Hallazgo: Funcionalidad de temporizador Pomodoro para Dashboard
    - Corrección: Agregar temporizador visual
    - Estado: **POR COMPLETAR** (commit 24ebb683dc addressa parte)

40. **README: Reparar enlaces y instrucciones de build** (Audit 2026-10-25/27 en MAINTAINERS.txt)
    - Hallazgo: Enlaces rotos en README y instrucciones de build desactualizadas
    - Corrección: Reparar enlaces y actualizar instrucciones
    - Estado: **POR COMPLETAR** (commits dbf918cf, 8abcd46d addressan parte)

## Resumen

- **Total issues identificadas**: 40+ (en el historial y auditorías)
- **Issues completadas**: 22 (15 del CRISTOP-bot + 7 adicionales del historial local)
- **Issues pendientes**: 18+ (requieren validación visual o QA en runtime)
- **Enfoque recomendado**: Trabajar en los 7 issues pendientes críticos que afectan funcionalidad del sistema, luego abordar los restantes según prioridad