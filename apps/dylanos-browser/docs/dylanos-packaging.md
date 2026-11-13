# Contrato de empaquetado de DylanOS Browser

`apps/dylanos-browser/` contiene la fuente vendorizada, el empaquetado Debian y los
gates que conectan un build Gecko real con la ISO de DylanOS 1.1 pre-beta. La fuente
upstream permanece fijada por `dylanos/upstream.json` y `source.lock.json`.

`source.lock.json` conserva `source_archive` y `sha256` como `unpublished` mientras
no exista una URL pública autorizada. Eso no se reemplaza por una URL ficticia para
builds locales: el candidato queda ligado al checkout mediante su commit y el
inventario SHA-256 del payload.

## Producir el candidato

```bash
npm run build:linux -- candidate
```

El build release crea el runtime Gecko y ejecuta
`scripts/dylanos/package_payload.py prepare`. El resultado queda ignorado bajo
`artifacts/phase-2/package/`:

- `usr/bin/dylanos-browser`: wrapper estable del sistema;
- `usr/lib/dylanos-browser/`: runtime completo;
- `payload-manifest.json`: esquema, modo `candidate`, commit fuente, desktop ID y
  metadatos/hash SHA-256 de cada archivo regular, además de destinos de symlinks.

Durante la preparación se materializan los enlaces del árbol de compilación para que
el runtime no dependa de rutas del host. Un enlace roto bloquea la preparación; si un
payload conserva algún enlace, el verificador exige que resuelva dentro del propio
payload y también lo incluye en el inventario, aunque apunte a un directorio.

La verificación es reproducible e independiente del build largo:

```bash
python3 scripts/dylanos/package_payload.py verify \
  --payload artifacts/phase-2/package
python3 -m unittest discover -v scripts/dylanos 'test_*.py'
```

Un archivo faltante, extra o alterado; un modo distinto de `candidate`; un wrapper
no canónico; o una identidad distinta de DylanOS Browser bloquean el paquete.

## Integración Debian e ISO

`scripts/build.sh` valida primero el payload en el host. Después copia al chroot solo
el payload, `debian/` y el verificador, ejecuta `dpkg-buildpackage -b -us -uc` sobre
Debian 13 e instala el `.deb` resultante con APT. `DYLANOS_BROWSER_ARTIFACT` permite
elegir otro directorio de candidato.

El paquete instala el runtime, el launcher `org.dylanos.browser.desktop`, el icono,
la política `DisableAppUpdate` y una copia del manifiesto en
`/usr/share/doc/dylanos-browser`. APT es la autoridad de actualización; el navegador
no usa el actualizador heredado de Zen.

Firefox ESR no se envía en la ISO y `build.sh` lo purga también de chroots reanudados.
Los defaults XDG de sistema y skel asignan HTML, HTTP y HTTPS al desktop ID de DylanOS
Browser. No hay scripts `postinst` ni llamadas a `xdg-settings`, y `stage.py` no
recorre hogares existentes: una preferencia ya elegida por el usuario no se modifica.

## Actualizar la base o publicar un artefacto

1. Actualizar y auditar la base en `dylanos/upstream.json`.
2. Ejecutar bootstrap, suites Gecko/DylanOS, build candidato y smoke test.
3. Regenerar el payload y verificarlo desde un directorio limpio.
4. Si existe una ubicación pública autorizada, publicar el artefacto fuente inmutable
   y actualizar juntos `source_archive` y `sha256`; nunca solo uno.
5. Ejecutar la QA completa de DylanOS y una instalación/purga/reinstalación del `.deb`
   dentro del chroot antes de generar la ISO.
