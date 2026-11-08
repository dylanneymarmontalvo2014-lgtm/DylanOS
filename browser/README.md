# Contrato de fuente de DylanOS Browser

Este directorio fija la fuente que DylanOS consumirá cuando exista un artefacto
publicado y verificable de DylanOS Browser. En la Fase 1 solo existe el contrato:
el navegador aún no está compilado, empaquetado ni instalado por DylanOS, y Firefox
ESR continúa siendo el navegador funcional de la imagen.

`source.lock.json` es la única referencia de versión para el empaquetado futuro.
Registra el fork, la base Zen/Firefox, el binario, el ID XDG y la autoridad de
actualización. Los valores `source_archive` y `sha256` permanecen como
`unpublished`; ambos deben sustituirse por una URL inmutable y un SHA-256 real
antes de que la Fase 2 pueda instalar cualquier paquete del navegador.

## Actualizar el pin

1. Integrar y probar la nueva base en la rama `development` de
   `DylanOS-Browser`, conservando su registro `dylanos/upstream.json`.
2. Crear una versión identificable y publicar su artefacto fuente correspondiente.
3. Descargar el artefacto en un entorno limpio, calcular su SHA-256 y comprobar
   que reproduce el árbol esperado.
4. Actualizar conjuntamente la versión, los datos upstream, `source_archive` y
   `sha256`; nunca actualizar solo la URL o solo el hash.
5. Ejecutar `python3 -m unittest -v scripts.tests.test_browser_contract` y la QA
   completa de DylanOS antes de preparar el paquete Debian.

APT será la autoridad de actualización del paquete estable. El navegador interno
no debe contactar servidores de actualización de Zen ni sustituir archivos
administrados por el paquete.

## Estado verificado de la Fase 1

La Fase 1 valida el fork, la procedencia, la identidad técnica, las preferencias
base y este contrato de distribución. No valida todavía:

- un binario Gecko compilado o un paquete instalable;
- benchmarks de memoria, CPU, GPU o tiempo de arranque;
- asociaciones XDG ni selección como navegador predeterminado;
- renderizado de Crimson Glass en X11 o Wayland;
- paridad funcional de pestañas horizontales;
- el SLA operativo de incorporación de parches de seguridad.

Ninguno de esos puntos debe anunciarse como terminado hasta superar la Fase 2 o
la fase específica posterior que lo implemente y mida.

## Scaffold Debian de Fase 2

`debian/` contiene únicamente el contrato inicial del paquete transitorio:
metadatos, reglas Debhelper, manifiesto de instalación, política de updater
desactivado y el lanzador XDG. Las reglas rechazan el empaquetado mientras no
exista un artefacto real en
`artifacts/phase-2/package/usr/bin/dylanos-browser`; no se incluye ni se simula
ningún binario en este repositorio.

La construcción final del `.deb` queda bloqueada hasta que `DylanOS-Browser`
produzca y autorice ese binario y su árbol de runtime. Hasta entonces,
`source.lock.json` conserva deliberadamente `source_archive` y `sha256` como
`unpublished`, Firefox ESR permanece en el perfil predeterminado y no se instala
nada en el chroot.

La revisión de cierre aplicó los 273 parches del fork sobre Firefox 159.0 y
verificó el árbol Gecko efectivo. Se conserva la política oficial de firma de
extensiones, se restauró la validación de certificados del actualizador, el perfil
usa un directorio propio y las rutas de publicación heredadas de Zen quedan
inactivas hasta disponer de infraestructura y claves de DylanOS. Esta importación
no equivale todavía a una compilación ni a una validación del binario.

El remoto declarado para `DylanOS-Browser` todavía no existe o no es accesible.
El fork verificable permanece local; no debe publicarse un lock estable ni activar
CI de publicación hasta crear el repositorio remoto con autorización explícita.
