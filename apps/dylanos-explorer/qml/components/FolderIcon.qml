import QtQuick
import DylanOS.Explorer

// Carpeta del icon theme activo del sistema, con un glifo blanco opcional
// encima (trazos stroke propios del app, p. ej. en tarjetas de inicio).
Item {
    id: root
    property real scaleFactor: 1
    implicitWidth: 66 * scaleFactor
    implicitHeight: 56 * scaleFactor
    width: implicitWidth
    height: implicitHeight

    DylanIcon {
        anchors.fill: parent
        name: "folder"
        fallback: "inode-directory"
    }
}
