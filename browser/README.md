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
