import QtQuick
import QtQuick.Effects
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#060A18"

    readonly property real unit: Math.max(0.6, Math.min(width / 1920, height / 1080))
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string userName: userAt(userIndex, "name") || userModel.lastUser
    property bool failed: false

    LayoutMirroring.enabled: Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    function userAt(index, role) {
        var i = userModel.index(index, 0)
        return userModel.data(i, Qt.UserRole + (role === "name" ? 1 : role === "realName" ? 2 : 4))
    }
    function sessionName(index) {
        return sessionModel.data(sessionModel.index(index, 0), Qt.UserRole + 4)
    }
    function doLogin() {
        failed = false
        busy.running = true
        sddm.login(userName, password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            busy.running = false
            failed = true
            password.text = ""
            password.forceActiveFocus()
            shake.restart()
        }
    }

    Timer {
        id: tick
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            clock.text = Qt.formatTime(now, "HH:mm")
            var format = Qt.locale().name.indexOf("pt") === 0 ? "dddd, d 'de' MMMM" : "dddd, d MMMM"
            date.text = Qt.locale().toString(now, format)
        }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
    }

    // Wallpaper eases into focus while the password field is active.
    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 48
        blur: 0.45
        brightness: -0.08
        saturation: 0.1
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#59060A18" }
            GradientStop { position: 0.55; color: "#1A060A18" }
            GradientStop { position: 1.0; color: "#80060A18" }
        }
    }

    Column {
        id: centerStack
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30 * root.unit
        spacing: 0

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#F5F7FC"
            font.family: "Inter Display"
            font.weight: Font.Light
            font.pixelSize: 124 * root.unit
            font.letterSpacing: -4 * root.unit
        }
        Text {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#C8D0E2"
            font.family: "Inter"
            font.pixelSize: 21 * root.unit
        }
        Item { width: 1; height: 56 * root.unit }

        // Avatar, a soft ring around the account picture or the DMOS mark.
        Rectangle {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96 * root.unit; height: width; radius: width / 2
            color: "#3311172B"
            border.color: "#40FFFFFF"
            border.width: 1
            Image {
                anchors.centerIn: parent
                width: parent.width * 0.58; height: width
                source: "assets/logo.svg"
                sourceSize: Qt.size(width * 2, height * 2)
            }
        }
        Item { width: 1; height: 14 * root.unit }

        // User name; arrows or clicks walk through accounts when there are several.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14 * root.unit
            Text {
                visible: userModel.count > 1
                text: "‹"; color: "#A8B2C9"
                font.pixelSize: 24 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent; anchors.margins: -10
                    onClicked: root.userIndex = (root.userIndex + userModel.count - 1) % userModel.count
                }
            }
            Text {
                text: root.userAt(root.userIndex, "realName") || root.userName
                color: "#F5F7FC"
                font.family: "Inter"
                font.weight: Font.Medium
                font.pixelSize: 20 * root.unit
            }
            Text {
                visible: userModel.count > 1
                text: "›"; color: "#A8B2C9"
                font.pixelSize: 24 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent; anchors.margins: -10
                    onClicked: root.userIndex = (root.userIndex + 1) % userModel.count
                }
            }
        }
        Item { width: 1; height: 22 * root.unit }

        // Password pill.
        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360 * root.unit; height: 52 * root.unit; radius: height / 2
            color: password.activeFocus ? "#33FFFFFF" : "#22FFFFFF"
            border.width: 1
            border.color: root.failed ? "#FF6B6B" : password.activeFocus ? "#802DD4BF" : "#33FFFFFF"
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }

            SequentialAnimation {
                id: shake
                property int d: 55
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: -12; duration: shake.d }
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 10; duration: shake.d }
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: -6; duration: shake.d }
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 0; duration: shake.d }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 24 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                visible: password.text.length === 0
                text: root.failed ? "Palavra-passe incorreta" : "Palavra-passe"
                color: root.failed ? "#FF9C9C" : "#A8B2C9"
                font.family: "Inter"
                font.pixelSize: 16 * root.unit
            }
            TextInput {
                id: password
                anchors.left: parent.left
                anchors.right: submit.left
                anchors.leftMargin: 24 * root.unit
                anchors.rightMargin: 8 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: "#F5F7FC"
                selectionColor: "#2DD4BF"
                font.family: "Inter"
                font.pixelSize: 18 * root.unit
                focus: true
                clip: true
                Keys.onReturnPressed: root.doLogin()
                Keys.onEnterPressed: root.doLogin()
                onTextChanged: root.failed = false
            }
            Rectangle {
                id: submit
                anchors.right: parent.right
                anchors.rightMargin: 6 * root.unit
                anchors.verticalCenter: parent.verticalCenter
                width: 40 * root.unit; height: width; radius: width / 2
                color: submitArea.containsPress ? "#22B8A5" : "#2DD4BF"
                scale: submitArea.containsMouse ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Image {
                    anchors.centerIn: parent
                    visible: !busy.running
                    width: parent.width * 0.5; height: width
                    source: "assets/arrow.svg"
                    sourceSize: Qt.size(width * 2, height * 2)
                }
                RotationAnimator on rotation {
                    id: busy
                    from: 0; to: 360; duration: 900
                    loops: Animation.Infinite
                    running: false
                }
                Rectangle {
                    visible: busy.running
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.14
                    width: parent.width * 0.14; height: width; radius: width / 2
                    color: "#04201C"
                }
                MouseArea {
                    id: submitArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.doLogin()
                }
            }
        }
    }

    // Session picker, bottom left.
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 32 * root.unit
        spacing: 10 * root.unit
        Rectangle {
            height: 40 * root.unit
            width: sessionLabel.width + 36 * root.unit
            radius: height / 2
            color: sessionArea.containsMouse ? "#2AFFFFFF" : "#18FFFFFF"
            border.color: "#26FFFFFF"
            Text {
                id: sessionLabel
                anchors.centerIn: parent
                text: root.sessionName(root.sessionIndex) || "Plasma"
                color: "#DDE3F0"
                font.family: "Inter"
                font.pixelSize: 14 * root.unit
            }
            MouseArea {
                id: sessionArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
            }
        }
    }

    // Power actions, bottom right.
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 32 * root.unit
        spacing: 10 * root.unit
        Repeater {
            model: [
                { icon: "assets/suspend.svg", shown: sddm.canSuspend, act: function () { sddm.suspend() } },
                { icon: "assets/reboot.svg", shown: sddm.canReboot, act: function () { sddm.reboot() } },
                { icon: "assets/power.svg", shown: sddm.canPowerOff, act: function () { sddm.powerOff() } }
            ]
            delegate: Rectangle {
                required property var modelData
                visible: modelData.shown
                width: 40 * root.unit; height: width; radius: width / 2
                color: powerArea.containsMouse ? "#2AFFFFFF" : "#18FFFFFF"
                border.color: "#26FFFFFF"
                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.5; height: width
                    source: modelData.icon
                    sourceSize: Qt.size(width * 2, height * 2)
                }
                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: modelData.act()
                }
            }
        }
    }
}
