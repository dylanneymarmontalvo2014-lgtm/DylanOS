import QtQuick
import QtQuick.Controls.Basic

Pane {
    id: root
    padding: 22
    background: Rectangle {
        radius: 20
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.palette.window === "#f5f5f7" ? "#ffffff" : "#1e1a24" }
            GradientStop { position: 1.0; color: root.palette.window === "#f5f5f7" ? "#f0f0f5" : "#131018" }
        }
        border.color: root.palette.window === "#f5f5f7" ? "#dcdce4" : "#3a2533"
        border.width: 1

        // Top specular line (liquid glass effect)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            radius: 20
            color: root.palette.window === "#f5f5f7" ? "#80ffffff" : "#22ffffff"
        }
    }
}
