import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import QtQuick.Controls as QQC2
import org.kde.notificationmanager as NotificationManager

/*
 * DylanOS Control Center — replicado del preview controlcenter_preview.png.
 *
 * En la barra superior muestra el icono de campana con el número de
 * notificaciones (compact representation); al pulsarlo se despliega el panel
 * completo: Notificaciones (modelo real de Plasma) + Centro de Control
 * (toggles, brillo, volumen y reproductor conectados al sistema real).
 */
PlasmoidItem {
    id: root

    readonly property int notificationCount: notifModel.count

    NotificationManager.Notifications {
        id: notifModel
        showExpired: false
        showJobs: false
        limit: 50
    }

    preferredRepresentation: compactRepresentation

    compactRepresentation: Item {
        Layout.minimumWidth: 38
        Layout.minimumHeight: 26

        // Separadores verticales discretos a los lados como en el preview
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 16
            color: Qt.rgba(1, 1, 1, 0.18)
        }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 16
            color: Qt.rgba(1, 1, 1, 0.18)
        }

        Rectangle {
            id: avatarCircle
            width: 22; height: 22; radius: 11
            color: mouseArea.containsMouse || root.expanded ? "#FF2A54" : "#DC143C"
            anchors.centerIn: parent

            Image {
                anchors.centerIn: parent
                width: 14; height: 14
                source: "logo.png"
                fillMode: Image.PreserveAspectFit
                mipmap: true
            }

            Rectangle {
                visible: root.notificationCount > 0
                width: Math.max(16, countLabel.implicitWidth + 8); height: 16; radius: 8
                color: "#FFFFFF"
                anchors.top: parent.top; anchors.topMargin: -5
                anchors.right: parent.right; anchors.rightMargin: -7
                border.color: "#DC143C"; border.width: 1
                QQC2.Label {
                    id: countLabel
                    anchors.centerIn: parent
                    text: root.notificationCount > 99 ? "99+" : root.notificationCount
                    color: "#DC143C"; font.pixelSize: 9; font.bold: true
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: root.notificationCount > 0 ? "Centro de control, " + root.notificationCount + " notificaciones" : "Abrir centro de control"
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 980
        Layout.preferredHeight: 780
        Layout.minimumWidth: 760
        Layout.minimumHeight: 600

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            NotificationsPanel {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.52
            }

            ControlCenterPanel {
                Layout.fillHeight: true
                Layout.fillWidth: true
            }
        }
    }
}
