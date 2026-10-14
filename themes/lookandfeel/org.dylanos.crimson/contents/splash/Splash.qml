import QtQuick

// Session startup only. KSplash controls stage; this is not Plymouth boot progress.
Rectangle {
    id: root
    property int stage: 0
    color: "#101014"
    gradient: Gradient {
        GradientStop { position: 0; color: "#24131e" }
        GradientStop { position: 0.6; color: "#101014" }
        GradientStop { position: 1; color: "#181822" }
    }
    Item {
        id: constellation
        anchors.centerIn: parent
        width: 280; height: 280
        opacity: root.stage >= 1 ? 1 : 0
        scale: root.stage >= 1 ? 1 : 0.85
        Behavior on opacity { NumberAnimation { duration: 650 } }
        Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: 180 + index * 44; height: width; radius: width / 2
                color: "transparent"; border.width: 1
                border.color: index === 0 ? "#55DC143C" : "#20ffffff"
                rotation: index * 60
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: -3; width: 6; height: 6; radius: 3; color: "#f48ba0" }
                RotationAnimator on rotation { from: 0; to: 360; duration: 7000 + index * 2000; loops: Animation.Infinite; running: root.stage > 0 && root.stage < 5 }
            }
        }
        Image { anchors.centerIn: parent; width: 94; height: 94; source: "images/logo.png"; fillMode: Image.PreserveAspectFit; mipmap: true }
    }
    Column {
        anchors.top: constellation.bottom; anchors.topMargin: 26
        anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "DylanOS"; color: "#f5f5f7"; font.family: "Inter"; font.pixelSize: 30; font.weight: Font.DemiBold; font.letterSpacing: -1 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.stage >= 5 ? "Todo listo." : "Preparando tu espacio…"; color: "#bcb5c0"; font.pixelSize: 13 }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    width: index < root.stage ? 22 : 6; height: 6; radius: 3
                    color: index < root.stage ? "#DC143C" : "#42404a"
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }
    }
}
