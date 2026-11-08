# Relevo técnico — DylanOS Browser, Fase 2

**Actualizado:** 2026-11-08 -05 (America/Bogota)
**Estado:** Task 3 validada parcialmente; Tasks 1 y 2 completadas; Tasks 4 y 5 pendientes.
**Plan vigente:** `/home/dylan/DylanOS/docs/plans/dylanos-browser-phase-2.md`

Este documento es el punto de reanudación para otro agente. No declara terminada
la Fase 2: el primer build diagnóstico no produjo todavía el binario ni su
manifiesto.

## Repositorios y ramas

### Fuente del navegador integrada

- Ruta: `/home/dylan/DylanOS/apps/dylanos-browser`
- Rama: `development`
- La fuente fue importada desde el checkout local histórico de DylanOS Browser.
- La rama y la publicación corresponden al repositorio `DylanOS/development`.
- Ledger: `.superpowers/sdd/dylanos-browser-phase-2/progress.md`

No descartar ni sobrescribir estos cambios: son la implementación en curso de
Task 3. El árbol `engine/` y los objetos de compilación son locales e ignorados.

### Integración de la distribución

- Ruta: `/home/dylan/DylanOS`
- El empaquetado Debian vive en `apps/dylanos-browser/debian/`.
- El contrato de procedencia vive en `apps/dylanos-browser/source.lock.json`.
- Firefox ESR debe permanecer instalado y como navegador predeterminado hasta
  superar la validación de paquete y VM.

## Trabajo completado y evidencia

- Task 1 completada: gates reproducibles de entorno, licencias y dependencias.
- Task 2 completada: bootstrap reproducible, importación del overlay y contratos
  efectivos de seguridad del fork.
- Commits de fuente relevantes: `900c637`, `7d48d13`, `dc6c6c1`, `4322eba`,
  `220ca7d`.
- Última suite completa antes de añadir el gate de memoria: 37/37 pruebas
  `test:dylanos` verdes.
- Después de añadir el gate de 16 GiB RAM+swap:
  - `python3 -m unittest scripts.dylanos.test_build_environment -v`: 6/6.
  - `python3 scripts/dylanos/check_build_environment.py`: OK con el swap temporal.
- En la reanudación del 2026-11-07 se liberó la caché regenerable de npm para
  recuperar espacio; el gate volvió a pasar con 30.6 GiB libres y 21.6 GiB de
  RAM+swap. `npm run test:dylanos` pasó 38/38 y el contrato de fuente de DylanOS
  pasó 2/2.
- Comprobaciones ya verdes durante Task 3: 26 pruebas específicas, `npm run lc`,
  `npm audit --omit=dev` (0 vulnerabilidades), `shellcheck` de los scripts de build,
  `compileall`, Prettier de los archivos entonces modificados y `git diff --check`.
  Todas deben repetirse al final porque hubo cambios posteriores.
- El árbol de integración contiene el scaffold Debian de Task 4 y su prueba
  TDD: 7/7 combinando el contrato de fuente y el paquete. `desktop-file-validate`
  pasa. Las reglas bloquean el `.deb` si falta el binario real; `source.lock.json`
  sigue deliberadamente con `unpublished`.
- Ese scaffold quedó comprometido en `development` como `f9f6174
  test(browser): preparar scaffold Debian transitorio`; no es el commit de cierre
  de Task 4 porque aún falta el binario y el `.deb` real.
- En DylanOS pasaron 23 pruebas Python dirigidas. La prueba runtime
  del plasmoide no pudo ejecutarse porque el árbol no contiene
  `work/chroot/plasmawindowed`; no se diagnosticó como fallo del código.

## Implementación de Task 3

- `build_linux.sh` implementa variantes `diagnostic` y `candidate`, fija Linux
  x86_64, desactiva PGO en diagnóstico, usa `ZEN_RELEASE=1` para candidato, genera
  logs/manifiestos y usa un trabajo por defecto para evitar OOM.
- `write_build_artifact.py` registra duración, tamaño y SHA-256 del binario,
  mozconfig y log.
- `smoke_browser.py` ejecuta bajo Xvfb con servidor HTTP local, HOME y perfil
  temporales; comprueba ventana principal, nueva y privada, WM_CLASS de DylanOS,
  ausencia del host de actualización de Zen, cierre limpio y crash dumps.
- `package.json` expone `build:linux` y `smoke:dylanos`.
- `check_build_environment.py` exige 16 GiB combinados de RAM+swap y permite
  inyección de datos para pruebas.
- Xvfb fue instalado en el host; `xdotool` y `xprop` están disponibles.

## Build diagnóstico

- Unidad: `dylanos-browser-build-phase2.service`
- El último build diagnóstico fue detenido por el apagado del servicio mientras
  enlazaba `gkrust` con LTO; no produjo el binario ni el manifiesto.
- Log: `apps/dylanos-browser/artifacts/phase-2/build-diagnostic.log` (local e ignorado)
- Última actividad observada: compilación Rust/Gecko en torno a 46 minutos.
- La advertencia de documentación de `servo/components/style` y las advertencias
  heredadas de `swgl` son upstream; hasta ahora no constituyen errores de build.
