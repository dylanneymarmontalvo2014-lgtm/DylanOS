pragma Singleton
import QtQuick

/*
 * MOCKUP DATA restante — Bloque 3
 *
 * Wi-Fi, Bluetooth, brillo, volumen, modo oscuro, no molestar, notificaciones
 * y reproductor YA son datos reales (ver SystemStatus.qml / NotificationsPanel.qml).
 * Lo único que sigue siendo mockup son los 3 accesos secundarios, que no
 * tienen una acción de sistema definida todavía (pendiente que definas qué
 * deben hacer: compartir por qué medio, proyectar a qué, etc).
 */
QtObject {
    readonly property var secondaryActions: [
        { id: "airdrop", icon: "emblem-shared", label: "Compartir" },
        { id: "project", icon: "video-display", label: "Proyectar" },
        { id: "powersave", icon: "battery-profile-powersave", label: "Ahorro de energía" }
    ]
}
