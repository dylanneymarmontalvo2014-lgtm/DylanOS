import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import DylanOS

ApplicationWindow {
    id: win
    visible: true
    width: 1280
    height: 800
    minimumWidth: 360
    minimumHeight: 480
    color: Colors.bg
    title: Store.storeName
    font.family: Typography.family

    readonly property bool wide: width >= Metrics.sidebarBreakpoint
    Binding { target: Nav; property: "windowWidth"; value: win.width }
    onWideChanged: if (wide) drawer.close()

    Connections {
        target: Nav
        function onNavigated() { drawer.close(); pages.active = false; pages.active = true }
    }

    component TopLink: AbstractButton {
        id: tl
        property string v
        property int badge: 0
        readonly property bool on: v === "home" ? Nav.topSection === "home" : Nav.view === v
        implicitHeight: Metrics.topBarHeight
        implicitWidth: row.implicitWidth + 8
        hoverEnabled: true
        Accessible.role: Accessible.PageTab
        Accessible.name: text
        onClicked: Nav.go(v)
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        background: Rectangle { color: "transparent"; border.width: 2; border.color: Colors.crimsonHi; radius: 6; visible: tl.visualFocus; anchors.margins: 8 }
        contentItem: Row {
            id: row
            spacing: 8
            leftPadding: 4
            Txt { anchors.verticalCenter: parent.verticalCenter; text: tl.text; font.pixelSize: Typography.sm; color: tl.on ? Colors.red500 : tl.hovered ? Colors.red300 : Colors.fg }
            Rectangle {
                visible: tl.badge > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20; radius: 10; color: Colors.crimson
                Txt { anchors.centerIn: parent; text: tl.badge; font.pixelSize: Typography.xs; color: "white" }
            }
        }
    }

    header: Rectangle {
        implicitHeight: Metrics.topBarHeight + 1
        color: Colors.bg
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Colors.line }
        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16; bottomMargin: 1 }
            spacing: 20
            AbstractButton {
                visible: !win.wide
                implicitWidth: 28; implicitHeight: 28
                Accessible.name: "Menú"
                onClicked: drawer.open()
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                contentItem: Item { Icon { anchors.centerIn: parent; name: "Menu"; size: 20; color: Colors.fg } }
                background: null
            }
            AbstractButton {
                id: logo
                implicitWidth: lrow.implicitWidth
                implicitHeight: 32
                Accessible.name: Store.storeName
                onClicked: Nav.go("home")
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                background: null
                contentItem: Row {
                    id: lrow
                    spacing: 10
                    Image {
                        source: "qrc:/data/logo.png"
                        sourceSize.width: 28; sourceSize.height: 28
                        width: 28; height: 28
                        mipmap: true
                        anchors.verticalCenter: parent.verticalCenter
                        Accessible.role: Accessible.Graphic; Accessible.description: "DylanOS"
                    }
                    Txt { anchors.verticalCenter: parent.verticalCenter; text: Store.storeName; font.weight: Font.DemiBold }
                }
            }
            Row {
                spacing: win.width < 640 ? 16 : 24
                TopLink { v: "home"; text: "Tienda" }
                TopLink { v: "library"; text: "Biblioteca" }
                TopLink { v: "updates"; text: "Actualizaciones"; badge: Store.updateCount }
            }
            Item { Layout.fillWidth: true }
            AbstractButton {
                id: gear
                implicitWidth: 36; implicitHeight: 36
                hoverEnabled: true
                Accessible.name: "Ajustes"
                onClicked: Nav.go("settings")
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                background: Rectangle { radius: Metrics.radiusControl; color: gear.hovered ? Colors.white(0.1) : "transparent"; border.width: 2; border.color: gear.visualFocus ? Colors.crimsonHi : "transparent" }
                contentItem: Item { Icon { anchors.centerIn: parent; name: "Settings"; size: 19; color: Nav.view === "settings" ? Colors.red500 : Colors.dim } }
            }
        }
    }

    RowLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 16

        SidebarPanel {
            visible: win.wide
            Layout.preferredWidth: Metrics.sidebarWidth
            Layout.fillHeight: true
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            RoundedBox { anchors.fill: parent; glow: true }
            Loader {
                id: pages
                anchors { fill: parent; margins: 1 }
                clip: true
                layer.enabled: true
                sourceComponent: {
                    switch (Nav.view) {
                    case "cats": return cCats
                    case "cat": return cBrowse
                    case "search": return cSearch
                    case "app": return cDetail
                    case "library": return cLibrary
                    case "updates": return cUpdates
                    case "installed": return cInstalled
                    case "settings": return cSettings
                    default: return cHome
                    }
                }
            }
        }
    }

    Component { id: cHome; HomePage {} }
    Component { id: cCats; CategoriesPage {} }
    Component { id: cBrowse; BrowsePage { catId: Nav.viewId } }
    Component { id: cSearch; SearchPage {} }
    Component { id: cDetail; DetailPage { appId: Nav.viewId } }
    Component { id: cLibrary; LibraryPage {} }
    Component { id: cUpdates; UpdatesPage {} }
    Component { id: cInstalled; InstalledPage {} }
    Component { id: cSettings; SettingsPage {} }

    Drawer {
        id: drawer
        edge: Qt.LeftEdge
        width: Math.min(288, win.width * 0.85)
        height: win.height
        padding: 12
        modal: true
        Overlay.modal: Rectangle { color: Colors.alpha("black", 0.7) }
        background: null
        contentItem: SidebarPanel {}
    }

    Toasts {
        parent: Overlay.overlay
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 20; bottomMargin: 20 }
    }
}
