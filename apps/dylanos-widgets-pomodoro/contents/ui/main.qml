pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Pomodoro.
 *
 * Temporizador de enfoque (25 min) y descanso (5 min) con la hora real del
 * sistema, no con un contador que deriva. La duración de cada modo y la
 * lógica de progreso son las mismas que ya usa el Dashboard histórico, que
 * están cubiertas por scripts/tests/test_pomodoro.py.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small]
    readonly property string defaultSize: Tokens.small
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell

    preferredRepresentation: fullRepresentation

    readonly property int focusSeconds: 25 * 60
    readonly property int breakSeconds: 5 * 60

    property string mode: "focus"
    property bool running: false
    property bool started: false
    property double remaining: focusSeconds
    property double deadlineMs: 0

    readonly property int durationSeconds: mode === "focus" ? focusSeconds : breakSeconds
    readonly property real progress: durationSeconds > 0
                                     ? 1 - Math.max(0, remaining) / durationSeconds : 0

    readonly property string status: !started ? "Listo para empezar"
                                    : running ? (mode === "focus" ? "Enfoque en curso"
                                                                  : "Descanso en curso")
                                    : "En pausa"

    readonly property string clockText: {
        const total = Math.max(0, Math.ceil(remaining));
        const minutes = Math.floor(total / 60);
        const seconds = total % 60;
        return (minutes < 10 ? "0" : "") + minutes + ":"
             + (seconds < 10 ? "0" : "") + seconds;
    }

    Timer {
        interval: 250
        running: root.running
        repeat: true
        onTriggered: root.tick()
    }

    function tick() {
        const left = (root.deadlineMs - Date.now()) / 1000;
        root.remaining = Math.max(0, left);
        if (left <= 0)
            root.finish();
    }

    function start() {
        root.deadlineMs = Date.now() + Math.max(0, root.remaining) * 1000;
        root.running = true;
        root.started = true;
    }

    function pause() {
        root.running = false;
    }

    function reset() {
        root.running = false;
        root.started = false;
        root.remaining = root.durationSeconds;
    }

    function finish() {
        root.running = false;
        root.mode = root.mode === "focus" ? "break" : "focus";
        root.remaining = root.durationSeconds;
        root.started = false;
    }

    function toggle() {
        if (root.running)
            root.pause();
        else
            root.start();
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.small, root.cellSize)
        implicitHeight: Tokens.heightFor(Tokens.small, root.cellSize)

        WidgetShell {
            anchors.fill: parent
            title: root.mode === "focus" ? "Enfoque" : "Descanso"
            subtitle: root.status

            Column {
                anchors.centerIn: parent
                spacing: Tokens.space1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.clockText
                    color: Tokens.white
                    font.family: Tokens.fontFamily
                    font.pixelSize: Math.round(root.cellSize * 0.24)
                    font.weight: Font.Light
                }

                WidgetMeter {
                    width: root.cellSize * 0.6
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: root.progress
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Tokens.space2

                    Rectangle {
                        width: playLabel.implicitWidth + Tokens.space3
                        height: playLabel.implicitHeight + Tokens.space1
                        radius: Tokens.radiusControl
                        color: playArea.containsMouse ? Tokens.gradientHoverTop
                                                      : Tokens.gradientTop

                        Text {
                            id: playLabel
                            anchors.centerIn: parent
                            text: root.running ? "Pausa" : "Iniciar"
                            color: Tokens.white
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSizeCaption - 1
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle()
                        }
                    }

                    Rectangle {
                        width: resetLabel.implicitWidth + Tokens.space3
                        height: resetLabel.implicitHeight + Tokens.space1
                        radius: Tokens.radiusControl
                        color: resetArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12)
                                                       : Qt.rgba(1, 1, 1, 0.06)

                        Text {
                            id: resetLabel
                            anchors.centerIn: parent
                            text: "Reiniciar"
                            color: Tokens.lightGray
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.fontSizeCaption - 1
                        }

                        MouseArea {
                            id: resetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.reset()
                        }
                    }
                }
            }
        }
    }
}
