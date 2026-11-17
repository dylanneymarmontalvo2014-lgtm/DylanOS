pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
// Los componentes comunes viven junto al widget (plasmoid autocontenido):
// un directorio hermano no entra en el ámbito QML sin declararlo.
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Reloj.
 *
 * Hora real del sistema. Sin zona horaria inventada ni datos de red: lee el
 * reloj local. Alterna entre formato de 12 y 24 horas según la configuración
 * regional del usuario.
 */
PlasmoidItem {
    id: root

    // Tamaños que el widget declara soportar (contrato común).
    readonly property var supportedSizes: [Tokens.small, Tokens.large]
    readonly property string defaultSize: Tokens.small

    // `screenGeometry` lo aporta la API de scripting; dentro del applet la
    // altura útil es la que Plasma asigna a la representación.
    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell
    readonly property bool wide: width > height * 1.4

    preferredRepresentation: fullRepresentation

    readonly property date now: wallClock.date
    readonly property bool show24h: Qt.locale().timeFormat(Locale.ShortFormat).indexOf("AP") === -1

    // Escala tipográfica derivada del lado del widget, no del propio Text:
    // usar `width` dentro del Text que la define provoca un bucle de binding.
    // En un cuadrado de 133 px la hora con segundos al lado se salía del
    // borde, así que los segundos van en su propia línea (ver delegado).
    readonly property int timeFontSize: Math.round(root.cellSize * (root.wide ? 0.42 : 0.31))
    readonly property int secondsFontSize: Math.max(Tokens.fontSizeCaption,
                                                    Math.round(root.cellSize * 0.09))

    Timer {
        id: wallClock
        property date date: new Date()
        interval: 1000
        running: true
        repeat: true
        // Se alinea al segundo exacto para que el reloj no derive.
        triggeredOnStart: true
        onTriggered: {
            date = new Date();
            const drift = 1000 - (date.getMilliseconds());
            interval = drift > 100 ? drift : 1000;
        }
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.small, root.cellSize)
        implicitHeight: Tokens.heightFor(Tokens.small, root.cellSize)

        WidgetCard {
            anchors.fill: parent
            variant: Tokens.variantDark
        }

        Column {
            anchors.centerIn: parent
            spacing: Tokens.space1

            // Hora con los segundos debajo, en pequeño y en Crimson: en un
            // cuadrado de 133 px ponerlos al lado derecho empujaba la hora
            // fuera de la tarjeta.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, root.show24h ? "HH:mm" : "h:mm")
                color: Tokens.white
                font.family: Tokens.fontFamily
                font.pixelSize: root.timeFontSize
                font.weight: Font.Light
                font.letterSpacing: -1
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, "ss")
                color: Tokens.crimson
                font.family: Tokens.fontFamily
                font.pixelSize: root.secondsFontSize
                font.weight: Font.DemiBold
                font.letterSpacing: 2
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.now, "ddd d MMM").toUpperCase()
                color: Tokens.lightGray
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.fontSizeCaption
                font.letterSpacing: 1
            }
        }
    }
}
