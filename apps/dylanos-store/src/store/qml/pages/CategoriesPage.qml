import QtQuick
import QtQuick.Layouts
import DylanOS

PageScaffold {
    title: "Categorías"
    sub: "Organizadas para poder ampliarse sin rediseñar la interfaz."
    AutoGrid {
        Layout.fillWidth: true
        minCell: 240
        model: Store.categories
        delegate: CategoryTile {}
    }
}
