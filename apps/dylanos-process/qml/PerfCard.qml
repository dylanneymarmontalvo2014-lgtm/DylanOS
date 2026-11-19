// Tarjeta de la pestaña Rendimiento: título, valor y gráfica de área real.
import QtQuick
import QtQuick.Layouts
import org.dylanos.process

Rectangle {
    id: card

    property string title
    property string value
    property string iconSource
    property color accent: Theme.red
    property color fillColor: Theme.redSubtle
    property var values: []
    property string detail: ""

    radius: Theme.panelRadius
    color: Theme.surfaceElevated
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Image {
                source: card.iconSource
                sourceSize.width: 16
                sourceSize.height: 16
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }

            Text {
                text: card.title
                color: Theme.textSecondary
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.Bold
            }

            Item { Layout.fillWidth: true }

            Text {
                text: card.value
                color: Theme.textPrimary
                font.family: Theme.monoFont
                font.pixelSize: 16
                font.weight: Font.Bold
            }
        }

        PerformanceChart {
            Layout.fillWidth: true
            Layout.fillHeight: true
            values: card.values
            stroke: card.accent
            fill: card.fillColor
        }

        Text {
            Layout.fillWidth: true
            text: card.detail
            color: Theme.textTertiary
            font.family: Theme.uiFont
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
