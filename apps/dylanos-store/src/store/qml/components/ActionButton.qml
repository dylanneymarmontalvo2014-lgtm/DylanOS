import QtQuick
import DylanOS

// Contextual button driven by installation state (Instalar / Abrir / Actualizar / N% · Cancelar / Reintentar).
Btn {
    id: root
    property var app
    property bool wide: false
    readonly property string st: app ? app.status : "none"
    minWidth: wide ? 132 : 0

    variant: st === "installed" ? "quiet" : st === "busy" ? "ghost" : st === "error" ? "danger" : "primary"
    iconName: st === "installed" ? "ExternalLink" : st === "update" ? "RefreshCw" : st === "busy" ? "Loader2" : st === "error" ? "RotateCcw" : ""
    spinIcon: st === "busy"
    text: st === "installed" ? "Abrir" : st === "update" ? "Actualizar"
        : st === "busy" ? Math.round(app.progress) + "% · Cancelar"
        : st === "error" ? "Reintentar" : st === "cancelled" ? "Instalar de nuevo" : "Instalar"
    Accessible.name: st === "busy" ? "Cancelar " + app.name : text

    onClicked: {
        if (st === "installed") Store.openApp(app.appId)
        else if (st === "update") Store.update(app.appId)
        else if (st === "busy") Store.cancel(app.appId)
        else if (st === "error") Store.retry(app.appId)
        else Store.install(app.appId)
    }
}
