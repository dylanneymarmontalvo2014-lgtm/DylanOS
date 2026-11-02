import QtQuick
import org.dylanos.configuration

Item {
    id: root
    property var settings: ({})
    property var effects: ({})

    function numberValue(key, fallback) {
        return settings && settings[key] !== undefined ? Number(settings[key]) : fallback
    }
    function boolValue(key, fallback) {
        return settings && settings[key] !== undefined ? Boolean(settings[key]) : fallback
    }

    readonly property int materialRadius: numberValue("cornerRadius", 18)
    readonly property int motionDuration: effects && effects.animations
                                         ? numberValue("animationDuration", 180) : 0
    readonly property real materialOpacity: effects && effects.surfaceOpacity !== undefined
                                            ? Number(effects.surfaceOpacity) / 100 : 0.42

    implicitWidth: 470
    implicitHeight: 232

    Rectangle {
        anchors.fill: parent
        radius: 24
        color: "#080608"
        clip: true

        Rectangle {
            width: 260
            height: 260
            radius: 130
            x: -70
            y: 66
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.34)
        }
        Rectangle {
            width: 190
            height: 190
            radius: 95
            x: parent.width - 108
            y: -72
            color: Qt.rgba(Theme.glassBorder.r, Theme.glassBorder.g, Theme.glassBorder.b, 0.22)
        }
        Rectangle {
            width: parent.width - 64
            height: 7
            radius: 4
            x: 34
            y: 116
            rotation: -8
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#00DC143C" }
                GradientStop { position: 0.46; color: "#E6DC143C" }
                GradientStop { position: 1; color: "#00FF5274" }
            }
        }

        Rectangle {
            id: shadow
            width: glass.width - 12
            height: glass.height - 8
            radius: glass.radius
            x: glass.x + 12
            y: glass.y + 18
            color: Qt.rgba(0, 0, 0, 0.48 * root.numberValue("shadows", 66) / 100)
        }

        Rectangle {
            id: glass
            width: parent.width - 88
            height: 144
            anchors.centerIn: parent
            radius: root.materialRadius
            color: Qt.rgba(0.086, 0.059, 0.075, root.materialOpacity)
            border.width: 1
            border.color: Qt.rgba(Theme.glassBorder.r, Theme.glassBorder.g, Theme.glassBorder.b,
                                  0.18 + 0.48 * root.numberValue("reflections", 64) / 100)

            Behavior on radius { NumberAnimation { duration: root.motionDuration; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: root.motionDuration } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                height: 1
                radius: 1
                color: Qt.rgba(Theme.glassSpecular.r, Theme.glassSpecular.g, Theme.glassSpecular.b,
                               0.16 + 0.48 * root.numberValue("reflections", 64) / 100)
            }

            Row {
                anchors.centerIn: parent
                spacing: 14
                Rectangle {
                    width: 48
                    height: 48
                    radius: 16
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.26)
                    border.width: 1
                    border.color: Qt.rgba(Theme.glassBorder.r, Theme.glassBorder.g, Theme.glassBorder.b, 0.46)
                    LucideIcon { anchors.centerIn: parent; name: "sliders-horizontal"; color: "#ffffff"; size: 23 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text { text: "Crimson Glass"; color: "#ffffff"; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Text {
                        text: effects && effects.blur ? "Desenfoque del compositor activo" : "Material opaco de respaldo"
                        color: "#c9c1c5"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
