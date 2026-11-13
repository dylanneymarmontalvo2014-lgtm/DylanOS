# DylanOS Browser ISO 1.1 pre-beta Implementation Plan

> **Para agentes:** usar `executing-plans`, respetar RED→GREEN y no hacer commits
> hasta que la verificación final completa sea verde. Las casillas son el registro
> verificable de ejecución.

**Objetivo:** integrar el paquete Debian de DylanOS Browser en el build de la ISO
1.1 pre-beta, convertirlo en navegador inicial del sistema y demostrar que el cambio
no sobrescribe preferencias de usuarios existentes.

**Arquitectura:** el build candidato del fork produce un payload local determinista
con manifiesto SHA-256; `scripts/build.sh` exige ese payload, construye el `.deb`
dentro del chroot y lo instala antes de generar las cachés de escritorio. `stage.py`
aporta los metadatos XDG idempotentes y solo escribe defaults de sistema/skel; nunca
recorre ni modifica configuraciones de hogares existentes.

**Tecnologías:** Bash, Python 3/unittest, Debhelper 13, XDG `mimeapps.list`, Gecko/Zen.

**Spec:** petición del usuario del 2026-11-13; sustituye la restricción transitoria
de Fase 2 que mantenía Firefox ESR como predeterminado.

## Restricciones globales

- Destino: rama `development` y push SSH a `origin/development` después de QA verde.
- Conservar cambios locales ajenos; el checkout de entrada está limpio.
- El payload debe proceder de un build `candidate` real y verificarse por manifiesto,
  no mediante un binario ficticio ni una copia sin hashes.
- No publicar una URL de artefacto inexistente ni falsear `source.lock.json`.
- Los defaults HTTP/HTTPS/HTML se aplican a skel y sistema; los `mimeapps.list` de
  usuarios existentes son datos del usuario y deben permanecer byte a byte intactos.
- `stage.py` continúa exigiendo un root explícito y siendo idempotente.
- Un único commit final en español, después de todas las verificaciones solicitadas.

## Enfoque de revisión

- Payload truncado o alterado después del build: la verificación de hashes debe fallar.
- Payload con identidad distinta de DylanOS Browser: el empaquetado debe bloquearse.
- Chroot reanudado que conserva Firefox ESR: la fase final debe purgarlo.
- Staging repetido sobre una imagen con hogares reales: solo skel/defaults cambian.
- Checkout parcial sin artefacto candidato: el build debe fallar pronto con un mensaje
  accionable, no producir una ISO sin navegador.

---

### Tarea 1: Payload reproducible y contrato Debian

**Archivos:**
- Crear: `apps/dylanos-browser/scripts/dylanos/package_payload.py`
- Crear: `apps/dylanos-browser/scripts/dylanos/test_package_payload.py`
- Modificar: `apps/dylanos-browser/scripts/dylanos/build_linux.sh`
- Modificar: `apps/dylanos-browser/debian/rules`
- Modificar: `apps/dylanos-browser/debian/control`
- Modificar: `apps/dylanos-browser/debian/changelog`
- Modificar: `scripts/tests/test_browser_package.py`

**Produce:** un árbol `artifacts/phase-2/package` con wrapper en `usr/bin`, runtime
en `usr/lib/dylanos-browser` y `payload-manifest.json` determinista que registra modo,
identidad, commit fuente y SHA-256 de cada archivo regular.

- [ ] Escribir pruebas que fallen porque el preparador/verificador no existe.
- [ ] Ejecutar las pruebas dirigidas y confirmar el fallo esperado.
- [ ] Implementar preparación y verificación del payload; integrar el paso solo en
  `build_linux.sh candidate` y hacer que Debhelper ejecute el verificador.
- [ ] Ejecutar pruebas de payload y paquete; confirmar que pasan y que una alteración
  del runtime bloquea el empaquetado.

### Tarea 2: Integración en build/staging y defaults iniciales

**Archivos:**
- Modificar: `scripts/build.sh`
- Modificar: `scripts/stage.py`
- Modificar: `packages/build/packages.list`
- Modificar: `packages/default/packages.list`
- Modificar: `configs/default-apps.conf`
- Modificar: `configs/plasma/skel/mimeapps.list`
- Modificar: `apps/com.dylanos.dock/contents/ui/main.qml`
- Modificar: `apps/com.dylanos.activeapp/contents/ui/ActiveAppLogic.js`
- Modificar: `apps/workspace/backend.py`
- Modificar: `scripts/tests/test_staging.py`
- Modificar: `scripts/tests/test_packages.sh`
- Modificar: `scripts/tests/test_shell_contract.py`
- Modificar: `scripts/tests/test_browser_contract.py`
- Modificar: `scripts/tests/test_activeapp_logic.js`

**Consume:** el payload verificado de la Tarea 1.

**Produce:** un `.deb` instalado en el chroot, Firefox ESR ausente incluso con
`--resume`, launcher/icono propios y defaults `org.dylanos.browser.desktop` para
`text/html`, HTTP y HTTPS sin escritura sobre hogares existentes.

- [ ] Escribir primero las aserciones de build, staging, listas, dock/workspace y
  preservación de un `mimeapps.list` preexistente bajo `/home/alice`.
- [ ] Ejecutar las suites dirigidas y confirmar que fallan por el estado Firefox.
- [ ] Implementar el cambio mínimo en build, staging y configuraciones.
- [ ] Repetir las suites dirigidas hasta obtener salida verde y limpia.

### Tarea 3: Documentación viva, QA final y publicación

**Archivos:**
- Modificar: `AGENTS.md`
- Modificar: `docs/architecture.md`
- Modificar: `apps/dylanos-browser/README.md`
- Modificar: `apps/dylanos-browser/docs/dylanos-packaging.md`
- Modificar: `docs/plans/dylanos-browser-iso-1.1-pre-beta.md`

- [ ] Actualizar solo documentación viva y eliminar afirmaciones obsoletas de que el
  navegador no se empaqueta, sin reescribir registros históricos.
- [ ] Ejecutar tests dirigidos, tests del navegador, `scripts/check.sh`, validaciones
  de shell/diff y una prueba reproducible de construcción Debian con fixture real.
- [ ] Revisar el diff completo y comprobar que no incluye cambios ajenos ni artefactos.
- [ ] Crear `feat(browser): integrar navegador predeterminado en la ISO` y hacer push
  normal por SSH a `origin development`; nunca usar force-push.
