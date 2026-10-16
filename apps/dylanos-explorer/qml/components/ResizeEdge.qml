import QtQuick

MouseArea {
    required property var window
    property int edges: 0
    property int cursor: Qt.ArrowCursor
    cursorShape: cursor
    acceptedButtons: Qt.LeftButton
    onPressed: window.startSystemResize(edges)
}
