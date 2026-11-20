import QtQuick
import QtQuick.Layouts
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * Tarjeta del catálogo en la galería.
 *
 * Muestra nombre, propósito, fuente de datos y los tamaños que el widget
 * declara. Cuando el widget tiene un límite funcional declarado, se indica
 * en la propia tarjeta: la galería no promete lo que el widget no hace.
 */
Item {
    id: card
    SystemPalette { id: systemPalette; colorGroup: SystemPalette.Active }

    property var entry: null

    readonly property bool limited: entry && (entry.status === "limited"
                                              || entry.status === "needs-pkg")
    readonly property color accent: entry && entry.inDefaultLayout
                                    ? Tokens.crimson : systemPalette.mid

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusInner
        color: systemPalette.window.hsvValue > 0.5
                   ? (hover.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04))
                   : (hover.containsMouse ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(0, 0, 0, 0.035))
        border.width: 1
        border.color: hover.containsMouse ? Tokens.crimson
                                          : (systemPalette.window.hsvValue > 0.5 ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.10))

        Behavior on color {
            ColorAnimation { duration: Tokens.durationFast }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.space3
            spacing: Tokens.space1

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space2

                Text {
                    text: card.entry ? card.entry.name : ""
                    color: systemPalette.text
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: card.entry && card.entry.inDefaultLayout
                    width: badge.implicitWidth + Tokens.space2
                    height: badge.implicitHeight + 2
                    radius: height / 2
                    color: Qt.rgba(220 / 255, 20 / 255, 60 / 255, 0.22)

                    Text {
                        id: badge
                        anchors.centerIn: parent
                        text: "Por defecto"
                        color: Tokens.crimson
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSizeCaption - 1
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: card.entry ? card.entry.description : ""
                color: systemPalette.mid
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeCaption
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: {
                    if (!card.entry)
                        return "";
                    return card.entry.dataSource + " · "
                           + (card.entry.requiresNetwork ? "requiere red" : "sin red");
                }
                color: card.entry && card.entry.requiresNetwork
                       ? Tokens.crimson : systemPalette.mid
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeCaption - 1
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.space1

                Repeater {
                    model: card.entry ? card.entry.sizes : []

                    delegate: Rectangle {
                        required property string modelData
                        width: sizeLabel.implicitWidth + Tokens.space2
                        height: sizeLabel.implicitHeight + 2
                        radius: Tokens.radiusControl - 4
                        color: Qt.rgba(1, 1, 1, 0.06)

                        Text {
                            id: sizeLabel
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: systemPalette.mid
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSizeCaption - 2
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: card.limited
                    width: limitText.implicitWidth + Tokens.space2
                    height: limitText.implicitHeight + 2
                    radius: Tokens.radiusControl - 4
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        id: limitText
                        anchors.centerIn: parent
                        text: card.entry && card.entry.status === "needs-pkg"
                              ? "Falta paquete" : "Con límite"
                        color: systemPalette.mid
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSizeCaption - 2
                    }
                }
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
    }
}
