// Pestaña Rendimiento: cinco gráficas con datos reales del sistema.
import QtQuick
import QtQuick.Layouts
import org.dylanos.process

Item {
    id: page

    GridLayout {
        anchors.fill: parent
        anchors.margins: 18
        columns: 2
        columnSpacing: 14
        rowSpacing: 14

        PerfCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 158
            title: qsTr("Uso de CPU")
            value: Math.round(processModel.cpuPercent) + "%"
            iconSource: "image://icon/cpu"
            accent: Theme.red
            fillColor: Theme.redSubtle
            values: root.cpuHistory
            detail: qsTr("%1 núcleos · carga %2 %3 %4").arg(processModel.cores)
                    .arg(processModel.load1.toFixed(2)).arg(processModel.load5.toFixed(2))
                    .arg(processModel.load15.toFixed(2))
        }

        PerfCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 158
            title: qsTr("Memoria")
            value: root.memText(processModel.memUsedBytes)
            iconSource: "image://icon/memory"
            accent: Theme.info
            fillColor: Theme.infoSubtle
            values: root.memHistory
            detail: qsTr("%1 de %2 en uso").arg(root.memText(processModel.memUsedBytes))
                    .arg(root.memText(processModel.memTotalBytes))
        }

        PerfCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 158
            title: qsTr("Disco")
            value: root.rateText(processModel.diskRead + processModel.diskWrite)
            iconSource: "image://icon/drive-harddisk-symbolic"
            accent: Theme.diskStroke
            fillColor: "#12ffffff"
            values: root.diskHistory
            detail: qsTr("%1 lectura · %2 escritura").arg(root.rateText(processModel.diskRead))
                    .arg(root.rateText(processModel.diskWrite))
        }

        PerfCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 158
            title: qsTr("Red")
            value: root.rateText(processModel.netRx + processModel.netTx)
            iconSource: "image://icon/network-wireless-symbolic"
            accent: Theme.success
            fillColor: Theme.successSubtle
            values: root.netHistory
            detail: qsTr("%1 recepción · %2 envío").arg(root.rateText(processModel.netRx))
                    .arg(root.rateText(processModel.netTx))
        }

        PerfCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 158
            title: qsTr("Swap")
            value: root.memText(processModel.swapUsedBytes)
            iconSource: "image://icon/drive-multidisk-symbolic"
            accent: Theme.warning
            fillColor: Theme.warningSubtle
            values: root.swapHistory
            detail: processModel.swapTotalBytes > 0
                    ? qsTr("%1 de %2 en uso").arg(root.memText(processModel.swapUsedBytes))
                        .arg(root.memText(processModel.swapTotalBytes))
                    : qsTr("Este sistema no tiene swap activa")
        }
    }
}
