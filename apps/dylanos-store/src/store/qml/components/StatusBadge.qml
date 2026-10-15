import QtQuick
import DylanOS

// Textual + iconic status chip (never colour-only).
Item {
    id: root
    property var app
    readonly property string st: app ? app.status : "none"
    implicitWidth: chip.visible ? chip.implicitWidth : 0
    implicitHeight: 20

    Chip {
        id: chip
        visible: root.st === "installed" || root.st === "update" || root.st === "busy" || root.st === "error"
        tone: root.st === "installed" ? (root.app.statusUnknown ? "warn" : "ok") : root.st === "update" ? "warn" : "red"
        iconName: root.st === "installed" ? (root.app.statusUnknown ? "HelpCircle" : "Check")
                : root.st === "update" ? "ArrowUpCircle" : root.st === "busy" ? "Loader2" : "AlertTriangle"
        spin: root.st === "busy"
        text: root.st === "installed" ? (root.app.statusUnknown ? "Estado desconocido" : "Instalada")
            : root.st === "update" ? "Actualización" : root.st === "busy" ? Strings.stage(root.app.progress) : "Error"
    }
}
