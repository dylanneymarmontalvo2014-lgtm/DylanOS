# Plasmoid DylanOS Active App

ID `com.dylanos.activeapp`. Muestra el nombre de la ventana activa mediante `TaskManager.TasksModel` y toma el ancho disponible del panel; si no hay una ventana activa, muestra «DylanOS». Se usa en la barra superior del layout inicial. No es un selector/lista de tareas: el dock inferior proporciona las tareas (`org.kde.plasma.icontasks`).

QML: `contents/ui/main.qml`; metadata: `metadata.json`. Ver [índice de plasmoids](../com.dylanos.search/README.md), [guía del escritorio](../../docs/guia-de-uso.md) y [`test_shell_contract.py`](../../scripts/tests/test_shell_contract.py).