import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import DylanOS

Item {
    id: root
    readonly property var items: [
        { v: "home", label: "Inicio", icon: "Home" },
        { v: "cats", label: "Categorías", icon: "LayoutGrid" },
        { v: "cat:office", label: "Productividad", icon: "Briefcase" },
        { v: "cat:dev", label: "Desarrollo", icon: "Code2" },
        { v: "cat:gfx", label: "Diseño", icon: "Palette" },
        { v: "cat:media", label: "Multimedia", icon: "Music" },
        { v: "cat:games", label: "Juegos", icon: "Gamepad2" },
        { v: "cat:sys", label: "Utilidades", icon: "Wrench" },
        { v: "cat:sec", label: "Seguridad", icon: "ShieldCheck" }
    ]
    readonly property string active: Nav.view === "cat" ? "cat:" + Nav.viewId : Nav.view

    component NavItem: AbstractButton {
        id: ni
        property string v
        property string iconName
        property int badge: 0
        readonly property bool on: root.active === v
        Layout.fillWidth: true
        implicitHeight: 44
        hoverEnabled: true
        Accessible.role: Accessible.PageTab
        Accessible.name: text
        Accessible.selected: on
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        onClicked: { const p = v.split(":"); Nav.go(p[0], p[1]) }
        background: Rectangle {
            radius: Metrics.radiusControl
            color: ni.on ? Colors.crimson : ni.hovered ? Colors.white(0.06) : "transparent"
            Rectangle { anchors.fill: parent; anchors.margins: -2; radius: 10; color: "transparent"; border.width: 2; border.color: Colors.crimsonHi; visible: ni.visualFocus }
        }
        contentItem: RowLayout {
            spacing: 12
            Icon { Layout.leftMargin: 12; name: ni.iconName; size: 18; color: ni.on || ni.hovered ? "white" : Colors.dim }
            Txt { Layout.fillWidth: true; text: ni.text; color: ni.on || ni.hovered ? "white" : Colors.dim }
            Rectangle {
                visible: ni.badge > 0
                Layout.preferredWidth: 20; Layout.preferredHeight: 20; Layout.rightMargin: 12
                radius: 10; color: Colors.crimson
                Txt { anchors.centerIn: parent; text: ni.badge; color: "white"; font.pixelSize: Typography.xs }
            }
        }
    }

    RoundedBox { anchors.fill: parent; glow: true }
    ColumnLayout {
        anchors { fill: parent; margins: 12 }
        spacing: 0

        // Search
        TextField {
            id: search
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.bottomMargin: 12
            text: Nav.query
            placeholderText: "Buscar aplicaciones…"
            placeholderTextColor: Colors.faint
            color: Colors.fg
            font.family: Typography.family
            font.pixelSize: Typography.sm
            leftPadding: 36; rightPadding: 32
            selectionColor: Colors.crimson
            Accessible.name: "Buscar aplicaciones"
            onTextEdited: Nav.setQuery(text)
            background: Rectangle {
                radius: Metrics.radiusControl
                color: Colors.alpha("black", 0.3)
                border.width: search.activeFocus ? 2 : 1
                border.color: search.activeFocus ? Colors.crimsonHi : Colors.line
                Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "Search"; size: 16; color: Colors.faint }
            }
            Item {
                visible: search.text !== ""
                x: search.width - 28; anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20
                Accessible.role: Accessible.Button
                Accessible.name: "Limpiar búsqueda"
                Icon { anchors.centerIn: parent; name: "X"; size: 16; color: Colors.faint }
                TapHandler { onTapped: Nav.setQuery("") }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: nav1.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: nav1
                width: parent.width
                spacing: 2
                Repeater {
                    model: root.items
                    delegate: NavItem { required property var modelData; v: modelData.v; text: modelData.label; iconName: modelData.icon }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; Layout.preferredHeight: 1; color: Colors.line }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 2
            NavItem { v: "updates"; text: "Actualizaciones"; iconName: "RefreshCw"; badge: Store.updateCount }
            NavItem { v: "installed"; text: "Instaladas"; iconName: "HardDriveDownload" }
        }
    }
}
