import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property string tab: "General"
    property var values: CrimsonGlass.settings
    property var caps: CrimsonGlass.capabilities
    property var active: CrimsonGlass.effectiveEffects

    function sync() {
        values = CrimsonGlass.settings
        caps = CrimsonGlass.capabilities
        active = CrimsonGlass.effectiveEffects
    }
    function updateOption(key, value) {
        if (CrimsonGlass.setOption(key, value)) {
            sync()
            applyTimer.restart()
        }
    }
    function modeLabel(value) {
        if (value === "dark") return "Oscuro"
        if (value === "light") return "Claro"
        return "Automático"
    }
    function modeValue(label) {
        if (label === "Oscuro") return "dark"
        if (label === "Claro") return "light"
        return "automatic"
    }
    function effectState(enabled, available) {
        if (!available) return "No disponible"
        return enabled ? "Activo" : "Desactivado"
    }

    Timer {
        id: applyTimer
        interval: 160
        repeat: false
        onTriggered: {
            CrimsonGlass.apply()
            root.sync()
        }
    }

    Connections {
        target: CrimsonGlass
        function onSettingsChanged() { root.sync() }
        function onCapabilitiesChanged() { root.sync() }
        function onEffectiveEffectsChanged() { root.sync() }
    }

    Column {
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        Rectangle {
            width: parent.width
            height: 268
            radius: 24
            color: Qt.rgba(Theme.glassTint.r, Theme.glassTint.g, Theme.glassTint.b, 0.78)
            border.width: 1
            border.color: Qt.rgba(Theme.glassBorder.r, Theme.glassBorder.g, Theme.glassBorder.b, 0.38)

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                height: 1
                color: Qt.rgba(Theme.glassSpecular.r, Theme.glassSpecular.g, Theme.glassSpecular.b, 0.32)
            }

            Row {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 24

                GlassPreview {
                    width: Math.min(470, parent.width * 0.58)
                    height: parent.height
                    settings: root.values
                    effects: root.active
                }

                Column {
                    width: parent.width - parent.spacing - 470
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Text {
                        width: parent.width
                        text: "Cristal con identidad Crimson"
                        color: Theme.c.text
                        font.pixelSize: 23
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width
                        text: "KWin aporta desenfoque y movimiento; los temas de Plasma, Qt y GTK conservan el material sin forzar aplicaciones incompatibles."
                        color: Theme.c.textDim
                        font.pixelSize: 13
                        lineHeight: 1.25
                        wrapMode: Text.WordWrap
                    }
                    Row {
                        spacing: 10
                        DToggle {
                            on: Boolean(root.values.enabled)
                            onToggled: function (value) { root.updateOption("enabled", value) }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.values.enabled ? "Crimson Glass activo" : "Crimson Glass desactivado"
                            color: Theme.c.text
                            font.pixelSize: 14
                        }
                    }
                    BadgePill {
                        text: root.active.lowPowerApplied ? "Degradación segura" : "Perfil completo"
                        tone: root.active.lowPowerApplied ? "#FEBC2E" : "#58D68D"
                    }
                }
            }
        }

        TabsBar {
            width: parent.width
            value: root.tab
            tabs: ["General", "Efectos", "Compatibilidad"]
            onPicked: function (value) { root.tab = value }
        }

        Column {
            visible: root.tab === "General"
            width: parent.width
            spacing: 16

            SectionTitle { text: "Material" }
            GroupBox {
                width: parent.width
                Repeater {
                    model: [
                        { key: "glassIntensity", title: "Intensidad del cristal", suffix: "%" },
                        { key: "transparency", title: "Transparencia", suffix: "%" },
                        { key: "blur", title: "Desenfoque", suffix: "%" },
                        { key: "reflections", title: "Reflejos y bordes", suffix: "%" },
                        { key: "shadows", title: "Sombras", suffix: "%" },
                        { key: "cornerRadius", title: "Radio de las esquinas", suffix: " px", maximum: 36 }
                    ]
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        title: modelData.title
                        last: index === 5
                        Item {
                            width: 294
                            height: 40
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                DSlider {
                                    width: 230
                                    value: Number(root.values[modelData.key])
                                    maximum: modelData.maximum || 100
                                    onMoved: function (value) { root.updateOption(modelData.key, value) }
                                }
                                Text {
                                    width: 50
                                    text: root.values[modelData.key] + modelData.suffix
                                    color: Theme.c.textDim
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            SectionTitle { text: "Identidad" }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Modo de color"
                    desc: "Automático sigue el esquema actual del sistema"
                    DSelect {
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.modeLabel(root.values.mode)
                        options: ["Automático", "Oscuro", "Claro"]
                        onPicked: function (value) { root.updateOption("mode", root.modeValue(value)) }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Acento Crimson"
                    last: true
                    Item {
                        width: accentRow.width
                        height: 40
                        Row {
                            id: accentRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Repeater {
                                model: ["#DC143C", "#E81740", "#FF2A54", "#AD0A2A"]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 34
                                    height: 34
                                    radius: 17
                                    color: modelData
                                    border.width: root.values.accent === modelData ? 2 : 1
                                    border.color: root.values.accent === modelData ? "#ffffff" : Qt.rgba(1, 1, 1, 0.24)
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.updateOption("accent", modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Column {
            visible: root.tab === "Efectos"
            width: parent.width
            spacing: 16

            SectionTitle { text: "Capas del escritorio" }
            GroupBox {
                width: parent.width
                Repeater {
                    model: [
                        { key: "panelTransparency", title: "Transparencia de paneles" },
                        { key: "dockTransparency", title: "Transparencia del dock" },
                        { key: "menuTransparency", title: "Transparencia de menús" },
                        { key: "animationDuration", title: "Duración de animaciones", maximum: 500, minimum: 60, suffix: " ms" }
                    ]
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        title: modelData.title
                        last: index === 3
                        Item {
                            width: 294
                            height: 40
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                DSlider {
                                    width: 230
                                    minimum: modelData.minimum || 0
                                    maximum: modelData.maximum || 100
                                    value: Number(root.values[modelData.key])
                                    onMoved: function (value) { root.updateOption(modelData.key, value) }
                                }
                                Text {
                                    width: 50
                                    text: root.values[modelData.key] + (modelData.suffix || "%")
                                    color: Theme.c.textDim
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            SectionTitle { text: "Compositor" }
            GroupBox {
                width: parent.width
                Repeater {
                    model: [
                        { key: "globalEffects", title: "Efectos globales", desc: "Aplica el perfil al escritorio y las ventanas" },
                        { key: "windowEffects", title: "Efectos de ventanas", desc: "Decoración, menús, diálogos y ventanas inactivas" },
                        { key: "backgroundBlur", title: "Desenfoque de fondo", desc: "Solo en superficies compatibles con KWin" },
                        { key: "animations", title: "Animaciones y transiciones", desc: "Apertura y menús emergentes" },
                        { key: "additionalEffects", title: "Efectos visuales adicionales", desc: "Contraste del compositor cuando está disponible" },
                        { key: "lowPower", title: "Modo de bajo consumo gráfico", desc: "Desactiva blur, contraste y movimiento costoso" }
                    ]
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        title: modelData.title
                        desc: modelData.desc
                        last: index === 5
                        DToggle {
                            anchors.verticalCenter: parent.verticalCenter
                            on: Boolean(root.values[modelData.key])
                            onToggled: function (value) { root.updateOption(modelData.key, value) }
                        }
                    }
                }
            }
        }

        Column {
            visible: root.tab === "Compatibilidad"
            width: parent.width
            spacing: 16

            SectionTitle { text: "Entorno detectado" }
            GroupBox {
                width: parent.width
                RowItem { width: parent.width; title: "Sesión gráfica"; desc: root.caps.sessionType; BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.caps.sessionType || "—" } }
                RowItem { width: parent.width; title: "Compositor"; desc: root.caps.backend; BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.caps.compositor || "—" } }
                RowItem { width: parent.width; title: "Desenfoque"; desc: root.caps.softwareRendering ? "Renderizado por software: se usa material opaco" : "Efecto nativo de KWin"; BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.effectState(root.active.blur, root.caps.blurAvailable); tone: root.active.blur ? "#58D68D" : "#FEBC2E" } }
                RowItem { width: parent.width; title: "Animaciones"; desc: root.caps.reducedMotion ? "Reducción de movimiento activa" : "Transiciones del compositor"; last: true; BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.effectState(root.active.animations, root.caps.animationsAvailable); tone: root.active.animations ? "#58D68D" : "#FEBC2E" } }
            }

            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    title: "Detección automática"
                    desc: "Adapta el perfil al backend y al hardware disponibles"
                    DToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        on: Boolean(root.values.autoDetect)
                        onToggled: function (value) { root.updateOption("autoDetect", value) }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Volver a detectar capacidades"
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Detectar de nuevo"
                        onClicked: {
                            CrimsonGlass.detectCapabilities()
                            root.sync()
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Valores predeterminados"
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Restaurar valores"
                        onClicked: {
                            CrimsonGlass.resetDefaults()
                            CrimsonGlass.apply()
                            root.sync()
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    title: "Configuración anterior"
                    desc: "Recupera únicamente las claves que Crimson Glass modificó"
                    last: true
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Recuperar configuración"
                        variant: "danger"
                        onClicked: {
                            CrimsonGlass.setOption("enabled", false)
                            CrimsonGlass.restorePrevious()
                            root.sync()
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10
            ActionButton {
                text: "Aplicar ahora"
                icon: "play"
                variant: "primary"
                onClicked: {
                    CrimsonGlass.apply()
                    root.sync()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: CrimsonGlass.lastMessage
                color: Theme.c.textDim
                font.pixelSize: 12
            }
        }
        Item { width: 1; height: 24 }
    }
}
