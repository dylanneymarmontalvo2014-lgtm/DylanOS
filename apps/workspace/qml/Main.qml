import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtCore

ApplicationWindow {
    id: win
    width: 1120; height: 760
    minimumWidth: 900; minimumHeight: 640
    visible: true
    title: pageTitle + " · DylanOS"
    font.family: "Inter"; font.pixelSize: 14
    color: dark ? "#151519" : "#f5f5f7"
    property string page: initialPage
    property bool dark: preferences.dark
    readonly property var names: ({welcome:"Bienvenido", files:"Archivos", notes:"Notas", store:"DylanOS Store", dev:"Desarrollo", monitor:"Monitor", settings:"Ajustes"})
    readonly property string pageTitle: names[page] || "DylanOS"
    readonly property var symbols: ({welcome:"✦", files:"▤", notes:"▥", store:"⊞", dev:"⌘", monitor:"◴", settings:"⚙"})
    palette.window: win.color
    palette.windowText: dark ? "#f5f5f7" : "#202024"
    palette.text: dark ? "#f5f5f7" : "#202024"
    palette.buttonText: dark ? "#f5f5f7" : "#202024"
    palette.base: dark ? "#202025" : "#ffffff"
    palette.button: dark ? "#2b2b32" : "#ebebf0"
    palette.mid: dark ? "#3c3b44" : "#dcdce4"
    palette.highlight: "#DC143C"
    palette.highlightedText: "white"
    palette.placeholderText: dark ? "#aaa7b4" : "#666373"
    Settings { id: preferences; category: "Appearance"; property bool dark: true }
    onDarkChanged: preferences.dark = dark
    onClosing: function(close) { if (page === "notes" && content.item) close.accepted = content.item.flush() }

    // Retained for internal navigation/QA; app launchers create separate processes.
    function changePage(key) {
        if (!names[key]) return
        if (page === "notes" && content.item && !content.item.flush()) return
        page = key
    }
    Connections {
        target: backend
        function onMessage(text) { toastLabel.text = text; toast.open(); toastTimer.restart() }
    }
    Shortcut { sequence: "Ctrl+W"; onActivated: win.close() }
    header: ToolBar {
        implicitHeight: 78
        padding: 0
        background: Rectangle {
            gradient: Gradient {
                GradientStop { position: 0; color: win.dark ? "#28131e" : "#faf7fa" }
                GradientStop { position: 1; color: win.dark ? "#141018" : "#eeedf3" }
            }
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: win.dark ? "#1affffff" : "#30ffffff" }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: win.dark ? "#35DC143C" : win.palette.mid }
        }
        RowLayout {
            width: parent.width; height: 78; spacing: 14
            Rectangle {
                Layout.leftMargin: 28; width: 42; height: 42; radius: 14
                color: win.dark ? "#46232f" : "#f8dfe6"; border.color: win.dark ? "#69404d" : "#edc5d0"
                Label { anchors.centerIn: parent; text: win.symbols[win.page]; color: win.dark ? "#ffa2b7" : "#b61035"; font.pixelSize: 24 }
            }
            ColumnLayout {
                spacing: 3
                Label { text: win.pageTitle; font.pixelSize: 18; font.weight: Font.DemiBold }
                Label { text: "DYLANOS"; color: win.palette.placeholderText; font.pixelSize: 9; font.letterSpacing: 2 }
            }
            Item { Layout.fillWidth: true }
            ActionButton {
                text: win.dark ? "Claro" : "Oscuro"; Layout.rightMargin: 28
                onClicked: win.dark = !win.dark
                Accessible.name: "Cambiar apariencia de esta aplicación"
            }
        }
    }
    Loader {
        id: content
        anchors.fill: parent; anchors.margins: 28
        source: ({welcome:"WelcomePage.qml", files:"FilesPage.qml", notes:"NotesPage.qml", store:"StorePage.qml", dev:"DevPage.qml", monitor:"MonitorPage.qml", settings:"SettingsPage.qml"})[win.page]
        onLoaded: reveal.restart()
        NumberAnimation { id: reveal; target: content; property: "opacity"; from: 0; to: 1; duration: 180 }
    }
    Popup {
        id: toast
        x: Math.max(16, (win.width - width) / 2); y: win.height - height - 115
        width: Math.min(650, win.width - 40); padding: 16
        background: Rectangle { color: win.palette.button; border.color: win.palette.mid; radius: 16 }
        contentItem: Label { id: toastLabel; wrapMode: Text.Wrap; Accessible.role: Accessible.AlertMessage }
    }
    Timer { id: toastTimer; interval: 6500; onTriggered: toast.close() }
}
