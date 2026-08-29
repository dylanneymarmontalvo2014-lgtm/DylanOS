import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

/*
 * DylanOS Control Center — Bloque 1: esqueleto visual
 *
 * Combina NotificationsPanel + ControlCenterPanel en un solo plasmoid,
 * replicando el layout del boceto (dos paneles flotantes lado a lado).
 * Sin lógica real todavía: todos los datos vienen de MockData.qml.
 */
PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

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
