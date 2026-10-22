# Cambios de CI, staging y dock — 2026-10-21

Este port se aplica directamente sobre `development` del repositorio canónico `dylanneymarmontalvo2014-lgtm/DylanOS`; conserva su historial y no modifica `main`. No se trasladaron commits completos de la bifurcación `CRISTOP-bot/DylanOS`.

## Registro individual de cambios

| Archivo | Cambio y motivo | Verificación prevista |
|---|---|---|
| `apps/com.dylanos.activeapp/contents/ui/main.qml` | Aumenta el ancho mínimo del nombre de la aplicación activa de 24 a 192 px para que el título de la barra superior sea legible. | `scripts/tests/test_shell_contract.py` verifica el valor. |
| `apps/com.dylanos.dock/contents/ui/main.qml` | Añade `applications:code.desktop` a los lanzadores fijados para usar la aplicación oficial instalada. | Prueba de contrato del dock. |
| `themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js` | Sustituye el ID incorrecto `com.microsoft.VSCode.desktop` por el ID `code.desktop`. | Prueba que ambos layouts usan el ID correcto y rechazan el antiguo. |
| `scripts/build-installer.sh` | Nuevo build reproducible del frontend: valida Node/npm y la versión compatible con Vite, ejecuta `npm ci` y build y exige `dist/index.html` no vacío. La salida de error de Node se concatena para mantener ShellCheck limpio. | Ejecución directa en CI y ShellCheck. |
| `scripts/build.sh` | Construye el frontend antes de entrar al namespace aislado, de modo que `stage.py` copie un `dist` generado. | Prueba de orden; el build ISO queda disponible manualmente. |
| `scripts/check.sh` | Incluye el helper en ShellCheck y genera el instalador antes de las pruebas de staging. | Workflow de lint. |
| `.github/workflows/build.yml` | Configura Node 22 con caché npm para el lockfile del instalador. | Workflow manual de build de ISO. |
| `.github/workflows/lint.yml` | Configura Node 22 con caché npm para poder construir y validar el frontend en los checks de push/PR. | Actions de lint. |
| `scripts/stage.py` | Ejecuta `chown` del home live solo como root; mantiene la asignación UID/GID 1000 en builds reales y permite staging rootless en CI. | Suite de staging del workflow. |
| `scripts/tests/test_explorer.py` | Reemplaza una aserción obsoleta de ZIP no versionado por verificaciones de los tres PNG de referencia que sí están en el repositorio. | Suite de Explorer. |
| `scripts/tests/test_shell_contract.py` | Añade regresiones para el ancho del título, el ID de VS Code oficial/configuración del repo y la secuencia build-antes-de-stage. | Nueva suite unittest. |
| `scripts/tests/test_desktop.py` | Actualiza el contrato de pines del dock para exigir `code.desktop` en vez del antiguo ID de VS Code. | `test_desktop` ejecuta el layout con Node en CI. |
| `packages/build/packages.list` | Añade la lista versionada de dependencias de compilación para la tienda nativa, requerida por `test_store.py` y el build. | Suite de store y build del sistema. |
| `docs/cambios-ci-dock-2026-10-21.md` | Registra por archivo cada cambio, su intención y evidencia de validación para mantener trazabilidad. | Se completará con los resultados concretos de Actions. |

## Dirección de VS Code

El branch canónico instala el paquete oficial `code` desde el repositorio apt de Microsoft (`packages/development/setup-repos.sh`). Por eso el dock usa `code.desktop`; no se reintroduce VSCodium ni se cambia la configuración de repositorios ya existente.

## Evidencia de pruebas

- Run `39718171476` (`f418c7f`): falló en ShellCheck (`SC2016`) antes de ejecutar las suites; la plantilla literal de Node se sustituyó por concatenación de cadenas en `scripts/build-installer.sh`.
- Run `39718356615` (`08e37ad`): pasó ShellCheck, el frontend del instalador compiló y pasaron 40 pruebas de paquetes, pero `test_desktop` aún esperaba el ID antiguo de VS Code. Se corrigió ese contrato en `scripts/tests/test_desktop.py`; la nueva ejecución está pendiente de verificar.
- ISO de producción/QEMU: no ejecutados como parte del workflow de lint; el workflow de build de ISO es manual.
