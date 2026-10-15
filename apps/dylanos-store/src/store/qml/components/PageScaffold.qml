import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import DylanOS

// Scrollable page with the React `Page` header (title, subtitle, right-aligned controls).
Flickable {
    id: root
    property string title
    property string sub
    property bool header: true
    property int pad: width < 640 ? Metrics.pagePaddingNarrow : Metrics.pagePadding
    default property alias content: body.data
    property alias headerControls: rightFlow.data
    readonly property real contentW: width - 2 * pad

    contentWidth: width
    contentHeight: column.implicitHeight + 2 * pad
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Colors.alpha("#3a2326", 1); opacity: parent.active ? 1 : 0.0 }
        background: null
    }

    opacity: 0
    y: 6
    Component.onCompleted: enter.start()
    ParallelAnimation {
        id: enter
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "y"; to: 0; duration: 220; easing.type: Easing.OutQuad }
    }

    ColumnLayout {
        id: column
        x: root.pad
        y: root.pad
        width: root.contentW
        spacing: 0

        Item {
            id: head
            visible: root.header
            Layout.fillWidth: true
            Layout.bottomMargin: 20
            readonly property real rightNatural: {
                let w = 0, n = 0
                for (let i = 0; i < rightFlow.children.length; ++i) {
                    const c = rightFlow.children[i]
                    if (c.visible) { w += c.implicitWidth; ++n }
                }
                return w + Math.max(0, n - 1) * rightFlow.spacing
            }
            readonly property bool beside: rightNatural === 0 || rightNatural + 280 <= width
            implicitHeight: beside ? Math.max(titleCol.implicitHeight, rightFlow.implicitHeight)
                                   : titleCol.implicitHeight + 12 + rightFlow.implicitHeight
            Column {
                id: titleCol
                width: head.beside ? head.width - head.rightNatural - (head.rightNatural > 0 ? 12 : 0) : head.width
                spacing: 4
                Txt { width: parent.width; text: root.title; font.pixelSize: Typography.h1; font.weight: Font.DemiBold; wrapMode: Text.WordWrap; Accessible.role: Accessible.Heading }
                Txt { visible: root.sub !== ""; width: parent.width; text: root.sub; color: Colors.dim; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
            }
            Flow {
                id: rightFlow
                spacing: 12
                width: Math.min(head.rightNatural, head.width)
                x: head.beside ? head.width - width : 0
                y: head.beside ? 0 : titleCol.implicitHeight + 12
            }
        }
        ColumnLayout { id: body; Layout.fillWidth: true; spacing: 0 }
    }
}
