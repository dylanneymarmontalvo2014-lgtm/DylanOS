# DylanOS Browser Phase 2 Implementation Plan

> **Para ejecución:** usar `subagent-driven-development` o `executing-plans`,
> respetar RED→GREEN y registrar resultados reales; no sustituir Firefox ESR.

**Objetivo:** producir el primer binario Linux x86_64 funcional de DylanOS Browser,
probarlo contra Gecko/Zen, generar un artefacto fuente verificable y preparar un
paquete Debian transitorio instalable junto a Firefox ESR.

**Arquitectura:** `DylanOS-Browser` sigue siendo la fuente del producto y descarga
Gecko mediante Surfer. `DylanOS` consume artefactos fijados por URL y SHA-256; no
compila Gecko durante el staging ni cambia defaults XDG en esta fase.

**Spec:** `docs/design/dylanos-browser.md`

**Estado de entrada verificado (2026-11-03):** `npm run download` e
`npm run import` ya se ejecutaron localmente sobre Firefox 159.0; los 273 parches
aplicaron correctamente y el contrato efectivo de seguridad pasó. Task 2 sigue
abierta porque faltan el manifiesto reproducible del entorno, `bootstrap`,
configuración/lint y los artefactos de evidencia. El remoto del fork aún no existe
o no es accesible, por lo que no hay CI remota ni artefactos autorizados.

## Restricciones globales

- Partir de los commits de Fase 1 y Firefox 159.0 fijado; una actualización de
  seguridad requiere un cambio de pin explícito y una nueva auditoría.
- No introducir secretos en el repositorio ni desactivar sandbox, Site Isolation,
  Safe Browsing, TLS o firmas de extensiones.
- El build de humo puede desactivar PGO para acortar diagnóstico; el candidato de
  paquete debe conservar PGO/LTO o documentar por qué no pudo hacerlo.
- Firefox ESR permanece instalado, predeterminado y visible hasta que el paquete
  transitorio supere las pruebas en chroot y VM.
- No publicar ni subir artefactos sin autorización explícita.

## Task 1: Convertir las comprobaciones rápidas en gates reproducibles

**Browser files:** `package.json`, `scripts/dylanos/check_build_environment.py`,
`scripts/dylanos/test_build_environment.py`, y un gate de licencia propio que
revise archivos modificados respecto de `upstream/stable` sin reescribir los 626
falsos/deudas heredados que reporta `surfer license-check` en 1.24b.

1. Escribir pruebas RED para Node 22, Python compatible, Rust 1.95.0, espacio libre
   mínimo de 30 GiB y herramientas Linux requeridas.
2. Implementar el diagnóstico sin instalar paquetes ni usar `sudo`.
3. Escribir pruebas RED del gate de licencia con repositorios temporales: un archivo
   nuevo sin MPL falla y el mismo archivo con encabezado pasa.
4. Mantener `surfer license-check` como auditoría upstream informativa y hacer que
   `npm run lc` sea un gate reproducible de los cambios DylanOS.
5. Ejecutar contratos, auditoría de dependencias y ambos gates; documentar cualquier
   CVE solo de desarrollo sin aplicar `npm audit fix` a ciegas.

**Commit:** `chore(browser): establecer gates reproducibles de bootstrap`

## Task 2: Bootstrap de Gecko y aplicación del overlay

**Browser outputs:** `engine/` ignorado, logs bajo `artifacts/bootstrap/` y un
manifiesto con versiones de Node, Python, Rust, clang y Surfer.

1. Verificar 30 GiB libres y guardar el manifiesto del entorno.
2. Ejecutar `npm ci` y `npm run download`; confirmar que la revisión descargada es
   Firefox 159.0 y no una versión flotante.
3. Ejecutar `npm run import`; el compilador `ffprefs` debe generar las cinco
   preferencias `dylanos.browser.*` en `engine/browser/app/profile/zen.js`.
4. Ejecutar `npm run bootstrap` sin interacción y conservar el log completo.
5. Ejecutar `./mach configure`/lint de las rutas modificadas y comprobar que no hay
   referencias a `updates.zen-browser.app` en el árbol efectivo.

**Commit:** solo scripts/manifiestos reproducibles; nunca `engine/`.

## Task 3: Compilación Linux y pruebas del binario

**Browser outputs:** objeto de build ignorado, resultados en `artifacts/phase-2/`.

1. Escribir primero un smoke test que exija binario `dylanos-browser`, app id propio,
   perfil temporal separado, arranque y cierre limpios y ausencia de conexiones al
   host de actualizaciones de Zen.
2. Compilar un build diagnóstico x86_64 con `SURFER_PLATFORM=linux`,
   `SURFER_COMPAT=x86_64`, PGO desactivado de forma explícita y LTO conservado cuando
   el flujo lo permita.
3. Ejecutar `npm run lint`, `npm test -- spaces`, `npm test -- tabs`,
   `npm test -- urlbar`, `npm test -- migration` y `npm run test:gtest`.
4. Ejecutar el smoke test bajo Xvfb con un HOME/perfil temporal; verificar ventana,
   URL local, nueva ventana, ventana privada y cierre sin crash.
5. Repetir el build candidato con la configuración release que usará el paquete y
   registrar duración, tamaño y hashes, sin afirmar mejoras de rendimiento.

**Commit:** `test(browser): validar primer binario Linux`

## Task 4: Artefacto fuente y paquete Debian transitorio

**DylanOS files:** `browser/debian/`, scripts de empaquetado, tests de paquete y
`browser/source.lock.json`.

1. Escribir pruebas RED del paquete: nombre/versión, binario, desktop ID, icono,
   MIME declarados, política de updater desactivado, fuente correspondiente y
   coexistencia con `firefox-esr`.
2. Generar un artefacto fuente determinista desde un tag local de candidato, calcular
   SHA-256 y verificar que se puede reconstruir en un directorio limpio.
3. Sustituir `unpublished` por una URL inmutable solo cuando el artefacto exista en
   una ubicación autorizada; antes de publicar, usar un repositorio/URI local de QA y
   no falsear el lock estable.
4. Construir el `.deb` transitorio con `dylanos-browser`,
   `org.dylanos.browser.desktop`, iconos propios, copyright/MPL y dependencias reales.
5. Instalar/desinstalar/reinstalar en el chroot; verificar que no sobrescribe Firefox,
   perfiles ni asociaciones existentes y que la desinstalación deja datos de usuario.

**Commit:** `feat(browser): añadir paquete Debian transitorio`

## Task 5: Validación en VM y puerta de salida

1. Construir una imagen de prueba con ambos navegadores y arrancarla en QEMU.
2. Probar navegación HTTPS, descargas, selector de archivos, notificaciones, extensión
   firmada, importación, nueva ventana y privada.
3. Confirmar que Firefox sigue siendo el default y que elegir DylanOS Browser mediante
   `xdg-settings` respeta la decisión del usuario sin mutaciones silenciosas.
4. Capturar conexiones de primer arranque e inventariar servicios Firefox/Zen/DylanOS;
   cualquier endpoint específico de Zen sin contrato propio bloquea la salida.
5. Ejecutar QA completa de ambos repositorios, guardar logs/hash y redactar el plan de
   Fase 3 para branding visual, ajustes, Crimson Glass y Quick Search.

**Puerta de salida:** binario y paquete reproducibles, smoke/VM verdes, fuente y hash
verificables, updater interno desactivado y limitaciones publicadas. No se retira
Firefox ESR ni se cambia el navegador predeterminado en esta fase.
