import QtQuick
import QtQuick.Controls.Basic
import DylanOS.Explorer

Rectangle {
    id: root
    required property var ctl
    required property var places
    required property var window
    signal settingsRequested()
    signal itemContext(string path, real x, real y)

    property int cornerRadius: 0
    radius: cornerRadius
    color: Theme.sidebar

    // square off the corners that touch the content area
    Rectangle { x: parent.width - parent.cornerRadius; width: parent.cornerRadius; height: parent.height; color: parent.color }

    // right border
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.hairline }

    // drag zone + traffic lights + history buttons
    Item {
        id: topBar
        width: parent.width; height: Theme.headerHeight
        DragHandler { target: null; onActiveChanged: if (active) root.window.startSystemMove() }
        WindowControls { x: 22; y: 30; window: root.window }

        Rectangle {
            x: 140; y: 18
            width: 80; height: 38; radius: 10
            color: Theme.field
            border.width: 1; border.color: Theme.hairline
            Row {
                anchors.fill: parent
                IconButton {
                    width: 40; height: 38
                    icon: "back"; iconSize: 17
                    enabled: root.ctl.canGoBack
                    onClicked: root.ctl.goBack()
                }
                IconButton {
                    width: 40; height: 38
                    icon: "forward"; iconSize: 17
                    enabled: root.ctl.canGoForward
                    onClicked: root.ctl.goForward()
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors { top: topBar.bottom; bottom: footer.top; left: parent.left; right: parent.right }
        anchors.rightMargin: 1
        contentHeight: col.implicitHeight + 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: DScrollBar {}

        Column {
            id: col
            x: 16
            width: parent.width - 32
            spacing: 0

            Txt {
                text: "Favoritos"
                color: Theme.accentLabel
                font.pixelSize: Theme.fontItem
                height: 30
                leftPadding: 6
            }
            Repeater {
                model: root.places.favorites
                delegate: SidebarItem {
                    required property var modelData
                    width: col.width
                    height: 34
                    text: modelData.name
                    icon: modelData.icon
                    active: root.ctl.location === modelData.path
                    onClicked: root.ctl.navigate(modelData.path)
                    onRightClicked: { const p = mapToItem(null, width / 2, height / 2); root.itemContext(modelData.path, p.x, p.y) }
                }
            }

            Item { width: 1; height: 14 }
            Txt {
                text: "Dispositivos"
                color: Theme.accentLabel
                font.pixelSize: Theme.fontItem
                height: 30
                leftPadding: 6
            }
            Repeater {
                model: root.places.devices
                delegate: DeviceItem {
                    required property var modelData
                    width: col.width
                    name: modelData.name
                    detail: modelData.text
                    usedFraction: modelData.usedFraction
                    onClicked: root.ctl.navigate(modelData.path)
                }
            }

            Item { width: 1; height: 8 }
            Txt {
                text: "Red"
                color: Theme.accentLabel
                font.pixelSize: Theme.fontItem
                height: 30
                leftPadding: 6
            }
            Repeater {
                model: root.places.network
                delegate: SidebarItem {
                    required property var modelData
                    width: col.width
                    height: 32
                    text: modelData.name
                    icon: modelData.icon
                    onClicked: root.ctl.openNetwork(modelData.kind)
                }
            }
        }
    }

    Item {
        id: footer
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        anchors.rightMargin: 1
        height: 62
        Rectangle { width: parent.width; height: 1; color: Theme.hairline }
        SidebarItem {
            x: 16; y: 14
            width: parent.width - 32
            height: 36
            text: "Configuración"
            icon: "gear"
            onClicked: root.settingsRequested()
        }
    }
}
