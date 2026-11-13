<!--
   - This Source Code Form is subject to the terms of the Mozilla Public
   - License, v. 2.0. If a copy of the MPL was not distributed with this
   - file, You can obtain one at http://mozilla.org/MPL/2.0/.
   -->

# DylanOS Browser

DylanOS Browser es el navegador de DylanOS Crimson, construido sobre Gecko a partir de
un fork mantenible de Zen Browser. Este árbol vive dentro de
`DylanOS/apps/dylanos-browser` y contiene el producto, sus parches, pruebas y
empaquetado Debian; la distribución principal aporta el staging y la integración ISO.

La ISO 1.1 pre-beta integra el candidato Linux como navegador predeterminado. El
artefacto sigue siendo local: no existe todavía una URL pública autorizada y el contrato
`source.lock.json` lo declara honestamente como `unpublished`.

## Procedencia reproducible

La base inicial es [Zen Browser](https://github.com/zen-browser/desktop), etiqueta
`1.24b`, commit `f75390aa2b797ddc3524ff9ed52ceb32a839f9fa`, sobre Firefox 159.0.
El registro legible por máquinas se conserva en `dylanos/upstream.json`.

El código correspondiente se mantiene dentro del repositorio DylanOS. El remoto
histórico `DylanOS-Browser` no es una dependencia de compilación ni una fuente
separada. DylanOS Browser no está afiliado ni respaldado por Mozilla ni por el proyecto Zen. Mozilla, Firefox,
Zen y sus logotipos pertenecen a sus respectivos titulares.

## Licencia

El código cubierto continúa disponible bajo la Mozilla Public License 2.0
(`MPL-2.0`). Se conservan el archivo `LICENSE`, los avisos de autoría y los encabezados
de licencia del proyecto upstream. La marca DylanOS se distribuye por separado y no
concede derechos sobre marcas de terceros.

## Desarrollo

La rama de integración es `development`. Antes de enviar cambios, ejecuta las pruebas
del producto y los gates diferenciales:

```bash
npm run check:environment
npm run test:dylanos
npm run lc
npm audit --omit=dev
```

`npm run lc` revisa los archivos nuevos de DylanOS y protege encabezados MPL
existentes sin convertir los 626 hallazgos heredados de Zen 1.24b en una reescritura
masiva. `npm run lc:upstream` conserva esa auditoría completa como diagnóstico
informativo. Las cinco alertas actuales del toolchain son dependencias de desarrollo;
el árbol de producción informa cero vulnerabilidades con `npm audit --omit=dev`.

### Bootstrap de Gecko

El bootstrap reproducible descarga Firefox 159.0, aplica el overlay del producto,
prepara el toolchain de Mozilla, configura el árbol efectivo y ejecuta lint, contratos,
licencias y auditoría de dependencias:

```bash
npm run bootstrap:dylanos
```

Los manifiestos de procedencia, versiones del toolchain y logs se generan bajo
`artifacts/bootstrap/`. Ese directorio es evidencia local y está fuera del control de
versiones; `engine/` también permanece como árbol generado. El script añade
`~/.cargo/bin` únicamente al proceso de lint para que Gecko pueda localizar y ejecutar
`cargo-audit` después de instalarlo.

### Build Linux y smoke test

El build diagnóstico conserva las suites Gecko/Zen habilitadas. El candidato activa
la configuración release y ThinLTO; ambos fijan Linux x86_64 y desactivan PGO de forma
explícita para esta fase:

```bash
npm run build:linux -- diagnostic
npm run build:linux -- candidate
npm run smoke:dylanos
```

Cada build genera bajo `artifacts/phase-2/` un log y un manifiesto con duración,
tamaño y hashes SHA-256. El modo `candidate` genera además `package/`: un wrapper en
`usr/bin`, el runtime en `usr/lib/dylanos-browser` y `payload-manifest.json` con el
inventario determinista que Debhelper vuelve a verificar. El smoke test se ejecuta en Xvfb con HOME y perfil temporales,
abre una URL local, una ventana nueva y otra privada, verifica la identidad de la
ventana y rechaza tráfico hacia el servidor de actualizaciones de Zen.
El build usa un job por defecto para mantenerse dentro de 8 GiB de RAM cuando Rust
aplica LTO; `DYLANOS_BUILD_JOBS` permite aumentarlo en hosts con más memoria.
El gate exige al menos 16 GiB combinados de RAM y swap para evitar que el enlazado
Rust sea terminado por el OOM killer.

Para construir la ISO después del candidato:

```bash
cd ../..
./scripts/build.sh --resume
```

`DYLANOS_BROWSER_ARTIFACT=/ruta/al/package` permite probar otro candidato. El build
falla antes del staging si falta el manifiesto, cambia cualquier SHA-256 o la identidad
Gecko no corresponde a DylanOS Browser.

Los cambios heredados de Zen conservan sus autores y pueden consultarse en el historial
del repositorio y en sus [guías de contribución](./docs/contribute.md).
