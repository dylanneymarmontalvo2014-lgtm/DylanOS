import QtQuick
import DylanOS.Explorer

DlgBase {
    id: root
    required property var ctl
    property var info: ({})
    property int sizeToken: -1
    property string sizeText: ""

    width: 500
    icon: info.isDir ? "folder" : "doc"
    title: "Propiedades"

    function formatSize(b) {
        if (b < 1000) return b + " B"
        const u = ["KB", "MB", "GB", "TB"]
        let v = b / 1000, i = 0
        while (v >= 1000 && i < u.length - 1) { v /= 1000; i++ }
        return v.toFixed(v < 10 ? 2 : 1) + " " + u[i]
    }
    function showFor(path) {
        info = ctl.properties(path)
        sizeText = info.isDir ? "Calculando…" : info.sizeText
        sizeToken = info.isDir ? ctl.requestSize([path]) : -1
        open()
    }
    Connections {
        target: root.ctl
        function onSizeComputed(token, bytes) {
            if (token === root.sizeToken)
                root.sizeText = root.formatSize(bytes) + " (" + bytes.toLocaleString(Qt.locale("es")) + " bytes)"
        }
    }

    Rectangle {
        width: parent.width; height: 64; radius: 12
        color: Theme.card; border.width: 1; border.color: Theme.hairline
        FileTypeIcon {
            x: 16; anchors.verticalCenter: parent.verticalCenter
            size: 36; isDir: !!root.info.isDir
            suffix: (root.info.name || "").split(".").pop()
        }
        Column {
            x: 66; width: parent.width - 80
            anchors.verticalCenter: parent.verticalCenter
            Txt { width: parent.width; text: root.info.name || ""; font.weight: Font.Medium; font.pixelSize: Theme.fontItem }
            Txt { width: parent.width; text: root.info.kind || ""; color: Theme.textDim; font.pixelSize: Theme.fontSmall + 1 }
        }
    }
    Repeater {
        model: [
            ["Ubicación", root.info.parent], ["Tamaño", root.sizeText],
            ["Contenido", root.info.isDir ? root.info.itemCount : ""],
            ["Tipo MIME", root.info.mime], ["Creado", root.info.created],
            ["Modificado", root.info.modified], ["Último acceso", root.info.accessed],
            ["Propietario", (root.info.owner || "") + (root.info.group ? " : " + root.info.group : "")],
            ["Permisos", root.info.permissions],
            ["Acceso", (root.info.readable ? "Lectura" : "Sin lectura") + (root.info.writable ? " · Escritura" : " · Solo lectura")],
            ["Enlace a", root.info.symlinkTarget], ["Oculto", root.info.hidden ? "Sí" : ""]
        ]
        delegate: Row {
            required property var modelData
            visible: !!modelData[1]
            height: visible ? implicitHeight : 0
            width: parent.width; spacing: 12
            Txt { width: 104; text: modelData[0]; color: Theme.textDim; font.pixelSize: Theme.fontSmall + 1 }
            Txt {
                width: parent.width - 116; text: modelData[1] || ""; font.pixelSize: Theme.fontSmall + 1
                elide: Text.ElideMiddle
            }
        }
    }
    footer: [ DButton { text: "Cerrar"; variant: "primary"; onClicked: root.close() } ]
}
