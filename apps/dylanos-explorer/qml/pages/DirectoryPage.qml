import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

Item {
    id: root
    required property var ctl
    signal itemContext(int row, real x, real y)
    signal backgroundContext(real x, real y)
    signal sortMenu(real x, real y)
    signal emptyTrashRequested()

    readonly property var model: ctl.model
    readonly property bool hasError: model.errorKind !== ""
    readonly property bool searching: ctl.searchText.trim() !== ""
    readonly property bool isEmpty: !hasError && model.count === 0
    readonly property bool showItems: !hasError && model.count > 0

    // path bar
    Item {
        id: bar
        width: parent.width; height: 48
        IconButton {
            x: 18; anchors.verticalCenter: parent.verticalCenter
            icon: "up"; iconSize: 18
            enabled: root.ctl.canGoUp
            onClicked: root.ctl.goUp()
        }
        Txt {
            x: 62; width: parent.width - 62 - 130
            anchors.verticalCenter: parent.verticalCenter
            text: root.searching ? "Resultados de «" + root.ctl.searchText.trim() + "» en " + root.ctl.title : (root.ctl.inTrash ? "Papelera" : root.ctl.location)
            color: Theme.textDim
            elide: Text.ElideMiddle
        }
        IconButton {
            id: eye
            anchors { right: sortBtn.left; rightMargin: 2; verticalCenter: parent.verticalCenter }
            icon: "eye"; iconSize: 18
            active: root.ctl.showHidden
            onClicked: root.ctl.showHidden = !root.ctl.showHidden
        }
        IconButton {
            id: sortBtn
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            icon: "sort"; iconSize: 18
            onClicked: { const p = sortBtn.mapToItem(null, 0, height + 4); root.sortMenu(p.x - 190, p.y) }
        }
        Rectangle { anchors.bottom: parent.bottom; x: 18; width: parent.width - 36; height: 1; color: Theme.hairline }
    }

    Rectangle {
        id: trashBanner
        visible: root.ctl.inTrash
        anchors { top: bar.bottom; left: parent.left; right: parent.right; margins: 14; topMargin: 10 }
        height: visible ? 46 : 0
        radius: 12
        color: Qt.rgba(0.88, 0.13, 0.18, 0.1)
        border.width: 1; border.color: Qt.rgba(0.9, 0.2, 0.25, 0.3)
        Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: "trash"; size: 18; color: Theme.accentLabel }
        Txt { x: 44; width: parent.width - 200; anchors.verticalCenter: parent.verticalCenter; text: "Los elementos de la papelera se pueden restaurar o eliminar definitivamente." }
        DButton {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: "Vaciar papelera"; variant: "danger"
            enabled: root.model.count > 0
            onClicked: root.emptyTrashRequested()
        }
    }

    Item {
        id: stage
        anchors {
            top: trashBanner.visible ? trashBanner.bottom : bar.bottom
            topMargin: trashBanner.visible ? 6 : 0
            bottom: status.top; left: parent.left; right: parent.right
        }

        FileGridView {
            anchors.fill: parent
            visible: root.showItems && root.ctl.viewMode === 0
            ctl: root.ctl
            onItemContext: (r, x, y) => root.itemContext(r, x, y)
            onBackgroundContext: (x, y) => root.backgroundContext(x, y)
        }
        FileListView {
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: preview.visible ? preview.left : parent.right }
            visible: root.showItems && (root.ctl.viewMode === 1 || root.ctl.viewMode === 3)
            ctl: root.ctl
            onItemContext: (r, x, y) => root.itemContext(r, x, y)
            onBackgroundContext: (x, y) => root.backgroundContext(x, y)
        }
        FileColumnsView {
            anchors.fill: parent
            visible: root.showItems && root.ctl.viewMode === 2
            ctl: root.ctl
            onItemContext: (r, x, y) => root.itemContext(r, x, y)
            onBackgroundContext: (x, y) => root.backgroundContext(x, y)
        }
        PreviewPanel {
            id: preview
            visible: root.showItems && root.ctl.viewMode === 3
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: 300
            ctl: root.ctl
        }

        // states
        MouseArea {
            visible: root.isEmpty
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: (m) => { const p = mapToItem(null, m.x, m.y); root.backgroundContext(p.x, p.y) }
        }
        EmptyState {
            visible: root.isEmpty
            anchors.centerIn: parent
            icon: root.searching ? "search" : (root.ctl.inTrash ? "trash" : "folder")
            title: root.searching ? "Sin resultados" : (root.ctl.inTrash ? "La papelera está vacía" : "Esta carpeta está vacía")
            detail: root.searching ? "No se encontró nada para «" + root.ctl.searchText.trim() + "». Prueba con otro nombre."
                                   : (root.ctl.inTrash ? "Los archivos que elimines aparecerán aquí." : "Haz clic derecho para crear una carpeta o pega archivos con Ctrl+V.")
            actionText: root.searching ? "Limpiar búsqueda" : ""
            onAction: root.ctl.searchText = ""
        }
        EmptyState {
            visible: root.hasError
            anchors.centerIn: parent
            icon: root.model.errorKind === "permission" ? "lock" : "warning"
            tint: Theme.danger
            title: root.model.errorKind === "permission" ? "Sin permiso para ver esta carpeta"
                   : root.model.errorKind === "notdir" ? "Esto no es una carpeta" : "La carpeta no existe"
            detail: root.model.errorKind === "permission" ? "Tu usuario no tiene permisos de lectura aquí. Explorer no usa privilegios elevados."
                    : root.model.errorKind === "notdir" ? "La ruta apunta a un archivo." : "Pudo haberse movido o eliminado."
            actionText: root.ctl.canGoBack ? "Volver" : "Ir a Inicio"
            onAction: root.ctl.canGoBack ? root.ctl.goBack() : root.ctl.goHome()
        }
    }

    Rectangle {
        id: status
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 34
        color: "transparent"
        Rectangle { width: parent.width; height: 1; color: Theme.hairline }
        Txt {
            x: 22; width: parent.width - 44; height: parent.height
            text: root.model.selectedCount > 0
                  ? root.model.selectedCount + (root.model.selectedCount === 1 ? " elemento seleccionado" : " elementos seleccionados") + " de " + root.model.count
                  : root.model.count + (root.model.count === 1 ? " elemento" : " elementos")
                    + (root.model.truncated ? " · resultados limitados, afina la búsqueda" : "")
            color: Theme.textDim
            font.pixelSize: Theme.fontSmall + 1
        }
    }
}
