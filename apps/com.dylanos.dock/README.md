# DylanOS Dock (`com.dylanos.dock`)

Plasmoid Plasma 6 alternativo de dock; **no es el dock que el layout predeterminado fija** (ese usa un panel Plasma con `org.kde.plasma.icontasks`). Su interfaz y delegados viven en `contents/ui/`; la configuración editable está en `contents/config/`.

La configuración del applet expone tamaño normal/hover de icono, espaciado, padding, opacidad, radio de esquinas, color de acento e indicador de app abierta. Esos controles configuran el plasmoid cuando el usuario lo añade a Plasma; no modifican el dock del perfil inicial si ese plasmoid no está activo.

No asumir que la animación o el render funcionen por el hecho de pasar las pruebas estáticas de tema; debe añadirse a una sesión Plasma para validación visual. Para el layout actualmente instalado, consulta [`../../themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js`](../../themes/lookandfeel/org.dylanos.crimson/contents/layouts/org.kde.plasma.desktop-layout.js) y la [guía de uso](../../docs/guia-de-uso.md).