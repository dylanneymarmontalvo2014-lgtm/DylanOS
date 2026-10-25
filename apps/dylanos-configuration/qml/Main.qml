import QtQuick
import QtQuick.Controls.Basic
import org.dylanos.configuration

// Ventana principal de DylanOS Configuration: barra lateral + páginas.
Window {
    id: window
    width: 1280
    height: 800
    minimumWidth: 1024
    minimumHeight: 640
    visible: true
    title: "DylanOS Configuration"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"

    Component.onCompleted: Theme.dark = Qt.binding(function () { return System.dark })

    property string route: startPage
    property string tab: ""
    property var history: [{ route: startPage, tab: "" }]
    readonly property bool canBack: history.length > 1

    function go(target, targetTab) {
        const nextTab = targetTab || ""
        const current = history[history.length - 1]
        if (current && current.route === target && (current.tab || "") === nextTab)
            return
        history = history.concat([{ route: target, tab: nextTab }])
        route = target
        tab = nextTab
        searchQuery = ""
    }
    function back() {
        if (history.length <= 1)
            return
        const next = history.slice(0, -1)
        history = next
        const prev = next[next.length - 1]
        route = prev.route
        tab = prev.tab || ""
    }

    // --- Navegación del prototipo (data/demo.ts) ---
    readonly property var navModel: [
        { id: "system", title: "Sistema", sub: "Información y actualizaciones", icon: "monitor", color: "#d4202f", sidebar: true, keywords: "inicio resumen dispositivo" },
        { id: "bluetooth", title: "Bluetooth y dispositivos", sub: "Dispositivos, impresoras, mouse", icon: "bluetooth", color: "#2f7be8", sidebar: true, keywords: "emparejar auriculares teclado" },
        { id: "network", title: "Red e Internet", sub: "Wi-Fi, Ethernet, VPN", icon: "wifi", color: "#7b4fe0", sidebar: true, keywords: "wifi ethernet conexión vpn proxy" },
        { id: "personalization", title: "Personalización", sub: "Fondo, temas, colores, pantalla", icon: "palette", color: "#e8702a", sidebar: true, keywords: "apariencia tema color fondo escritorio paneles iconos fuente wallpaper" },
        { id: "apps", title: "Aplicaciones", sub: "Aplicaciones instaladas y predeterminadas", icon: "layout-grid", color: "#d4202f", sidebar: true, keywords: "navegador correo predeterminadas instaladas" },
        { id: "accounts", title: "Cuentas", sub: "Tu cuenta, sincronización, familia", icon: "user", color: "#d4202f", sidebar: true, keywords: "usuario perfil sesión inicio" },
        { id: "datetime", title: "Hora e idioma", sub: "Fecha, hora, región, idioma", icon: "globe", color: "#1f9aa6", sidebar: true, keywords: "zona horaria teclado formato región" },
        { id: "privacy", title: "Privacidad y seguridad", sub: "Permisos, cámara, micrófono", icon: "shield", color: "#4a55c8", sidebar: true, keywords: "bloqueo ubicación permisos seguridad" },
        { id: "power", title: "Energía y batería", sub: "Modo de energía, batería, suspensión", icon: "battery", color: "#4caf50", sidebar: true, keywords: "suspensión tapa ahorro" },
        { id: "accessibility", title: "Accesibilidad", sub: "Lectores, contraste, subtítulos", icon: "accessibility", color: "#2f7be8", sidebar: true, keywords: "contraste texto movimiento teclado" },
        { id: "updates", title: "Sistema y actualizaciones", sub: "Actualizaciones, copias de seguridad", icon: "settings-2", color: "#d4202f", sidebar: true, keywords: "actualizar copia respaldo" },
        { id: "about", title: "Acerca de DylanOS", sub: "Información del sistema", icon: "info", color: "#d4202f", sidebar: true, keywords: "versión debian kde plasma kernel procesador memoria" },
        { id: "display", title: "Pantalla", sub: "Brillo, escala, resolución", icon: "sun", color: "#e8702a", sidebar: false, keywords: "monitor resolución escala brillo orientación frecuencia luz nocturna" },
        { id: "sound", title: "Sonido", sub: "Volumen, salida, entrada", icon: "volume-2", color: "#d4202f", sidebar: false, keywords: "volumen micrófono altavoces silenciar" },
        { id: "notifications", title: "Notificaciones", sub: "Alertas y notificaciones", icon: "bell", color: "#d4202f", sidebar: false, keywords: "no molestar concentración alertas" },
        { id: "storage", title: "Almacenamiento", sub: "Uso de discos y limpieza", icon: "hard-drive", color: "#d4202f", sidebar: false, keywords: "disco limpieza espacio" }
    ]

    readonly property var searchOptions: [
        { label: "Modo oscuro", route: "personalization", tab: "Apariencia" },
        { label: "Color de énfasis", route: "personalization", tab: "Apariencia" },
        { label: "Tema de iconos", route: "personalization", tab: "Apariencia" },
        { label: "Fondo de pantalla", route: "personalization", tab: "Fondo de pantalla" },
        { label: "Comportamiento del escritorio", route: "personalization", tab: "Escritorio" },
        { label: "Navegador web predeterminado", route: "apps", tab: "Predeterminadas" },
        { label: "Aplicaciones instaladas", route: "apps", tab: "Instaladas" },
        { label: "Bloqueo automático", route: "privacy" },
        { label: "Zona horaria", route: "datetime" },
        { label: "Distribución del teclado", route: "datetime" },
        { label: "Contraste alto", route: "accessibility" },
        { label: "Tapa del portátil", route: "power" },
        { label: "Resolución", route: "display" },
        { label: "Volumen", route: "sound" },
        { label: "No molestar", route: "notifications" },
        { label: "Liberar espacio", route: "storage" },
        { label: "Redes Wi-Fi disponibles", route: "network" }
    ]

    property string searchQuery: ""
    readonly property var filteredNav: {
        const q = searchQuery.toLowerCase()
        if (q === "")
            return navModel
        return navModel.filter(function (n) {
            return (n.title + " " + n.sub + " " + n.keywords).toLowerCase().includes(q)
        })
    }
    readonly property var filteredOptions: {
        const q = searchQuery.toLowerCase()
        if (q === "")
            return []
        return searchOptions.filter(function (o) { return o.label.toLowerCase().includes(q) })
    }

    function pageTitle(routeId) {
        for (let i = 0; i < navModel.length; i++)
            if (navModel[i].id === routeId)
                return navModel[i].title
        return routeId
    }
    function pageSub(routeId) {
        for (let i = 0; i < navModel.length; i++)
            if (navModel[i].id === routeId)
                return navModel[i].sub
        return ""
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWindow
        border.width: 1
        border.color: Theme.c.border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.c.winBgTop }
            GradientStop { position: 0.55; color: Theme.c.winBgMid }
            GradientStop { position: 1.0; color: Theme.c.winBgBottom }
        }
    }

    Row {
        anchors.fill: parent

        Rectangle {
            width: Theme.sidebarWidth
            height: parent.height
            color: Theme.c.sidebar

            Column {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.topMargin: 16
                anchors.bottomMargin: 16

                WindowControls {
                    onCloseClicked: window.close()
                    onMinimizeClicked: window.showMinimized()
                    onMaximizeClicked: window.showMaximized()
                }

                SearchField {
                    width: parent.width
                    placeholder: "Buscar en configuración"
                    onTextChanged: {
                        if (text !== window.searchQuery)
                            window.searchQuery = text
                    }
                    onAccepted: {
                        if (window.filteredNav.length > 0)
                            window.go(window.filteredNav[0].id)
                        else if (window.filteredOptions.length > 0)
                            window.go(window.filteredOptions[0].route, window.filteredOptions[0].tab)
                    }
                }

                Item { width: 1; height: 14 }

                ListView {
                    id: navList
                    width: parent.width
                    height: parent.height - 76
                    clip: true
                    spacing: 2
                    model: window.searchQuery === ""
                           ? window.navModel.filter(function (n) { return n.sidebar })
                           : window.filteredNav
                    delegate: NavRow {
                        required property var modelData
                        width: navList.width
                        icon: modelData.icon
                        iconColor: modelData.color
                        title: modelData.title
                        sub: modelData.sub
                        active: window.route === modelData.id
                        onClicked: window.go(modelData.id)
                    }
                }
            }
        }

        Column {
            width: parent.width - Theme.sidebarWidth
            height: parent.height

            Item {
                id: header
                width: parent.width
                height: 78

                Rectangle {
                    id: backBtn
                    visible: window.canBack && window.route !== "system"
                    width: 36
                    height: 36
                    radius: 18
                    color: Theme.c.surfaceStrong
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    anchors.verticalCenter: parent.verticalCenter
                    LucideIcon { anchors.centerIn: parent; name: "arrow-left"; color: Theme.c.text; size: 18 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.back()
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: backBtn.visible ? 80 : 32
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: window.route === "system" ? "Configuración del sistema" : window.pageTitle(window.route)
                        font.pixelSize: 24
                        color: Theme.c.text
                    }
                    Text {
                        visible: window.route !== "system"
                        text: window.pageSub(window.route)
                        font.pixelSize: 13
                        color: Theme.c.textDim
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onPressed: window.startSystemMove()
                }
            }

            Loader {
                id: pageLoader
                width: parent.width
                height: parent.height - header.height
                source: {
                    switch (window.route) {
                    case "system": return Qt.resolvedUrl("pages/SystemPage.qml")
                    case "about": return Qt.resolvedUrl("pages/AboutPage.qml")
                    case "personalization": return Qt.resolvedUrl("pages/PersonalizationPage.qml")
                    case "network": return Qt.resolvedUrl("pages/NetworkPage.qml")
                    case "bluetooth": return Qt.resolvedUrl("pages/BluetoothPage.qml")
                    case "apps": return Qt.resolvedUrl("pages/AppsPage.qml")
                    case "accounts": return Qt.resolvedUrl("pages/AccountsPage.qml")
                    case "datetime": return Qt.resolvedUrl("pages/DateTimePage.qml")
                    case "privacy": return Qt.resolvedUrl("pages/PrivacyPage.qml")
                    case "power": return Qt.resolvedUrl("pages/PowerPage.qml")
                    case "accessibility": return Qt.resolvedUrl("pages/AccessibilityPage.qml")
                    case "updates": return Qt.resolvedUrl("pages/UpdatesPage.qml")
                    case "display": return Qt.resolvedUrl("pages/DisplayPage.qml")
                    case "sound": return Qt.resolvedUrl("pages/SoundPage.qml")
                    case "notifications": return Qt.resolvedUrl("pages/NotificationsPage.qml")
                    case "storage": return Qt.resolvedUrl("pages/StoragePage.qml")
                    default: return Qt.resolvedUrl("pages/SystemPage.qml")
                    }
                }
            }
        }
    }

    Toast {
        id: globalToast
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 96
        Component.onCompleted: System.actionFailed.connect(function (msg) { globalToast.show(msg) })
    }
}


