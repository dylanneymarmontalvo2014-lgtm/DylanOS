import QtQuick 2.15
SideCard {
    title: "Sesiones disponibles"
    height: 118
    Text {
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: (typeof sessionModel !== "undefined" && sessionModel) ? sessionModel.count + " sesión(es) detectada(s)" : "Consultando sesiones…"
        color: "#FFFFFF"; font.pixelSize: 14; wrapMode: Text.Wrap
    }
}
