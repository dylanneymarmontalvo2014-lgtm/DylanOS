pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Reproductor multimedia.
 *
 * Controla la reproducción real por MPRIS con `playerctl`, que ya está en el
 * perfil base (packages/default/packages.list). Sin reproductor activo el
 * widget lo dice; no muestra una canción de ejemplo.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.mediumWide]
    readonly property string defaultSize: Tokens.mediumWide
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    property bool playing: false
    property bool available: false
    property string title: ""
    property string artist: ""

    readonly property bool hasTrack: root.title.length > 0

    Timer {
        id: poll
        interval: 5000
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
            if (sourceName === "playerctl status") {
                root.available = data.exitCode === 0 && out.length > 0;
                root.playing = out === "Playing";
            } else if (sourceName === "playerctl metadata --format {{title}}|||{{artist}}") {
                if (data.exitCode === 0) {
                    const parts = out.split("|||");
                    root.title = (parts[0] || "").trim();
                    root.artist = (parts[1] || "").trim();
                }
            }
        }
    }

    function refresh() {
        reader.connectSource("playerctl status");
        reader.connectSource("playerctl metadata --format {{title}}|||{{artist}}");
    }

    function command(action) {
        reader.connectSource("playerctl " + action);
        // Se refresca después para que el icono refleje el estado real.
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: root.refresh()
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.mediumWide, root.cellSize)
        implicitHeight: root.cellSize

        WidgetShell {
            anchors.fill: parent
            title: "Reproductor"

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.space1

                Text {
                    width: parent.width
                    text: root.available
                          ? (root.hasTrack ? root.title : "Sin metadatos")
                          : "Sin reproductor activo"
                    color: PlasmaCore.Theme.textColor
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.available && root.artist.length > 0 ? root.artist
                                                                  : ""
                    color: PlasmaCore.Theme.disabledTextColor
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeCaption
                    elide: Text.ElideRight
                    visible: text.length > 0
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Tokens.space3
                    visible: root.available

                    Repeater {
                        model: [
                            { "glyph": "\u23ee", "action": "previous" },
                            { "glyph": root.playing ? "\u23f8" : "\u25b6", "action": "play-pause" },
                            { "glyph": "\u23ed", "action": "next" }
                        ]

                        delegate: Item {
                            id: control
                            required property var modelData
                            width: Tokens.space5
                            height: Tokens.space5

                            Text {
                                anchors.centerIn: parent
                                text: control.modelData.glyph
                                color: controlArea.containsMouse ? Tokens.crimson
                                                                 : PlasmaCore.Theme.textColor
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSizeHeading
                            }

                            MouseArea {
                                id: controlArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.command(control.modelData.action)
                            }
                        }
                    }
                }
            }
        }
    }
}
