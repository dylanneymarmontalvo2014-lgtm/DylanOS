import QtQuick 2.15
import QtQuick.Layouts 1.15

// Calendario REAL del mes en curso, navegable con las flechas.
SideCard {
    id: calendarCard
    height: 254

    property date viewDate: new Date()

    function monthName(d) {
        const raw = Qt.formatDate(d, "MMMM")
        return raw.charAt(0).toUpperCase() + raw.slice(1)
    }

    // 1 = lunes ... 7 = domingo (la referencia arranca en domingo)
    function firstWeekday(d) {
        const js = new Date(d.getFullYear(), d.getMonth(), 1).getDay()
        return js // 0 = domingo
    }

    function daysInMonth(d) {
        return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
    }

    function rebuild() {
        dayModel.clear()
        const prev = new Date(viewDate.getFullYear(), viewDate.getMonth(), 0)
        const lead = firstWeekday(viewDate)
        const prevDays = daysInMonth(prev)
        for (let i = lead - 1; i >= 0; i--)
            dayModel.append({ day: prevDays - i, current: false, today: false })
        const total = daysInMonth(viewDate)
        const today = new Date()
        for (let d = 1; d <= total; d++) {
            const isToday = d === today.getDate() && viewDate.getMonth() === today.getMonth() && viewDate.getFullYear() === today.getFullYear()
            dayModel.append({ day: d, current: true, today: isToday })
        }
        while (dayModel.count < 42) {
            let nextDay = dayModel.count - lead - total + 1
            dayModel.append({ day: nextDay, current: false, today: false })
        }
    }

    onViewDateChanged: rebuild()
    Component.onCompleted: rebuild()

    ListModel { id: dayModel }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: calendarCard.monthName(calendarCard.viewDate) + " " + calendarCard.viewDate.getFullYear()
                font.pixelSize: 15; font.weight: Font.DemiBold; color: "#DC143C"
                Layout.fillWidth: true
            }
            MouseArea {
                width: 24; height: 24
                Layout.alignment: Qt.AlignVCenter
                Text { text: "‹"; font.pixelSize: 18; color: "#B3B3B3"; anchors.centerIn: parent }
                onClicked: calendarCard.viewDate = new Date(calendarCard.viewDate.getFullYear(), calendarCard.viewDate.getMonth() - 1, 1)
            }
            MouseArea {
                width: 24; height: 24
                Layout.alignment: Qt.AlignVCenter
                Text { text: "›"; font.pixelSize: 18; color: "#B3B3B3"; anchors.centerIn: parent }
                onClicked: calendarCard.viewDate = new Date(calendarCard.viewDate.getFullYear(), calendarCard.viewDate.getMonth() + 1, 1)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 0
            rowSpacing: 6
            Repeater {
                model: ["D", "L", "M", "M", "J", "V", "S"]
                delegate: Text {
                    text: modelData
                    font.pixelSize: 11; font.weight: Font.DemiBold; color: "#B3B3B3"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
            Repeater {
                model: dayModel
                delegate: Item {
                    Layout.preferredWidth: (calendarCard.width - 28) / 7
                    Layout.preferredHeight: 28
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        anchors.centerIn: parent
                        visible: model.today
                        color: "#DC143C"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        font.pixelSize: 12
                        color: !model.current ? "#5a5a5a" : (model.today ? "#FFFFFF" : "#E5E5E5")
                        font.weight: model.today ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}