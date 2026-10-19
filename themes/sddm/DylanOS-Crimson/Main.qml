import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

/*
 * DylanOS Crimson — pantalla de inicio de sesión.
 * Replica previews/DylanOS shell/sddm_preview.png: barra superior con logo,
 * indicadores y reloj; bloque central con candado "Bloqueado", reloj metálico
 * y fecha; tarjetas laterales; pista de huella abajo.
 *
 * Autenticación real: cualquier tecla o clic sobre el fondo revela el campo
 * de contraseña (sddm.login con usuario y sesión reales). El clima, la música
 * y el sistema son contenido de referencia: un greeter no tiene acceso a esa
 * información; el calendario y los relojes son reales.
 */
Rectangle {
    id: root
    width: 1280; height: 800; color: "#0A0A0A"
    property bool authenticating: false
    property bool loginVisible: false
    property string errorText: ""

    readonly property color cCrimson: "#DC143C"
    readonly property color cWhite: "#FFFFFF"
    readonly property color cGray: "#B3B3B3"

    Image { anchors.fill: parent; source: config.background; fillMode: Image.PreserveAspectCrop }
    Rectangle { anchors.fill: parent; color: "#66000000" }

    // Cualquier tecla o clic revela el acceso (pista "presiona cualquier tecla").
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.revealLogin()
    }
    FocusScope {
        anchors.fill: parent
        focus: !root.loginVisible
        Keys.onPressed: (event) => root.revealLogin()
    }

    function revealLogin() {
        if (!loginVisible) {
            loginVisible = true
            password.forceActiveFocus()
        }
    }
    function getHour12() {
        var h = new Date().getHours() % 12;
        if (h === 0) h = 12;
        return (h < 10 ? "0" : "") + h;
    }

    function getAmPm() {
        return new Date().getHours() >= 12 ? "PM" : "AM";
    }

    function getSpanishDate() {
        var d = new Date();
        var days = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
        var months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
        var dayName = days[d.getDay()];
        var dayNum = (d.getDate() < 10 ? "0" : "") + d.getDate();
        var monthName = months[d.getMonth()];
        return dayName + ", " + dayNum + " de " + monthName;
    }

    // ============================================================ barra superior
    Item {
        id: topBar
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 64

        Row {
            anchors.left: parent.left; anchors.leftMargin: 32
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Image {
                source: "logo.png"; width: 30; height: 30
                fillMode: Image.PreserveAspectFit; mipmap: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "DylanOS"; anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 22; font.weight: Font.DemiBold; color: root.cWhite
            }
        }

        Row {
            anchors.right: parent.right; anchors.rightMargin: 32
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            Image { source: "images/network-wireless.svg"; width: 18; height: 18; mipmap: true; anchors.verticalCenter: parent.verticalCenter }
            Image { source: "images/bluetooth.svg"; width: 18; height: 18; mipmap: true; anchors.verticalCenter: parent.verticalCenter }
            Image { source: "images/video-display.svg"; width: 18; height: 18; mipmap: true; anchors.verticalCenter: parent.verticalCenter }
            // Indicador de batería como en el preview
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: 26; height: 13; radius: 3; color: "transparent"
                    border.color: root.cWhite; border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: parent.width - 4; height: parent.height - 4
                        anchors.centerIn: parent; radius: 1.5; color: root.cWhite
                    }
                    Rectangle {
                        width: 2; height: 5; radius: 1; color: root.cWhite
                        anchors.left: parent.right; anchors.leftMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Text { text: "100%"; font.pixelSize: 13; color: root.cWhite; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                id: topClock
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 14; font.weight: Font.DemiBold; color: root.cWhite
                text: root.getHour12() + ":" + Qt.formatDateTime(new Date(), "mm") + " " + root.getAmPm()
            }
        }
    }

    // ============================================================ centro: reloj
    Item {
        id: centerBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: parent.height * 0.08
        width: parent.width * 0.44; height: 320

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Image {
                source: "images/lock.svg"
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
            }
            Text {
                text: "Bloqueado"; anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 18; color: "#CFCFCF"
            }
        }

        // Anillos elípticos concéntricos rojos detrás del reloj (como en el preview)
        Canvas {
            id: ripples
            anchors.centerIn: clockRow
            width: 520; height: 220
            z: -1
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var radii = [90, 120, 155, 195];
                for (var i = 0; i < radii.length; i++) {
                    var r = radii[i];
                    ctx.beginPath();
                    ctx.ellipse(cx - r, cy - r * 0.45, r * 2, r * 0.9);
                    ctx.strokeStyle = Qt.rgba(0.86, 0.08, 0.24, 0.12 - i * 0.02);
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                }
            }
        }

        Row {
            id: clockRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 38
            spacing: 8

            Text {
                id: bigClockHour
                text: root.getHour12()
                font.pixelSize: 136; font.weight: Font.Bold; color: "#F0F0F0"
                style: Text.Raised; styleColor: "#333333"
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    text: root.getAmPm()
                    font.pixelSize: 22; font.weight: Font.Bold; color: root.cCrimson
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Column {
                    spacing: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { width: 14; height: 14; radius: 7; color: root.cCrimson }
                    Rectangle { width: 14; height: 14; radius: 7; color: root.cCrimson }
                }
            }

            Text {
                id: bigClockMinute
                text: Qt.formatDateTime(new Date(), "mm")
                font.pixelSize: 136; font.weight: Font.Bold; color: "#F0F0F0"
                style: Text.Raised; styleColor: "#333333"
            }
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockRow.bottom; anchors.topMargin: 8
            text: root.getSpanishDate()
            font.pixelSize: 25; color: root.cWhite
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dateText.bottom; anchors.topMargin: 10
            width: 60; height: 2; color: root.cCrimson
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            topClock.text = root.getHour12() + ":" + Qt.formatDateTime(new Date(), "mm") + " " + root.getAmPm()
            bigClockHour.text = root.getHour12()
            bigClockMinute.text = Qt.formatDateTime(new Date(), "mm")
            dateText.text = root.getSpanishDate()
        }
    }
    // ============================================================ acceso real
    Column {
        id: loginBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: parent.height * 0.53
        spacing: 12
        visible: root.loginVisible || root.authenticating
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }

        ComboBox {
            id: user
            model: userModel
            textRole: "name"
            currentIndex: (typeof userModel !== "undefined" && userModel && userModel.lastIndex !== undefined) ? userModel.lastIndex : 0
            visible: typeof userModel !== "undefined" && userModel && userModel.count > 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            Accessible.name: "Usuario"
        }

        Rectangle {
            width: 300; height: 42; radius: 21
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#40FFFFFF"
            border.color: password.activeFocus ? cCrimson : "#55FFFFFF"
            border.width: 1

            TextInput {
                id: password
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.right: arrow.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password; color: cWhite; font.pixelSize: 14
                selectionColor: cCrimson
                enabled: !root.authenticating
                focus: root.loginVisible
                onAccepted: arrow.doLogin()
                Accessible.name: "Contraseña"
                Label {
                    visible: !password.text
                    text: "Introducir contraseña"
                    color: "#C7C7CC"; font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                id: arrow
                width: 28; height: 28; radius: 14
                anchors.right: parent.right; anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                color: mouseArea.containsMouse ? cWhite : "#D1D1D6"
                enabled: !root.authenticating && session.currentIndex >= 0
                opacity: enabled ? 1 : 0.4
                Label { anchors.centerIn: parent; text: "→"; color: "#1C1C1E"; font.pixelSize: 15; font.bold: true }
                function doLogin() {
                    if (!enabled) return
                    root.authenticating = true; root.errorText = ""
                    sddm.login(user.currentText, password.text, session.currentIndex)
                }
                MouseArea { id: mouseArea; anchors.fill: parent; hoverEnabled: true; onClicked: arrow.doLogin() }
            }
        }

        Label {
            visible: root.errorText !== ""
            text: root.errorText; color: "#FF9F97"; font.pixelSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
            wrapMode: Text.Wrap; width: 320; horizontalAlignment: Text.AlignHCenter
        }
        Label {
            visible: root.authenticating
            text: "Iniciando sesión…"; color: "#E5E5EA"; font.pixelSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.authenticating = false
            password.text = ""
            root.errorText = "Contraseña incorrecta. Inténtalo de nuevo."
            root.loginVisible = true
            password.forceActiveFocus()
        }
    }
    // ============================================================ columna izquierda
    Column {
        anchors.left: parent.left; anchors.leftMargin: 36
        anchors.top: parent.top; anchors.topMargin: 96
        width: 308; spacing: 14

        WeatherCard {}
        EventCard {}
        MediaCard {}
        SystemCard {}
    }

    // ============================================================ columna derecha
    Column {
        anchors.right: parent.right; anchors.rightMargin: 36
        anchors.top: parent.top; anchors.topMargin: 96
        width: 308; spacing: 14

        CalendarCard {}
        RemindersCard {}
        ShortcutsCard {}
    }

    // ============================================================ parte inferior
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 34
        spacing: 12
        Image {
            source: "images/fingerprint.svg"; width: 44; height: 44
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "Usa tu huella o presiona cualquier tecla para desbloquear"
            font.pixelSize: 15; color: "#D8D8D8"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // Apagado real (sddm.powerOff) — abajo a la izquierda.
    Rectangle {
        anchors.left: parent.left; anchors.leftMargin: 28
        anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        width: 46; height: 46; radius: 23
        color: powerArea.containsMouse ? "#2A2A2A" : "#1D1D1D"
        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
        Image { source: "images/system-shutdown.svg"; width: 20; height: 20; anchors.centerIn: parent }
        MouseArea {
            id: powerArea; anchors.fill: parent; hoverEnabled: true
            onClicked: if (sddm.canPowerOff) sddm.powerOff()
        }
    }

    // Cámara / acción rápida (como en el preview) — abajo a la derecha.
    Rectangle {
        id: camButton
        anchors.right: parent.right; anchors.rightMargin: 28
        anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        width: 46; height: 46; radius: 23
        color: camArea.containsMouse ? "#2A2A2A" : "#1D1D1D"
        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
        Image { source: "images/camera.svg"; width: 22; height: 22; anchors.centerIn: parent }
        MouseArea {
            id: camArea; anchors.fill: parent; hoverEnabled: true
            onClicked: root.revealLogin()
        }
    }

    // Selector de sesión real (sessionModel) — junto al botón de cámara.
    ComboBox {
        id: session
        model: sessionModel
        textRole: "name"
        currentIndex: (typeof sessionModel !== "undefined" && sessionModel && sessionModel.lastIndex !== undefined) ? sessionModel.lastIndex : 0
        visible: typeof sessionModel !== "undefined" && sessionModel && sessionModel.count > 1
        anchors.right: camButton.left; anchors.rightMargin: 12
        anchors.verticalCenter: camButton.verticalCenter
        width: 180
        Accessible.name: "Sesión"
    }
}