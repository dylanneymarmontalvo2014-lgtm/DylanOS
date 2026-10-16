import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

// items: [{ id, text, icon, danger, enabled, checked, separator }]
Popup {
    id: root
    property var items: []
    signal triggered(string id)

    function openAt(list, x, y) {
        items = list
        root.x = x
        root.y = y
        open()
    }

    parent: Overlay.overlay
    padding: 6
    margins: 8
    width: 232
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 70 } }

    background: Rectangle {
        radius: 14
        color: Theme.popup
        border.width: 1
        border.color: Theme.border
    }

    contentItem: Column {
        spacing: 1
        Repeater {
            model: root.items
            delegate: Item {
                id: entry
                required property var modelData
                readonly property bool sep: !!modelData.separator
                readonly property bool on: modelData.enabled !== false
                width: root.width - root.padding * 2
                height: sep ? 9 : 34

                Rectangle {
                    visible: entry.sep
                    anchors.centerIn: parent
                    width: parent.width - 12; height: 1
                    color: Theme.hairline
                }
                Rectangle {
                    visible: !entry.sep
                    anchors.fill: parent
                    radius: 9
                    color: area.containsMouse && entry.on
                           ? (entry.modelData.danger ? Qt.rgba(1, 0.3, 0.35, 0.16) : Theme.accentDeep) : "transparent"
                }
                Icon {
                    visible: !entry.sep && !!entry.modelData.icon
                    x: 11; anchors.verticalCenter: parent.verticalCenter
                    name: entry.modelData.icon || ""
                    size: 17
                    color: entry.modelData.danger ? Theme.danger : Theme.textDim
                    opacity: entry.on ? 1 : 0.4
                }
                Txt {
                    visible: !entry.sep
                    x: 38; width: parent.width - 68
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.text || ""
                    color: entry.modelData.danger ? Theme.danger : Theme.text
                    opacity: entry.on ? 1 : 0.4
                }
                Icon {
                    visible: !!entry.modelData.checked
                    x: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                    name: "check"; size: 15; color: Theme.accentLabel
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    enabled: !entry.sep && entry.on
                    hoverEnabled: true
                    onClicked: { root.close(); root.triggered(entry.modelData.id) }
                }
            }
        }
    }
}
