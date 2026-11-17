pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Clima.
 *
 * Único widget del layout por defecto que depende de la red. La regla del
 * proyecto es tajante: nada de datos simulados. Por eso:
 *
 *   - La temperatura y la condición solo se muestran si llegan del servicio
 *     de clima de Plasma con un proveedor realmente configurado.
 *   - Sin proveedor, la tarjeta muestra un estado explícito que abre la
 *     configuración del applet. No inventa «22°» ni un icono de sol.
 *
 * Punto de integración pendiente (F3): el engine `weather` de plasma5support
 * con la estación configurada. No se escribe aquí la consulta porque no se
 * puede cargar contra un plasmashell real en este entorno; mientras tanto
 * `hasData` es false y la tarjeta nunca muestra una cifra.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.mediumWide, Tokens.small,
                                           Tokens.large]
    // Tamaño por defecto del encargo: doble de ancho, misma altura.
    readonly property string defaultSize: Tokens.mediumWide

    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    readonly property bool hasData: false
    readonly property string condition: ""
    readonly property string temperature: ""
    readonly property string location: ""
    readonly property string forecastSummary: ""

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.mediumWide, root.cellSize)
        implicitHeight: Tokens.heightFor(Tokens.mediumWide, root.cellSize)

        WidgetCard {
            anchors.fill: parent
            variant: Tokens.variantCrimson
        }

        // ── Con datos del proveedor ──────────────────────────────────────
        Column {
            anchors.fill: parent
            anchors.margins: Tokens.space4
            spacing: Tokens.space1
            visible: root.hasData

            Text {
                text: root.location
                color: Tokens.materialTextSecondary[Tokens.variantCrimson]
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeCaption
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: root.temperature
                color: Tokens.white
                font.family: Tokens.fontFamily
                font.pixelSize: Math.round(root.cellSize * 0.32)
                font.weight: Font.Light
            }

            Text {
                text: root.condition
                color: Tokens.white
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeHeading
            }

            Text {
                text: root.forecastSummary
                color: Tokens.materialTextSecondary[Tokens.variantCrimson]
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeCaption
                elide: Text.ElideRight
                width: parent.width
            }
        }

        // ── Sin proveedor: estado explícito, nunca datos inventados ──────
        Column {
            anchors.centerIn: parent
            width: parent.width - Tokens.space6
            spacing: Tokens.space2
            visible: !root.hasData

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Clima"
                color: Tokens.white
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeHeading
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Configura tu ubicación para ver el clima real."
                color: Tokens.materialTextSecondary[Tokens.variantCrimson]
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeCaption
            }

            Rectangle {
                id: configButton
                anchors.horizontalCenter: parent.horizontalCenter
                width: configLabel.implicitWidth + Tokens.space5
                height: configLabel.implicitHeight + Tokens.space2
                radius: Tokens.radiusControl
                color: configArea.containsMouse
                       ? Tokens.gradientHoverTop : Tokens.gradientTop

                Text {
                    id: configLabel
                    anchors.centerIn: parent
                    text: "Configurar"
                    color: Tokens.white
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: configArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Abre la configuración real del applet; no simula nada.
                    onClicked: root.showConfigurationInterface()
                }
            }
        }
    }
}
