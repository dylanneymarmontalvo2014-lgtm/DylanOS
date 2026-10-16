import QtQuick
import DylanOS.Explorer

Rectangle {
    id: root
    required property var ctl
    property alias text: input.text
    function focusField() { input.forceActiveFocus(); input.selectAll() }

    height: Theme.controlHeight
    radius: 10
    color: Theme.field
    border.width: 1
    border.color: input.activeFocus ? Theme.accentDeep : Theme.hairline

    Icon {
        x: 13
        anchors.verticalCenter: parent.verticalCenter
        name: "search"; size: 17; color: Theme.textDim
    }
    TextInput {
        id: input
        x: 40
        width: parent.width - 80
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        font.pixelSize: Theme.fontBase
        selectionColor: Theme.accentDeep
        clip: true
        onTextChanged: debounce.restart()
        Keys.onEscapePressed: { text = ""; root.ctl.searchText = ""; root.parent.forceActiveFocus() }
        Txt {
            visible: input.text === ""
            text: "Buscar archivos..."
            color: Theme.textFaint
        }
    }
    IconButton {
        visible: input.text !== ""
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        width: 28; height: 28
        icon: "close"; iconSize: 14
        onClicked: { input.text = ""; root.ctl.searchText = "" }
    }
    Timer {
        id: debounce
        interval: 250
        onTriggered: root.ctl.searchText = input.text
    }
    Connections {
        target: root.ctl
        function onSearchTextChanged() {
            if (root.ctl.searchText !== input.text && !debounce.running)
                input.text = root.ctl.searchText
        }
    }
}
