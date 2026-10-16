import QtQuick
import DylanOS.Explorer

DlgBase {
    id: root
    required property var ctl
    width: 480
    icon: "gear"
    title: "Configuración"

    component Toggle: Rectangle {
        id: t
        property bool checked
        signal toggled(bool value)
        width: 42; height: 24; radius: 12
        color: checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.14)
        Behavior on color { ColorAnimation { duration: 100 } }
        Rectangle {
            y: 3; x: t.checked ? 21 : 3; width: 18; height: 18; radius: 9; color: "#fff"
            Behavior on x { NumberAnimation { duration: 110 } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled(!t.checked) }
    }
    component Row2: Item {
        id: r
        property string label
        property string hint
        default property alias control: slot.data
        width: parent.width; height: 48
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 160
            Txt { width: parent.width; text: r.label }
            Txt { width: parent.width; text: r.hint; color: Theme.textFaint; font.pixelSize: Theme.fontSmall }
        }
        Item { id: slot; anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 150; height: 30 }
    }

    Row2 {
        label: "Mostrar archivos ocultos"; hint: "Los que empiezan por punto (Ctrl+H)"
        Toggle { anchors.right: parent.right; checked: root.ctl.showHidden; onToggled: (v) => root.ctl.showHidden = v }
    }
    Row2 {
        label: "Confirmar antes de enviar a la papelera"; hint: "Eliminar definitivamente siempre pide confirmación"
        Toggle { anchors.right: parent.right; checked: root.ctl.confirmTrash; onToggled: (v) => root.ctl.confirmTrash = v }
    }
    Row2 {
        label: "Vista predeterminada"; hint: ""
        ViewToggle { anchors.right: parent.right; width: 150; height: 30; mode: root.ctl.viewMode; onModeSelected: (m) => root.ctl.viewMode = m }
    }
    Column {
        width: parent.width; spacing: 6
        Txt { text: "Dirección del Servidor DLN"; width: parent.width }
        Rectangle {
            width: parent.width; height: 40; radius: 10
            color: Theme.field; border.width: 1
            border.color: urlInput.activeFocus ? Theme.accentDeep : Theme.hairline
            TextInput {
                id: urlInput
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text; font.pixelSize: Theme.fontBase
                selectionColor: Theme.accentDeep
                text: root.ctl.serverUrl
                clip: true
                onEditingFinished: root.ctl.serverUrl = text.trim()
                Txt { visible: urlInput.text === ""; text: "smb://servidor/compartido"; color: Theme.textFaint }
            }
        }
    }
    footer: [ DButton { text: "Listo"; variant: "primary"; onClicked: { root.ctl.serverUrl = urlInput.text.trim(); root.close() } } ]
}
