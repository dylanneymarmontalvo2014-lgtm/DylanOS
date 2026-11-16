import QtQuick
import DylanOS.Explorer

// Icono de tipo de archivo resuelto del icon theme activo del sistema
// (nombres estándar XDG). El fallback conservado es el badge coloreado
// anterior, solo si el tema activo no trae el icono solicitado.
Item {
    id: root
    property string suffix
    property bool isDir: false
    property real size: 24

    readonly property var kinds: ({
        "pptx": "x-office-presentation", "ppt": "x-office-presentation", "odp": "x-office-presentation",
        "docx": "x-office-document", "doc": "x-office-document", "odt": "x-office-document", "rtf": "x-office-document",
        "xlsx": "x-office-spreadsheet", "xls": "x-office-spreadsheet", "ods": "x-office-spreadsheet", "csv": "x-office-spreadsheet",
        "pdf": "application-pdf",
        "txt": "text-plain", "md": "text-markdown", "log": "text-plain", "xml": "text-plain", "json": "text-plain", "conf": "text-plain",
        "mp4": "video-x-generic", "mkv": "video-x-generic", "avi": "video-x-generic", "webm": "video-x-generic", "mov": "video-x-generic",
        "mp3": "audio-x-generic", "flac": "audio-x-generic", "ogg": "audio-x-generic", "wav": "audio-x-generic", "m4a": "audio-x-generic",
        "png": "image-x-generic", "jpg": "image-x-generic", "jpeg": "image-x-generic", "gif": "image-x-generic",
        "webp": "image-x-generic", "svg": "image-x-generic", "bmp": "image-x-generic",
        "zip": "application-zip", "tar": "application-zip", "gz": "application-zip", "xz": "application-zip",
        "bz2": "application-zip", "7z": "application-zip", "rar": "application-zip",
        "deb": "application-x-deb", "appimage": "application-x-executable",
        "py": "text-x-python", "js": "text-x-javascript", "ts": "text-x-javascript", "cpp": "text-x-cpp",
        "h": "text-x-cpp", "hpp": "text-x-cpp", "sh": "application-x-shellscript", "qml": "text-x-generic",
        "html": "text-x-generic", "css": "text-x-generic", "iso": "application-zip"
    })
    readonly property string iconName: root.isDir
        ? "folder"
        : (root.kinds[root.suffix.toLowerCase()] || "text-x-generic")
    implicitWidth: size
    implicitHeight: size

    DylanIcon {
        visible: true
        anchors.centerIn: parent
        width: root.size
        height: root.size
        name: root.iconName
        fallback: "text-x-generic"
    }
}
