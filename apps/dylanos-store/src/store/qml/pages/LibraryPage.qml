import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import DylanOS

PageScaffold {
    id: page
    title: "Biblioteca"
    sub: "Organiza tus aplicaciones."
    property string tab: "fav"

    Rectangle {
        Layout.bottomMargin: 20
        implicitWidth: tabs.implicitWidth + 8
        implicitHeight: 44
        radius: 12; color: Colors.surface; border.width: 1; border.color: Colors.line
        Row {
            id: tabs
            x: 4; y: 4
            spacing: 0
            Repeater {
                model: [["fav", "Favoritos"], ["col", "Colecciones"], ["rec", "Usadas recientemente"]]
                delegate: AbstractButton {
                    id: tb
                    required property var modelData
                    height: 36
                    implicitWidth: tl.implicitWidth + 32
                    hoverEnabled: true
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData[1]
                    Accessible.selected: page.tab === modelData[0]
                    onClicked: page.tab = modelData[0]
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    background: Rectangle { radius: 8; color: page.tab === tb.modelData[0] ? Colors.crimson : "transparent" }
                    contentItem: Txt { id: tl; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: tb.modelData[1]; font.pixelSize: Typography.sm; color: page.tab === tb.modelData[0] ? "white" : tb.hovered ? "white" : Colors.dim }
                }
            }
        }
    }

    AutoGrid {
        visible: page.tab === "fav" && Store.favorites.length > 0
        Layout.fillWidth: true
        model: Store.favorites
        delegate: AppCard { app: Store.app(modelData) }
    }
    EmptyState {
        visible: page.tab === "fav" && Store.favorites.length === 0
        Layout.fillWidth: true
        iconName: "Heart"
        title: "Aún no hay favoritos"
        text: "Marca el corazón en una ficha para guardarla aquí."
    }

    ColumnLayout {
        visible: page.tab === "col"
        Layout.fillWidth: true
        spacing: 20
        Repeater {
            model: Store.collections
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                ColumnLayout {
                    spacing: 0
                    Txt { text: modelData.name; font.weight: Font.DemiBold }
                    Txt { text: modelData.desc; color: Colors.dim; font.pixelSize: Typography.xs }
                }
                AutoGrid { Layout.fillWidth: true; model: modelData.ids; delegate: AppCard { app: Store.app(modelData) } }
            }
        }
        RowLayout {
            spacing: 8
            Icon { name: "Cloud"; size: 16; color: Colors.faint }
            Txt { Layout.fillWidth: true; text: "Sincronizar colecciones entre equipos: función futura (requeriría una cuenta)."; color: Colors.faint; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
        }
    }

    ColumnLayout {
        visible: page.tab === "rec"
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: note.implicitHeight + 24
            radius: Metrics.radiusCard; color: Colors.surface; border.width: 1; border.color: Colors.line
            Txt { id: note; x: 12; y: 12; width: parent.width - 24; text: "Se muestran tus aplicaciones instaladas o actualizadas más recientemente."; color: Colors.dim; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
        }
        Item {
            visible: Store.recentInstalls(1).length > 0
            Layout.fillWidth: true
            implicitHeight: rl.implicitHeight + 16
            RoundedBox { anchors.fill: parent; fill: Colors.surface50; radius: 16 }
            ColumnLayout {
                id: rl
                x: 8; y: 8; width: parent.width - 16
                spacing: 4
                Repeater {
                    model: Store.recentInstalls(8)
                    delegate: AppRow { visible: index < 4; Layout.fillWidth: true; app: Store.app(modelData) }
                }
            }
        }
        EmptyState {
            visible: Store.recentInstalls(1).length === 0
            Layout.fillWidth: true
            iconName: "PackageOpen"
            title: "Todavía no hay actividad"
            text: "Instala o actualiza aplicaciones y aparecerán aquí."
        }
    }
}
