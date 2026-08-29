import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// Panel de Centro de Control — Bloque 3: TODO conectado a datos reales
// (Wi-Fi, Bluetooth, brillo, volumen, modo oscuro, no molestar local, MPRIS)
Rectangle {
    id: root

    color: "#0d0d0f"
    radius: 22
    border.color: "#2a1618"
    border.width: 1

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.55
        shadowBlur: 0.7
        shadowVerticalOffset: 10
        shadowHorizontalOffset: 0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Kirigami.Icon {
                source: "configure"; isMask: true
                Layout.preferredWidth: 22; Layout.preferredHeight: 22
                color: "#f5f5f5"
            }
            QQC2.Label {
                text: "Centro de control"
                font.pixelSize: 20; font.bold: true; color: "#f5f5f5"
            }
            Item { Layout.fillWidth: true }
            QQC2.ToolButton { icon.name: "document-edit"; icon.color: "#c4c4c4"; flat: true }
        }

        // Grid 2x2 — TODO real
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            // ----- Wi-Fi -----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 16
                color: SystemStatus.wifiPowered ? "#e11d2e" : "#1a1414"
                border.color: SystemStatus.wifiPowered ? "#ff4d5a" : "#2a1618"
                border.width: 1
                opacity: SystemStatus.wifiAvailable ? 1.0 : 0.5

                layer.enabled: SystemStatus.wifiPowered
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: "#e11d2e"
                    shadowOpacity: 0.5; shadowBlur: 0.8
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: SystemStatus.wifiAvailable
                    onClicked: SystemStatus.toggleWifi()
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    Kirigami.Icon {
                        source: "network-wireless"; isMask: true
                        color: SystemStatus.wifiPowered ? "white" : "#c4c4c4"
                        Layout.preferredWidth: 22; Layout.preferredHeight: 22
                    }
                    Item { Layout.fillHeight: true }
                    QQC2.Label {
                        text: "Wi-Fi"
                        color: SystemStatus.wifiPowered ? "white" : "#f5f5f5"
                        font.pixelSize: 13; font.bold: true
                    }
                    QQC2.Label {
                        text: !SystemStatus.wifiAvailable ? "No detectado"
                              : SystemStatus.wifiPowered ? (SystemStatus.wifiSsid || "Conectado")
                              : "Desactivado"
                        color: SystemStatus.wifiPowered ? "#ffd7da" : "#9a9a9a"
                        font.pixelSize: 11
                    }
                }
            }

            // ----- Bluetooth -----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 16
                color: SystemStatus.bluetoothPowered ? "#e11d2e" : "#1a1414"
                border.color: SystemStatus.bluetoothPowered ? "#ff4d5a" : "#2a1618"
                border.width: 1
                opacity: SystemStatus.bluetoothAvailable ? 1.0 : 0.5

                layer.enabled: SystemStatus.bluetoothPowered
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: "#e11d2e"
                    shadowOpacity: 0.5; shadowBlur: 0.8
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: SystemStatus.bluetoothAvailable
                    onClicked: SystemStatus.toggleBluetooth()
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    Kirigami.Icon {
                        source: "preferences-system-bluetooth"; isMask: true
                        color: SystemStatus.bluetoothPowered ? "white" : "#c4c4c4"
                        Layout.preferredWidth: 22; Layout.preferredHeight: 22
                    }
                    Item { Layout.fillHeight: true }
                    QQC2.Label {
                        text: "Bluetooth"
                        color: SystemStatus.bluetoothPowered ? "white" : "#f5f5f5"
                        font.pixelSize: 13; font.bold: true
                    }
                    QQC2.Label {
                        text: !SystemStatus.bluetoothAvailable ? "No detectado"
                              : SystemStatus.bluetoothPowered ? "Activo" : "Desactivado"
                        color: SystemStatus.bluetoothPowered ? "#ffd7da" : "#9a9a9a"
                        font.pixelSize: 11
                    }
                }
            }

            // ----- No molestar (local al widget) -----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 16
                color: SystemStatus.doNotDisturb ? "#e11d2e" : "#1a1414"
                border.color: SystemStatus.doNotDisturb ? "#ff4d5a" : "#2a1618"
                border.width: 1

                layer.enabled: SystemStatus.doNotDisturb
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: "#e11d2e"
                    shadowOpacity: 0.5; shadowBlur: 0.8
                }

                MouseArea { anchors.fill: parent; onClicked: SystemStatus.toggleDoNotDisturb() }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    Kirigami.Icon {
                        source: "notifications-disabled"; isMask: true
                        color: SystemStatus.doNotDisturb ? "white" : "#c4c4c4"
                        Layout.preferredWidth: 22; Layout.preferredHeight: 22
                    }
                    Item { Layout.fillHeight: true }
                    QQC2.Label {
                        text: "No molestar"
                        color: SystemStatus.doNotDisturb ? "white" : "#f5f5f5"
                        font.pixelSize: 13; font.bold: true
                    }
                    QQC2.Label {
                        text: SystemStatus.doNotDisturb ? "Activado" : "Desactivado"
                        color: SystemStatus.doNotDisturb ? "#ffd7da" : "#9a9a9a"
                        font.pixelSize: 11
                    }
                }
            }

            // ----- Modo oscuro -----
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                radius: 16
                color: SystemStatus.darkModeActive ? "#e11d2e" : "#1a1414"
                border.color: SystemStatus.darkModeActive ? "#ff4d5a" : "#2a1618"
                border.width: 1

                layer.enabled: SystemStatus.darkModeActive
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: "#e11d2e"
                    shadowOpacity: 0.5; shadowBlur: 0.8
                }

                MouseArea { anchors.fill: parent; onClicked: SystemStatus.toggleDarkMode() }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    Kirigami.Icon {
                        source: "weather-clear-night"; isMask: true
                        color: SystemStatus.darkModeActive ? "white" : "#c4c4c4"
                        Layout.preferredWidth: 22; Layout.preferredHeight: 22
                    }
                    Item { Layout.fillHeight: true }
                    QQC2.Label {
                        text: "Modo oscuro"
                        color: SystemStatus.darkModeActive ? "white" : "#f5f5f5"
                        font.pixelSize: 13; font.bold: true
                    }
                    QQC2.Label {
                        text: SystemStatus.darkModeActive ? "Activado" : "Desactivado"
                        color: SystemStatus.darkModeActive ? "#ffd7da" : "#9a9a9a"
                        font.pixelSize: 11
                    }
                }
            }
        }

        // ----- Brillo (real) -----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Kirigami.Icon {
                source: "display-brightness"; isMask: true; color: "#c4c4c4"
                Layout.preferredWidth: 20; Layout.preferredHeight: 20
            }
            QQC2.Slider {
                id: brightnessSlider
                Layout.fillWidth: true
                from: 0; to: 1
                enabled: SystemStatus.brightnessAvailable
                onMoved: SystemStatus.setBrightness(value)

                Binding {
                    target: brightnessSlider; property: "value"
                    value: SystemStatus.brightnessValue
                    when: !brightnessSlider.pressed
                }

                background: Rectangle {
                    x: brightnessSlider.leftPadding
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: brightnessSlider.availableWidth; height: 6; radius: 3
                    color: "#2a2a2a"
                    Rectangle {
                        width: brightnessSlider.visualPosition * parent.width
                        height: parent.height; radius: 3; color: "#e11d2e"
                    }
                }
                handle: Rectangle {
                    x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                    y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                    width: 18; height: 18; radius: 9; color: "white"
                }
            }
        }

        // ----- Volumen (real) -----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Kirigami.Icon {
                source: "audio-volume-high"; isMask: true; color: "#c4c4c4"
                Layout.preferredWidth: 20; Layout.preferredHeight: 20
            }
            QQC2.Slider {
                id: volumeSlider
                Layout.fillWidth: true
                from: 0; to: 1
                enabled: SystemStatus.volumeAvailable
                onMoved: SystemStatus.setVolume(value)

                Binding {
                    target: volumeSlider; property: "value"
                    value: SystemStatus.volumeValue
                    when: !volumeSlider.pressed
                }

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth; height: 6; radius: 3
                    color: "#2a2a2a"
                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height; radius: 3; color: "#e11d2e"
                    }
                }
                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 18; height: 18; radius: 9; color: "white"
                }
            }
        }

        // Accesos secundarios (siguen mockup — no forman parte de este bloque)
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: MockData.secondaryActions
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    radius: 14
                    color: "#1a1414"
                    border.color: "#2a1618"
                    border.width: 1
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Kirigami.Icon {
                            source: modelData.icon; isMask: true; color: "#c4c4c4"
                            Layout.preferredWidth: 20; Layout.preferredHeight: 20
                            Layout.alignment: Qt.AlignHCenter
                        }
                        QQC2.Label {
                            text: modelData.label
                            color: "#c4c4c4"; font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // ----- Reproductor (MPRIS real vía playerctl) -----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            radius: 16
            color: "#1a1414"
            border.color: "#2a1618"
            border.width: 1

            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 12

                Rectangle {
                    Layout.preferredWidth: 60; Layout.preferredHeight: 60; radius: 10
                    color: "#e11d2e"
                    visible: SystemStatus.mprisAvailable

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: "#e11d2e"
                        shadowOpacity: 0.55; shadowBlur: 0.7
                    }
                }
                Kirigami.Icon {
                    source: "audio-x-generic"; isMask: true; color: "#6a6a6a"
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    visible: !SystemStatus.mprisAvailable
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    QQC2.Label {
                        text: SystemStatus.mprisAvailable ? SystemStatus.mprisTitle : "Sin reproducción activa"
                        color: "#f5f5f5"; font.pixelSize: 14; font.bold: true
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    QQC2.Label {
                        text: SystemStatus.mprisArtist
                        color: "#9a9a9a"; font.pixelSize: 12
                        visible: SystemStatus.mprisAvailable
                    }
                    RowLayout {
                        spacing: 16
                        visible: SystemStatus.mprisAvailable
                        QQC2.ToolButton {
                            icon.name: "media-skip-backward"; icon.color: "#f5f5f5"; flat: true
                            onClicked: SystemStatus.mprisPrevious()
                        }
                        QQC2.ToolButton {
                            icon.name: SystemStatus.mprisPlaying ? "media-playback-pause" : "media-playback-start"
                            icon.color: "#f5f5f5"; flat: true
                            onClicked: SystemStatus.mprisPlayPause()
                        }
                        QQC2.ToolButton {
                            icon.name: "media-skip-forward"; icon.color: "#f5f5f5"; flat: true
                            onClicked: SystemStatus.mprisNext()
                        }
                    }
                }
            }
        }

        QQC2.Button {
            Layout.fillWidth: true
            text: "Configuración rápida"
            icon.name: "configure"
            icon.color: "#c4c4c4"
            flat: true
            onClicked: {}
        }
    }
}
