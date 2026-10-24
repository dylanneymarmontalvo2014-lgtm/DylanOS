# Plasmoid DylanOS Search (`com.dylanos.search`)

Botón de lupa compacto para panel Plasma 6. Al pulsarlo lanza `dylanos-spotlight`; el atajo global configurado en `configs/plasma/skel/kglobalshortcutsrc` es `Ctrl+Space` (en la UI se muestra Ctrl+Espacio). No contiene el motor de búsqueda: ese vive en [`../dylanos-spotlight/README.md`](../dylanos-spotlight/README.md) y [`../dylanos-spotlight/backend.py`](../dylanos-spotlight/backend.py).

QML: `contents/ui/main.qml`; metadata: `metadata.json`. El icono puede ejecutarse si `dylanos-spotlight` está instalado. Revisa el [índice de plasmoids](../com.dylanos.activeapp/README.md), la [guía general](../../docs/guia-de-uso.md) y el [contrato del shell](../../scripts/tests/test_shell_contract.py).