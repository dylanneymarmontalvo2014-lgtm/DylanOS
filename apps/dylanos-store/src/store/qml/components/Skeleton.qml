import QtQuick
import DylanOS

Rectangle {
    radius: Metrics.radiusCard
    color: Colors.white(0.06)
    SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: visible
        NumberAnimation { from: 1; to: 0.5; duration: 1000; easing.type: Easing.InOutQuad }
        NumberAnimation { from: 0.5; to: 1; duration: 1000; easing.type: Easing.InOutQuad }
    }
}
