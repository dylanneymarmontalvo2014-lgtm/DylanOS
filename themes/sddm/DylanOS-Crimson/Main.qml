import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    width: parent ? parent.width : 1280
    height: parent ? parent.height : 800
    color: "#0A0A0A"

    property bool authenticating: false
    property string errorText: ""
    property date currentDate: new Date()
    readonly property color cCrimson: "#DC143C"
    readonly property color cWhite: "#FFFFFF"
    readonly property int avatarSize: Math.min(92, Math.max(64, height * 0.13))
    readonly property int clockSize: Math.max(52, Math.min(118, height * 0.15, width * 0.12))
    readonly property string userAvatarSource: user.currentText.length > 0
        ? "/var/lib/AccountsService/icons/" + user.currentText : ""

    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        color: "#66000000"
    }

    function getHour12() {
        var hour = currentDate.getHours() % 12
        if (hour === 0)
            hour = 12
        return (hour < 10 ? "0" : "") + hour
    }

    function getAmPm() {
        return currentDate.getHours() >= 12 ? "PM" : "AM"
    }

    function getSpanishDate() {
        var days = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
        var months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
        return days[currentDate.getDay()] + ", "
            + currentDate.getDate() + " de " + months[currentDate.getMonth()]
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(58, root.height * 0.09)

        Row {
            anchors.centerIn: parent
            spacing: 10
            Image {
                source: "logo.png"
                width: 28
                height: 28
                fillMode: Image.PreserveAspectFit
                mipmap: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "DylanOS"
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 21
                font.weight: Font.DemiBold
                color: root.cWhite
            }
        }
    }

    Item {
        id: centerBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: topBar.bottom
        anchors.topMargin: root.height * 0.025
        width: Math.min(root.width - 32, 620)
        height: root.height * 0.34

        Row {
            id: clockRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.height * 0.025
            spacing: 8

            Text {
                text: root.getHour12()
                font.pixelSize: root.clockSize
                font.weight: Font.Bold
                color: "#F0F0F0"
                style: Text.Raised
                styleColor: "#333333"
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                Text {
                    text: root.getAmPm()
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: root.cCrimson
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Column {
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { width: 10; height: 10; radius: 5; color: root.cCrimson }
                    Rectangle { width: 10; height: 10; radius: 5; color: root.cCrimson }
                }
            }

            Text {
                text: Qt.formatDateTime(root.currentDate, "mm")
                font.pixelSize: root.clockSize
                font.weight: Font.Bold
                color: "#F0F0F0"
                style: Text.Raised
                styleColor: "#333333"
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockRow.bottom
            anchors.topMargin: 8
            text: root.getSpanishDate()
            font.pixelSize: Math.max(18, Math.min(25, root.height * 0.034))
            color: root.cWhite
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockRow.bottom
            anchors.topMargin: Math.max(44, root.height * 0.085)
            width: 52
            height: 2
            color: root.cCrimson
        }
    }

    Column {
        id: loginBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: centerBlock.bottom
        anchors.topMargin: root.height * 0.012
        width: Math.min(340, root.width - 40)
        spacing: Math.max(8, root.height * 0.014)

        Item {
            width: root.avatarSize
            height: root.avatarSize
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                id: avatarFrame
                anchors.fill: parent
                radius: width / 2
                color: "#242126"
                clip: true

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: root.userAvatarSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: user.currentText.length > 0
                        ? user.currentText.substring(0, 1).toUpperCase() : ""
                    font.pixelSize: root.avatarSize * 0.42
                    font.weight: Font.Medium
                    color: root.cWhite
                    visible: avatarImage.status !== Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: "#B3DC143C"
                    border.width: 2
                }
            }
        }

        ComboBox {
            id: user
            model: userModel
            textRole: "name"
            currentIndex: (typeof userModel !== "undefined" && userModel && userModel.lastIndex !== undefined)
                ? userModel.lastIndex : 0
            visible: typeof userModel !== "undefined" && userModel && userModel.count > 1
            width: parent.width
            height: 42
            Accessible.name: "Usuario"
        }

        Text {
            visible: user.currentText.length > 0 && !user.visible
            text: user.currentText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: root.cWhite
        }

        Rectangle {
            id: passwordField
            width: parent.width
            height: 48
            radius: height / 2
            color: "#40FFFFFF"
            border.color: password.activeFocus ? root.cCrimson : "#66FFFFFF"
            border.width: 1

            TextInput {
                id: password
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.right: loginAction.left
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: root.cWhite
                font.pixelSize: 15
                selectionColor: root.cCrimson
                enabled: !root.authenticating
                focus: true
                onAccepted: root.doLogin()
                Accessible.name: "Contraseña"
            }

            Text {
                anchors.left: password.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Contraseña"
                color: "#C7C7CC"
                font.pixelSize: 15
                visible: password.text.length === 0
            }

            Rectangle {
                id: loginAction
                width: 34
                height: 34
                radius: 17
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                color: loginArea.containsMouse ? root.cWhite : "#D1D1D6"
                enabled: !root.authenticating && session.currentIndex >= 0
                opacity: enabled ? 1 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: "→"
                    color: "#1C1C1E"
                    font.pixelSize: 18
                    font.bold: true
                }
                MouseArea {
                    id: loginArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: loginAction.enabled
                    onClicked: root.doLogin()
                    Accessible.name: "Iniciar sesión"
                }
            }
        }

        ComboBox {
            id: session
            model: sessionModel
            textRole: "name"
            currentIndex: (typeof sessionModel !== "undefined" && sessionModel && sessionModel.lastIndex !== undefined)
                ? sessionModel.lastIndex : 0
            visible: typeof sessionModel !== "undefined" && sessionModel && sessionModel.count > 1
            width: parent.width
            height: 40
            Accessible.name: "Sesión"
        }

        Label {
            visible: root.errorText !== ""
            text: root.errorText
            color: "#FF9F97"
            font.pixelSize: 12
            width: parent.width
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }

        Label {
            visible: root.authenticating
            text: "Iniciando sesión…"
            color: "#E5E5EA"
            font.pixelSize: 12
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }
    }

    function doLogin() {
        if (authenticating || session.currentIndex < 0)
            return
        authenticating = true
        errorText = ""
        sddm.login(user.currentText, password.text, session.currentIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.authenticating = false
            password.text = ""
            root.errorText = "Contraseña incorrecta. Inténtalo de nuevo."
            password.forceActiveFocus()
        }
    }

    Rectangle {
        id: powerButton
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: 44
        height: 44
        radius: 22
        color: powerArea.containsMouse ? "#2A2A2A" : "#1D1D1D"
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        Image {
            anchors.centerIn: parent
            source: "images/system-shutdown.svg"
            width: 20
            height: 20
        }
        MouseArea {
            id: powerArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (sddm.canPowerOff) sddm.powerOff()
            Accessible.name: "Apagar"
        }
    }
}
