import QtQuick
import QtQuick.Layouts
import DylanOS

PageScaffold {
    id: page
    header: false
    property string appId
    readonly property var app: Store.app(appId)
    readonly property string st: app.status
    readonly property bool inst: st === "installed" || st === "update" || ((st === "busy" || st === "error") && app.isUpdate)
    readonly property bool favorite: Store.favorites.indexOf(appId) >= 0
    readonly property bool twoCols: Nav.windowWidth >= 1024
    readonly property string na: "Información no disponible"

    component Info: Rectangle {
        property string k
        property string v
        property bool faint: false
        Layout.fillWidth: true
        implicitHeight: ic.implicitHeight + 24
        radius: Metrics.radiusCard
        color: Colors.surface60
        border.width: 1
        border.color: Colors.line
        ColumnLayout {
            id: ic
            x: 12; y: 12; width: parent.width - 24
            spacing: 2
            Txt { text: k; color: Colors.faint; font.pixelSize: Typography.xs }
            Txt { Layout.fillWidth: true; text: v; color: faint ? Colors.faint : Colors.fg; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
        }
    }
    component Notice: Rectangle {
        property string icon
        property string text
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Metrics.radiusCard; color: Colors.surface; border.width: 1; border.color: Colors.line
        RowLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 8
            Icon { name: icon; size: 16; color: Colors.dim }
            Txt { Layout.fillWidth: true; text: parent.parent.text; color: Colors.dim; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 24

        AbstractButtonLike {
            label: page.app.categoryLabel
            chevron: false
            contentItem: Row {
                spacing: 4
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "ChevronLeft"; size: 16; color: Colors.dim }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: page.app.categoryLabel; color: Colors.dim; font.pixelSize: Typography.sm }
            }
            onClicked: Nav.go("cat", page.app.category)
        }

        // Header
        Item {
            Layout.fillWidth: true
            implicitHeight: hdr.implicitHeight + (page.width < 640 ? 40 : 48)
            RoundedBox { anchors.fill: parent; glow: true }
            GridLayout {
                id: hdr
                readonly property bool stacked: page.width < 640 + 2 * page.pad
                x: stacked ? 20 : 24; y: stacked ? 20 : 24
                width: parent.width - 2 * x
                columns: stacked ? 1 : 3
                columnSpacing: 20; rowSpacing: 16
                AppIcon { app: page.app; size: 96 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Txt { text: page.app.name; font.pixelSize: Typography.display; font.weight: Font.DemiBold; Accessible.role: Accessible.Heading }
                        Item { width: sb.implicitWidth; height: 36; StatusBadge { id: sb; app: page.app; anchors.verticalCenter: parent.verticalCenter } }
                    }
                    Txt { Layout.fillWidth: true; Layout.topMargin: 4; text: page.app.shortDesc; color: Colors.dim; wrapMode: Text.WordWrap }
                    Row {
                        Layout.topMargin: 8
                        spacing: 8
                        Chip { text: page.app.categoryLabel }
                        Chip { text: page.app.developer }
                    }
                }
                Flow {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.maximumWidth: hdr.stacked ? hdr.width : 360
                    spacing: 8
                    AbstractButtonLike {
                        id: favBtn
                        checkable: true
                        checked: page.favorite
                        Accessible.name: "Favorito"
                        width: 40; height: 40
                        onClicked: Store.toggleFavorite(page.appId)
                        contentItem: Item {
                            Icon { anchors.centerIn: parent; name: page.favorite ? "HeartFilled" : "Heart"; size: 18; color: page.favorite ? Colors.crimsonHi : (favBtn.hovered ? "white" : Colors.dim) }
                        }
                        background: Rectangle { radius: Metrics.radiusControl; color: "transparent"; border.width: favBtn.visualFocus ? 2 : 1; border.color: favBtn.visualFocus ? Colors.crimsonHi : Colors.line }
                    }
                    ActionButton { app: page.app; wide: true }
                    Btn { visible: page.inst && page.st !== "busy"; variant: "danger"; text: "Desinstalar"; iconName: "Trash2"; onClicked: confirm.open() }
                }
            }
        }

        // Progress
        Rectangle {
            visible: page.st === "busy"
            Layout.fillWidth: true
            implicitHeight: pcol.implicitHeight + 32
            radius: Metrics.radiusCard; color: Colors.surface; border.width: 1; border.color: Colors.line
            ColumnLayout {
                id: pcol
                x: 16; y: 16; width: parent.width - 32
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Icon { name: "Loader2"; size: 16; color: Colors.crimsonHi; spin: true }
                    Txt { Layout.fillWidth: true; text: (page.app.isUpdate ? "Actualizando…" : "Instalando…") + " " + Strings.stage(page.app.progress); font.pixelSize: Typography.sm; font.weight: Font.Medium; elide: Text.ElideRight }
                    Txt { text: Math.round(page.app.progress) + "%"; font.pixelSize: Typography.sm }
                }
                Progress { Layout.fillWidth: true; value: page.app.progress; label: "Progreso" }
                Btn { Layout.topMargin: 4; small: true; variant: "ghost"; text: "Cancelar"; onClicked: Store.cancel(page.appId) }
            }
        }
        ErrorBox { visible: page.st === "error"; Layout.fillWidth: true; app: page.app; onRetry: Store.retry(page.appId) }
        Notice { visible: page.st === "cancelled"; icon: "Ban"; text: "Instalación cancelada. No se ha modificado el sistema." }
        Notice { visible: Store.offline && page.st === "none"; icon: "WifiOff"; text: "Sin conexión: la instalación no estará disponible hasta recuperarla." }

        // Screenshots
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            Txt { text: "Capturas de pantalla"; font.pixelSize: Typography.lg; font.weight: Font.DemiBold; Accessible.role: Accessible.Heading }
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 162 + 8
                contentWidth: shots.implicitWidth
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: shots
                    spacing: 12
                    Repeater {
                        model: 3
                        delegate: Item {
                            required property int index
                            width: 288; height: 162
                            Rectangle {
                                anchors.fill: parent
                                radius: Metrics.radiusCard
                                border.width: 1; border.color: Colors.line
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Qt.tint(Colors.panel, Colors.alpha(page.app.color, 0.3)) }
                                    GradientStop { position: 1; color: Colors.panel }
                                }
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "ImageOff"; size: 22; color: Colors.faint }
                                Txt { text: "Captura " + (index + 1) + " no disponible"; color: Colors.faint; font.pixelSize: Typography.xs }
                            }
                        }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: page.twoCols ? 2 : 1
            columnSpacing: 24; rowSpacing: 24

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 0
                Txt { text: "Acerca de esta aplicación"; font.pixelSize: Typography.lg; font.weight: Font.DemiBold; Layout.bottomMargin: 8 }
                Txt { Layout.fillWidth: true; text: page.app.longDesc; color: Colors.dim; wrapMode: Text.WordWrap; lineHeight: 1.45 }
                Txt { text: "Valoraciones y reseñas"; font.pixelSize: Typography.lg; font.weight: Font.DemiBold; Layout.topMargin: 24; Layout.bottomMargin: 8 }
                Txt { text: "Todavía no hay valoraciones de usuarios."; color: Colors.faint; font.pixelSize: Typography.sm }
                Txt { visible: page.st === "update" && page.app.changes.length > 0; text: "Novedades de la versión " + page.app.newVersion; font.pixelSize: Typography.lg; font.weight: Font.DemiBold; Layout.topMargin: 24; Layout.bottomMargin: 8 }
                Repeater {
                    model: page.st === "update" ? page.app.changes : []
                    delegate: Txt { Layout.fillWidth: true; Layout.leftMargin: 8; required property string modelData; text: "•  " + modelData; color: Colors.dim; font.pixelSize: Typography.sm; wrapMode: Text.WordWrap }
                }
            }
            GridLayout {
                Layout.fillWidth: !page.twoCols
                Layout.preferredWidth: page.twoCols ? 320 : -1
                Layout.alignment: Qt.AlignTop
                columns: page.twoCols ? 1 : 2
                columnSpacing: 8; rowSpacing: 8
                Info { k: "Versión instalada"; v: page.inst ? page.app.currentVersion : "No instalada" }
                Info { k: "Versión disponible"; v: page.app.newVersion !== "" ? page.app.newVersion : page.app.version !== "" ? page.app.version : page.na }
                Info { k: "Tamaño de descarga"; v: page.app.size }
                Info { k: "Licencia"; v: page.app.license }
                Info { k: "Actualizado"; v: page.app.date }
                Info { k: "Fuente"; v: "Repositorio del sistema (apt)" }
                Info { k: "Requisitos del sistema"; v: page.na; faint: true }
                Info { k: "Compatibilidad"; v: "Sin verificar"; faint: true }
                Info { k: "Enlaces"; v: "Sitio oficial: no configurado"; faint: true }
            }
        }
    }

    ConfirmDialog {
        id: confirm
        objectName: "confirmUninstall"
        title: "¿Desinstalar " + page.app.name + "?"
        message: "Se eliminará la aplicación del sistema. Esta acción no se puede deshacer; tus documentos no se borrarán."
        actions: [
            Btn { text: "Cancelar"; variant: "ghost"; onClicked: confirm.close() },
            Btn { text: "Desinstalar"; iconName: "Trash2"; onClicked: { confirm.close(); Store.uninstall(page.appId) } }
        ]
    }
}
