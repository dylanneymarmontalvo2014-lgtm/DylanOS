pragma ComponentBehavior: Bound
import QtQuick
import org.kde.plasma.plasmoid
import "lib"
import "lib/WidgetTokens.js" as Tokens

/*
 * DylanOS Widgets — Calendario.
 *
 * Mes actual con el día de hoy resaltado en Crimson y navegación entre meses.
 * Todo se calcula con la fecha del sistema: no hay eventos ni festivos
 * inventados (igual que el calendario del Dashboard histórico).
 *
 * La semana empieza en lunes, convención de es_ES.
 */
PlasmoidItem {
    id: root

    readonly property var supportedSizes: [Tokens.small, Tokens.large,
                                           Tokens.extraLarge]
    readonly property string defaultSize: Tokens.small

    readonly property int cellSize: height > 0 ? height : Tokens.defaultCell
    readonly property bool wide: width > height * 1.4

    preferredRepresentation: fullRepresentation

    readonly property date today: new Date()
    property date shownMonth: new Date(today.getFullYear(), today.getMonth(), 1)

    readonly property var monthNames: ["enero", "febrero", "marzo", "abril", "mayo",
                                       "junio", "julio", "agosto", "septiembre",
                                       "octubre", "noviembre", "diciembre"]
    readonly property var dayInitials: ["L", "M", "X", "J", "V", "S", "D"]

    readonly property string monthLabel: monthNames[shownMonth.getMonth()]
                                          + " " + shownMonth.getFullYear()

    // Abreviatura para widgets estrechos (133 px): tres letras + año. En un
    // cuadrado tan pequeño ni siquiera eso cabe junto a los botones, así que
    // se omite el año; la fecha completa está en el Calendario grande y en el
    // propio día resaltado.
    readonly property string shortMonthLabel: root.cellSize < 180
        ? monthNames[shownMonth.getMonth()].substr(0, 3)
        : monthNames[shownMonth.getMonth()].substr(0, 3) + " " + shownMonth.getFullYear()

    // Celdas del mes: huecos iniciales + días reales. Se calcula una vez por
    // cambio de mes en lugar de recalcular en cada delegate.
    readonly property var monthCells: buildMonth(shownMonth)

    function buildMonth(base) {
        const year = base.getFullYear();
        const month = base.getMonth();
        const firstDay = new Date(year, month, 1);
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        // getDay(): 0 = domingo. Desplazado para que el lunes sea la columna 0.
        const lead = (firstDay.getDay() + 6) % 7;
        const cells = [];
        for (let i = 0; i < lead; ++i)
            cells.push(0);
        for (let day = 1; day <= daysInMonth; ++day)
            cells.push(day);
        return cells;
    }

    function shiftMonth(delta) {
        shownMonth = new Date(shownMonth.getFullYear(),
                              shownMonth.getMonth() + delta, 1);
    }

    function isToday(day) {
        return day > 0
            && day === today.getDate()
            && shownMonth.getMonth() === today.getMonth()
            && shownMonth.getFullYear() === today.getFullYear();
    }

    fullRepresentation: Item {
        implicitWidth: Tokens.widthFor(Tokens.small, root.cellSize)
        implicitHeight: Tokens.heightFor(Tokens.small, root.cellSize)

        WidgetCard {
            anchors.fill: parent
            variant: Tokens.variantDark
        }

        Column {
            id: content
            anchors.fill: parent
            // Margen reducido en widgets pequeños: con 16 px por lado en un
            // cuadrado de 133 px no quedaba alto para 6 filas de días.
            anchors.margins: root.cellSize < 180 ? Tokens.space2 : Tokens.space3
            spacing: Tokens.space1
            clip: true

            // Cabecera con navegación real entre meses.
            Item {
                id: monthHeader
                width: parent.width
                height: Tokens.space5

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    // En un widget de 133 px el nombre completo no cabe junto a
                    // los dos botones; se abrevia en vez de cortar con «…».
                    text: root.shortMonthLabel
                    color: Tokens.white
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.fontSizeBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width - navRow.width - Tokens.space2
                }
                Row {
                    id: navRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.space1

                    Repeater {
                        model: [{ "glyph": "\u2039", "delta": -1 },
                                { "glyph": "\u203A", "delta": 1 }]

                        delegate: Item {
                            id: navButton
                            required property var modelData
                            width: Tokens.space5
                            height: Tokens.space5

                            Text {
                                anchors.centerIn: parent
                                text: navButton.modelData.glyph
                                color: navArea.containsMouse
                                       ? Tokens.crimson : Tokens.lightGray
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.fontSizeBody
                            }

                            MouseArea {
                                id: navArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.shiftMonth(navButton.modelData.delta)
                            }
                        }
                    }
                }
            }

            // Iniciales de la semana.
            Grid {
                id: weekdayRow
                columns: 7
                width: parent.width

                Repeater {
                    model: root.dayInitials
                    delegate: Text {
                        required property string modelData
                        width: dayGrid.cellWidth
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Tokens.lightGray
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.fontSizeCaption - 1
                        font.weight: Font.DemiBold
                    }
                }
            }

            Grid {
                id: dayGrid
                width: parent.width
                columns: 7

                // La rejilla NO puede desbordar la tarjeta. En vez de recortar
                // días (lo que hacía desaparecer el 30), se reparte el alto
                // disponible entre las filas que el mes necesita de verdad.
                readonly property int maxRows: 6
                readonly property real cellWidth: width / 7
                readonly property real available: content.height - monthHeader.height
                                                 - weekdayRow.height - content.spacing
                readonly property int rowsNeeded: Math.max(
                    1, Math.ceil(root.monthCells.length / columns))
                // Sin suelo de 12 px: en un cuadrado de 133 px solo quedan ~69 px
                // útiles y 6 filas × 12 px desbordaban la tarjeta. El suelo real
                // lo pone la legibilidad de la cifra (9 px), y la fuente escala
                // con la celda.
                readonly property real cellHeight: Math.max(
                    Tokens.space2 + 2, available / Math.min(maxRows, rowsNeeded))

                Repeater {
                    model: root.monthCells

                    delegate: Item {
                        id: dayCell
                        required property int modelData
                        width: dayGrid.cellWidth
                        height: dayGrid.cellHeight

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) - 3
                            height: width
                            radius: width / 2
                            color: root.isToday(dayCell.modelData)
                                   ? Tokens.crimson : "transparent"
                            visible: dayCell.modelData > 0
                        }

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.modelData > 0 ? dayCell.modelData : ""
                            color: root.isToday(dayCell.modelData)
                                   ? Tokens.white : Tokens.lightGray
                            font.family: Tokens.fontFamily
                            // La cifra nunca puede ser mayor que su celda.
                            font.pixelSize: Math.min(Tokens.fontSizeCaption - 1,
                                                     Math.floor(dayGrid.cellHeight - 3))
                            font.weight: root.isToday(dayCell.modelData)
                                         ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
        }
    }
}
