import QtQuick
import org.kde.plasma.core as PlasmaCore
import "WidgetTokens.js" as Tokens

/*
 * Cabecera común de un widget: título tenue y, opcionalmente, una acción.
 *
 * Mantener la jerarquía tipográfica en un solo sitio evita que cada widget
 * elija su tamaño de letra, que es justo lo que la auditoría de diseño
 * señaló como inconsistencia.
 */
Item {
    id: header

    property string title: ""
    property string secondaryText: ""
    property color textColor: PlasmaCore.Theme.textColor
    property color secondaryColor: PlasmaCore.Theme.disabledTextColor
    property string actionIcon: ""
    property string actionTooltip: ""

    signal actionClicked()

    implicitHeight: titleText.implicitHeight + Tokens.space1

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.right: actionButton.visible ? actionButton.left : parent.right
        anchors.rightMargin: actionButton.visible ? Tokens.space2 : 0
        anchors.top: parent.top
        text: header.title
        color: header.textColor
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.fontSizeHeading
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        visible: text.length > 0
    }

    Text {
        anchors.left: parent.left
        anchors.right: titleText.right
        anchors.top: titleText.bottom
        text: header.secondaryText
        color: header.secondaryColor
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.fontSizeCaption
        elide: Text.ElideRight
        visible: text.length > 0
    }

    Item {
        id: actionButton
        anchors.right: parent.right
        anchors.top: parent.top
        width: Tokens.space5
        height: Tokens.space5
        visible: header.actionIcon.length > 0

        Text {
            anchors.centerIn: parent
            text: header.actionIcon
            color: header.secondaryColor
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.fontSizeBody
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: header.actionClicked()
        }
    }
}
