import QtQuick
import DylanOS.Explorer

Item {
    id: root
    property string name
    property string detail
    property string icon: ""
    property real usedFraction: 0
    signal clicked()

    height: 58

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: area.containsMouse ? Theme.cardHover : "transparent"
    }
    // Icono real de la unidad según el icon theme activo (KFilePlacesModel).
    DylanIcon {
        x: 12
        y: 2
        width: 19
        height: 19
        name: root.icon
        fallback: "drive-harddisk"
    }
    Txt {
        x: 42; y: 2
        width: parent.width - 52
        text: root.name
        font.pixelSize: Theme.fontItem - 1
    }
    Rectangle {
        x: 42; y: 27
        width: parent.width - 54; height: 4; radius: 2
        color: Qt.rgba(1, 1, 1, 0.14)
        Rectangle {
            width: parent.width * Math.min(1, Math.max(0, root.usedFraction))
            height: parent.height; radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.accentDeep }
                GradientStop { position: 1; color: root.usedFraction > 0.9 ? Theme.danger : Theme.accentBright }
            }
        }
    }
    Txt {
        x: 42; y: 35
        width: parent.width - 52
        text: root.detail
        color: Theme.textDim
        font.pixelSize: Theme.fontSmall + 0.5
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
