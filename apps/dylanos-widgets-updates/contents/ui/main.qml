pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens
import "lib/WidgetData.js" as Data

/*
 * DylanOS Widgets — Actualizaciones.
 *
 * Cuenta paquetes APT pendientes con `apt-get -s upgrade`, que SIMULA la
 * actualización y no modifica el sistema. Con el botón se abre DylanOS Store,
 * la única tienda visible del sistema (nunca Discover).
 *
 * Refresco cada 6 h: consultar APT es caro y no cambia en minutos.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.mediumWide]
    readonly property string defaultSize: Tokens.small
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell
    readonly property bool wide: width > height * 1.4

    preferredRepresentation: fullRepresentation

    // -1 = no se pudo consultar. 0 es un dato válido: no hay actualizaciones.
    property int pending: -1

    readonly property color accent: root.pending > 0 ? Tokens.crimson
                                 : root.pending === 0 ? Tokens.white : Tokens.lightGray

    Timer {
        id: poll
        interval: 6 * 60 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    P5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            if (sourceName.indexOf("apt-get") === 0) {
                if (data.exitCode === 0 || data.exitCode === 100)
                    root.pending = Data.countAptUpgrades(data.stdout || "");
            }
        }
    }

    P5Support.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => disconnectSource(sourceName)
    }

    function refresh() {
        reader.connectSource("apt-get -s upgrade");
    }

    function openStore() {
        // La tienda oficial; el id coincide con org.dylanos.store.desktop.
        launcher.connectSource("dylanos-store");
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(root.wide ? Tokens.mediumWide : Tokens.small,
                                       root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: root.cellSize < 180 ? "Mejoras" : "Actualizaciones"
            actionIcon: root.wide ? "" : "\u21bb"
            onActionClicked: root.refresh()

            // Ancho explícito: con solo `centerIn` la columna adopta el ancho
            // de su hijo más ancho y el texto largo desbordaba la tarjeta.
            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.space1

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.pending < 0 ? "—" : root.pending
                    color: root.accent
                    font.family: Tokens.fontFamily
                    font.pixelSize: Math.round(root.cellSize * 0.26)
                    font.weight: Font.Light
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: {
                        if (root.pending < 0)
                            return "No se pudo consultar APT";
                        if (root.pending === 0)
                            return "Todo actualizado";
                        return root.pending === 1 ? "paquete pendiente"
                                                  : "paquetes pendientes";
                    }
                    color: Tokens.lightGray
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: storeLabel.implicitWidth + Tokens.space4
                    height: storeLabel.implicitHeight + Tokens.space1
                    radius: Tokens.radiusControl
                    color: storeArea.containsMouse ? Tokens.gradientHoverTop
                                                   : Tokens.gradientTop

                    Text {
                        id: storeLabel
                        anchors.centerIn: parent
                        text: "Abrir tienda"
                        color: Tokens.white
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSizeCaption - 1
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: storeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openStore()
                    }
                }
            }
        }
    }
}
