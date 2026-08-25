import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Shapes 1.8
import org.kde.breeze.components
import "components"


Rectangle {
    width: 640
    height: 480
    LayoutMirroring.enabled: Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true
    property int sizeAvatar: 80
    property int longitudMasLarga: 0

    property int lastIndexUser: user.currentIndex
    property string lastNameUser: user.currentText
    property int implicitCustomWidth: 0
    property bool firtInteraction: true
    property bool startAnimationNames: false
    TextConstants {
        id: textConstants
    }

    // hack for disable autostart QtQuick.VirtualKeyboard

    function determinateNewIndex() {
        console.log(lastNameUser, lastIndexUser)
        for (var j = 0; j < qmlUserModel.count; j++) {
            if (qmlUserModel.get(j).name === lastNameUser) {
                return j
                break
            }
        }
    }

    FontLoader {
        id: fontbold
        source: "fonts/SFUIText-Semibold.otf"
    }

    Loader {
        id: inputPanel
        property bool keyboardActive: false
        source: "components/VirtualKeyboard.qml"
    }
    Connections {
        target: sddm
        onLoginSucceeded: {

        }
        onLoginFailed: {
            password.placeholderText = textConstants.loginFailed
            password.placeholderTextColor = "white"
            password.text = ""
            password.focus = false
            errorMsgContainer.visible = true
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: true
        Binding on source {
            when: config.background !== undefined
            value: config.background
        }

    }



    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 40
        anchors.topMargin: 15

        Item {

            Image {
                id: shutdown
                height: 22
                width: 22
                source: "images/system-shutdown.svg"
                fillMode: Image.PreserveAspectFit

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        shutdown.source = "images/system-shutdown-hover.svg"
                        var component = Qt.createComponent(
                                    "components/ShutdownToolTip.qml")
                        if (component.status === Component.Ready) {
                            var tooltip = component.createObject(shutdown)
                            tooltip.x = -100
                            tooltip.y = 40
                            tooltip.destroy(600)
                        }
                    }
                    onExited: {
                        shutdown.source = "images/system-shutdown.svg"
                    }
                    onClicked: {
                        shutdown.source = "images/system-shutdown-pressed.svg"
                        sddm.powerOff()
                    }
                }
            }
        }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 70
        anchors.topMargin: 15

        Item {

            Image {
                id: reboot
                height: 22
                width: 22
                source: "images/system-reboot.svg"
                fillMode: Image.PreserveAspectFit

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        reboot.source = "images/system-reboot-hover.svg"
                        var component = Qt.createComponent(
                                    "components/RebootToolTip.qml")
                        if (component.status === Component.Ready) {
                            var tooltip = component.createObject(reboot)
                            tooltip.x = -100
                            tooltip.y = 40
                            tooltip.destroy(600)
                        }
                    }
                    onExited: {
                        reboot.source = "images/system-reboot.svg"
                    }
                    onClicked: {
                        reboot.source = "images/system-reboot-pressed.svg"
                        sddm.reboot()
                    }
                }
            }
        }
    }
Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 88
        anchors.topMargin: 15

    }
        Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 110
        anchors.topMargin: 15

         ComboBox {
                    id: session
                    height: 22
                    width: 150
                    model: sessionModel
                    textRole: "name"
                    displayText: ""
                    currentIndex: sessionModel.lastIndex
                    background: Rectangle {
                    implicitWidth: parent.width
                    implicitHeight: parent.height
                    color: "transparent"
                }


                    delegate: MenuItem {
                        id: menuitems
                        width: slistview.width * 4
                        text: session.textRole ? (Array.isArray(session.model) ? modelData[session.textRole] : model[session.textRole]) : modelData
                        highlighted: session.highlightedIndex === index
                        hoverEnabled: session.hoverEnabled
                        onClicked: {
                            ava.source = "/var/lib/AccountsService/icons/" + user.currentText
                            session.currentIndex = index
                            slistview.currentIndex = index
                            session.popup.close()
                        }
                    }
                    indicator: Rectangle{
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        height: parent.height
                        width: 22
                        color: "transparent"
                        Image{
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: width
                            fillMode: Image.PreserveAspectFit
                            source: "images/conf.svg"
                        }
                    }
                    popup: Popup {
                        width: parent.width
                        height: parent.height * menuitems.count
                        implicitHeight: slistview.contentHeight
                        margins: 0
                        contentItem: ListView {
                            id: slistview
                            clip: true
                            anchors.fill: parent
                            model: session.model
                            spacing: 0
                            highlightFollowsCurrentItem: true
                            currentIndex: session.highlightedIndex
                            delegate: session.delegate
                        }
                    }

                }
    }
    HueSaturation {
        id: ser
        anchors.fill: parent
        source: wallpaper
        hue: -0.3
        saturation: 2.0
        lightness: 0.2
        opacity: 0.1
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: identclock
        }
    }
        BrightnessContrast {
        anchors.fill: parent
        source: wallpaper
        brightness: 0.2
        contrast: 0.2
        //visible: false
        //opacity: 1
        layer.enabled: true
                               layer.effect: OpacityMask {
                               maskSource: identclock
                                }
    }
    FastBlur {
        anchors.fill: parent
        source: wallpaper
        radius: 32
        visible: listuser.visible ? false : true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: maskOfBlur
        }
    }
    Rectangle {
        id: maskOfBlur
        anchors.fill: parent
        color: "transparent"
        visible: false
        Rectangle {
            implicitWidth: 250
            implicitHeight: 32
            color: "#000"
            radius: 15
            anchors.bottom:  parent.bottom
            anchors.bottomMargin: baseOfUserDialog.anchors.bottomMargin + password.anchors.bottomMargin
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
    Item {
    id: identclock
    width: parent.width
    height: parent.height
    opacity: 0.8
   Rectangle {
       height: 300
       width: 400
       anchors.horizontalCenter: parent.horizontalCenter
       color: "transparent"
            Clock {
            id: clock
            visible: true
            anchors.topMargin: 100
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
        }
}
}


Rectangle {
    id: baseOfUserDialog
    width: listuser.visible ? listuser.width > password.width ? listuser.width + (listuser.spacing*userModel.count) : password.width : password.width
    height: listuser.visible ? listuser.height + password.height + greetingLabel.height + password.height + password.anchors.bottomMargin + 10 : sizeAvatar + password.height + greetingLabel.height + password.height + password.anchors.bottomMargin +10
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 40
    color: "transparent"
Column {
    id: sectionLogin
    height: parent.height
    width: parent.width

    ListModel {
        id: qmlUserModel

    }
    function createModel() {
        // Agregar todos los usuarios al modelo qmlUserModel
        qmlUserModel.clear()
        for (var y = 0; y < userModel.count; y++) {
            user.currentIndex = y
            qmlUserModel.append({
                name: user.currentText,
                icon: "/var/lib/AccountsService/icons/" + user.currentText
            });
        }
        lastIndexUser = determinateNewIndex()
        // Mover lastIndexUser al final
        var tempName = ""
        var tempIcon = ""
        tempName = qmlUserModel.get(lastIndexUser).name
        tempIcon = qmlUserModel.get(lastIndexUser).icon

        // Eliminar el usuario en lastIndexUser
        qmlUserModel.remove(lastIndexUser)

        qmlUserModel.append({
            name: tempName,
            icon: tempIcon
        });
    }



    ListView {
        id: listuser
        width: implicitCustomWidth + sizeAvatar*.9
        height: ((sizeAvatar*.9) + 10)*userModel.count
        model: qmlUserModel
        anchors.left: parent.left
        anchors.leftMargin: ((parent.width/2) - (sizeAvatar*.9)/2)+5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: usernametext.top
        anchors.bottomMargin: -10
        visible: false
        currentIndex: userModel.lastIndex

        delegate: Item {
            height: sizeAvatar*.9
            width: nameList.implicitWidth + height + contentFullUser.spacing
            Row {
                id: contentFullUser
                height: parent.height - 10
                width: parent.width + spacing
                spacing: 10
                anchors.top: parent.top
                Rectangle {
                    id: maskByList
                    width: sizeAvatar*.9
                    height: width
                    color: "black"
                    visible: false
                    radius: height/2
                }
                Image {
                    id: avaList
                    source: model.icon
                    height: parent.height
                    width: height
                    fillMode: Image.PreserveAspectFit
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: maskByList
                    }

                }

                Text {
                    id: nameList
                    text: model.name
                    color: "white"  // Asegúrate de que el texto sea visible sobre el fondo
                    font.bold: true
                    visible: !startAnimationNames
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle {
                id: resalt
                color: "#ff991c"
                width: parent.width/3.5
                height: width
                radius: width/2
                border.color: "white"
                border.width: width/14
                visible: model.name === userModel.currentText
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                Image {
                    id: palomita
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width*.6
                    height: width
                    source: "images/palomita.svg"
                    sourceSize: Qt.size(width, width)
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: contentFullUser
                onClicked: {
                    console.log("pruebas", lastIndexUser)
                    lastNameUser = nameList.text
                    lastIndexUser = determinateNewIndex()
                    listuser.visible = !listuser.visible
                    ava.visible = !ava.visible
                }
            }
            Component.onCompleted: {
                implicitCustomWidth = nameList.implicitWidth > implicitCustomWidth ? nameList.implicitWidth : implicitCustomWidth
            }
        }


    }


                        Rectangle {
                            id: mask
                            width: sizeAvatar
                            height: sizeAvatar
                            radius: sizeAvatar/2
                            visible: false
                        }

                        DropShadow {
                            anchors.fill: ava
                            width: mask.width - 4
                            height: mask.height - 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 15.0
                            samples: 15
                            color: "#50000000"
                            source: mask
                            visible: listuser.visible ? false : true
                        }
                    Image {
                        id: ava
                        width: sizeAvatar
                        height: sizeAvatar
                        visible: true
                        fillMode: Image.PreserveAspectCrop
                        anchors.horizontalCenter: parent.horizontalCenter

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: mask
                        }
                        source: "/var/lib/AccountsService/icons/" + lastNameUser
                        onStatusChanged: {
                            if (status == Image.Error)
                                return source = "images/.face.icon"
                        }
                         MouseArea {
                           anchors.fill: ava
                           onClicked: {
                              //lastIndexUser = firtInteraction ? user.currentIndex : lastIndexUser
                              sectionLogin.createModel()
                              listuser.visible = true
                              ava.visible = false
                              //lastIndexUser = false
                    }
                }
                    }

                // Custom ComboBox for hack colors on DropDownMenu
                ComboBox {
                    id: user
                    height: 40
                    width: 226
                    textRole: "name"
                    currentIndex: userModel.lastIndex
                    anchors.left: parent.left
                    anchors.leftMargin: 50
                    model: userModel
                    visible: false

                }

                Text {
                    id: usernametext
                    text: lastNameUser
                    anchors.top: parent.top
                    anchors.topMargin: listuser.visible ? listuser.height + 20 : sizeAvatar + 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 20
                    font.family: fontbold.name
                    font.capitalization: Font.Capitalize
                    font.weight: Font.DemiBold
                    visible: listuser.visible ? false : true
                    color: "white"
                    layer.enabled: true
                       layer.effect: DropShadow {
                       horizontalOffset: 1
                       verticalOffset: 1
                       radius: 10
                samples: 25
                color: "#26000000"
            }
                }

                Text  {
                    id: demo
                    //font.pixelSize:
                    text: password.text ? password.text : textConstants.password
                    font.weight: Font.DemiBold
                    visible: false
                }

                TextField {
                    id: password
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: greetingLabel.height*2
                    height: 32
                    width: 250
                    placeholderTextColor: "#66FFFFFF"
                    color: "#fff"
                    echoMode: TextInput.Password
                    focus: true
                    font.weight: Font.DemiBold
                    leftPadding: (width - demo.implicitWidth)/2
                    placeholderText: textConstants.password
                    //horizontalAlignment: TextInput.AlignHCenter
                    visible: listuser.visible ? false : true

                    onAccepted: sddm.login(lastNameUser, password.text,
                                           session.currentIndex)

                    background: Rectangle {

                    implicitWidth: parent.width
                    implicitHeight: parent.height
                    color: "#fff"
                    opacity: 0.2
                    radius: 15
                    }

                    Image {
                        id: caps
                        width: 24
                        height: 24
                        opacity: 0
                        state: keyboard.capsLock ? "activated" : ""
                        anchors.right: password.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10
                        fillMode: Image.PreserveAspectFit
                        source: "images/capslock.svg"
                        sourceSize.width: 24
                        sourceSize.height: 24

                        states: [
                            State {
                                name: "activated"
                                PropertyChanges {
                                    target: caps
                                    opacity: 1
                                }
                            },
                            State {
                                name: ""
                                PropertyChanges {
                                    target: caps
                                    opacity: 0
                                }
                            }
                        ]

                        transitions: [
                            Transition {
                                to: "activated"
                                NumberAnimation {
                                    target: caps
                                    property: "opacity"
                                    from: 0
                                    to: 1
                                    duration: imageFadeIn
                                }
                            },

                            Transition {
                                to: ""
                                NumberAnimation {
                                    target: caps
                                    property: "opacity"
                                    from: 1
                                    to: 0
                                    duration: imageFadeOut
                                }
                            }
                        ]
                    }
                }
                Label {
                id: greetingLabel
                text: "Enter Password"
                color: "#fff"
                style: Text.Normal
                visible: listuser.visible ? false : true

                styleColor: "transparent"
                font.pointSize:8
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                font.bold: true
            }
}



                Keys.onPressed: {
                    if (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter) {
                        sddm.login(user.currentText, password.text,
                                   session.currentIndex)
                        event.accepted = true
                    }
                }

                // Custom ComboBox for hack colors on DropDownMenu

            }
    }

