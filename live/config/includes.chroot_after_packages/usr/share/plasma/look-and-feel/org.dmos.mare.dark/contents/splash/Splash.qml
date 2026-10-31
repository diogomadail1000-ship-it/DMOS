import QtQuick

Rectangle {
    id: root
    color: "#060A18"
    property int stage: 0

    onStageChanged: if (stage === 2) intro.running = true

    Image {
        anchors.fill: parent
        source: "/usr/share/wallpapers/DMOS-Mare/contents/images_dark/3840x2160.jpg"
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(1920, 1080)
        opacity: 0.55
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: 220
        height: 240
        opacity: 0

        Image {
            id: logo
            anchors.horizontalCenter: parent.horizontalCenter
            source: "images/logo.svg"
            sourceSize: Qt.size(192, 192)
            width: 96
            height: 96
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: 18
            text: "DMOS"
            color: "#F5F7FC"
            font.family: "Inter Display"
            font.weight: Font.Light
            font.pixelSize: 30
            font.letterSpacing: 8
        }
        // Tide: a thin luminous bar that fills with the startup stages.
        Rectangle {
            id: track
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 180
            height: 3
            radius: 2
            color: "#26FFFFFF"
            Rectangle {
                height: parent.height
                radius: 2
                width: parent.width * Math.min(1, root.stage / 6)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#5EEAD4" }
                    GradientStop { position: 1; color: "#FF8A70" }
                }
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    NumberAnimation {
        id: intro
        target: content
        property: "opacity"
        to: 1
        duration: 500
        easing.type: Easing.OutCubic
    }
}
