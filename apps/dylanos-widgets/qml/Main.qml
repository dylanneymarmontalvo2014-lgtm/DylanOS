import QtQuick
import org.kde.plasma.core as PlasmaCore
import QtQuick.Layouts
import QtQuick.Controls as QQC2
// ApplicationWindow viene de QtQuick.Controls; se importa además sin alias
// para que la raíz de la ventana resuelva.
import QtQuick.Controls
import "lib"
import "lib/WidgetTokens.js" as Tokens
import "WidgetCatalog.js" as Catalog

/*
 * Galería de DylanOS Widgets.
 *
 * Ventana frameless de DylanOS (semáforos a la izquierda, arrastre por
 * startSystemMove) con el catálogo completo agrupado por categoría, buscador
 * y preview real de cada widget.
 *
 * El botón «Añadir» no simula nada: pide al shell de Plasma que cree el
 * applet en la retícula del escritorio mediante evaluateScript, exactamente
 * igual que hace el layout del primer arranque.
 */
ApplicationWindow {
    id: window

    visible: true
    width: 980
    height: 660
    minimumWidth: 720
    minimumHeight: 480
    title: "Galería de Widgets"
    // Ventana DylanOS sin decoración de KWin: semáforos integrados en la
    // cabecera, igual que Calculator, Explorer y Configuration.
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    SystemPalette { id: systemPalette; colorGroup: SystemPalette.Active }
    readonly property bool dark: systemPalette.window.hsvValue < 0.5
    readonly property color foreground: dark ? "#f4eeee" : "#211a1b"
    readonly property color secondaryText: dark ? "#b3b3b3" : "#655b5d"
    readonly property int pageMargin: Tokens.space6

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusWidget
        gradient: Gradient {
            GradientStop { position: 0; color: window.dark ? "#F0201618" : "#F7FAF6F6" }
            GradientStop { position: 0.6; color: window.dark ? "#F5100C0D" : "#F7F0E8E9" }
            GradientStop { position: 1; color: window.dark ? "#F0280A0E" : "#F7E8E0E1" }
        }
        border.width: 1
        border.color: window.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.10)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Barra de título con semáforos ───────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 46

            MouseArea {
                anchors.fill: parent
                // Arrastre nativo: KWin mueve la ventana, no la app.
                onPressed: window.startSystemMove()
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Tokens.space4
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.space2

                Repeater {
                    model: [
                        { "color": "#FF5F57", "action": "close" },
                        { "color": "#FEBC2E", "action": "minimize" },
                        { "color": "#28C840", "action": "maximize" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: 12
                        height: 12
                        radius: 6
                        color: modelData.color

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.modelData.action === "close")
                                    Qt.quit();
                                else if (parent.modelData.action === "minimize")
                                    window.showMinimized();
                                else
                                    window.showMaximized();
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "Galería de Widgets"
                color: window.foreground
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeBody
                font.weight: Font.DemiBold
            }
        }

        // ── Cabecera: título y buscador ─────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 84

            Column {
                anchors.left: parent.left
                anchors.leftMargin: window.pageMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.space1

                Text {
                    text: "DylanOS Widgets"
                    color: window.foreground
                    font.family: Tokens.fontFamily
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Catalog.count() + " widgets · "
                          + Catalog.roadmap.length + " en el roadmap"
                    color: window.secondaryText
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: window.pageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: 260
                height: 36
                radius: Tokens.radiusControl
                color: window.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
                border.width: 1
                border.color: searchField.activeFocus ? Tokens.crimson
                                                      : (window.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.12))

                QQC2.TextField {
                    id: searchField
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.space3
                    anchors.rightMargin: Tokens.space3
                    placeholderText: "Buscar widget…"
                    color: window.foreground
                    placeholderTextColor: window.secondaryText
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                    background: null
                    selectByMouse: true
                }
            }
        }

        // ── Rejilla de catálogo ─────────────────────────────────────────
        GridView {
            id: gallery
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: window.pageMargin
            Layout.rightMargin: window.pageMargin
            Layout.bottomMargin: window.pageMargin
            cellWidth: 300
            cellHeight: 132
            clip: true
            model: Catalog.search(searchField.text)
            boundsBehavior: Flickable.StopAtBounds

            delegate: CatalogCard {
                required property var modelData
                width: gallery.cellWidth - Tokens.space3
                height: gallery.cellHeight - Tokens.space3
                entry: modelData
            }

            QQC2.ScrollBar.vertical: QQC2.ScrollBar { }
        }
    }
}
