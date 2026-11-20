import QtQuick
import org.kde.plasma.core as PlasmaCore
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

/*
 * DylanOS Search — botón de la barra superior que lanza DylanOS Spotlight.
 * Replicado del preview del escritorio (icono de lupa junto al área de estado).
 */
PlasmoidItem {
    id: root

    readonly property int iconSize: 20

    CommandRunner { id: runner }

    preferredRepresentation: compactRepresentation
    compactRepresentation: Item {
        Layout.minimumWidth: root.iconSize + 12
        Layout.minimumHeight: root.iconSize + 8

        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.iconSize; height: root.iconSize
            source: "system-search"
            isMask: true
            color: PlasmaCore.Theme.textColor
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: runner.run("dylanos-spotlight")
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: root.iconSize + 12
        Layout.minimumHeight: root.iconSize + 8
        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.iconSize; height: root.iconSize
            source: "system-search"; isMask: true; color: PlasmaCore.Theme.textColor
        }
        MouseArea {
            anchors.fill: parent
            onClicked: runner.run("dylanos-spotlight")
        }
    }
}