import QtQuick
import DylanOS.Explorer

Item {
    id: root
    required property var ctl
    required property var window
    property alias search: searchField

    height: Theme.headerHeight

    DragHandler { target: null; onActiveChanged: if (active) root.window.startSystemMove() }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onDoubleTapped: root.window.visibility === Window.Maximized ? root.window.showNormal() : root.window.showMaximized()
    }

    Row {
        x: Theme.pagePadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.ctl.isHome ? "home" : (root.ctl.inTrash ? "trash" : "folder")
            size: 25
            color: Theme.textDim
            strokeWidth: 1.9
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: root.ctl.title
            font.pixelSize: Theme.fontTitle
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.width - 700)
        }
    }

    ViewToggle {
        anchors { right: searchField.left; rightMargin: 40; verticalCenter: parent.verticalCenter }
        mode: root.ctl.viewMode
        onModeSelected: (m) => root.ctl.viewMode = m
    }
    SearchField {
        id: searchField
        ctl: root.ctl
        anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
        width: 327
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hairline }
}
