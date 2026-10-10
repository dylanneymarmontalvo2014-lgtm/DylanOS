import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtCore

ApplicationWindow {
    id: win
    width: 1180; height: 780
    minimumWidth: 940; minimumHeight: 650
    visible: true
    title: pageTitle + " · DylanOS"
    font.family: "Inter"
    font.pixelSize: 14
    color: dark ? "#14151b" : "#f4f5f8"
    property string page: initialPage
    property bool dark: preferences.dark
    readonly property var pages: [
        {key:"welcome", name:"Bienvenido", symbol:"✦", group:"DYLANOS"},
        {key:"files", name:"Archivos", symbol:"▤", group:""},
        {key:"notes", name:"Notas", symbol:"▥", group:""},
        {key:"store", name:"Software", symbol:"⊞", group:""},
        {key:"dev", name:"Desarrollo", symbol:"⌘", group:"ESPACIO DE TRABAJO"},
        {key:"monitor", name:"Monitor", symbol:"◴", group:""},
        {key:"settings", name:"Ajustes", symbol:"⚙", group:""}
    ]
    readonly property string pageTitle: pages.filter(p => p.key === page)[0].name
    palette.window: win.color
    palette.windowText: dark ? "#f1f1f6" : "#20212b"
    palette.text: dark ? "#f1f1f6" : "#20212b"
    palette.buttonText: dark ? "#f1f1f6" : "#20212b"
    palette.base: dark ? "#1d1f28" : "#ffffff"
    palette.button: dark ? "#2a2d38" : "#e9eaf0"
    palette.mid: dark ? "#383b49" : "#d8dae3"
    palette.highlight: "#DC143C"
    palette.highlightedText: "white"
    palette.placeholderText: dark ? "#a1a5b8" : "#636879"
    Settings { id: preferences; property bool dark: true }
    onDarkChanged: preferences.dark = dark
    onClosing: function(close) { if (page === "notes" && content.item) close.accepted = content.item.flush() }

    function changePage(key) {
        if (page === "notes" && content.item && !content.item.flush()) return
        page = key
    }
    Connections {
        target: backend
        function onMessage(text) { toastLabel.text = text; toast.open(); toastTimer.restart() }
    }
    Shortcut { sequence: "Ctrl+1"; onActivated: win.changePage("files") }
    Shortcut { sequence: "Ctrl+2"; onActivated: win.changePage("notes") }
    Shortcut { sequence: "Ctrl+3"; onActivated: win.changePage("dev") }

    RowLayout {
        anchors.fill: parent; spacing: 0
        Rectangle {
            Layout.preferredWidth: 226; Layout.fillHeight: true
            gradient: Gradient {
                GradientStop { position: 0; color: win.dark ? "#292632" : "#eee6ee" }
                GradientStop { position: 0.55; color: win.dark ? "#202430" : "#e6edf5" }
                GradientStop { position: 1; color: win.dark ? "#20212b" : "#edf0f6" }
            }
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: win.palette.mid }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 20; spacing: 8
                RowLayout {
                    Layout.topMargin: 15; Layout.bottomMargin: 25; spacing: 11
                    Image {
                        Layout.preferredWidth: 37; Layout.preferredHeight: 37
                        source: "../../branding/logo.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    Column {
                        Text { text: "DylanOS"; color: win.palette.text; font.pixelSize: 21; font.weight: Font.DemiBold; font.letterSpacing: -0.7 }
                        Text { text: "1.0 BETA"; color: win.palette.placeholderText; font.pixelSize: 9; font.letterSpacing: 2 }
                    }
                }
                Repeater {
                    model: win.pages
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 9
                        Label {
                            visible: modelData.group !== ""; text: modelData.group
                            color: win.palette.placeholderText; font.pixelSize: 9; font.letterSpacing: 1.3
                            Layout.topMargin: 15; Layout.leftMargin: 12; Layout.bottomMargin: 5
                        }
                        ItemDelegate {
                            id: nav
                            Layout.fillWidth: true; implicitHeight: 43
                            onClicked: win.changePage(modelData.key)
                            background: Rectangle {
                                radius: 11
                                color: win.page === modelData.key ? (win.dark ? "#61404e" : "#f5cdd3") : nav.hovered ? win.palette.button : "transparent"
                                border.color: win.page === modelData.key ? (win.dark ? "#825263" : "#eab7c0") : "transparent"
                            }
                            contentItem: RowLayout {
                                spacing: 12
                                Label { text: modelData.symbol; font.pixelSize: 20; Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; color: win.page === modelData.key ? (win.dark ? "#ffb6c1" : "#a82a41") : win.palette.placeholderText }
                                Label { text: modelData.name; font.pixelSize: 13; font.weight: win.page === modelData.key ? Font.DemiBold : Font.Normal; Layout.fillWidth: true }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Rectangle { Layout.fillWidth: true; height: 1; color: win.palette.mid }
                Label { text: "Un espacio para tus ideas."; color: win.palette.placeholderText; font.pixelSize: 11; Layout.topMargin: 12 }
                Label { text: "Debian + KDE Plasma"; color: win.palette.placeholderText; font.pixelSize: 10; Layout.bottomMargin: 6 }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 28; Layout.bottomMargin: 20
                Label { text: win.pageTitle; font.pixelSize: 16; font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
                Label { text: "TU ESPACIO, A TU MANERA"; color: win.palette.placeholderText; font.pixelSize: 9; font.letterSpacing: 1.5 }
                ToolButton { text: win.dark ? "☀" : "☾"; onClicked: win.dark = !win.dark; Accessible.name: "Cambiar apariencia de las apps"; font.pixelSize: 21 }
            }
            Loader {
                id: content
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.bottomMargin: 24
                source: ({welcome:"WelcomePage.qml", files:"FilesPage.qml", notes:"NotesPage.qml", store:"StorePage.qml", dev:"DevPage.qml", monitor:"MonitorPage.qml", settings:"SettingsPage.qml"})[win.page]
            }
        }
    }
    Popup {
        id: toast
        x: Math.max(16, (win.width - width) / 2); y: win.height - height - 24
        width: Math.min(650, win.width - 40); padding: 16
        background: Rectangle { color: win.palette.button; border.color: win.palette.mid; radius: 12 }
        contentItem: Label { id: toastLabel; wrapMode: Text.Wrap }
    }
    Timer { id: toastTimer; interval: 6500; onTriggered: toast.close() }
}
