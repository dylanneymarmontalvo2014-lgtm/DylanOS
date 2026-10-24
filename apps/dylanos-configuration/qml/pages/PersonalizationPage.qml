import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Personalización: apariencia, fondo de pantalla y escritorio.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property string tab: Window.window && Window.window.tab ? Window.window.tab : "Apariencia"
    property var schemes: []
    property var walls: []
    property string currentScheme: System.configString("kdeglobals", "General", "ColorScheme")

    function refresh() {
        schemes = System.colorSchemes()
        walls = System.wallpapers()
        currentScheme = System.configString("kdeglobals", "General", "ColorScheme")
    }
    Component.onCompleted: Qt.callLater(refresh)

    function applyTema(oscuro) {
        let candidates = oscuro ? ["DylanOSDark", "BreezeDark"] : ["DylanOSLight", "BreezeLight"]
        for (const name of candidates) {
            for (const s of schemes) {
                if (s.name === name) {
                    if (System.applyColorScheme(s.name))
                        toast.show("Tema aplicado: " + s.name)
                    return
                }
            }
        }
        for (const s of schemes) {
            if (s.dark === oscuro) {
                System.applyColorScheme(s.name)
                toast.show("Tema aplicado: " + s.name)
                return
            }
        }
    }

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        TabsBar {
            width: parent.width
            value: root.tab
            tabs: ["Apariencia", "Fondo de pantalla", "Escritorio"]
            onPicked: function (t) { root.tab = t; Window.window.tab = t }
        }

        Column {
            visible: root.tab === "Apariencia"
            width: parent.width
            spacing: 16

            Text { text: "Tema"; font.pixelSize: 18; color: Theme.c.text }

            Row {
                width: parent.width
                spacing: 16
                Repeater {
                    model: [
                        { k: true, l: "Oscuro", icon: "moon", bg1: "#1d1213", bg2: "#0b0708" },
                        { k: false, l: "Claro", icon: "sun", bg1: "#faf5f5", bg2: "#e8dede" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 32) / 3
                        height: 130
                        radius: Theme.radiusCard
                        color: Theme.c.surface
                        border.width: 1.5
                        border.color: Theme.dark === modelData.k ? Theme.accent : Theme.c.border

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10
                            Rectangle {
                                width: parent.width
                                height: 72
                                radius: 8
                                gradient: Gradient {
                                    GradientStop { position: 0; color: modelData.bg1 }
                                    GradientStop { position: 1; color: modelData.bg2 }
                                }
                                LucideIcon {
                                    anchors.centerIn: parent
                                    name: modelData.icon
                                    color: modelData.k ? "#ffffff" : "#222222"
                                    size: 26
                                }
                            }
                            Row {
                                width: parent.width
                                spacing: 8
                                Text { text: modelData.l; font.pixelSize: 14; color: Theme.c.text }
                                LucideIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: Theme.dark === modelData.k
                                    name: "check"
                                    color: Theme.accentStrong
                                    size: 16
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyTema(modelData.k)
                        }
                    }
                }
            }

            Text { text: "Color de énfasis"; font.pixelSize: 18; color: Theme.c.text }

            GroupBox {
                width: parent.width
                height: 72
                // El hijo directo de GroupBox cae en un Column: los anchors
                // verticales no funcionan dentro de positioners. Se envuelve
                // el Row en un Item de altura completa.
                Item {
                    width: parent.width
                    height: 72
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                    Repeater {
                        model: ["#DC143C", "#ff5a36", "#f5a524", "#3ecf6e", "#1f9aa6", "#2f7be8", "#7b4fe0", "#d63fa0"]
                        delegate: Rectangle {
                            required property var modelData
                            width: 40
                            height: 40
                            radius: 20
                            color: modelData
                            border.width: 2
                            border.color: System.accent.toLowerCase() === modelData.toLowerCase() ? Theme.c.text : "transparent"
                            LucideIcon {
                                anchors.centerIn: parent
                                visible: System.accent.toLowerCase() === parent.modelData.toLowerCase()
                                name: "check"
                                color: "#ffffff"
                                size: 18
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    System.accent = modelData
                                    toast.show("Color de énfasis actualizado")
                                }
                            }
                        }
                    }
                    }
                }
            }

            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "palette"
                    title: "Tema de iconos y cursores"
                    desc: "Gestionados por los módulos nativos"
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Abrir iconos"
                        onClicked: System.openKcm(["kcm_icons"])
                    }
                }
                RowItem {
                    width: parent.width
                    icon: "type"
                    title: "Fuentes y tamaño del texto"
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Abrir fuentes"
                        onClicked: System.openKcm(["kcm_fonts"])
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Más opciones de apariencia"
                    last: true
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Abrir apariencia"
                        onClicked: System.openKcm(["kcm_lookandfeel"])
                    }
                }
            }
        }

        // ---------------- Fondo de pantalla ----------------
        Column {
            visible: root.tab === "Fondo de pantalla"
            width: parent.width
            spacing: 16

            Text { text: "Galería"; font.pixelSize: 18; color: Theme.c.text }

            Flow {
                width: parent.width
                spacing: 16
                Repeater {
                    model: root.walls
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 32) / 3
                        height: 150
                        radius: Theme.radiusCard
                        color: Theme.c.surface
                        border.width: 1.5
                        border.color: Theme.c.border
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: modelData.path
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 36
                            color: Qt.rgba(0, 0, 0, 0.55)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                width: parent.width - 24
                                text: modelData.name
                                font.pixelSize: 14
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (System.applyWallpaper(modelData.path))
                                    toast.show("Fondo aplicado: " + modelData.name)
                            }
                        }
                    }
                }
            }
        }

        // ---------------- Escritorio ----------------
        Column {
            visible: root.tab === "Escritorio"
            width: parent.width
            spacing: 16

            Text { text: "Comportamiento"; font.pixelSize: 18; color: Theme.c.text }

            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Doble clic para abrir"
                    desc: "Preferencia real de KDE (SingleClick invertido)"
                    DToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        on: System.singleClick()
                        onToggled: function (v) { System.setSingleClick(v) }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Restaurar sesión al iniciar"
                    desc: "Preferencia real de sesión de Plasma"
                    DToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        on: System.restoreSession()
                        onToggled: function (v) { System.setRestoreSession(v) }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Paneles y esquinas activas"
                    desc: "Se configuran en el módulo de comportamiento del escritorio"
                    last: true
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Abrir escritorio"
                        onClicked: System.openKcm(["kcm_behavior", "desktopbehavior", "kcm_desktopbehavior"])
                    }
                }
            }
        }
    }

    Toast {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 70
    }
}



