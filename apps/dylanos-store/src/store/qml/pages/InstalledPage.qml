import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import DylanOS

PageScaffold {
    id: page
    title: "Aplicaciones instaladas"
    sub: filter.count + " aplicaciones"
    property bool failed: false
    property var pendingApp: null

    AppFilterModel { id: filter; sourceModel: Store.appModel; statusFilter: "managed"; nameOnly: true; sortKey: "name" }

    headerControls: [
        TextField {
            id: search
            implicitWidth: 200; implicitHeight: 36
            placeholderText: "Filtrar instaladas…"
            placeholderTextColor: Colors.faint
            color: Colors.fg
            font.family: Typography.family; font.pixelSize: Typography.sm
            leftPadding: 12
            Accessible.name: "Filtrar instaladas"
            onTextChanged: filter.query = text
            background: Rectangle { radius: Metrics.radiusControl; color: Colors.surface2; border.width: search.activeFocus ? 2 : 1; border.color: search.activeFocus ? Colors.crimsonHi : Colors.line }
        },
        Select { label: "Ordenar"; value: filter.sortKey; options: [["name", "Nombre"], ["category", "Categoría"]]; onPicked: v => filter.sortKey = v }
    ]

    EmptyState {
        visible: page.failed
        Layout.fillWidth: true
        iconName: "ServerCrash"; error: true
        title: "No se pudo cargar la lista"
        text: "No fue posible leer el estado del software instalado."
        Btn { text: "Reintentar"; onClicked: page.failed = false }
    }
    Item {
        visible: !page.failed && filter.count > 0
        Layout.fillWidth: true
        implicitHeight: lst.implicitHeight
        RoundedBox { anchors.fill: parent; fill: Colors.surface50; radius: 16 }
        ColumnLayout {
            id: lst
            width: parent.width
            spacing: 0
            Repeater {
                model: filter
                delegate: Item {
                    id: row
                    required property int index
                    required property var app
                    readonly property var a: app
                    Layout.fillWidth: true
                    implicitHeight: g.implicitHeight + 24
                    Rectangle { visible: row.index > 0; width: parent.width; height: 1; color: Colors.line }
                    GridLayout {
                        id: g
                        x: 12; y: 12; width: parent.width - 24
                        columns: width < 520 ? 2 : 3
                        columnSpacing: 12; rowSpacing: 8
                        AppIcon { app: row.a; size: 44 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Flow {
                                Layout.fillWidth: true; spacing: 8
                                Txt { text: row.a.name; font.weight: Font.Medium }
                                Item { width: sb.implicitWidth; height: 22; StatusBadge { id: sb; app: row.a; anchors.verticalCenter: parent.verticalCenter } }
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: row.a.categoryLabel + " · v" + (row.a.statusUnknown ? "desconocida" : row.a.currentVersion) + (row.a.installedOn !== "" ? " · Instalada el " + row.a.installedOn : "")
                                color: Colors.dim; font.pixelSize: Typography.xs; wrapMode: Text.WordWrap
                            }
                        }
                        Row {
                            Layout.columnSpan: g.columns === 2 ? 2 : 1
                            spacing: 8
                            Btn { small: true; variant: "quiet"; text: "Abrir"; onClicked: Store.openApp(row.a.appId) }
                            Btn { small: true; variant: "ghost"; text: "Detalles"; onClicked: Nav.go("app", row.a.appId) }
                            Btn { small: true; variant: "danger"; iconName: "Trash2"; Accessible.name: "Desinstalar " + row.a.name; onClicked: { page.pendingApp = row.a; del.open() } }
                        }
                    }
                }
            }
        }
    }
    EmptyState {
        visible: !page.failed && filter.count === 0
        Layout.fillWidth: true
        title: search.text !== "" ? "Sin coincidencias" : "Aún no hay aplicaciones instaladas"
        text: "Explora la tienda para encontrar tu próxima aplicación."
        Btn { text: "Ir a la tienda"; onClicked: Nav.go("home") }
    }
    ConfirmDialog {
        id: del
        objectName: "confirmUninstall"
        title: "¿Desinstalar " + (page.pendingApp ? page.pendingApp.name : "") + "?"
        message: "Se eliminará la aplicación del sistema. Esta acción no se puede deshacer."
        actions: [
            Btn { text: "Cancelar"; variant: "ghost"; onClicked: del.close() },
            Btn { text: "Desinstalar"; onClicked: { del.close(); Store.uninstall(page.pendingApp.appId) } }
        ]
    }
}
