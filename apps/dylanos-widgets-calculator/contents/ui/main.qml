pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import "lib"
import "lib/WidgetTokens.js" as Tokens
import "lib/WidgetCalc.js" as Calc

/*
 * DylanOS Widgets — Calculadora rápida.
 *
 * El evaluador vive en lib/WidgetCalc.js (sin `eval`, con límites de longitud
 * y magnitud) para poder verificarlo con `node` además de a mano.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small]
    readonly property string defaultSize: Tokens.small
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    property string expression: ""
    property string result: ""
    property bool invalid: false

    function update() {
        const outcome = Calc.evaluate(root.expression);
        root.invalid = root.expression.length > 0 && !outcome.ok;
        root.result = outcome.ok ? Calc.formatValue(outcome.value) : "";
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.small, root.cellSize)
        implicitHeight: Tokens.heightFor(Tokens.small, root.cellSize)

        WidgetShell {
            anchors.fill: parent
            title: "Calculadora"

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.space1

                Rectangle {
                    width: parent.width
                    height: Tokens.space5
                    radius: Tokens.radiusControl
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: root.invalid ? Tokens.crimson
                                               : Qt.rgba(1, 1, 1, 0.10)

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.space2
                        anchors.rightMargin: Tokens.space2
                        verticalAlignment: TextInput.AlignVCenter
                        color: Tokens.white
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSizeBody
                        selectionColor: Tokens.crimson
                        clip: true
                        onTextChanged: {
                            root.expression = text;
                            root.update();
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "12 * (3 + 4)"
                            color: Tokens.lightGray
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSizeCaption
                            visible: input.text.length === 0
                        }
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: root.invalid ? "Expresión no válida" : root.result
                    color: root.invalid ? Tokens.crimson : Tokens.white
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeHeading
                    font.weight: Font.DemiBold
                    elide: Text.ElideLeft
                }
            }
        }
    }
}
