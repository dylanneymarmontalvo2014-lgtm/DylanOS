import QtQuick
import QtQuick.Layouts
import DylanOS

PageScaffold {
    id: page
    title: "Actualizaciones"
    sub: done ? "Todo al día" : pending + " pendientes"


    // Rows come from the initial updates list; recomputed on every state change.
    property int tick: 0
    Connections { target: Store; function onCountsChanged() { page.tick++ } }
    Repeater { id: stateProbe; model: Store.list("updates"); delegate: Item { Connections { target: Store.app(modelData); function onStateChanged() { page.tick++ } } } }

    readonly property var rows: Store.list("updates").map(id => Store.app(id))
    readonly property int pending: { tick; return rows.filter(a => a.status === "update").length }
    readonly property bool busy: { tick; return rows.some(a => a.status === "busy") }
    readonly property bool done: { tick; return rows.length > 0 && rows.every(a => a.status === "installed") }
    readonly property bool failedAny: { tick; return rows.some(a => a.status === "error") }
    readonly property real total: { tick; return rows.reduce((n, a) => n + (a.status === "installed" ? 100 : a.status === "busy" ? a.progress : 0), 0) / Math.max(1, rows.length) }
    property string openId: ""

    headerControls: Btn { text: "Actualizar todas"; iconName: "RefreshCw"; enabled: page.pending > 0 && !page.busy; onClicked: auth.open() }

    Rectangle {
        visible: page.busy || page.done || page.failedAny
        Layout.fillWidth: true
        Layout.bottomMargin: 16
        implicitHeight: sum.implicitHeight + 32
        radius: Metrics.radiusCard
        color: page.done ? Colors.alpha(Colors.ok, 0.1) : Colors.surface
        border.width: 1
        border.color: page.done ? Colors.alpha(Colors.ok, 0.4) : Colors.line
        ColumnLayout {
            id: sum
            x: 16; y: 16; width: parent.width - 32
            spacing: 8
            RowLayout {
                visible: page.done
                spacing: 8
                Icon { name: "CheckCircle2"; size: 24; color: Colors.ok }
                Txt { Layout.fillWidth: true; text: "Todas las actualizaciones se han instalado correctamente."; font.weight: Font.Medium; wrapMode: Text.WordWrap }
            }
            RowLayout {
                visible: !page.done
                Layout.fillWidth: true
                Txt { Layout.fillWidth: true; text: page.failedAny && !page.busy ? "Algunas actualizaciones han fallado" : "Progreso general"; font.pixelSize: Typography.sm }
                Txt { text: Math.round(page.total) + "%"; font.pixelSize: Typography.sm }
            }
            Progress { visible: !page.done; Layout.fillWidth: true; value: page.total; label: "Progreso general" }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: page.rows
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property var a: modelData
                readonly property string s: a.status
                Layout.fillWidth: true
                implicitHeight: rc.implicitHeight + 24
                radius: Metrics.radiusCard; color: Colors.surface60; border.width: 1; border.color: Colors.line
                ColumnLayout {
                    id: rc
                    x: 12; y: 12; width: parent.width - 24
                    spacing: 12
                    GridLayout {
                        Layout.fillWidth: true
                        columns: width < 520 ? 3 : 4
                        columnSpacing: 12; rowSpacing: 8
                        AppIcon { app: row.a; size: 44 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            AbstractButtonLike {
                                label: row.a.name
                                chevron: false
                                implicitHeight: 24
                                onClicked: Nav.go("app", row.a.appId)
                                contentItem: Txt { text: row.a.name; font.weight: Font.Medium; font.underline: parent.hovered }
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: (row.s === "installed" ? "Actualizada a " + row.a.currentVersion : row.a.version + " → " + row.a.newVersion) + " · " + row.a.size
                                color: Colors.dim; font.pixelSize: Typography.xs; elide: Text.ElideRight
                            }
                        }
                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: 32
                            Chip { id: chip; visible: row.s === "installed"; anchors.verticalCenter: parent.verticalCenter; tone: "ok"; text: "Actualizada"; iconName: "Check" }
                            Btn {
                                id: act
                                visible: row.s !== "installed"
                                small: true
                                variant: row.s === "busy" ? "ghost" : row.s === "error" ? "danger" : "primary"
                                text: row.s === "busy" ? "Cancelar" : row.s === "error" ? "Reintentar" : "Actualizar"
                                iconName: row.s === "error" ? "RotateCcw" : ""
                                onClicked: row.s === "busy" ? Store.cancel(row.a.appId) : row.s === "error" ? Store.retry(row.a.appId) : Store.update(row.a.appId)
                            }
                            implicitWidth: row.s === "installed" ? chip.implicitWidth : act.implicitWidth
                        }
                        AbstractButtonLike {
                            id: exp
                            implicitWidth: 32; implicitHeight: 32
                            Accessible.name: "Ver cambios"
                            Accessible.checked: page.openId === row.a.appId
                            onClicked: page.openId = page.openId === row.a.appId ? "" : row.a.appId
                            contentItem: Item { Icon { anchors.centerIn: parent; name: "ChevronDown"; size: 16; color: Colors.dim; rotation: page.openId === row.a.appId ? 180 : 0 } }
                            background: Rectangle { radius: Metrics.radiusControl; color: exp.hovered ? Colors.white(0.1) : "transparent" }
                        }
                    }
                    ColumnLayout {
                        visible: row.s === "busy"
                        Layout.fillWidth: true
                        spacing: 4
                        Txt { text: Strings.stage(row.a.progress) + " · " + Math.round(row.a.progress) + "%"; color: Colors.dim; font.pixelSize: Typography.xs }
                        Progress { Layout.fillWidth: true; value: row.a.progress; label: row.a.name }
                    }
                    ErrorBox { visible: row.s === "error"; Layout.fillWidth: true; app: row.a; onRetry: Store.retry(row.a.appId) }
                    ColumnLayout {
                        visible: page.openId === row.a.appId
                        Layout.fillWidth: true
                        Layout.leftMargin: 40
                        spacing: 4
                        Repeater { model: row.a.changes; delegate: Txt { required property string modelData; Layout.fillWidth: true; text: "•  " + modelData; color: Colors.dim; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap } }
                    }
                }
            }
        }
    }

    EmptyState {
        visible: page.done
        Layout.fillWidth: true
        Layout.topMargin: 16
        iconName: "CheckCircle2"
        title: "Sin actualizaciones pendientes"
        text: "Tu software está al día."
    }

    ConfirmDialog {
        id: auth
        objectName: "authDialog"
        iconName: "KeyRound"
        title: "Se requiere autenticación"
        message: "Para actualizar " + page.pending + " aplicaciones se necesitan permisos de administrador."
        actions: [
            Btn { text: "Cancelar"; variant: "ghost"; onClicked: auth.close() },
            Btn { text: "Autorizar"; onClicked: { auth.close(); Store.updateAll() } }
        ]
    }
}
