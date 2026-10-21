import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 360
    height: 570
    minimumWidth: 280
    minimumHeight: 540
    title: "Calculadora"
    // Ventana DylanOS sin decoración de KWin: controles de ventana
    // integrados en la propia cabecera, como el resto de apps nativas.
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    readonly property int radius: 22
    font.family: "Inter"

    property real storedValue: 0
    property string pendingOperator: ""
    property bool resetOnNextDigit: true
    property string lastExpression: ""

    readonly property color accentRed: "#DC143C"
    readonly property color keyDark: "#1c1c1c"

    function formatNumber(n) {
        if (!isFinite(n)) return "Error"
        if (n === Math.floor(n) && Math.abs(n) < 1e15)
            return Math.floor(n).toString()
        return parseFloat(n.toFixed(8)).toString()
    }

    function inputDigit(d) {
        if (display.text === "Error") clearAll()
        if (resetOnNextDigit || display.text === "0") {
            display.text = d
            resetOnNextDigit = false
        } else if (display.text.length < 12) {
            display.text += d
        }
    }

    function inputDecimal() {
        if (display.text === "Error") clearAll()
        if (resetOnNextDigit) {
            display.text = "0."
            resetOnNextDigit = false
            return
        }
        if (display.text.indexOf(".") === -1)
            display.text += "."
    }

    function clearAll() {
        display.text = "0"
        lastExpression = ""
        storedValue = 0
        pendingOperator = ""
        resetOnNextDigit = true
    }

    function applyPercent() {
        display.text = formatNumber(parseFloat(display.text) / 100)
        resetOnNextDigit = true
    }

    function setOperator(op) {
        if (display.text === "Error") return
        if (pendingOperator !== "" && !resetOnNextDigit) {
            compute()
        } else {
            storedValue = parseFloat(display.text)
        }
        pendingOperator = op
        resetOnNextDigit = true
    }

    // Window shortcuts keep working after clicking or tabbing between keys.
    Repeater {
        model: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        delegate: Item {
            id: keyBinding
            required property string modelData
            Shortcut { sequence: keyBinding.modelData; onActivated: root.inputDigit(keyBinding.modelData) }
        }
    }
    Shortcut { sequences: [".", ","]; onActivated: root.inputDecimal() }
    Shortcut { sequence: "+"; onActivated: root.setOperator("+") }
    Shortcut { sequence: "-"; onActivated: root.setOperator("-") }
    Shortcut { sequence: "*"; onActivated: root.setOperator("×") }
    Shortcut { sequence: "/"; onActivated: root.setOperator("÷") }
    Shortcut { sequence: "%"; onActivated: root.applyPercent() }
    Shortcut { sequences: ["Return", "Enter", "="]; onActivated: root.compute() }
    Shortcut { sequences: ["Escape", "Delete"]; onActivated: root.clearAll() }
    Shortcut { sequence: "Backspace"; onActivated: { display.text = display.text.slice(0, -1) || "0" } }

    function compute() {
        if (pendingOperator === "") return
        var current = parseFloat(display.text)
        var result = current
        lastExpression = formatNumber(storedValue) + " " + pendingOperator + " " + display.text + " ="

        switch (pendingOperator) {
            case "+": result = storedValue + current; break
            case "-": result = storedValue - current; break
            case "×": result = storedValue * current; break
            case "÷": result = current !== 0 ? storedValue / current : NaN; break
        }

        display.text = formatNumber(result)
        storedValue = result
        pendingOperator = ""
        resetOnNextDigit = true
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: root.radius
        clip: true
        color: "#19171e"
        border.width: 1
        border.color: "#2e2736"

        // Arrastre de la ventana desde la cabecera.
        MouseArea {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: headerRow.bottom
            z: -1
            onPressed: root.startSystemMove()
            onDoubleClicked: root.visibility === Window.Maximized ? root.showNormal() : root.showMaximized()
        }

        ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter
                Rectangle {
                    width: 12; height: 12; radius: 12
                    color: calcClose.containsMouse ? "#ff766d" : "#ff5f57"
                    Accessible.name: "Cerrar"; Accessible.role: Accessible.Button
                    MouseArea { id: calcClose; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
                }
                Rectangle {
                    width: 12; height: 12; radius: 12
                    color: calcMin.containsMouse ? "#ffd066" : "#febc2e"
                    Accessible.name: "Minimizar"; Accessible.role: Accessible.Button
                    MouseArea { id: calcMin; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showMinimized() }
                }
                Rectangle {
                    width: 12; height: 12; radius: 12
                    color: calcMax.containsMouse ? "#48dc60" : "#28c840"
                    Accessible.name: "Maximizar"; Accessible.role: Accessible.Button
                    MouseArea { id: calcMax; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.visibility === Window.Maximized ? root.showNormal() : root.showMaximized() }
                }
            }
            Text { text: "DYLANOS"; color: "#b4a9bb"; font.pixelSize: 10; font.letterSpacing: 2 }
            Item { Layout.fillWidth: true }
            Text { text: "Calculadora"; color: "#f0dde6"; font.pixelSize: 13 }
        }
        Item { Layout.fillHeight: true }
        Text { text: root.lastExpression; color: "#b9acbf"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 15; elide: Text.ElideLeft }

        Text {
            id: display
            objectName: "display"
            text: "0"
            color: "#ffffff"
            font.pixelSize: 56
            font.weight: Font.Light
            horizontalAlignment: Text.AlignRight
            Layout.fillWidth: true
            elide: Text.ElideLeft
        }

        GridLayout {
            columns: 4
            rowSpacing: 10
            columnSpacing: 10
            Layout.fillWidth: true

            CalcButton { label: "AC"; bgColor: root.keyDark; onClicked: root.clearAll() }
            CalcButton { label: "%"; bgColor: root.keyDark; onClicked: root.applyPercent() }
            CalcButton { label: "÷"; bgColor: root.accentRed; onClicked: root.setOperator("÷") }
            CalcButton { label: "×"; bgColor: root.accentRed; onClicked: root.setOperator("×") }

            CalcButton { label: "7"; onClicked: root.inputDigit("7") }
            CalcButton { label: "8"; onClicked: root.inputDigit("8") }
            CalcButton { label: "9"; onClicked: root.inputDigit("9") }
            CalcButton { label: "-"; bgColor: root.accentRed; onClicked: root.setOperator("-") }

            CalcButton { label: "4"; onClicked: root.inputDigit("4") }
            CalcButton { label: "5"; onClicked: root.inputDigit("5") }
            CalcButton { label: "6"; onClicked: root.inputDigit("6") }
            CalcButton { label: "+"; bgColor: root.accentRed; onClicked: root.setOperator("+") }

            CalcButton { label: "1"; onClicked: root.inputDigit("1") }
            CalcButton { label: "2"; onClicked: root.inputDigit("2") }
            CalcButton { label: "3"; onClicked: root.inputDigit("3") }
            CalcButton {
                label: "="
                bgColor: root.accentRed
                Layout.rowSpan: 2
                Layout.preferredHeight: 132
                onClicked: root.compute()
            }

            CalcButton {
                label: "0"
                Layout.columnSpan: 2
                onClicked: root.inputDigit("0")
            }
            CalcButton { label: "."; onClicked: root.inputDecimal() }
        }
        }
    }
}
