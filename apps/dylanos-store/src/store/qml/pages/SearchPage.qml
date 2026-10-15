import QtQuick
import QtQuick.Layouts
import DylanOS

PageScaffold {
    id: page
    readonly property string q: Nav.query
    title: "Resultados para «" + q + "»"
    property bool loading: false
    sub: Store.offline ? "" : loading ? "Buscando…" : filter.count + (filter.count === 1 ? " resultado" : " resultados")

    onQChanged: { loading = true; loadTimer.restart() }
    Component.onCompleted: { loading = true; loadTimer.start() }
    Timer { id: loadTimer; interval: 350; onTriggered: page.loading = false }

    AppFilterModel { id: filter; sourceModel: Store.appModel; query: page.q; sortKey: "relevance" }

    headerControls: [
        Select {
            visible: !Store.offline; label: "Categoría"; value: filter.category
            options: [["all", "Todas"]].concat(Store.categories.map(c => [c.id, c.label]))
            onPicked: v => filter.category = v
        },
        Select { visible: !Store.offline; label: "Ordenar"; value: filter.sortKey; options: [["relevance", "Relevancia"], ["name", "Nombre"]]; onPicked: v => filter.sortKey = v },
        Btn { visible: !Store.offline; small: true; variant: "ghost"; text: "Limpiar"; iconName: "X"; onClicked: Nav.setQuery("") }
    ]

    EmptyState {
        visible: Store.offline
        Layout.fillWidth: true
        iconName: "CloudOff"; error: true
        title: "No se pudo completar la búsqueda"
        text: "Error al contactar con el repositorio. Comprueba tu conexión."
        Btn { text: "Reintentar"; onClicked: Store.offline = false }
    }
    ColumnLayout {
        visible: !Store.offline && page.loading
        Layout.fillWidth: true
        spacing: 8
        Repeater { model: 4; delegate: Skeleton { Layout.fillWidth: true; Layout.preferredHeight: 64 } }
    }
    Item {
        visible: !Store.offline && !page.loading && filter.count > 0
        Layout.fillWidth: true
        implicitHeight: list.implicitHeight + 16
        RoundedBox { anchors.fill: parent; fill: Colors.surface50; radius: 16 }
        ColumnLayout {
            id: list
            x: 8; y: 8; width: parent.width - 16
            spacing: 4
            Repeater {
                model: filter
                delegate: AppRow {
                    Layout.fillWidth: true
                    app: model.app
                    extra: model.app.categoryLabel + " · " + model.reason
                }
            }
        }
    }
    EmptyState {
        visible: !Store.offline && !page.loading && filter.count === 0
        Layout.fillWidth: true
        iconName: "SearchX"
        title: "Sin resultados para «" + page.q + "»"
        text: "Revisa la ortografía o prueba con otra palabra clave o categoría."
        Repeater { model: ["navegador", "vídeo", "editor", "juegos"]; delegate: Btn { required property string modelData; small: true; variant: "ghost"; text: modelData; onClicked: Nav.setQuery(modelData) } }
        Repeater { model: Store.categories.slice(0, 3); delegate: Btn { required property var modelData; small: true; variant: "quiet"; text: modelData.label; onClicked: Nav.go("cat", modelData.id) } }
    }
}
