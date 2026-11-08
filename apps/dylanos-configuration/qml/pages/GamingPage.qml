import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// DylanOS Gaming: catálogo, perfiles y diagnóstico reales vía GamingService
// (PackageKit/Flatpak, power-profiles-daemon, D-Bus Notifications.Inhibit y
// el helper polkit org.dylanos.gaming.helper). Ningún control simula una
// acción: cada botón llama al servicio nativo.
ScrollView {
    id: root
    anchors.fill: parent
    contentWidth: availableWidth

    property string tab: Window.window && Window.window.tab ? Window.window.tab : "General"
    property var hw: ({})
    property var st: ({})
    property var cat: []
    property var profs: []
    property string query: ""

    readonly property var profileNames: ({
        "balanced": "Gaming Balanced",
        "performance": "Gaming Performance",
        "competitive": "Gaming Competitive",
        "streaming": "Gaming Streaming",
        "emulation": "Gaming Emulation"
    })
    readonly property var emulationIds: ["dolphin-emu", "rpcs3", "pcsx2", "retroarch", "prism"]
    readonly property var streamingIds: ["obs", "discord"]

    function refresh() {
        hw = Gaming.hardware()
        st = Gaming.status()
        cat = Gaming.catalog()
        profs = Gaming.profiles()
    }
    function filtered(ids) {
        const q = root.query.toLowerCase()
        const out = []
        for (let i = 0; i < cat.length; i++) {
            const a = cat[i]
            if (ids && ids.indexOf(a.id) < 0) continue
            if (!ids && q !== "" && !(a.name + " " + a.function).toLowerCase().includes(q)) continue
            out.push(a)
        }
        return out
    }
    function appById(id) {
        for (let i = 0; i < cat.length; i++)
            if (cat[i].id === id) return cat[i]
        return null
    }
    function statusLabel(a) {
        if (a.installed) return "Instalada"
        if (a.unavailable) return "No disponible"
        if (!a.compatible) return "Incompatible"
        return "Disponible"
    }
    function statusTone(a) {
        if (a.installed) return "#4caf50"
        if (!a.compatible || a.unavailable) return Theme.c.textDim
        return Theme.accentStrong
    }

    Component.onCompleted: Qt.callLater(refresh)
    Connections {
        target: Gaming
        function onCatalogChanged() { root.refresh() }
        function onProfileChanged() { root.refresh() }
        function onHardwareChanged() { root.refresh() }
    }

    Column {
        id: col
        x: 32
        y: 4
        width: root.width - 64
        spacing: 16

        Rectangle {
            width: parent.width
            height: 96
            radius: Theme.radiusCard
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.border

            Row {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 16
                LucideIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "gamepad-2"
                    color: Theme.accentStrong
                    size: 40
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 320
                    spacing: 6
                    Text {
                        text: root.st.activeProfile
                              ? (root.profileNames[root.st.activeProfile] || root.st.activeProfile)
                              : "Sin perfil activo"
                        font.pixelSize: 20
                        color: Theme.c.text
                    }
                    Text {
                        text: root.st.installedCount !== undefined
                              ? root.st.installedCount + " de " + root.st.catalogCount + " aplicaciones instaladas"
                              : "Catálogo de 20 aplicaciones"
                        font.pixelSize: 13
                        color: Theme.c.textDim
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    BadgePill { visible: !!root.hw.gpuVendor && root.hw.gpuVendor !== "unknown"; text: (root.hw.gpuVendor || "").toUpperCase(); tone: Theme.accentStrong }
                    BadgePill { visible: !!root.hw.vulkan; text: "Vulkan"; tone: "#4caf50" }
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Restaurar"
                        variant: "danger"
                        enabled2: root.st.hasBackup === true
                        onClicked: { Gaming.restoreProfile(); root.refresh() }
                    }
                }
            }
        }

        ErrorBanner {
            width: parent.width
            visible: Gaming.lastError !== ""
            message: Gaming.lastError
            onRetry: Gaming.refresh()
        }

        Rectangle {
            width: parent.width
            height: 40
            visible: Gaming.busy
            radius: Theme.radiusCard
            color: Theme.c.surface
            border.width: 1
            border.color: Theme.c.border
            Row {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 220
                    text: Gaming.progressMessage || "Trabajando…"
                    font.pixelSize: 13
                    color: Theme.c.textDim
                    elide: Text.ElideRight
                }
                Meter {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    pct: Gaming.progress
                }
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Cancelar"
                    variant: "danger"
                    onClicked: Gaming.cancelTask()
                }
            }
        }

        TabsBar {
            width: parent.width
            value: root.tab
            tabs: ["General", "Rendimiento", "Gráficos", "Aplicaciones", "Streaming", "Emulación", "Diagnóstico"]
            onPicked: function (t) { root.tab = t; if (Window.window) Window.window.tab = t }
        }

        // ---- General ---------------------------------------------------
        Column {
            visible: root.tab === "General"
            width: parent.width
            spacing: 16

            Text { text: "Perfiles Gaming"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                Repeater {
                    model: root.profs
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        icon: "gamepad-2"
                        iconColor: modelData.active ? Theme.accentStrong : Theme.c.textDim
                        title: modelData.name
                        desc: modelData.summary
                        last: index === root.profs.length - 1
                        ActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.active ? "Activo" : "Aplicar"
                            variant: modelData.active ? "ghost" : "primary"
                            enabled2: !modelData.active
                            onClicked: { Gaming.applyProfile(modelData.id); root.refresh() }
                        }
                    }
                }
            }

            Text { text: "Recomendaciones de hardware"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                visible: (root.hw.recommendations || []).length > 0
                Repeater {
                    model: root.hw.recommendations || []
                    delegate: RowItem {
                        required property string modelData
                        required property int index
                        width: parent.width
                        icon: "info"
                        desc: modelData
                        last: index === (root.hw.recommendations || []).length - 1
                    }
                }
            }
            Text {
                width: parent.width
                visible: (root.hw.recommendations || []).length === 0
                text: "Cada perfil es reversible: \"Restaurar\" devuelve el entorno, MangoHud, el gobernador de CPU y el perfil de energía al estado previo a aplicar Gaming."
                font.pixelSize: 12
                color: Theme.c.textDim
                wrapMode: Text.WordWrap
            }
        }

        // ---- Rendimiento -------------------------------------------------
        Column {
            visible: root.tab === "Rendimiento"
            width: parent.width
            spacing: 16

            Text { text: "Perfil de rendimiento"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "zap"
                    title: "Perfil activo"
                    DSelect {
                        anchors.verticalCenter: parent.verticalCenter
                        value: root.st.activeProfile ? (root.profileNames[root.st.activeProfile] || root.st.activeProfile) : "Ninguno"
                        options: root.profs.map(function (p) { return p.name })
                        menuWidth: 220
                        onPicked: function (v) {
                            for (const p of root.profs) {
                                if (p.name === v) { Gaming.applyProfile(p.id); root.refresh(); break }
                            }
                        }
                    }
                }
                RowItem {
                    width: parent.width
                    icon: "cpu"
                    title: "Gobernador de CPU"
                    desc: root.hw.governorAvailable ? "Se ajusta al aplicar el perfil (helper con lista blanca)" : "Este hardware no expone scaling_governor"
                    BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.hw.governorAvailable ? "Disponible" : "No disponible"; tone: root.hw.governorAvailable ? "#4caf50" : Theme.c.textDim }
                }
                RowItem {
                    width: parent.width
                    icon: "package"
                    title: "GameMode"
                    desc: "Se invoca por juego con gamemoderun; no es un interruptor global"
                    last: true
                    BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.hw.gamemode ? "Instalado" : "No instalado"; tone: root.hw.gamemode ? "#4caf50" : Theme.c.textDim }
                }
            }

            Text {
                width: parent.width
                text: "No se prometen mejoras de FPS ni de latencia: cada perfil aplica ajustes documentados y reversibles, sin mediciones garantizadas."
                font.pixelSize: 12
                color: Theme.c.textDim
                wrapMode: Text.WordWrap
            }
        }

        // ---- Gráficos ------------------------------------------------
        Column {
            visible: root.tab === "Gráficos"
            width: parent.width
            spacing: 16

            Text { text: "GPU detectada"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem { width: parent.width; icon: "sliders-horizontal"; title: "Modelo"; desc: root.hw.gpu || "—" }
                RowItem { width: parent.width; icon: "box"; title: "Controlador"; desc: root.hw.driver || "—" }
                RowItem {
                    width: parent.width
                    icon: "check"
                    title: "Vulkan"
                    last: false
                    BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.hw.vulkan ? "Disponible" : "No detectado"; tone: root.hw.vulkan ? "#4caf50" : Theme.c.textDim }
                }
                RowItem {
                    width: parent.width
                    icon: "check"
                    title: "OpenGL"
                    desc: "Aceleración activa: " + (root.hw.acceleration || "—")
                    last: true
                    BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.hw.opengl ? "Disponible" : "No detectado"; tone: root.hw.opengl ? "#4caf50" : Theme.c.textDim }
                }
                RowItem {
                    width: parent.width
                    icon: "play"
                    title: "Gamescope"
                    desc: "Debian 13 Backports; DylanOS no habilita Backports automáticamente"
                    last: true
                    BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.hw.gamescope ? "Instalado" : "No instalado"; tone: root.hw.gamescope ? "#4caf50" : Theme.c.textDim }
                }
            }

            Text { text: "Compatibilidad Proton/Wine"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "layout-grid"
                    title: "DXVK / VKD3D-Proton"
                    desc: "Requieren Vulkan; se activan automáticamente en Proton/Wine si está disponible"
                    BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.hw.dxvkReady ? "Compatible" : "No compatible"; tone: root.hw.dxvkReady ? "#4caf50" : Theme.c.textDim }
                }
                RowItem {
                    width: parent.width
                    icon: "download"
                    title: "Arquitectura i386"
                    desc: "Necesaria para Steam y Wine de 32 bits"
                    last: true
                    BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.hw.i386 ? "Habilitada" : "No habilitada"; tone: root.hw.i386 ? "#4caf50" : Theme.c.textDim }
                }
            }

            Text {
                width: parent.width
                text: "Los parámetros por fabricante (AMD/NVIDIA/Intel) se aplican solo cuando coinciden con la GPU detectada; CoreCtrl está pensado para AMD y no fuerza ajustes en otros fabricantes."
                font.pixelSize: 12
                color: Theme.c.textDim
                wrapMode: Text.WordWrap
            }
        }

        // ---- Aplicaciones ------------------------------------------------
        Column {
            visible: root.tab === "Aplicaciones"
            width: parent.width
            spacing: 16

            Row {
                width: parent.width
                spacing: 12
                SearchField {
                    width: parent.width - 220
                    placeholder: "Buscar en el catálogo"
                    text: root.query
                    onTextChanged: root.query = text
                }
                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Instalar recomendadas"
                    variant: "primary"
                    enabled2: !Gaming.busy
                    onClicked: Gaming.installRecommended()
                }
            }

            EmptyState {
                visible: root.filtered().length === 0
                width: parent.width
                icon: "search"
                title: "Sin resultados"
                desc: "Prueba con otro nombre."
            }

            GroupBox {
                visible: root.filtered().length > 0
                width: parent.width
                Repeater {
                    model: root.filtered()
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        title: modelData.name
                        desc: modelData.function + " · aprox. " + modelData.sizeMb + " MB"
                              + (modelData.needsI386 && !modelData.i386Enabled ? " · requiere i386; se habilita con autorización al instalar" : "")
                              + (modelData.reason ? " · " + modelData.reason : "")
                              + (modelData.notes ? " · " + modelData.notes : "")
                        last: index === root.filtered().length - 1
                        IconTile {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "package"
                            size: 36
                            plain: true
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.statusLabel(modelData); tone: root.statusTone(modelData) }
                            ActionButton {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.installed ? "Actualizar" : "Instalar"
                                variant: "primary"
                                enabled2: !Gaming.busy && (modelData.installed || (modelData.compatible && !modelData.unavailable))
                                onClicked: modelData.installed ? Gaming.updateApp(modelData.id) : Gaming.installApp(modelData.id)
                            }
                            ActionButton {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData.installed
                                text: "Quitar"
                                variant: "danger"
                                enabled2: !Gaming.busy
                                onClicked: Gaming.uninstallApp(modelData.id)
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.filtered().length > 0
                text: "La instalación usa PackageKit (apt) o Flatpak según cada aplicación; el tamaño es aproximado. No se añaden repositorios de terceros."
                font.pixelSize: 12
                color: Theme.c.textDim
                wrapMode: Text.WordWrap
            }
        }

        // ---- Streaming ------------------------------------------------
        Column {
            visible: root.tab === "Streaming"
            width: parent.width
            spacing: 16

            Text { text: "Grabación y streaming"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                Repeater {
                    model: root.filtered(root.streamingIds)
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        icon: "play"
                        title: modelData.name
                        desc: String(modelData.function || "")
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.statusLabel(modelData); tone: root.statusTone(modelData) }
                            ActionButton {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.installed ? "Quitar" : "Instalar"
                                variant: modelData.installed ? "danger" : "primary"
                                enabled2: !Gaming.busy && (modelData.installed || modelData.compatible)
                                onClicked: modelData.installed ? Gaming.uninstallApp(modelData.id) : Gaming.installApp(modelData.id)
                            }
                        }
                    }
                }
            }

            Text { text: "Perfil Streaming"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "gamepad-2"
                    title: "Gaming Streaming"
                    desc: "Crea el perfil DylanOSStreaming en OBS e inhibe notificaciones mientras esté activo"
                    last: true
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.st.activeProfile === "streaming" ? "Activo" : "Aplicar"
                        variant: root.st.activeProfile === "streaming" ? "ghost" : "primary"
                        enabled2: root.st.activeProfile !== "streaming"
                        onClicked: { Gaming.applyProfile("streaming"); root.refresh() }
                    }
                }
            }

            Text {
                width: parent.width
                text: "Los dispositivos de audio/vídeo y la aceleración por hardware se configuran dentro de OBS Studio; DylanOS Gaming solo prepara el perfil inicial."
                font.pixelSize: 12
                color: Theme.c.textDim
                wrapMode: Text.WordWrap
            }
        }

        // ---- Emulación ------------------------------------------------
        Column {
            visible: root.tab === "Emulación"
            width: parent.width
            spacing: 16

            Text { text: "Emuladores"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                Repeater {
                    model: root.filtered(root.emulationIds)
                    delegate: RowItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        title: modelData.name
                        desc: modelData.function + (modelData.reason ? " · " + modelData.reason : "")
                        last: index === root.filtered(root.emulationIds).length - 1
                        IconTile { anchors.verticalCenter: parent.verticalCenter; icon: "box"; size: 36; plain: true }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            BadgePill { anchors.verticalCenter: parent.verticalCenter; text: root.statusLabel(modelData); tone: root.statusTone(modelData) }
                            ActionButton {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.installed ? "Quitar" : "Instalar"
                                variant: modelData.installed ? "danger" : "primary"
                                enabled2: !Gaming.busy && (modelData.installed || (modelData.compatible && !modelData.unavailable))
                                onClicked: modelData.installed ? Gaming.uninstallApp(modelData.id) : Gaming.installApp(modelData.id)
                            }
                        }
                    }
                }
            }

            GroupBox {
                width: parent.width
                RowItem {
                    width: parent.width
                    icon: "gamepad-2"
                    title: "Gaming Emulation"
                    desc: "Perfil orientado a estabilidad de emuladores sobre rendimiento bruto"
                    last: true
                    ActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.st.activeProfile === "emulation" ? "Activo" : "Aplicar"
                        variant: root.st.activeProfile === "emulation" ? "ghost" : "primary"
                        enabled2: root.st.activeProfile !== "emulation"
                        onClicked: { Gaming.applyProfile("emulation"); root.refresh() }
                    }
                }
            }
        }

        // ---- Diagnóstico ------------------------------------------------
        Column {
            visible: root.tab === "Diagnóstico"
            width: parent.width
            spacing: 16

            Row {
                width: parent.width
                SectionTitle {
                    width: parent.width - 120
                    text: "Hardware"
                }
                ActionButton {
                    text: "Actualizar"
                    icon: "refresh-cw"
                    onClicked: root.refresh()
                }
            }
            GroupBox {
                width: parent.width
                RowItem { width: parent.width; icon: "cpu"; title: "CPU"; desc: (root.hw.cpu || "—") + " · " + (root.hw.cores || 0) + " núcleos" }
                RowItem { width: parent.width; icon: "hard-drive"; title: "Memoria"; desc: root.hw.memory || "—" }
                RowItem { width: parent.width; icon: "hard-drive"; title: "Espacio libre"; desc: (root.hw.freeGb !== undefined ? root.hw.freeGb + " GB" : "—") }
                RowItem { width: parent.width; icon: "box"; title: "Arquitectura"; desc: root.hw.arch || "—"; last: true }
            }

            Text { text: "Estado del perfil"; font.pixelSize: 18; color: Theme.c.text }
            GroupBox {
                width: parent.width
                RowItem { width: parent.width; icon: "gamepad-2"; title: "Perfil activo"; desc: root.st.activeProfile ? (root.profileNames[root.st.activeProfile] || root.st.activeProfile) : "Ninguno" }
                RowItem { width: parent.width; icon: "package"; title: "Aplicaciones"; desc: (root.st.installedCount || 0) + " instaladas de " + (root.st.catalogCount || 0) }
                RowItem { width: parent.width; icon: "rotate-ccw"; title: "Respaldo disponible"; desc: root.st.hasBackup ? "Sí — se puede restaurar" : "No hay cambios que restaurar"; last: true }
            }

            Text {
                width: parent.width
                visible: (root.hw.recommendations || []).length > 0
                text: "Notas de compatibilidad"
                font.pixelSize: 18
                color: Theme.c.text
            }
            GroupBox {
                width: parent.width
                visible: (root.hw.recommendations || []).length > 0
                Repeater {
                    model: root.hw.recommendations || []
                    delegate: RowItem {
                        required property string modelData
                        required property int index
                        width: parent.width
                        icon: "info"
                        desc: modelData
                        last: index === (root.hw.recommendations || []).length - 1
                    }
                }
            }
        }
    }
}
