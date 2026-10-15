import QtQuick
import QtQuick.Layouts
import DylanOS

// Category listing (id "all" = whole catalog).
PageScaffold {
    id: page
    property string catId: "all"
    readonly property var cat: catId === "all" ? null : Store.category(catId)
    title: cat ? cat.label : "Todas las aplicaciones"
    sub: cat ? cat.desc : "Todo el catálogo de aplicaciones."

    headerControls: [
        Select { label: "Mostrar"; value: filter.statusFilter; options: [["all", "Todas"], ["available", "No instaladas"], ["installed", "Instaladas"]]; onPicked: v => filter.statusFilter = v },
        Select { label: "Ordenar"; value: filter.sortKey; options: [["name", "Nombre"], ["date", "Más recientes"]]; onPicked: v => filter.sortKey = v }
    ]

    AppFilterModel { id: filter; sourceModel: Store.appModel; category: page.catId; sortKey: "name" }

    AutoGrid {
        visible: filter.count > 0
        Layout.fillWidth: true
        model: filter
        delegate: AppCard { app: model.app }
    }
    EmptyState {
        visible: filter.count === 0
        Layout.fillWidth: true
        title: "Nada que mostrar"
        text: "Ninguna aplicación coincide con estos filtros."
        Btn { variant: "ghost"; text: "Quitar filtros"; onClicked: filter.statusFilter = "all" }
    }
}
