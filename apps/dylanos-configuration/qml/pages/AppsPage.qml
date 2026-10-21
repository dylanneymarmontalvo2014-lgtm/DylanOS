import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Aplicaciones: instaladas reales (escritorio XDG) y predeterminadas reales.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property string tab: Window.window && Window.window.tab ? Window.window.tab : "Instaladas"
    property var apps: []
    property string query: ""
    property string cat: "Todas"

    function refresh() { apps = System.installedApps() }
    function categories() {
        const cats = ["Todas"]
        for (let i = 0; i < apps.length; i++) {
            const parts = (apps[i].categories || "").split(";")
            for (const p of parts) {
                if (p && cats.indexOf(p) < 0 && ["KDE", "Qt", "GTK", "GNOME"].indexOf(p) < 0)
                    cats.push(p)
            }
        }
        return cats.slice(0, 12)
    }
    function filtered() {
        const q = query.toLowerCase()
        const out = []
        for (let i = 0; i < apps.length; i++) {
            const a = apps[i]
            if ((cat === "Todas" || (a.categories || "").includes(cat)) &&
                ((a.name + " " + (a.desc || "")).toLowerCase().includes(q)))
                out.push(a)
        }
        return out
    }
    Component.onCompleted: Qt.callLater(refresh)

    Column {
        id: col
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        TabsBar {
            width: parent.width
            value: root.tab
            tabs: ["Instaladas", "Predeterminadas"]
            onPicked: function (t) { root.tab = t; Window.window.tab = t }
        }

        Column {
            visible: root.tab === "Instaladas"
            width: parent.width
            spacing: 16

            Row {
                width: parent.width
                spacing: 12
                SearchField {
                    width: parent.width - 210
                    placeholder: "Buscar aplicaciones"
                    text: root.query
                    onTextChanged: root.query = text
                }
                DSelect {
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.cat
                    options: root.categories()
                    menuWidth: 190
                    onPicked: function (v) { root.cat = v }
                }
            }

            EmptyState {
                visible: root.filtered().length === 0
                width: parent.width
                icon: "search"
                title: "Sin resultados"
                desc: "Prueba con otro nombre o categoría."
            }

            GroupBox {
                visible: root.filtered().length > 0
                width: parent.width
                Repeater {
                    model: root.filtered().slice(0, 60)
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        title: modelData.name
                        desc: (modelData.desc || "Aplicación") + " · " + root.cat
                        last: index === root.filtered().length - 1 || index === 59
                        IconTile {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "package"
                            size: 36
                            plain: true
                        }
                    }
                }
            }

            Text {
                visible: root.filtered().length > 0
                text: "La instalación y desinstalación se gestionan en DylanOS Store."
                font.pixelSize: 12
                color: Theme.c.textDim
            }
        }

        Column {
            visible: root.tab === "Predeterminadas"
            width: parent.width
            spacing: 16

            GroupBox {
                width: parent.width
                Repeater {
                    model: [
                        { k: "browser", t: "Navegador web", icon: "globe" },
                        { k: "fileManager", t: "Gestor de archivos", icon: "folder-open" },
                        { k: "mail", t: "Correo", icon: "mail" },
                        { k: "media", t: "Reproductor multimedia", icon: "play" }
                    ]
                    delegate: RowItem {
                        id: defaultRow
                        required property var modelData
                        required property int index
                        width: parent.width
                        icon: modelData.icon
                        title: modelData.t
                        desc: "Actual: " + (System.defaultApp(modelData.k) || "—")
                        last: index === 3
                        DSelect {
                            anchors.verticalCenter: parent.verticalCenter
                            property var opts: System.defaultAppCandidates(modelData.k)
                            property string current: System.defaultApp(modelData.k) || ""
                            value: displayName()
                            options: names()
                            menuWidth: 240
                            function names() {
                                const out = []
                                for (const o of opts) out.push(o.name)
                                return out
                            }
                            function displayName() {
                                for (const o of opts)
                                    if (o.desktop === current)
                                        return o.name
                                return current || "—"
                            }
                            onPicked: function (v) {
                                for (const o of opts) {
                                    if (o.name === v) {
                                        System.setDefaultApp(modelData.k, o.desktop)
                                        break
                                    }
                                }
                                defaultRow.desc = "Actual: " + (System.defaultApp(modelData.k) || "—")
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: "Los valores se escriben con xdg-settings/xdg-mime, el mecanismo estándar de aplicaciones predeterminadas."
                font.pixelSize: 12
                color: Theme.c.textDim
                wrapMode: Text.WordWrap
            }
        }
    }
}

