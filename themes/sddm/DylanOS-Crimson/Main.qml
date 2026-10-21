import QtQuick 2.15
import QtQuick.Controls 2.15
import "components"

/*
 * DylanOS Crimson — pantalla de inicio de sesión.
 * Replica previews/DylanOS shell/sddm_preview.png: barra superior con logo,
 * indicadores y reloj; bloque central con candado "Bloqueado", reloj metálico
 * y fecha; tarjetas laterales; acceso con avatar y contraseña abajo.
 *
 * Autenticación real mediante sddm.login con usuario y sesión reales. El clima,
 * la música y el sistema son contenido de referencia: un greeter no tiene
 * acceso a esa información; el calendario y los relojes son reales.
 */
Rectangle {
    id: root
    width: parent ? parent.width : 1280
    height: parent ? parent.height : 800
    color: "#0A0A0A"
    property bool authenticating: false
    property string errorText: ""

    readonly property color cCrimson: "#DC143C"
    readonly property color cWhite: "#FFFFFF"
    readonly property color cGray: "#B3B3B3"
    readonly property int avatarSize: Math.max(58, Math.min(72, height * 0.085))
    readonly property real layoutScale: Math.min(1, width / 1280, height / 800)
    readonly property real railScale: Math.min(1, width / 1280, (height - 170) / 824)
    readonly property string accountsAvatarSource: user.currentText.length > 0
        ? "/var/lib/AccountsService/icons/" + user.currentText : ""
    readonly property string userAvatarSource: user.currentValue
        ? user.currentValue : accountsAvatarSource

    // Captura de QA (opt-in): solo si theme.conf define screenshot=<ruta> se
    // graba un PNG de la interfaz renderizada. En producción la clave está
    // vacía y el Timer nunca se dispara (escribir en disco en cada arranque
    // sería un artefacto de depuración inaceptable).
    Timer {
        interval: 1200
        running: typeof config.screenshot === "string" && config.screenshot.length > 0
        repeat: false
        onTriggered: root.grabToImage(function(result) {
            result.saveToFile(config.screenshot)
        })
    }

    Image { anchors.fill: parent; source: config.background; fillMode: Image.PreserveAspectCrop }
    Rectangle { anchors.fill: parent; color: "#7A000000" }
    // El preview es prácticamente negro en su tercio superior: degradado que
    // hunde el fondo arriba y libera hacia abajo, sin tocar tarjetas ni texto
    // (se pintan encima).
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#A8000000" }
            GradientStop { position: 0.45; color: "#48000000" }
            GradientStop { position: 1; color: "#26000000" }
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
        z: 10
        // El preview mantiene la barra superior muy tenue sobre el fondo.
        opacity: 0.75

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
        anchors.top: parent.top; anchors.topMargin: parent.height * 0.095
        width: parent.width * 0.44; height: 360
        scale: root.layoutScale
        transformOrigin: Item.Top

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

        // Resplandor carmesí del preview: gradiente radial amplio que envuelve
        // el reloj y baja hasta el bloque de acceso (medido sobre la imagen de
        // referencia: ocupa ~el 12-88% del ancho y ~el 22-97% del alto, con
        // núcleo fuerte en el reloj). Los anillos finos originales apenas se
        // percibían frente al resplandor sólido del diseño aprobado.
        Canvas {
            id: crimsonGlow
            z: -1
            x: root.width * 0.12
            y: root.height * 0.22
            width: root.width * 0.76
            height: root.height * 0.75
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height * 0.38;
                var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, width * 0.55);
                g.addColorStop(0.0, Qt.rgba(0.86, 0.08, 0.24, 0.42));
                g.addColorStop(0.45, Qt.rgba(0.86, 0.08, 0.24, 0.22));
                g.addColorStop(1.0, Qt.rgba(0.86, 0.08, 0.24, 0.0));
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);
                // Motivo de anillos del diseño original, ahora dentro del halo.
                var radii = [90, 120, 155, 195];
                for (var i = 0; i < radii.length; i++) {
                    var r = radii[i];
                    ctx.beginPath();
                    ctx.ellipse(cx - r, cy - r * 0.45, r * 2, r * 0.9);
                    ctx.strokeStyle = Qt.rgba(0.98, 0.29, 0.40, 0.10 - i * 0.015);
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                }
            }
        }

        Row {
            id: clockRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 48
            spacing: 8

            Text {
                id: bigClockHour
                text: root.getHour12()
                font.pixelSize: 160; font.weight: Font.Bold; color: "#F0F0F0"
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
                font.pixelSize: 160; font.weight: Font.Bold; color: "#F0F0F0"
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
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        width: 320
        spacing: 8
        scale: root.layoutScale
        transformOrigin: Item.Bottom

        Item {
            width: root.avatarSize
            height: root.avatarSize
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#242126"
                clip: true

                Image {
                    id: avatarImage
                    anchors.centerIn: parent
                    width: root.avatarSize * 0.78
                    height: width
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
            valueRole: "icon"
            currentIndex: (typeof userModel !== "undefined" && userModel && userModel.lastIndex !== undefined) ? userModel.lastIndex : 0
            visible: typeof userModel !== "undefined" && userModel && userModel.count > 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            Accessible.name: "Usuario"
        }

        Text {
            visible: user.currentText.length > 0 && !user.visible
            text: user.currentText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: root.cWhite
        }

        Rectangle {
            width: 300; height: 42; radius: 21
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#40FFFFFF"
            border.color: password.activeFocus ? root.cCrimson : "#55FFFFFF"
            border.width: 1

            TextInput {
                id: password
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.right: arrow.left; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password; color: root.cWhite; font.pixelSize: 14
                selectionColor: root.cCrimson
                enabled: !root.authenticating
                focus: true
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
                color: mouseArea.containsMouse ? root.cWhite : "#D1D1D6"
                enabled: !root.authenticating && session.currentIndex >= 0
                opacity: enabled ? 1 : 0.4
                Accessible.name: "Iniciar sesión"
                Accessible.role: Accessible.Button
                Label { anchors.centerIn: parent; text: "→"; color: "#1C1C1E"; font.pixelSize: 15; font.bold: true }
                function doLogin() {
                    if (!enabled) return
                    root.authenticating = true; root.errorText = ""
                    sddm.login(user.currentText, password.text, session.currentIndex)
                }
                MouseArea { id: mouseArea; anchors.fill: parent; hoverEnabled: true; onClicked: arrow.doLogin() }
            }
        }

        ComboBox {
            id: session
            model: sessionModel
            textRole: "name"
            currentIndex: (typeof sessionModel !== "undefined" && sessionModel && sessionModel.lastIndex !== undefined) ? sessionModel.lastIndex : 0
            visible: typeof sessionModel !== "undefined" && sessionModel && sessionModel.count > 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            Accessible.name: "Sesión"
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
            password.forceActiveFocus()
        }
    }
    // ============================================================ columna izquierda
    Column {
        id: leftRail
        anchors.left: parent.left; anchors.leftMargin: 36
        anchors.top: parent.top; anchors.topMargin: Math.max(64, 96 * root.railScale)
        width: 308; spacing: 14
        scale: root.railScale
        transformOrigin: Item.TopLeft

        WeatherCard {}
        EventCard {}
        MediaCard {}
        SystemCard {}
    }

    // ============================================================ columna derecha
    Column {
        id: rightRail
        anchors.right: parent.right; anchors.rightMargin: 36
        anchors.top: parent.top; anchors.topMargin: Math.max(64, 96 * root.railScale)
        width: 308; spacing: 14
        scale: root.railScale
        transformOrigin: Item.TopRight

        CalendarCard {}
        RemindersCard {}
        ShortcutsCard {}
    }

    // Acciones de energía reales (sddm.powerOff/reboot/suspend) — abajo a la
    // izquierda. El preview solo muestra el apagado: reinicio y suspensión se
    // integran como botones gemelos discretos con la misma composición.
    Row {
        anchors.left: parent.left; anchors.leftMargin: 28
        anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        spacing: 10

        Rectangle {
            width: 46; height: 46; radius: 23
            color: powerArea.containsMouse ? "#2A2A2A" : "#1D1D1D"
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
            Accessible.name: "Apagar"
            Accessible.role: Accessible.Button
            Image { source: "images/system-shutdown.svg"; width: 20; height: 20; anchors.centerIn: parent }
            MouseArea {
                id: powerArea; anchors.fill: parent; hoverEnabled: true
                onClicked: if (sddm.canPowerOff) sddm.powerOff()
            }
        }

        Rectangle {
            visible: sddm.canReboot
            width: 46; height: 46; radius: 23
            color: rebootArea.containsMouse ? "#2A2A2A" : "#1D1D1D"
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
            Accessible.name: "Reiniciar"
            Accessible.role: Accessible.Button
            Image { source: "images/system-reboot.svg"; width: 20; height: 20; anchors.centerIn: parent }
            MouseArea {
                id: rebootArea; anchors.fill: parent; hoverEnabled: true
                onClicked: if (sddm.canReboot) sddm.reboot()
            }
        }

        Rectangle {
            visible: sddm.canSuspend
            width: 46; height: 46; radius: 23
            color: suspendArea.containsMouse ? "#2A2A2A" : "#1D1D1D"
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
            Accessible.name: "Suspender"
            Accessible.role: Accessible.Button
            Image { source: "images/moon.svg"; width: 18; height: 18; anchors.centerIn: parent }
            MouseArea {
                id: suspendArea; anchors.fill: parent; hoverEnabled: true
                onClicked: if (sddm.canSuspend) sddm.suspend()
            }
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
        Accessible.name: "Enfocar contraseña"
        Accessible.role: Accessible.Button
        Image { source: "images/camera.svg"; width: 22; height: 22; anchors.centerIn: parent }
        MouseArea {
            id: camArea; anchors.fill: parent; hoverEnabled: true
            onClicked: password.forceActiveFocus()
        }
    }

}
