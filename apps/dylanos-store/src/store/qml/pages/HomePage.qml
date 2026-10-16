import QtQuick
import QtQuick.Layouts
import DylanOS

PageScaffold {
    id: page
    title: "Descubre lo mejor para DylanOS"

    property int heroIndex: 0
    // shelfVersion hace reactiva la lectura: el catálogo SQL se puede
    // refrescar en caliente (remoto) y las estanterías se re-leen solas.
    readonly property var featured: Store.shelfVersion >= 0 ? Store.list("featured") : []
    readonly property var hero: featured.length > 0 ? Store.app(featured[heroIndex]) : null
    function nextHero() { if (featured.length > 0) heroIndex = (heroIndex + 1) % featured.length }
    function prevHero() { if (featured.length > 0) heroIndex = (heroIndex - 1 + featured.length) % featured.length }
    readonly property bool asideBeside: Nav.windowWidth >= 1536

    Timer { interval: 7000; running: page.visible && !Store.offline && page.featured.length > 1; repeat: true; onTriggered: page.nextHero() }

    EmptyState {
        visible: Store.offline
        Layout.fillWidth: true
        iconName: "WifiOff"; error: true
        title: "Sin conexión"
        text: "No se puede contactar con las fuentes de software. Puedes seguir administrando las aplicaciones ya instaladas."
        Btn { text: "Reintentar"; iconName: "RefreshCw"; onClicked: Store.offline = false }
        Btn { text: "Ver instaladas"; variant: "ghost"; onClicked: Nav.go("installed") }
    }

    GridLayout {
        visible: !Store.offline
        Layout.fillWidth: true
        columns: page.asideBeside ? 2 : 1
        columnSpacing: 20
        rowSpacing: 20

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 28

            // Hero
            Item {
                id: heroRoot
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(heroCol.implicitHeight + (page.width < 640 ? 48 : 64), 230)

                // Paginador: arrastra el cuadro o usa las flechas ←/→.
                // Zona de captura por debajo del contenido: los botones
                // (instalar/detalles) siguen recibiendo sus clics.
                MouseArea {
                    id: heroSwipe
                    z: 0
                    anchors.fill: parent
                    hoverEnabled: false
                    property real pressX: 0
                    onPressed: (mouse) => { pressX = mouse.x; heroRoot.forceActiveFocus() }
                    onReleased: (mouse) => {
                        const dx = mouse.x - pressX
                        if (dx > 60) page.prevHero()
                        else if (dx < -60) page.nextHero()
                    }
                }
                Keys.onLeftPressed: page.prevHero()
                Keys.onRightPressed: page.nextHero()

                RoundedBox { anchors.fill: parent; hero: true }
                AppIcon {
                    visible: page.width >= 640 && page.hero
                    app: page.hero
                    size: 170
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: page.width >= 768 ? 48 : 24
                    opacity: 0.95
                }
                ColumnLayout {
                    id: heroCol
                    x: page.width < 640 ? 24 : 32
                    y: page.width < 640 ? 24 : 32
                    width: Math.min(448, parent.width - x * 2)
                    spacing: 0
                    Chip { tone: "red"; text: "DESTACADA" }
                    Txt { Layout.topMargin: 12; text: page.hero ? page.hero.name : ""; font.pixelSize: page.width < 640 ? Typography.display : Typography.hero; font.weight: Font.DemiBold; Accessible.role: Accessible.Heading }
                    Txt { Layout.topMargin: 8; Layout.fillWidth: true; text: page.hero ? page.hero.shortDesc : ""; color: Colors.white(0.8); font.pixelSize: Typography.lg; wrapMode: Text.WordWrap }
                    Flow {
                        Layout.topMargin: 24
                        Layout.fillWidth: true
                        spacing: 8
                        ActionButton { visible: page.hero !== null; app: page.hero; wide: true }
                        Btn { visible: page.hero !== null; variant: "ghost"; text: "Ver detalles"; onClicked: Nav.go("app", page.hero.appId) }
                    }
                }
                Row {
                    x: 24; y: parent.height - 16 - 8
                    spacing: 8
                    Repeater {
                        model: page.featured.length
                        delegate: Item {
                            required property int index
                            width: index === page.heroIndex ? 24 : 8; height: 8
                            Accessible.role: Accessible.Button
                            Accessible.name: "Destacada " + (index + 1)
                            Rectangle { anchors.fill: parent; radius: 4; color: index === page.heroIndex ? Colors.crimsonHi : Colors.white(0.3) }
                            TapHandler { onTapped: page.heroIndex = index }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            Behavior on width { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }

            // Quick tiles
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: [
                        { icon: "RefreshCw", tint: true, title: "Actualizaciones", sub: Store.updateCount ? Store.updateCount + " disponibles" : "Todo al día", view: "updates" },
                        { icon: "HardDriveDownload", tint: false, title: "Instaladas", sub: Store.installedCount + " aplicaciones", view: "installed" }
                    ]
                    delegate: Card {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 74
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title
                        onClicked: Nav.go(modelData.view)
                        RowLayout {
                            anchors { fill: parent; margins: 16 }
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 8
                                color: modelData.tint ? Colors.alpha(Colors.crimson, 0.2) : Colors.white(0.07)
                                Icon { anchors.centerIn: parent; name: modelData.icon; size: 20; color: modelData.tint ? Colors.red300 : Colors.dim }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Txt { Layout.fillWidth: true; text: modelData.title; font.weight: Font.Medium; elide: Text.ElideRight }
                                Txt { Layout.fillWidth: true; text: modelData.sub; color: Colors.dim; font.pixelSize: Typography.xs; elide: Text.ElideRight }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                SectionHead { Layout.fillWidth: true; title: "Recomendado para ti"; hasMore: true; onMoreClicked: Nav.go("cat", "all") }
                AutoGrid { Layout.fillWidth: true; model: Store.shelfVersion >= 0 ? Store.list("recommended") : []; delegate: AppCard { app: Store.app(modelData) } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                SectionHead { Layout.fillWidth: true; title: "Novedades"; hasMore: true; onMoreClicked: Nav.go("cat", "all") }
                AutoGrid { Layout.fillWidth: true; model: Store.shelfVersion >= 0 ? Store.list("newest") : []; delegate: AppCard { app: Store.app(modelData) } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                SectionHead { Layout.fillWidth: true; title: "Categorías"; hasMore: true; onMoreClicked: Nav.go("cats") }
                AutoGrid {
                    Layout.fillWidth: true
                    minCell: 190
                    model: Store.categories.slice(0, 6)
                    delegate: CategoryTile { compact: true }
                }
            }
        }

        // Aside
        GridLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: page.asideBeside ? 340 : -1
            Layout.maximumWidth: page.asideBeside ? 340 : 100000
            columns: (!page.asideBeside && Nav.windowWidth >= 768) ? 2 : 1
            columnSpacing: 20
            rowSpacing: 20

            Panel {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                SectionHead { Layout.fillWidth: true; title: "Aplicaciones populares"; hasMore: true; onMoreClicked: Nav.go("cat", "all") }
                Repeater { model: Store.shelfVersion >= 0 ? Store.list("popular") : []; delegate: AppRow { Layout.fillWidth: true; app: Store.app(modelData); rank: index + 1 } }
            }
            Panel {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                SectionHead { Layout.fillWidth: true; title: "Esenciales" }
                Repeater { model: Store.shelfVersion >= 0 ? Store.list("essential") : []; delegate: AppRow { Layout.fillWidth: true; app: Store.app(modelData) } }
            }
            Panel {
                Layout.fillWidth: true
                Layout.columnSpan: parent.columns
                Txt { Layout.bottomMargin: 12; text: "Actividad reciente"; font.pixelSize: Typography.lg; font.weight: Font.DemiBold }
                Repeater {
                    model: Store.recentInstalls(3)
                    delegate: RowLayout {
                        required property string modelData
                        readonly property var a: Store.app(modelData)
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                        spacing: 8
                        Icon { name: "Check"; size: 14; color: Colors.ok }
                        Txt { Layout.fillWidth: true; text: a.name + " instalada · " + a.installedOn; color: Colors.dim; font.pixelSize: Typography.sm; elide: Text.ElideRight }
                    }
                }
                AbstractButtonLike { Layout.topMargin: 4; label: "Ver historial"; chevron: false; onClicked: Nav.go("installed") }
            }
        }
    }
}
