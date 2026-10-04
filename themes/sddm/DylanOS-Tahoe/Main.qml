import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// DylanOS Tahoe — pantalla de login estilo macOS:
// reloj grande arriba, avatar circular centrado, campo contraseña tipo píldora.
Rectangle {
    id: root
    width: 1280; height: 800; color: "#1c1c1e"
    property bool authenticating: false

    Image { anchors.fill: parent; source: config.background; fillMode: Image.PreserveAspectCrop }
    // Oscurecido suave tipo "vibrancy" de macOS (sin blur para compatibilidad SDDM).
    Rectangle { anchors.fill: parent; color: "#40000000" }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm") }

    Column {
        anchors.top: parent.top; anchors.topMargin: parent.height * .09
        anchors.horizontalCenter: parent.horizontalCenter; spacing: 4
        Label { id: clock; anchors.horizontalCenter: parent.horizontalCenter
            font.family: "Inter"; font.pixelSize: 76; font.weight: Font.Bold; color: "white" }
        Label { text: Qt.formatDate(new Date(), "dddd, d 'de' MMMM"); anchors.horizontalCenter: parent.horizontalCenter
            font.family: "Inter"; font.pixelSize: 18; font.weight: Font.Medium; color: "#f2f2f7" }
    }

    Column {
        anchors.centerIn: parent; anchors.verticalCenterOffset: 60; spacing: 14

        // Avatar circular con la inicial del usuario (estilo macOS).
        Rectangle {
            width: 96; height: 96; radius: 48; anchors.horizontalCenter: parent.horizontalCenter
            color: "#0a84ff"
            Label { anchors.centerIn: parent
                text: user.currentText ? user.currentText.charAt(0).toUpperCase() : "?"
                color: "white"; font.pixelSize: 44; font.weight: Font.Medium }
        }

        Label { text: user.currentText || "Usuario"; anchors.horizontalCenter: parent.horizontalCenter
            color: "white"; font.family: "Inter"; font.pixelSize: 21; font.weight: Font.Medium }

        // Selector de usuario solo si hay varios (macOS muestra lista solo multiusuario).
        ComboBox {
            id: user; model: userModel; textRole: "name"; currentIndex: userModel.lastIndex
            visible: userModel.count > 1; anchors.horizontalCenter: parent.horizontalCenter
            Accessible.name: "Usuario"
        }

        // Campo contraseña tipo píldora translúcida + botón flecha.
        Rectangle {
            width: 280; height: 38; radius: 19; anchors.horizontalCenter: parent.horizontalCenter
            color: "#40ffffff"; border.color: password.activeFocus ? "#0a84ff" : "#55ffffff"; border.width: 1

            TextInput {
                id: password
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.right: arrow.left; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password; color: "white"; font.pixelSize: 14
                selectionColor: "#0a84ff"
                enabled: !root.authenticating; focus: true
                onAccepted: arrow.doLogin()
                Accessible.name: "Contraseña"
                Label { visible: !password.text; text: "Introducir contraseña"
                    color: "#c7c7cc"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle {
                id: arrow
                width: 26; height: 26; radius: 13; anchors.right: parent.right; anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                color: mouseArea.containsMouse ? "#ffffff" : "#d1d1d6"
                enabled: !root.authenticating && session.currentIndex >= 0
                opacity: enabled ? 1 : 0.4
                Label { anchors.centerIn: parent; text: "→"; color: "#1c1c1e"; font.pixelSize: 15; font.bold: true }
                function doLogin() {
                    if (!enabled) return
                    root.authenticating = true; error.text = ""
                    sddm.login(user.currentText, password.text, session.currentIndex)
                }
                MouseArea { id: mouseArea; anchors.fill: parent; hoverEnabled: true; onClicked: arrow.doLogin() }
            }
        }

        Label { id: error; color: "#ff9f97"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter
            wrapMode: Text.Wrap; width: 300; horizontalAlignment: Text.AlignHCenter }

        Label { visible: root.authenticating; text: "Iniciando sesión…"; color: "#e5e5ea"
            font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
    }

    // Barra inferior discreta: sesión y energía como texto (estilo macOS).
    Row {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 28
        anchors.horizontalCenter: parent.horizontalCenter; spacing: 26
        ComboBox { id: session; model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex
            visible: sessionModel.count > 1; width: 200; Accessible.name: "Sesión" }
        Label { text: "Suspender"; color: "#e5e5ea"; visible: sddm.canSuspend
            MouseArea { anchors.fill: parent; onClicked: sddm.suspend() } }
        Label { text: "Reiniciar"; color: "#e5e5ea"; visible: sddm.canReboot
            MouseArea { anchors.fill: parent; onClicked: sddm.reboot() } }
        Label { text: "Apagar"; color: "#e5e5ea"; visible: sddm.canPowerOff
            MouseArea { anchors.fill: parent; onClicked: sddm.powerOff() } }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.authenticating = false; password.text = ""
            error.text = "Contraseña incorrecta. Inténtalo de nuevo."
            password.forceActiveFocus()
        }
    }
}
