# Execution ledger — plan: docs/plans/beta-premium.md

- Ruling: ejecutar en el checkout `development` actual — los cambios locales sin confirmar en la barra superior, staging y pruebas están dentro del alcance y no se pueden trasladar limpiamente a un worktree sin riesgo de pérdida — coste si es incorrecto: los cambios de esta entrega quedan mezclados con el trabajo local y deben revisarse por archivo antes de confirmar.
- Ruling: guardar este ledger en `docs/plans/` — `AGENTS.md` protege `.superpowers/` y `docs/superpowers/` como registros históricos — coste si es incorrecto: las herramientas auxiliares de SDD no podrán actualizar el ledger automáticamente.
- Pre-flight: Task 1 produce el layout sin dashboard que Tasks 2 y 3 comparten con la barra/dock; no hay conflicto.
- Pre-flight: Task 2 y Task 5 comparten la identidad KWin de las aplicaciones; `setDesktopFileName` canónico es la fuente de verdad.
- Pre-flight: Task 4 conserva PackageKit y añade Flatpak como backend paralelo; no sustituye la Store ni expone Discover.
- Pre-flight: Task 6 ya satisface el contrato funcional; solo se cambiará ante una diferencia visual o funcional comprobada.
- Task 1: complete — `python -m unittest scripts.tests.test_desktop scripts.tests.test_staging` → 9/9; `bash scripts/tests/test_packages.sh` → 62/62.
- Task 1: Ruling: conservar el código fuente de `apps/com.dylanos.dashboard` pero retirarlo del layout y del payload — “eliminar widgets” se cumple en el sistema entregado sin borrar una implementación histórica aún referenciada por documentación y pruebas — coste si es incorrecto: el repositorio conserva código no empaquetado hasta una limpieza posterior.
- Task 2: complete — 2/2 contratos de barra, normalización Node y carga real de `com.dylanos.activeapp` bajo Plasma pasan sin errores QML.
- Task 3: complete — contrato de ampliación pasa y `com.dylanos.dock` carga bajo `plasmawindowed` sin errores QML.
- Task 3: Ruling: conservar el dashboard en el smoke test aunque ya no se empaquete — valida el código histórico sin volver a añadirlo al sistema — coste si es incorrecto: el QA invierte seis segundos en un componente no enviado.
- Task 4: complete — Store 16/16, paquetes 62/62 y sintaxis de `build.sh` pasan; Flathub se configura como remoto de sistema idempotente.
- Task 5: complete — App Center abre como superposición fullscreen sin semáforos; auditoría de Explorer, Configuration, Calculator, Workspace y Spotlight 33/33.
- Task 5: Ruling: App Center es la excepción deliberada al patrón de ventanas independientes — funciona como selector superpuesto y se cierra con Escape o al pulsar el fondo — coste si es incorrecto: no se podrá redimensionar ni minimizar como una app convencional.
- Task 6: complete — SDDM 3/3 con greeter real; fondo, avatar, contraseña, autenticación y energía usan datos/acciones reales.
- Final review: self-review — la política de esta sesión no autorizó delegación; `git diff --check` limpio, tema de iconos aceptado por `gtk-update-icon-cache` y ninguna zona histórica protegida fue editada.
- Final: minor (deferred): Vite informa dos avisos de compatibilidad futura en `vite.config.ts`; el build actual termina correctamente y no forma parte de este cambio.
- Final: Ruling: integrar todos los cambios de esta entrega en `development` y publicarlos por el remoto SSH, conforme a la autorización explícita del usuario — coste si es incorrecto: el commit agrupa el trabajo local previo que ya estaba dentro del alcance de la beta.
