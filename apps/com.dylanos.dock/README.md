# DylanOS Dock (`com.dylanos.dock`)

Plasmoid de dock para Plasma 6, integrado en el layout predeterminado de DylanOS. Su interfaz y delegados viven en `contents/ui/`; la configuración editable está en `contents/config/`.

La configuración del applet expone tamaño normal/hover de icono, espaciado, padding, opacidad, radio de esquinas, color de acento e indicador de app abierta. Al acercar el cursor, el icono bajo el puntero crece y los dos vecinos a cada lado aumentan progresivamente con una animación breve; al salir, todos vuelven suavemente al tamaño normal. El tamaño máximo predeterminado se ha ajustado a 64 px para un zoom moderado. Las pruebas verifican el contrato de QML y staging, pero el efecto visual final debe confirmarse en una sesión real de Plasma 6. Esos controles configuran el plasmoid integrado en los perfiles nuevos; los usuarios que ya tengan un perfil no reciben una sustitución automática del panel.

No asumir que la animación o el render funcionen por el hecho de pasar las pruebas estáticas de tema; debe añadirse a una sesión Plasma para validación visual. El layout de perfiles nuevos incluye el plasmoid y conserva la papelera al final del panel. Los perfiles Plasma existentes no se sobrescriben. Para el layout consulta [`../../themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js`](../../themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js) y la [guía de uso](../../docs/guia-de-uso.md).

## Zoom suave del dock (2026-10-24)

El dock predeterminado ahora usa este plasmoid de DylanOS. La ampliación es
local, sin procesos ni sondeos: icono bajo el puntero hasta 64 px, vecinos
próximos con escalas intermedias y animación OutCubic de 170 ms. Al salir del
dock, los iconos vuelven a su tamaño base de 48 px. Se conserva la lista de
apps fijadas que tenía el layout y la papelera como widget del panel.


## Corrección del dock vacío (2026-10-24)

El ancho mínimo del applet ahora se calcula con la cantidad real de entradas
del modelo y el tamaño configurado de cada delegado. Antes se leía
`dockRow.implicitWidth` desde fuera de `dockContent`, donde ese id no está en
alcance QML; el error impedía que Plasma asignara correctamente el espacio al
dock y en la captura solo aparecía la papelera del panel. La prueba de contrato
verifica el cálculo independiente del componente. El render visual final debe
confirmarse en Plasma; la prueba de código no sustituye esa QA.


## Tamaños seguros

El tamaño base y el tamaño máximo al pasar el cursor se configuran por separado.
El dock reserva el mayor de los dos para el ancho/alto de sus celdas y trata un
`hoverSize` menor que `iconSize` como el tamaño base, evitando recortes o
solapamientos con configuraciones guardadas fuera del rango visual esperado.
