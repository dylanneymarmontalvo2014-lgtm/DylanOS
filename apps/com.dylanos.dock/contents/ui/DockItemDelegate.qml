import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Controls.Basic as DockControls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: delegateRoot

    property var appIcon
    property string appName: ""
    property bool isRunning: false
    property bool isPinned: false

    signal clicked()
    signal togglePin()

    readonly property real baseSize: Plasmoid.configuration.iconSize
    readonly property real hoverSize: Plasmoid.configuration.hoverSize

    width: hoverSize + 8
    height: hoverSize + 16

    Kirigami.Icon {
        id: icon
        source: delegateRoot.appIcon
        width: delegateRoot.baseSize
        height: delegateRoot.baseSize
        smooth: true
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: indicator.top
        anchors.bottomMargin: 5
        transformOrigin: Item.Bottom

        Behavior on width {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: indicator
        width: (delegateRoot.isRunning && Plasmoid.configuration.showIndicator) ? 5 : 0
        height: 5
        radius: 2.5
        color: Plasmoid.configuration.accentColor
        opacity: width > 0 ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2

        Behavior on width { NumberAnimation { duration: 140 } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    PlasmaComponents3.ToolTip {
        visible: mouseArea.containsMouse && delegateRoot.appName !== ""
        text: delegateRoot.appName
    }

    component DockMenuItem: DockControls.MenuItem {
        id: menuEntry

        implicitWidth: Math.max(200, contentItem.implicitWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(40, contentItem.implicitHeight + topPadding + bottomPadding)
        leftPadding: 16
        rightPadding: 16
        topPadding: 10
        bottomPadding: 10
        leftInset: 0
        rightInset: 0
        topInset: 0
        bottomInset: 0
        hoverEnabled: true
        indicator: null
        arrow: null

        contentItem: Text {
            text: menuEntry.text
            font: menuEntry.font
            color: menuEntry.enabled ? "#ffffff" : "#9ca3af"
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 14
            antialiasing: true
            border.width: 0
            color: {
                if (!menuEntry.enabled)
                    return "transparent"
                if (menuEntry.down)
                    return "#B01030"
                if (menuEntry.hovered || menuEntry.highlighted)
                    return "#DC143C"
                return "transparent"
            }
            Behavior on color {
                ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
        }
    }

    DockControls.Menu {
        id: contextMenu
        padding: 8
        margins: 8
        spacing: 4
        leftInset: 0
        rightInset: 0
        topInset: 0
        bottomInset: 0
        implicitWidth: Math.max(216, implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: implicitContentHeight + topPadding + bottomPadding
        modal: false
        dim: false
        focus: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        transformOrigin: Item.Center

        // popupType is available starting with Qt 6.8.
        Component.onCompleted: {
            if ("popupType" in contextMenu) {
                contextMenu["popupType"] = QQC2.Popup.Window
            }
        }

        background: Rectangle {
            radius: 22
            antialiasing: true
            border.width: 0
            // Apply alpha to the background only; keep text fully opaque.
            color: Qt.rgba(10 / 255, 10 / 255, 10 / 255, 0.55)
        }

        contentItem: ListView {
            implicitWidth: contentItem.childrenRect.width
            implicitHeight: contentHeight
            model: contextMenu.contentModel
            currentIndex: contextMenu.currentIndex
            spacing: contextMenu.spacing
            clip: true
            interactive: false
            boundsBehavior: Flickable.StopAtBounds
        }

        delegate: DockMenuItem {}

        enter: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 150
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.96
                    to: 1
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }

        exit: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 100
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 1
                    to: 0.98
                    duration: 100
                    easing.type: Easing.InCubic
                }
            }
        }

        DockMenuItem {
            text: delegateRoot.isPinned ? "Quitar del Dock" : "Fijar en el Dock"
            onTriggered: delegateRoot.togglePin()
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: {
            icon.width = delegateRoot.hoverSize
            icon.height = delegateRoot.hoverSize
        }
        onExited: {
            icon.width = delegateRoot.baseSize
            icon.height = delegateRoot.baseSize
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
            } else {
                delegateRoot.clicked()
            }
        }
    }
}
