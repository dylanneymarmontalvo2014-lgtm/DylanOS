import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 320
    height: 480
    minimumWidth: 280
    minimumHeight: 420
    title: "Calculadora"
    color: "#0a0a0a"

    property real storedValue: 0
    property string pendingOperator: ""
    property bool resetOnNextDigit: true

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

    Item {
        focus: true
        Keys.onPressed: function(event) {
            if (/^[0-9]$/.test(event.text)) root.inputDigit(event.text)
            else if (event.text === "." || event.text === ",") root.inputDecimal()
            else if (event.text === "+" || event.text === "-") root.setOperator(event.text)
            else if (event.text === "*") root.setOperator("×")
            else if (event.text === "/") root.setOperator("÷")
            else if (event.text === "%") root.applyPercent()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.text === "=") root.compute()
            else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Delete) root.clearAll()
            else if (event.key === Qt.Key_Backspace) { display.text = display.text.slice(0, -1) || "0" }
            else return
            event.accepted = true
        }
    }

    function compute() {
        if (pendingOperator === "") return
        var current = parseFloat(display.text)
        var result = current

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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Item { Layout.fillHeight: true }

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
            rowSpacing: 12
            columnSpacing: 12
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
                Layout.preferredHeight: 140
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
