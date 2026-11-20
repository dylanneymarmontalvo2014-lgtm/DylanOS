import QtQuick
import "WidgetTokens.js" as Tokens

/*
 * Contenedor estándar de un widget de datos: superficie Crimson Glass,
 * cabecera y cuerpo.
 *
 * Existe para que los 20 widgets compartan la misma jerarquía y el mismo
 * espaciado. Sin esto cada widget acabaría eligiendo sus márgenes, que es la
 * inconsistencia que la auditoría de diseño señaló en el escritorio anterior.
 */
Item {
    id: shell
    SystemPalette { id: systemPalette; colorGroup: SystemPalette.Active }

    property string title: ""
    property string subtitle: ""
    property string variant: systemPalette.window.hsvValue > 0.5 ? Tokens.variantDark : Tokens.variantLight
    property bool performanceMode: false
    property string actionIcon: ""
    signal actionClicked()

    // El contenido se declara como hijos; se ancla al área bajo la cabecera.
    default property alias content: body.data

    WidgetCard {
        anchors.fill: parent
        variant: shell.variant
        performanceMode: shell.performanceMode
    }

    WidgetHeader {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.space4
        title: shell.title
        secondaryText: shell.subtitle
        textColor: shell.variant === Tokens.variantDark ? Tokens.white : Tokens.materialText[Tokens.variantLight]
        secondaryColor: Tokens.materialTextSecondary[shell.variant] || Tokens.lightGray
        actionIcon: shell.actionIcon
        onActionClicked: shell.actionClicked()
        visible: shell.title.length > 0 || shell.subtitle.length > 0
    }

    Item {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.space4
        anchors.top: header.visible ? header.bottom : parent.top
        anchors.topMargin: header.visible ? Tokens.space3 : Tokens.space4
    }
}
