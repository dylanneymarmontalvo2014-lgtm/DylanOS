import QtQuick
import "WidgetTokens.js" as Tokens

/*
 * Superficie Crimson Glass de un widget.
 *
 * Material translúcido con borde especular superior, reflejo interior y sombra
 * suave, según docs/crimson-glass.md: la tarjeta NO decide si hay blur. El
 * compositor aplica el desenfoque del escritorio; aquí solo se fija el
 * relleno, el borde y la sombra. En modo rendimiento el relleno es
 * prácticamente opaco y la sombra desaparece.
 *
 * El degradado es deliberado: una tarjeta de color plano sobre un fondo oscuro
 * se lee como un hueco negro, no como vidrio.
 */
Item {
    id: surface

    property string variant: Tokens.variantDark
    // Estado que publica Crimson Glass (modo bajo consumo / llvmpipe).
    property bool performanceMode: false
    property bool showShadow: true

    readonly property color fillColor: Tokens.materialFill[variant]
                                        || Tokens.materialFill[Tokens.variantDark]
    readonly property color fillTop: Tokens.materialFillTop[variant]
                                        || Tokens.materialFillTop[Tokens.variantDark]
    readonly property real fillOpacity: performanceMode
                                        ? Tokens.materialOpacityPerformance
                                        : Tokens.materialOpacity
    readonly property color textColor: Tokens.materialText[variant]
                                        || Tokens.materialText[Tokens.variantDark]
    readonly property color textSecondaryColor: Tokens.materialTextSecondary[variant]
                                        || Tokens.materialTextSecondary[Tokens.variantDark]

    // Sombra suave: se desvanece en modo rendimiento para no gastar blur.
    Rectangle {
        anchors.fill: card
        anchors.topMargin: surface.showShadow && !surface.performanceMode
                           ? Tokens.space4 : 0
        radius: card.radius
        color: "#B0000000"
        visible: surface.showShadow && !surface.performanceMode
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Tokens.radiusWidget
        opacity: surface.fillOpacity
        antialiasing: true
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, surface.performanceMode ? 0.10 : 0.14)

        /*
         * Vidrio: más luminoso arriba (luz que entra) y más profundo abajo.
         * Con `performanceMode` el degradado se aplana para que el contenido
         * gane contraste sobre un relleno casi opaco.
         */
        gradient: Gradient {
            GradientStop {
                position: 0
                color: surface.performanceMode
                       ? surface.fillColor : surface.fillTop
            }
            GradientStop {
                position: 1
                color: surface.fillColor
            }
        }

        // Reflejo especular superior: la línea de luz del material.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.space3
            height: 1
            radius: 1
            color: Qt.rgba(1, 1, 1, surface.performanceMode ? 0.06 : 0.22)
        }

        // Halo interior muy tenue: da volumen sin ensuciar el texto.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Tokens.radiusWidget - 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, surface.performanceMode ? 0.03 : 0.05)
        }
    }

    // El contenido se declara como hijos de este Item.
}
