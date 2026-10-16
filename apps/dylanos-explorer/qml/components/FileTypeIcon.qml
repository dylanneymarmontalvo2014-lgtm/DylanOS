import QtQuick
import DylanOS.Explorer

// Small coloured badge per file type (documents, images, media, archives).
Item {
    id: root
    property string suffix
    property bool isDir: false
    property real size: 24

    readonly property var kinds: ({
        "pptx": ["#d24726", "P"], "ppt": ["#d24726", "P"], "odp": ["#d24726", "P"],
        "docx": ["#2b6cd9", "W"], "doc": ["#2b6cd9", "W"], "odt": ["#2b6cd9", "W"],
        "xlsx": ["#1e8e4e", "X"], "xls": ["#1e8e4e", "X"], "ods": ["#1e8e4e", "X"], "csv": ["#1e8e4e", "X"],
        "pdf": ["#d8342c", "PDF"], "txt": ["#7a7f87", "T"], "md": ["#7a7f87", "M"],
        "mp4": ["#7a3fc4", "▶"], "mkv": ["#7a3fc4", "▶"], "avi": ["#7a3fc4", "▶"], "webm": ["#7a3fc4", "▶"],
        "mp3": ["#d0407a", "♪"], "flac": ["#d0407a", "♪"], "ogg": ["#d0407a", "♪"], "wav": ["#d0407a", "♪"],
        "png": ["#3d8fe0", ""], "jpg": ["#3d8fe0", ""], "jpeg": ["#3d8fe0", ""], "gif": ["#3d8fe0", ""],
        "webp": ["#3d8fe0", ""], "svg": ["#3d8fe0", ""],
        "zip": ["#e0a526", "Z"], "tar": ["#e0a526", "Z"], "gz": ["#e0a526", "Z"], "xz": ["#e0a526", "Z"],
        "7z": ["#e0a526", "Z"], "deb": ["#c2185b", "D"],
        "py": ["#3f7fb5", "Py"], "js": ["#c9a81e", "JS"], "cpp": ["#4a6fb0", "C+"], "qml": ["#2fa05a", "Q"],
        "sh": ["#5a6270", "$"]
    })
    readonly property var info: kinds[suffix.toLowerCase()] || ["#6b6266", ""]
    readonly property bool isImage: info[0] === "#3d8fe0"

    implicitWidth: size
    implicitHeight: size

    FolderIcon {
        visible: root.isDir
        anchors.centerIn: parent
        scaleFactor: root.size / 66 * 1.05
    }
    Rectangle {
        visible: !root.isDir
        anchors.centerIn: parent
        width: root.size * 0.86
        height: root.size
        radius: root.size * 0.18
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(root.info[0], 1.2) }
            GradientStop { position: 1; color: root.info[0] }
        }
        Txt {
            visible: root.info[1] !== ""
            anchors.centerIn: parent
            text: root.info[1]
            color: "#fff"
            font.pixelSize: root.size * (root.info[1].length > 1 ? 0.34 : 0.5)
            font.bold: true
            elide: Text.ElideNone
        }
        Icon {
            visible: root.isImage
            anchors.centerIn: parent
            name: "image"
            size: root.size * 0.6
            color: "#fff"
        }
    }
}
