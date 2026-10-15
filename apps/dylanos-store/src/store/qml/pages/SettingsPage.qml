import QtQuick
import QtQuick.Layouts
import DylanOS

PageScaffold {
    id: page
    title: "Ajustes"

    // Draft vs saved preferences (Aplicar / Descartar), mirroring the prototype.
    property var draft: ({ theme: "dark", lang: "es", notif: true, auto: false, freq: "daily", telem: false })
    property var saved: ({ theme: "dark", lang: "es", notif: true, auto: false, freq: "daily", telem: false })
    readonly property bool dirty: JSON.stringify(draft) !== JSON.stringify(saved)
    function set(k, v) { const d = Object.assign({}, draft); d[k] = v; draft = d }

    headerControls: [
        Btn { variant: "ghost"; text: "Descartar"; enabled: page.dirty; onClicked: page.draft = page.saved },
        Btn { text: "Aplicar"; enabled: page.dirty; onClicked: { page.saved = page.draft; Store.notify("Preferencias guardadas", "ok") } }
    ]

    component Group: Item {
        id: grp
        property string title
        default property alias rows: gcol.data
        Layout.fillWidth: true
        implicitHeight: gcol.implicitHeight + 32
        RoundedBox { anchors.fill: parent; fill: Colors.surface60; radius: 16 }
        ColumnLayout {
            id: gcol
            x: 16; y: 16; width: parent.width - 32
            spacing: 0
            Txt { text: grp.title; color: Colors.red300; font.pixelSize: Typography.sm; font.weight: Font.DemiBold; Layout.bottomMargin: 4 }
        }
    }
    component SRow: Item {
        id: sr
        property string t
        property string d
        property bool first: false
        default property alias control: slot.data
        Layout.fillWidth: true
        implicitHeight: Math.max(txt.implicitHeight, slot.implicitHeight) + 24
        Rectangle { visible: sr.y > 1; width: parent.width; height: 1; color: Colors.line }
        RowLayout {
            anchors { fill: parent; topMargin: 12; bottomMargin: 12 }
            spacing: 16
            ColumnLayout {
                id: txt
                Layout.fillWidth: true
                spacing: 0
                Txt { Layout.fillWidth: true; text: sr.t; font.pixelSize: Typography.sm; font.weight: Font.Medium; wrapMode: Text.WordWrap }
                Txt { visible: sr.d !== ""; Layout.fillWidth: true; text: sr.d; color: Colors.dim; font.pixelSize: Typography.xs; wrapMode: Text.WordWrap }
            }
            Item { id: slot; Layout.alignment: Qt.AlignVCenter; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: 768
        spacing: 16

        Group {
            title: "Apariencia"
            SRow {
                t: "Tema"; d: "La tienda usa por ahora el tema oscuro de DylanOS."
                Rectangle {
                    width: seg.implicitWidth + 4; height: 32
                    radius: Metrics.radiusControl; color: "transparent"; border.width: 1; border.color: Colors.line
                    Row {
                        id: seg
                        x: 2; y: 2
                        Repeater {
                            model: [["light", "Claro"], ["dark", "Oscuro"], ["auto", "Automático"]]
                            delegate: Rectangle {
                                id: seg1
                                required property var modelData
                                width: sl.implicitWidth + 24; height: 28; radius: 6
                                color: page.draft.theme === modelData[0] ? Colors.crimson : "transparent"
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData[1]
                                Accessible.checked: page.draft.theme === modelData[0]
                                Txt { id: sl; anchors.centerIn: parent; text: seg1.modelData[1]; font.pixelSize: Typography.sm; color: page.draft.theme === seg1.modelData[0] ? "white" : Colors.dim }
                                TapHandler { onTapped: page.set("theme", seg1.modelData[0]) }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }
            SRow { t: "Idioma"; Select { value: page.draft.lang; options: [["es", "Español"], ["en", "English"]]; onPicked: v => page.set("lang", v) } }
        }
        Group {
            title: "Notificaciones y actualizaciones"
            SRow { t: "Notificar actualizaciones disponibles"; Toggle { checked: page.draft.notif; Accessible.name: "Notificaciones"; onToggled: page.set("notif", checked) } }
            SRow { t: "Actualizar automáticamente"; d: "Pendiente de integración con el sistema."; Toggle { checked: page.draft.auto; Accessible.name: "Actualización automática"; onToggled: page.set("auto", checked) } }
            SRow { t: "Frecuencia de comprobación"; Select { value: page.draft.freq; options: [["daily", "Diaria"], ["weekly", "Semanal"], ["manual", "Manual"]]; onPicked: v => page.set("freq", v) } }
        }
        Group {
            title: "Fuentes de software"
            SRow { t: "Repositorio DylanOS"; d: "Gestión de fuentes: pendiente de integración."; Chip { text: "Predeterminado" } }
            SRow { t: "Añadir fuente"; Btn { small: true; variant: "quiet"; text: "Añadir"; enabled: false } }
        }
        Group {
            title: "Privacidad"
            SRow { t: "Enviar datos de uso anónimos"; d: "Desactivado por defecto."; Toggle { checked: page.draft.telem; Accessible.name: "Telemetría"; onToggled: page.set("telem", checked) } }
        }
        Group {
            title: "Conexión"
            SRow { t: "Modo sin conexión"; d: "Suspende las descargas e instalaciones hasta que se desactive."; Toggle { checked: Store.offline; Accessible.name: "Sin conexión"; onToggled: Store.offline = checked } }
        }
        Group {
            title: "Acerca de"
            Item {
                Layout.fillWidth: true
                implicitHeight: 96
                RowLayout {
                    anchors { fill: parent; topMargin: 16; bottomMargin: 16 }
                    spacing: 16
                    Image {
                        source: "qrc:/data/logo.png"
                        sourceSize.width: 64; sourceSize.height: 64
                        Layout.preferredWidth: 64; Layout.preferredHeight: 64
                        mipmap: true
                        Accessible.role: Accessible.Graphic; Accessible.description: "DylanOS"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Txt { text: Store.storeName; font.pixelSize: Typography.lg; font.weight: Font.DemiBold }
                        Txt { Layout.fillWidth: true; text: "Tienda de aplicaciones de DylanOS Crimson · Versión " + Store.storeVersion; color: Colors.dim; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
                        Txt { text: "Backend: " + Store.backendKind; color: Colors.faint; font.pixelSize: Typography.xs }
                    }
                }
            }
            SRow { t: "Créditos y licencias"; d: "Pendiente: listar licencias de los componentes."; Btn { small: true; variant: "quiet"; text: "Ver"; enabled: false } }
            SRow { t: "Ayuda y soporte"; d: "Enlaces oficiales: sin configurar."; Btn { small: true; variant: "quiet"; text: "Abrir"; enabled: false } }
        }
    }
}
