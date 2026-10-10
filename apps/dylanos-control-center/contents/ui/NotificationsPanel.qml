import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

// Panel de Notificaciones — Bloque 3: modelo REAL de notificaciones.
// ⚠️ Parte más riesgosa del bloque: si "org.kde.notificationmanager" no carga,
// SOLO este panel falla (Centro de Control sigue funcionando) — avísame el
// error exacto de la terminal para ajustar nombres de roles/métodos.
Rectangle {
    id: root

    readonly property color cBlack:      "#0A0A0A"
    readonly property color cGray:       "#1A1A1A"
    readonly property color cCrimson:    "#DC143C"
    readonly property color cWhite:      "#FFFFFF"
    readonly property color cLightGray:  "#B3B3B3"
    readonly property color cCardBorder: Qt.rgba(1, 1, 1, 0.08)

    color: cBlack
    radius: 22
    border.color: cCardBorder
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

    NotificationManager.Notifications {
        id: notificationsModel
        showExpired: false
        showJobs: false
        limit: 50
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Kirigami.Icon {
                source: "notifications"; isMask: true
                Layout.preferredWidth: 22; Layout.preferredHeight: 22
                color: cWhite
            }
            QQC2.Label {
                text: "Notificaciones"
                font.pixelSize: 20; font.bold: true; color: cWhite
            }
            Rectangle {
                width: 24; height: 24; radius: 12
                color: cCrimson
                visible: notificationsModel.count > 0

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: cCrimson
                    shadowOpacity: 0.7; shadowBlur: 0.6
                }
                QQC2.Label {
                    anchors.centerIn: parent
                    text: notificationsModel.count
                    color: cWhite; font.pixelSize: 12; font.bold: true
                }
            }
            Item { Layout.fillWidth: true }
            QQC2.ToolButton { icon.name: "overflow-menu"; icon.color: cLightGray; flat: true }
        }

        // ----- Modo "No molestar" activo: no mostramos la lista -----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: SystemStatus.doNotDisturb
            spacing: 8
            Item { Layout.fillHeight: true }
            Kirigami.Icon {
                source: "notifications-disabled"; isMask: true; color: "#5a5a5a"
                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignHCenter
            }
            QQC2.Label {
                text: "No molestar activado"
                color: cLightGray; font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
            }
            Item { Layout.fillHeight: true }
        }

        // ----- Lista real -----
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            visible: !SystemStatus.doNotDisturb
            model: notificationsModel

            delegate: Rectangle {
                width: ListView.view.width
                height: notifLayout.implicitHeight + 24
                radius: 14
                color: cGray
                border.color: cCardBorder
                border.width: 1

                RowLayout {
                    id: notifLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                        color: cCrimson
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 20; height: 20
                            source: model.iconName || model.desktopEntry || "dialog-information"
                            isMask: true; color: cWhite
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            QQC2.Label {
                                text: model.summary || model.applicationName || "Notificación"
                                color: cWhite; font.pixelSize: 14; font.bold: true
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            QQC2.Label {
                                text: model.updated ? Qt.formatTime(model.updated, "hh:mm") : ""
                                color: cLightGray; font.pixelSize: 11
                            }
                        }
                        QQC2.Label {
                            text: model.body || ""
                            color: cLightGray; font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: "window-close"
                        icon.color: "#7a7a7a"
                        flat: true
                        visible: model.closable !== false
                        onClicked: notificationsModel.close(index)
                    }
                }
            }
        }

        QQC2.Button {
            Layout.fillWidth: true
            text: "Borrar todo"
            icon.name: "edit-clear-all"
            icon.color: cLightGray
            flat: true
            visible: !SystemStatus.doNotDisturb
            onClicked: {
                for (let i = notificationsModel.count - 1; i >= 0; i--) {
                    notificationsModel.close(i)
                }
            }
        }
    }
}
