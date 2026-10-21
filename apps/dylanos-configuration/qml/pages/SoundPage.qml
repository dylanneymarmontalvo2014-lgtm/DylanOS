import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Sonido: volumen, silencio y dispositivos reales vía PulseAudio (pactl).
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property var state: ({})

    function refresh() { state = System.audio() }
    Component.onCompleted: Qt.callLater(refresh)

    function sinkNames() {
        const list = []
        const devices = state.sinks || []
        for (let i = 0; i < devices.length; i++)
            list.push(devices[i].description || devices[i].name)
        return list
    }
    function sourceNames() {
        const list = []
        const devices = state.sources || []
        for (let i = 0; i < devices.length; i++)
            list.push(devices[i].description || devices[i].name)
        return list
    }
    function findSink(desc) {
        const devices = state.sinks || []
        for (let i = 0; i < devices.length; i++)
            if ((devices[i].description || devices[i].name) === desc)
                return devices[i].name
        return ""
    }
    function findSource(desc) {
        const devices = state.sources || []
        for (let i = 0; i < devices.length; i++)
            if ((devices[i].description || devices[i].name) === desc)
                return devices[i].name
        return ""
    }

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        EmptyState {
            visible: state.available === false
            width: parent.width
            icon: "volume-2"
            title: "Sin servidor de sonido"
            desc: "PulseAudio/PipeWire no está disponible en este sistema."
        }

        Text { visible: state.available !== false; text: "Salida"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            visible: state.available !== false
            width: parent.width
            RowItem {
                width: parent.width
                icon: "speaker"
                title: "Dispositivo de salida"
                DSelect {
                    anchors.verticalCenter: parent.verticalCenter
                    value: state.defaultSink || "—"
                    options: root.sinkNames()
                    onPicked: function (v) {
                        System.setDefaultSink(root.findSink(v))
                        root.refresh()
                    }
                }
            }
            RowItem {
                width: parent.width
                icon: state.muted ? "volume-x" : "volume-2"
                title: "Volumen general"
                desc: state.muted ? "Silenciado" : ""
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: Theme.radiusControl
                        color: state.muted ? Theme.accent : Theme.c.surfaceStrong
                        LucideIcon {
                            anchors.centerIn: parent
                            name: state.muted ? "volume-x" : "volume-2"
                            color: state.muted ? "#ffffff" : Theme.c.text
                            size: 17
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                System.setSinkMute(!state.muted)
                                root.refresh()
                            }
                        }
                    }
                    DSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 260
                        value: state.muted ? 0 : (state.volume || 0)
                        onMoved: function (v) {
                            System.setSinkVolume(v)
                            state.volume = v
                            if (state.muted && v > 0) {
                                System.setSinkMute(false)
                                state.muted = false
                            }
                        }
                    }
                }
            }
            RowItem {
                width: parent.width
                title: "Nivel de salida"
                last: true
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: 14
                        delegate: Rectangle {
                            required property int index
                            width: 5
                            height: 4 + (index * 7 % 5) * 3
                            radius: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: !state.muted && (state.volume || 0) > 0 && index < 9 ? Theme.accent : Theme.c.track
                        }
                    }
                }
            }
        }

        Text { visible: state.available !== false; text: "Entrada"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            visible: state.available !== false
            width: parent.width
            RowItem {
                width: parent.width
                icon: "mic"
                title: "Dispositivo de entrada"
                DSelect {
                    anchors.verticalCenter: parent.verticalCenter
                    value: state.defaultSource || "—"
                    options: root.sourceNames()
                    onPicked: function (v) {
                        System.setDefaultSource(root.findSource(v))
                        root.refresh()
                    }
                }
            }
            RowItem {
                width: parent.width
                title: "Volumen del micrófono"
                DSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 260
                    value: state.micVolume || 0
                    onMoved: function (v) {
                        System.setMicVolume(v)
                        state.micVolume = v
                    }
                }
            }
            RowItem {
                width: parent.width
                title: "Silenciar micrófono"
                last: true
                DToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    on: state.micMuted === true
                    onToggled: function (v) {
                        System.setMicMute(v)
                        root.refresh()
                    }
                }
            }
        }

        Text { visible: state.available !== false; text: "Más opciones"; font.pixelSize: 18; color: Theme.c.text }

        GroupBox {
            visible: state.available !== false
            width: parent.width
            RowItem {
                width: parent.width
                title: "Sonidos del sistema"
                desc: "Efectos al iniciar sesión y alertas"
                last: true
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Abrir sonido"
                    onClicked: System.openKcm(["kcm_pulseaudio"])
                }
            }
        }
    }
}

