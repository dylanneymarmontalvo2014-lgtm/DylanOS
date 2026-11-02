import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Selector del prototipo: botón de campo con menú emergente de opciones.
Button {
    id: root
    property string value: ""
    property var options: []
    property int menuWidth: 220
    signal picked(string value)
    readonly property int motionDuration: CrimsonGlass.effectiveEffects.animations
                                          ? Math.min(180, CrimsonGlass.settings.animationDuration)
                                          : 0

    width: menuWidth
    height: 40
    leftPadding: 12
    rightPadding: 12

    background: Rectangle {
        radius: Theme.radiusControl
        color: Theme.c.field
        border.width: 1
        border.color: root.down || root.hovered ? Theme.glassBorder : Theme.c.border

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 2 }
            height: 1
            color: Theme.glassSpecular
            opacity: 0.14
        }
    }
    contentItem: Item {
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: chevron.left
            anchors.rightMargin: 8
            text: root.value
            color: Theme.c.text
            font.pixelSize: 14
            elide: Text.ElideRight
        }
        LucideIcon {
            id: chevron
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-down"
            color: Theme.c.textDim
            size: 16
            rotation: popup.visible ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
        }
    }
    onClicked: popup.open()

    Popup {
        id: popup
        y: parent.height + 6
        width: Math.max(root.width, 180)
        height: Math.min(contentHeight + 12, 240)
        padding: 6
        background: Rectangle {
            radius: 12
            color: Theme.c.menuBg
            border.width: 1
            border.color: Theme.glassBorder

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 3 }
                height: 1
                color: Theme.glassSpecular
                opacity: 0.24
            }
        }
        contentItem: ListView {
            id: list
            clip: true
            model: root.options
            spacing: 2
            delegate: ItemDelegate {
                required property var modelData
                required property int index
                width: list.width
                height: 36
                background: Rectangle {
                    radius: 8
                    color: parent.hovered ? Theme.c.surfaceStrong : "transparent"
                }
                contentItem: Item {
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: modelData === root.value ? Theme.accentStrong : Theme.c.text
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        width: parent.width - 24
                    }
                    LucideIcon {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData === root.value
                        name: "check"
                        color: Theme.accentStrong
                        size: 15
                    }
                }
                onClicked: {
                    root.picked(modelData)
                    popup.close()
                }
            }
        }
    }
}