- Siguen ausentes:
  - `engine/obj-x86_64-pc-linux-gnu/dist/bin/dylanos-browser`
  - `artifacts/phase-2/build-diagnostic.json`
- El primer intento fue interrumpido por el reinicio del host antes de producir
  error final; no se detectó error de compilador. El segundo intento reutiliza el
  objeto existente y continúa sin reiniciar manualmente.

Supervisión segura:

```bash
systemctl --user show dylanos-browser-build-phase2.service \
  -p ActiveState -p SubState -p MainPID -p ExecMainStatus -p Result
tail -80 apps/dylanos-browser/artifacts/phase-2/build-diagnostic.log
```

La unidad ya no está activa. Antes de reintentarlo hay que recuperar al menos 16 GiB
combinados de RAM+swap; el gate actual detecta 9,6 GiB y debe permanecer rojo.

## Swap temporal y prevención de OOM

El intento con dos trabajos agotó memoria/swap y reinició procesos del escritorio.
El build actual usa `gmake -j1` y dos swaps temporales:

- `/var/tmp/dylanos-browser-build.swap` — 8 GiB.
- `/var/tmp/dylanos-browser-build-extra.swap` — 4 GiB.
- `/swapfile` — 2 GiB preexistentes; no tocarlo.

Solo después de completar build diagnóstico y candidato, confirmar que no hay build
activo y que existe memoria suficiente; entonces retirar exactamente los dos swaps
temporales:

```bash
sudo swapoff /var/tmp/dylanos-browser-build-extra.swap
sudo swapoff /var/tmp/dylanos-browser-build.swap
sudo rm /var/tmp/dylanos-browser-build-extra.swap
sudo rm /var/tmp/dylanos-browser-build.swap
```

## Pasos exactos para terminar

1. Dejar finalizar el build diagnóstico activo. Si falla, conservar el log y usar
   diagnóstico sistemático antes de modificar scripts. Si termina, verificar el
   binario, `application.ini`, manifiesto, hashes y duración.
2. Ejecutar las pruebas reales contra el árbol efectivo una vez exista el binario:

   ```bash
   npm run lint
   npm test -- spaces
   npm test -- tabs
   npm test -- urlbar
   npm test -- migration
   npm run test:gtest
   npm run smoke:dylanos
   ```

3. Ejecutar el build candidato release con un servicio persistente equivalente y
   `bash scripts/dylanos/build_linux.sh candidate`. Verificar su mozconfig: LTO
   conservado cuando sea viable, tests desactivados para release y PGO documentado
   con honestidad si no puede usarse. Repetir el smoke contra el candidato.
4. Ejecutar desde cero todos los gates de cierre: `npm run test:dylanos`,
   `npm run lc`, `npm audit --omit=dev`, comprobación de entorno, `shellcheck`,
   `compileall`, Prettier de todas las rutas modificadas y `git diff --check`.
5. Solo con evidencia verde, crear el commit de Task 3:
   `test(browser): validar primer binario Linux`. El manifiesto del build actual
   reflejará `220ca7d` porque los scripts de Task 3 aún no estaban comprometidos al
   iniciarlo; no alterar ni falsear ese dato. Registrar la explicación.
6. Marcar Task 3 en el ledger mediante `task-done` usando el plan de
   `development`; si la identidad histórica del ledger impide la herramienta,
   registrar manualmente commit, comando y resultado reales sin reescribir Tasks 1-2.
7. Ejecutar Task 4 del plan en `/home/dylan/DylanOS`:
   artefacto fuente determinista, lock local de QA verificable y paquete Debian
   coexistente con Firefox ESR. No inventar URL pública ni hash estable.
   El árbol todavía no contiene un artefacto publicado; el host
   sí tiene `dpkg-buildpackage` y `debootstrap`, por lo que se puede crear el
   scaffold después de verificar el binario. El lock debe seguir usando `unpublished`
   hasta disponer de una ubicación autorizada.
8. Ejecutar Task 5: imagen de prueba y QEMU, QA funcional, captura de conexiones,
    verificación de defaults XDG y plan de Fase 3. QEMU 8.2.2 está instalado, pero
    `/dev/kvm` no existe; la VM usaría TCG y el árbol no tiene `work/chroot`.
    Dejar evidencia precisa del bloqueo y no declarar la puerta verde si no puede
    construirse una imagen limpia.
9. Retirar los swaps temporales como se indica arriba únicamente cuando ya no sean
   necesarios.
10. Hacer revisión completa de la rama y documentar terminados, pendientes y
    limitaciones. No sustituir Firefox, cambiar asociaciones globales ni afirmar
    benchmarks sin autorización y pruebas reproducibles. Publicar `development`
    solo después de verificar el binario real.

## Criterio de relevo

El siguiente agente debe continuar el proceso activo y los cambios existentes; no
repetir Tasks 1-2. Task 3 solo está completa cuando ambos builds exigidos, suites y
smoke tests tienen evidencia real. Tasks 4-5 siguen sujetas a todas las restricciones
globales del plan.
