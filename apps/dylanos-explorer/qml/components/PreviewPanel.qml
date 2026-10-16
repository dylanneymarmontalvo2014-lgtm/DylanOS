import QtQuick
import DylanOS.Explorer

// Right-hand details pane for the "preview" view mode.
Rectangle {
    id: root
    required property var ctl
    property var info: ({})
    property string currentPath

    color: Qt.rgba(0, 0, 0, 0.18)
    Rectangle { width: 1; height: parent.height; color: Theme.hairline }

    function refresh() {
        const paths = root.ctl.model.selectedPaths()
        if (paths.length === 1) { currentPath = paths[0]; info = root.ctl.properties(paths[0]) }
        else { currentPath = ""; info = ({ count: paths.length }) }
    }
    Component.onCompleted: refresh()
    Connections { target: root.ctl.model; function onSelectionChanged() { root.refresh() } }

    readonly property bool isImage: ["png", "jpg", "jpeg", "gif", "webp", "bmp"].indexOf((info.name || "").split(".").pop().toLowerCase()) >= 0

    Column {
        anchors { fill: parent; margins: 22 }
        spacing: 14
        visible: root.currentPath !== ""

        Rectangle {
            width: parent.width; height: 170; radius: 14
            color: Theme.card; border.width: 1; border.color: Theme.hairline
            clip: true
            Image {
                visible: root.isImage
                anchors { fill: parent; margins: 6 }
                source: root.isImage ? "file://" + encodeURI(root.currentPath) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 600
            }
            FileTypeIcon {
                visible: !root.isImage
                anchors.centerIn: parent
                size: 84
                isDir: !!root.info.isDir
                suffix: (root.info.name || "").split(".").pop()
            }
        }
        Txt { width: parent.width; text: root.info.name || ""; font.pixelSize: Theme.fontSection; font.weight: Font.Medium; wrapMode: Text.WrapAnywhere; maximumLineCount: 2 }
        Repeater {
            model: [
                ["Tipo", root.info.kind], ["Tamaño", root.info.isDir ? root.info.itemCount : root.info.sizeText],
                ["Modificado", root.info.modified], ["Permisos", root.info.permissions]
            ]
            delegate: Row {
                required property var modelData
                width: parent.width; spacing: 10
                Txt { width: 84; text: modelData[0]; color: Theme.textDim; font.pixelSize: Theme.fontSmall + 1 }
                Txt { width: parent.width - 94; text: modelData[1] || "—"; font.pixelSize: Theme.fontSmall + 1 }
            }
        }
    }
    EmptyState {
        visible: root.currentPath === ""
        anchors.centerIn: parent
        icon: "preview"
        title: (root.info.count || 0) > 1 ? root.info.count + " elementos seleccionados" : "Sin selección"
        detail: (root.info.count || 0) > 1 ? "" : "Selecciona un archivo para ver sus detalles."
    }
}
