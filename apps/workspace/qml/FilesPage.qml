import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: filesPage
    spacing: 14
    property string selectedPath: ""
    property string selectedName: ""
    property bool grid: false
    property var filtered: backend.files.filter(item => item.name.toLowerCase().includes(search.text.toLowerCase()))
    Connections { target: backend; function onFilesChanged() { filesPage.selectedPath = "" } }
    Shortcut { sequence: "Alt+Left"; onActivated: backend.back() }
    Shortcut { sequence: "Alt+Up"; onActivated: backend.up() }
    Shortcut { sequence: "Ctrl+L"; onActivated: { location.forceActiveFocus(); location.selectAll() } }
    Shortcut { sequence: "F5"; onActivated: backend.refresh() }
    RowLayout {
        Layout.fillWidth: true; spacing: 7
        ActionButton { text: "‹"; enabled: backend.canBack && !backend.busy; onClicked: backend.back(); Accessible.name: "Atrás" }
        ActionButton { text: "›"; enabled: backend.canForward && !backend.busy; onClicked: backend.forward(); Accessible.name: "Adelante" }
        ActionButton { text: "↑"; enabled: !backend.busy; onClicked: backend.up(); Accessible.name: "Carpeta superior" }
        Field { id: location; text: backend.folder; Layout.fillWidth: true; selectByMouse: true; onAccepted: backend.navigate(text); Accessible.name: "Ruta de la carpeta" }
        ActionButton { text: filesPage.grid ? "Lista" : "Iconos"; onClicked: filesPage.grid = !filesPage.grid }
    }
    RowLayout {
        Layout.fillWidth: true
        Field { id: search; placeholderText: "Buscar en esta carpeta"; Layout.fillWidth: true; selectByMouse: true }
        CheckBox { text: "Ocultos"; onToggled: backend.showHidden(checked) }
        ActionButton { text: "Nueva carpeta"; enabled: !backend.busy; onClicked: { nameDialog.renaming = false; nameInput.text = ""; nameDialog.open() } }
    }
    RowLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
        Surface {
            Layout.preferredWidth: 156; Layout.fillHeight: true; padding: 10
            ColumnLayout {
                anchors.fill: parent; spacing: 4
                Label { text: "FAVORITOS"; font.pixelSize: 9; color: palette.placeholderText; Layout.margins: 9; font.letterSpacing: 1 }
                Repeater {
                    model: backend.places
                    delegate: Selectable { required property var modelData; text: modelData.name; Layout.fillWidth: true; highlighted: backend.folder === modelData.path; onClicked: backend.navigate(modelData.path) }
                }
                Item { Layout.fillHeight: true }
                ActionButton { text: "Abrir en Dolphin"; Layout.fillWidth: true; onClicked: backend.openProject(backend.folder, "files") }
            }
        }
        Surface {
            Layout.fillWidth: true; Layout.fillHeight: true; padding: 8
            StackLayout {
                anchors.fill: parent; currentIndex: filesPage.grid ? 1 : 0
                ListView {
                    id: listing; clip: true; model: filesPage.filtered; spacing: 2
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Selectable {
                        id: fileRow
                        required property var modelData
                        width: listing.width; height: 58
                        highlighted: filesPage.selectedPath === modelData.path
                        onClicked: { filesPage.selectedPath = modelData.path; filesPage.selectedName = modelData.name }
                        onDoubleClicked: backend.openFile(modelData.path)
                        contentItem: RowLayout {
                            spacing: 13
                            Label { text: fileRow.modelData.folder ? "▰" : "▤"; color: fileRow.modelData.folder ? "#83b8f2" : "#d9afbb"; font.pixelSize: 29; Layout.preferredWidth: 36 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Label { text: fileRow.modelData.name; elide: Text.ElideMiddle; Layout.fillWidth: true; font.pixelSize: 13 }
                                Label { text: fileRow.modelData.modified; font.pixelSize: 10; color: palette.placeholderText }
                            }
                            Label { text: fileRow.modelData.size; font.pixelSize: 11; color: palette.placeholderText }
                        }
                    }
                    Label { anchors.centerIn: parent; visible: listing.count === 0 && !backend.busy; text: search.text ? "No hay coincidencias." : "Esta carpeta está vacía."; color: palette.placeholderText }
                }
                GridView {
                    id: iconView; clip: true; model: filesPage.filtered
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 125))); cellHeight: 116
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Selectable {
                        required property var modelData
                        width: iconView.cellWidth - 5; height: 108
                        highlighted: filesPage.selectedPath === modelData.path
                        onClicked: { filesPage.selectedPath = modelData.path; filesPage.selectedName = modelData.name }
                        onDoubleClicked: backend.openFile(modelData.path)
                        contentItem: ColumnLayout {
                            Label { text: modelData.folder ? "▰" : "▤"; font.pixelSize: 44; color: modelData.folder ? "#83b8f2" : "#d9afbb"; Layout.alignment: Qt.AlignHCenter }
                            Label { text: modelData.name; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { text: backend.busy ? "Trabajando…" : filesPage.filtered.length + " elementos"; color: palette.placeholderText; font.pixelSize: 11; Layout.fillWidth: true }
        ActionButton { text: "Abrir"; enabled: filesPage.selectedPath !== ""; onClicked: backend.openFile(filesPage.selectedPath) }
        ActionButton { text: "Copiar"; enabled: filesPage.selectedPath !== ""; onClicked: backend.copy(filesPage.selectedPath) }
        ActionButton { text: "Pegar"; enabled: !backend.busy; onClicked: backend.paste() }
        ActionButton { text: "Renombrar"; enabled: filesPage.selectedPath !== "" && !backend.busy; onClicked: { nameDialog.renaming = true; nameInput.text = filesPage.selectedName; nameDialog.open() } }
        ActionButton { text: "Papelera"; enabled: filesPage.selectedPath !== "" && !backend.busy; onClicked: trashDialog.open() }
    }
    Dialog {
        id: nameDialog; property bool renaming: false
        title: renaming ? "Renombrar elemento" : "Nueva carpeta"; modal: true; anchors.centerIn: parent; width: 370
        standardButtons: Dialog.Ok | Dialog.Cancel
        Field { id: nameInput; width: parent.width; placeholderText: "Nombre"; selectByMouse: true }
        onOpened: { nameInput.forceActiveFocus(); nameInput.selectAll() }
        onAccepted: renaming ? backend.rename(filesPage.selectedPath, nameInput.text) : backend.newFolder(nameInput.text)
    }
    Dialog {
        id: trashDialog; title: "Mover a la papelera"; modal: true; anchors.centerIn: parent; width: 400
        standardButtons: Dialog.Ok | Dialog.Cancel
        Label { text: "¿Mover «" + filesPage.selectedName + "» a la papelera? Puedes recuperarlo desde Dolphin."; width: parent.width; wrapMode: Text.Wrap }
        onAccepted: backend.trash(filesPage.selectedPath)
    }
}
