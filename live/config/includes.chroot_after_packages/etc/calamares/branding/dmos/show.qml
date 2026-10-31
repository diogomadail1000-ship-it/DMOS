import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        interval: 12000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    // Shared backdrop: a Slide only covers the middle of the page, this covers all of it.
    Rectangle {
        anchors.fill: parent
        z: -1
        color: "#0C1122"
        Image {
            anchors.fill: parent
            source: "welcome.png"
            fillMode: Image.PreserveAspectCrop
            opacity: 0.6
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.8
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "#F5F7FC"
                font.pixelSize: 30
                font.weight: Font.Light
                text: "Bem-vindo ao DMOS"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: "#C8D0E2"
                font.pixelSize: 16
                text: "A instalação decorre sozinha e demora alguns minutos. Pode continuar a usar o computador."
            }
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.8
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "#F5F7FC"
                font.pixelSize: 30
                font.weight: Font.Light
                text: "Claro ou escuro, à sua escolha"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: "#C8D0E2"
                font.pixelSize: 16
                text: "Em Definições, Tema Global, encontra o DMOS Maré nas versões Claro e Escuro."
            }
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.8
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "#F5F7FC"
                font.pixelSize: 30
                font.weight: Font.Light
                text: "Mais aplicações no Discover"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: "#C8D0E2"
                font.pixelSize: 16
                text: "O Discover instala aplicações do Debian e, em Flatpak, do repositório que escolher."
            }
        }
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() {
    }
}
