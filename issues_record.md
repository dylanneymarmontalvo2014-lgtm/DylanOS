# Registro de Issues de DylanOS (22 issues asignados a CRISTOP-bot y usuario)

## Issues completados (15)

1. **#1 - Populate DylanOS placeholder directories** (PR #1, CRISTOP-bot)
   - Commit: 92618f2
   - Descripción: Añadir directorios `.gitkeep` y archivos de configuración base (branding, configs, packages, scripts, themes, docs, installer, etc.)
   - Archivos afectados: 57 files, 692 insertions
   - Estado: **COMPLETADO**

2. **#2 - Fix Debian package validation in CI** (PR #2, CRISTOP-bot)
   - Commit: 4f46f71
   - Descripción: Corregir `.github/workflows/build.yml` para validación de paquetes Debian en CI
   - Estado: **COMPLETADO**

3. **#3 - Add Docker build helpers** (PR #3, CRISTOP-bot)
   - Commit: 69cb5a1
   - Descripción: Añadir `.dockerignore`, Dockerfile, install-deps.sh y actualizar workflows
   - Estado: **COMPLETADO**

4. **#4 - Welcome and diagnostics QEMU smoke workflow** (PR #4, CRISTOP-bot)
   - Commit: eec6110 (superseded by PR #5)
   - Descripción: Flujo de trabajo de prueba smoke para bienvenida y diagnóstico en QEMU
   - Estado: **SUPERADO por PR #5**

5. **#5 - Add DylanOS welcome, diagnostics, and ISO release workflows** (PR #5, CRISTOP-bot)
   - Commit: 0eb4fc0
   - Descripción: Añadir `.github/workflows/iso-smoke.yml`, `.github/workflows/release-iso.yml`, bienvenida diagnostics, y actualizar scripts de prueba
   - Archivos: 13 files, 514 insertions
   - Estado: **COMPLETADO**

6. **#6 - Refresh DylanOS README and expand project documentation** (PR #6, CRISTOP-bot)
   - Commit: aaf2cf5
   - Descripción: Actualizar README.md, CHANGELOG.md, CONTRIBUTING.md, docs/*, agregar banners y paletas
   - Archivos: 15 files, 480 insertions, 265 deletions
   - Estado: **COMPLETADO**

7. **#7 - Remove slow automatic QEMU ISO build workflow** (PR #7, CRISTOP-bot)
   - Commit: 99b97a2
   - Descripción: Remover `iso-smoke.yml` y actualizar docs/*
   - Estado: **COMPLETADO**

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