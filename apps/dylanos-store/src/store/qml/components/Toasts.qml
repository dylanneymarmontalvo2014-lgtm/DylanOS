import QtQuick
import DylanOS

Column {
    id: root
    spacing: 8
    z: 100
    ListModel { id: toasts }
    property int seq: 0

    Connections {
        target: Store
        function onToast(text, tone) { toasts.append({ key: ++root.seq, text: text, tone: tone }) }
    }
    Repeater {
        model: toasts
        delegate: Rectangle {
            id: t
            required property int key
            required property string text
            required property string tone
            required property int index
            width: row.implicitWidth + 32
            height: 46
            radius: Metrics.radiusCard
            color: Colors.surface2
            border.width: 1
            border.color: Colors.line
            opacity: 0
            Accessible.role: Accessible.AlertMessage
            Accessible.name: text
            NumberAnimation on opacity { from: 0; to: 1; duration: 220 }
            Row {
                id: row
                anchors.centerIn: parent
                spacing: 8
                Icon { anchors.verticalCenter: parent.verticalCenter; size: 18
                    name: t.tone === "ok" ? "CheckCircle2" : t.tone === "err" ? "AlertTriangle" : "Info"
                    color: t.tone === "ok" ? Colors.ok : t.tone === "err" ? Colors.red400 : Colors.dim }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: t.text; font.pixelSize: Typography.sm }
            }
            Timer { running: true; interval: 4200; onTriggered: { for (let i = 0; i < toasts.count; ++i) { if (toasts.get(i).key === t.key) { toasts.remove(i); break } } } }
        }
    }
}
