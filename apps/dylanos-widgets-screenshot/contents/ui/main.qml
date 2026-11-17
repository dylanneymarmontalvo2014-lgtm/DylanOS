pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Captura rápida.
 *
 * Lanza Spectacle (kde-spectacle está en el perfil base) y muestra cuántas
 * capturas hay en ~/Imágenes. No simula una captura ni genera una imagen de
 * ejemplo: si Spectacle no está instalado, lo dice.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small]
    readonly property string defaultSize: Tokens.small
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    // -1 = no se pudo determinar.
    property int captures: -1
    property bool spectacleAvailable: false

    readonly property string picturesDir: root.homeDir.length > 0
                                          ? root.homeDir + "/Imágenes" : ""

    property string homeDir: ""

    Timer {
        id: poll
        interval: 120000
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
            const out = (data.stdout || "").trim();
            if (sourceName.indexOf("printf") !== -1 && sourceName.indexOf("HOME") !== -1) {
                if (out.length > 0) {
                    root.homeDir = out;
                    root.refresh();
                }
            } else if (sourceName.indexOf("command -v spectacle") !== -1) {
                root.spectacleAvailable = out.length > 0;
            } else if (sourceName.indexOf("find") !== -1) {
                const value = parseInt(out, 10);
                root.captures = isFinite(value) ? value : -1;
            }
        }
    }

    function refresh() {
        if (root.homeDir.length === 0) {
            reader.connectSource("sh -c 'printf %s \"$HOME\"'");
            return;
        }
        reader.connectSource("sh -c 'command -v spectacle'");
        reader.connectSource("sh -c 'find \"$HOME/Imágenes\" -maxdepth 1 -type f "
                             + "\\( -name \"*.png\" -o -name \"*.jpg\" \\) 2>/dev/null | wc -l'");
    }

    function takeScreenshot() {
        // Lanzamiento real de Spectacle; sin shell intermedio.
        reader.connectSource("spectacle --capture-active-screen --background --nonotify");
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.small, root.cellSize)
        implicitHeight: Tokens.heightFor(Tokens.small, root.cellSize)

        WidgetShell {
            anchors.fill: parent
            title: "Captura"

            Column {
                anchors.centerIn: parent
                spacing: Tokens.space1

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: shotLabel.implicitWidth + Tokens.space4
                    height: shotLabel.implicitHeight + Tokens.space2
                    radius: Tokens.radiusControl
                    color: !root.spectacleAvailable ? Qt.rgba(1, 1, 1, 0.05)
                          : shotArea.containsMouse ? Tokens.gradientHoverTop
                                                   : Tokens.gradientTop

                    Text {
                        id: shotLabel
                        anchors.centerIn: parent
                        text: root.spectacleAvailable ? "Capturar" : "Sin Spectacle"
                        color: root.spectacleAvailable ? Tokens.white : Tokens.lightGray
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSizeCaption
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: shotArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.spectacleAvailable
                        cursorShape: root.spectacleAvailable ? Qt.PointingHandCursor
                                                             : Qt.ArrowCursor
                        onClicked: root.takeScreenshot()
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.captures >= 0
                          ? root.captures + (root.captures === 1 ? " captura" : " capturas")
                          : "Sin dato"
                    color: Tokens.lightGray
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                }
            }
        }
    }
}
