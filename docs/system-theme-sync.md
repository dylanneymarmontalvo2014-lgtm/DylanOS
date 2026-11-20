# Modo claro y oscuro en DylanOS

DylanOS Configuration es el punto de control del tema del escritorio. En **Personalización → Tema**, aplica el esquema de color de Plasma `DylanOSDark` o `DylanOSLight`. `SystemService.dark` determina el modo a partir del esquema activo y vigila los cambios de `~/.config/kdeglobals`.

Las aplicaciones no mantienen un segundo ajuste propio ni invocan la ventana de Configuration en cada arranque. Se conectan a la paleta pública que Qt/Plasma publica para la sesión, de modo que un cambio hecho en Configuration se refleja en sus propiedades QML mientras están abiertas:

- Las aplicaciones Qt Quick de DylanOS usan `SystemPalette` para determinar la luminosidad del esquema y seleccionar su paleta clara u oscura. Las paletas conservan el acento Crimson.
- Los plasmoides y widgets usan `PlasmaCore.Theme.textColor` / `disabledTextColor` para el texto y seleccionan el material claro u oscuro a partir de la paleta activa.
- Los temas de Explorer, Process y Store exponen ambos juegos de tokens y mantienen las mismas métricas y funciones.
- DylanOS Browser usa sus hojas `schemes/light.inc.css` y `schemes/dark.inc.css` según la preferencia de tema oscuro del sistema Firefox/Plasma.
- DylanOS Workspace ya no guarda un modo visual independiente: su control de tema pide a la integración del sistema que aplique el modo mediante la misma ruta que DylanOS Configuration.

## Límites y comportamiento

El tema cambia apariencia, no activa ni desactiva funciones. Las actualizaciones del esquema de Plasma se propagan mediante la paleta del framework; algunos componentes nativos de terceros pueden depender de su propio soporte de colores del sistema. No se promete que páginas web dentro del navegador cambien su contenido: esto afecta la interfaz del navegador y las aplicaciones DylanOS, no fuerza un modo oscuro/claro en sitios web.

La apariencia propia del navegador puede tener ajustes de tema adicionales de Firefox. Los colores codificados que representan estados, gráficos de datos, logotipos o el acento Crimson se mantienen deliberadamente; no se invierten por luminancia.

## Verificación

`python3 -m unittest scripts.tests.test_system_theme_sync` comprueba el contrato de conexión con el modo del sistema, la existencia de paletas de ambas variantes y el seguimiento del tema en los 20 paquetes de widgets. También valida que el navegador conserve ambas hojas de esquema. Esa prueba es estática; no sustituye una inspección visual de las apps abiertas en una sesión Plasma con ambos esquemas.
