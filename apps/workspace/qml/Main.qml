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
    // Ventana DylanOS Shell: sin decoración de KWin. El título vive en la
    // barra superior propia y los controles (cerrar/minimizar/maximizar)
    // son parte del frontend, como en Explorer y Configuration.
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    readonly property int radius: 22
    property string page: initialPage
    property bool dark: preferences.dark
    readonly property var names: ({welcome:"Bienvenido", files:"Archivos", notes:"Notas", dev:"Desarrollo", monitor:"Monitor", settings:"Ajustes"})
    readonly property string pageTitle: names[page] || "DylanOS"
    readonly property var symbols: ({welcome:"✦", files:"▤", notes:"▥", dev:"⌘", monitor:"◴", settings:"⚙"})
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
    Rectangle {
        id: frame
        anchors.fill: parent
        radius: win.radius
        clip: true
        color: win.dark ? "#151519" : "#f5f5f7"
        border.width: 1
        border.color: win.dark ? "#2e2736" : "#d6d0d4"

        Rectangle {
            id: chrome
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 78
            gradient: Gradient {
                GradientStop { position: 0; color: win.dark ? "#28131e" : "#faf7fa" }
                GradientStop { position: 1; color: win.dark ? "#141018" : "#eeedf3" }
            }
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: win.dark ? "#1affffff" : "#30ffffff" }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: win.dark ? "#35DC143C" : win.palette.mid }
        RowLayout {
            anchors.fill: parent; spacing: 14
            anchors.leftMargin: 20; anchors.rightMargin: 28
            // Controles de ventana integrados (a la izquierda, estilo DylanOS)
            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter
                Rectangle {
                    width: 13; height: 13; radius: 13
                    color: closeBtn.containsMouse ? "#ff766d" : "#ff5f57"
                    Accessible.name: "Cerrar"; Accessible.role: Accessible.Button
                    Rectangle { anchors.centerIn: parent; visible: closeBtn.containsMouse; width: 6; height: 1.6; radius: 1; color: "#4d0000" }
                    MouseArea { id: closeBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.close() }
                }
                Rectangle {
                    width: 13; height: 13; radius: 13
                    color: minBtn.containsMouse ? "#ffd066" : "#febc2e"
                    Accessible.name: "Minimizar"; Accessible.role: Accessible.Button
                    Rectangle { anchors.centerIn: parent; visible: minBtn.containsMouse; width: 6; height: 1.6; radius: 1; color: "#5b3d00" }
                    MouseArea { id: minBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.showMinimized() }
                }
                Rectangle {
                    width: 13; height: 13; radius: 13
                    color: maxBtn.containsMouse ? "#48dc60" : "#28c840"
                    Accessible.name: "Maximizar"; Accessible.role: Accessible.Button
                    Rectangle {
                        anchors.centerIn: parent
                        visible: maxBtn.containsMouse && win.visibility !== Window.Maximized
                        width: 5; height: 5; radius: 1; color: "#004d10"
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: maxBtn.containsMouse && win.visibility === Window.Maximized
                        width: 7; height: 7; radius: 1; color: "#004d10"
                        Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 1; color: maxBtn.containsMouse ? "#48dc60" : "#28c840" }
                    }
                    MouseArea { id: maxBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized() }
                }
            }

            Rectangle {
                Layout.leftMargin: 8; width: 42; height: 42; radius: 14
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
                text: win.dark ? "Claro" : "Oscuro"
                onClicked: win.dark = !win.dark
                Accessible.name: "Cambiar apariencia de esta aplicación"
            }
        }

        // Arrastre de la ventana desde la barra y doble clic para maximizar.
        MouseArea {
            anchors.fill: chrome
            z: -1
            onPressed: win.startSystemMove()
            onDoubleClicked: win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized()
        }
        }

        Loader {
            id: content
            anchors.top: chrome.bottom
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 28
            source: ({welcome:"WelcomePage.qml", files:"FilesPage.qml", notes:"NotesPage.qml", dev:"DevPage.qml", monitor:"MonitorPage.qml", settings:"SettingsPage.qml"})[win.page]
            onLoaded: reveal.restart()
            NumberAnimation { id: reveal; target: content; property: "opacity"; from: 0; to: 1; duration: 180 }
        }
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
