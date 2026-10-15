import QtQuick
import DylanOS

// Interactive surface used by cards, tiles and rows (hover border + lift like React hover:border-crimson/50).
Item {
    id: root
    property bool interactive: true
    property bool lift: false
    property color fill: Colors.surface70
    property color hoverFill: Colors.surface2
    property color border: Colors.line
    property int radius: Metrics.radiusCard
    property alias hovered: hh.hovered
    property alias pressedByTap: tap.pressed
    signal clicked()
    signal activated()
    default property alias content: inner.data
    activeFocusOnTab: interactive
    Accessible.role: Accessible.Link
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()

    transform: Translate { y: root.lift && hh.hovered ? -2 : 0; Behavior on y { NumberAnimation { duration: 120 } } }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.interactive && hh.hovered ? root.hoverFill : root.fill
        border.width: 1
        border.color: root.interactive && hh.hovered ? Colors.alpha(Colors.crimson, 0.5) : root.border
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: root.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Colors.crimsonHi
        visible: root.activeFocus
    }
    Item { id: inner; anchors.fill: parent }
    HoverHandler { id: hh; enabled: root.interactive; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: root.interactive; onTapped: root.clicked() }
}
