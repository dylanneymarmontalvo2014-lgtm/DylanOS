// Las cuatro tarjetas de recurso de la cabecera, con datos reales.
import QtQuick
import QtQuick.Layouts
import org.dylanos.process

Item {
    id: cards

    // Las cuatro tarjetas comparten la altura de la más alta: la RAM y la Swap
    // llevan barra de progreso y necesitan más espacio que la de CPU.
    readonly property real cardHeight: Math.max(cpuCard.implicitHeight,
                                                ramCard.implicitHeight,
                                                swapCard.implicitHeight,
                                                procCard.implicitHeight)
    implicitHeight: cardHeight + 28

    // Puntos de la minigráfica de CPU en la escala 100×36 del prototipo.
    function sparkPoints(values) {
        if (!values || values.length < 2)
            return ""
        var out = []
        for (var i = 0; i < values.length; ++i) {
            var x = (i / (values.length - 1)) * 100
            var y = 36 - Math.max(0, Math.min(1, values[i])) * (36 - 4) - 2
            out.push(x.toFixed(2) + "," + y.toFixed(2))
        }
        return out.join(" ")
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        ResourceCard {
            id: cpuCard
            Layout.fillWidth: true
            Layout.preferredHeight: cards.cardHeight
            Layout.maximumHeight: cards.cardHeight
            label: qsTr("CPU")
            value: Math.round(processModel.cpuPercent) + "%"
            iconSource: "image://icon/cpu"
            accent: Theme.red
            accentSubtle: Theme.redSubtle
            points: cards.sparkPoints(root.cpuHistory)
        }

        ResourceCard {
            id: ramCard
            Layout.fillWidth: true
            Layout.preferredHeight: cards.cardHeight
            Layout.maximumHeight: cards.cardHeight
            label: qsTr("RAM")
            // El prototipo separa el número de la unidad: "5.1" + "/ 8.0 GB".
            value: Format.memoryValue(processModel.memUsedBytes)
            suffix: "/ " + Format.memory(processModel.memTotalBytes)
            iconSource: "image://icon/memory"
            accent: Theme.info
            accentSubtle: Theme.infoSubtle
            progress: Format.ratio(processModel.memUsedBytes, processModel.memTotalBytes)
            progressColor: Theme.info
        }

        ResourceCard {
            id: swapCard
            Layout.fillWidth: true
            Layout.preferredHeight: cards.cardHeight
            Layout.maximumHeight: cards.cardHeight
            label: qsTr("Swap")
            value: processModel.swapTotalBytes > 0
                   ? Format.memoryValue(processModel.swapUsedBytes) : "0"
            suffix: "/ " + Format.memory(processModel.swapTotalBytes)
            iconSource: "image://icon/drive-multidisk-symbolic"
            accent: Theme.warning
            accentSubtle: Theme.warningSubtle
            progress: processModel.swapTotalBytes > 0
                      ? Format.ratio(processModel.swapUsedBytes, processModel.swapTotalBytes) : 0
            progressColor: Theme.warning
        }

        ResourceCard {
            id: procCard
            Layout.fillWidth: true
            Layout.preferredHeight: cards.cardHeight
            Layout.maximumHeight: cards.cardHeight
            label: qsTr("Procesos")
            value: processModel.count.toFixed(0)
            iconSource: "image://icon/utilities-system-monitor"
            accent: Theme.textSecondary
            accentSubtle: Theme.neutralSubtle
            footer: qsTr("%1 hilos activos").arg(processModel.threads)
        }
    }
}
