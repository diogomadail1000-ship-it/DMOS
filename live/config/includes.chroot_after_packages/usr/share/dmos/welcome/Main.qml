import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import "file:///usr/share/plasma/plasmoids/org.dmos.hub/contents/code/sources.js" as Sources

// "Bem-vindo ao DMOS": first-run setup in five short pages.
Window {
    id: win
    width: 1040
    height: 700
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Window
    title: "Bem-vindo ao DMOS"

    readonly property var pages: ["inicio", "aparencia", "ligacao", "noticias", "aplicacoes", "pronto"]
    property int page: 0
    property bool dark: true
    property bool live: false
    property string network: "unknown"
    property var chosen: ({})

    // Palette follows the chosen look, so the choice is visible straight away.
    readonly property color ink: dark ? "#F5F7FC" : "#1A2238"
    readonly property color inkDim: dark ? "#A8B2C9" : "#5B6580"
    readonly property color glass: dark ? Qt.rgba(0.04, 0.06, 0.13, 0.72) : Qt.rgba(0.97, 0.98, 1.0, 0.74)
    readonly property color line: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0.1, 0.13, 0.22, 0.10)
    readonly property color tile: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.65)
    readonly property color accent: dark ? "#2DD4BF" : "#0E8F88"
    readonly property color onAccent: dark ? "#04201C" : "#FFFFFF"
    readonly property string wallpaper: "file:///usr/share/wallpapers/DMOS-Mare/contents/"
                                        + (dark ? "images_dark" : "images") + "/3840x2160.jpg"

    function chosenIds() {
        return Sources.list.filter(function (s) { return chosen[s.id] }).map(function (s) { return s.id })
    }

    function finish() {
        shell.run("kwriteconfig6 --file dmosrc --group News --key Sources '" + chosenIds().join(",") + "'")
        shell.run("kwriteconfig6 --file dmosrc --group Welcome --key Done true")
        quitTimer.start()
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        function run(command) { connectSource(command) }
        onNewData: function (source, data) {
            disconnectSource(source)
            var out = data.stdout.trim()
            if (source.indexOf("nmcli") === 0) {
                win.network = out || "unknown"
            } else if (source.indexOf("test -d /run/live") === 0) {
                win.live = out === "live"
            } else if (source.indexOf("kreadconfig6 --file dmosrc --group News") === 0) {
                var map = {}
                out.split(",").forEach(function (id) { if (id) map[id] = true })
                win.chosen = map
            } else if (source.indexOf("kreadconfig6 --file kdeglobals") === 0) {
                win.dark = out.indexOf("org.dmos.mare.light") < 0
            }
        }
    }

    Timer { id: quitTimer; interval: 600; onTriggered: Qt.quit() }
    Timer {
        // Connection state, only while its page is open.
        interval: 3000; repeat: true; triggeredOnStart: true
        running: win.pages[win.page] === "ligacao"
        onTriggered: shell.run("nmcli -t -f STATE general")
    }

    Component.onCompleted: {
        shell.run("test -d /run/live/medium && echo live || echo installed")
        shell.run("kreadconfig6 --file dmosrc --group News --key Sources")
        shell.run("kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage")
        var args = Qt.application.arguments
        var at = args.indexOf("--page")
        if (at >= 0 && at + 1 < args.length && pages.indexOf(args[at + 1]) >= 0) {
            page = pages.indexOf(args[at + 1])
        }
        x = (Screen.width - width) / 2
        y = (Screen.height - height) / 2
        // Wayland app id "org.dmos.welcome.qml", matching org.dmos.welcome.qml.desktop.
        Qt.application.domain = "welcome.dmos.org"
        Qt.application.name = "Bem-vindo ao DMOS"
        visible = true
    }

    // ---- Frame: blurred wallpaper behind a tinted pane, soft shadow, 1 px rim. ----
    Item {
        id: frame
        anchors.fill: parent
        anchors.margins: 28

        Rectangle {
            id: shadowSource
            anchors.fill: parent
            radius: 22
            color: "black"
            visible: false
        }
        MultiEffect {
            anchors.fill: shadowSource
            source: shadowSource
            shadowEnabled: true
            shadowBlur: 1.0
            shadowOpacity: win.dark ? 0.6 : 0.25
            shadowVerticalOffset: 10
            autoPaddingEnabled: true
        }

        Rectangle {
            id: paneMask
            anchors.fill: parent
            radius: 22
            visible: false
            layer.enabled: true
        }
        Item {
            id: pane
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: paneMask
            }

            Image {
                id: backdrop
                anchors.fill: parent
                source: win.wallpaper
                sourceSize: Qt.size(1280, 720)
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: backdrop
                blurEnabled: true
                blurMax: 64
                blur: 1.0
                saturation: 0.25
            }
            Rectangle {
                anchors.fill: parent
                color: win.glass
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 22
            color: "transparent"
            border.width: 1
            border.color: win.line
        }

        // Drag anywhere on the empty pane to move the window.
        MouseArea {
            anchors.fill: parent
            onPressed: win.startSystemMove()
        }

        // Close.
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 18
            width: 30; height: 30; radius: 15
            color: closeArea.containsMouse ? win.tile : "transparent"
            Text { anchors.centerIn: parent; text: "×"; color: win.inkDim; font.pixelSize: 22 }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: win.finish()
            }
        }

        // ---- Pages ----
        Item {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 64
            anchors.rightMargin: 64
            anchors.topMargin: 56
            anchors.bottomMargin: 96

            Page {
                index: 0
                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 18
                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        source: "file:///usr/share/icons/hicolor/scalable/apps/dmos-logo.svg"
                        sourceSize: Qt.size(220, 220)
                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 110
                    }
                    Title { text: "Bem-vindo ao DMOS"; Layout.alignment: Qt.AlignHCenter; font.pixelSize: 44 }
                    Body {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: 560
                        text: win.live
                              ? "Está a experimentar o DMOS sem alterar o seu computador. Em poucos passos fica com tudo a seu gosto, ou pode instalá-lo já."
                              : "Vamos deixar o sistema a seu gosto. São só cinco passos, e pode mudar tudo mais tarde nas Definições."
                    }
                    Button {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 10
                        visible: win.live
                        secondary: true
                        label: "Instalar o DMOS"
                        onActivated: shell.run("calamares-install-debian")
                    }
                }
            }

            Page {
                index: 1
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: "Escolha o seu visual" }
                    Body { text: "O tema aplica-se de imediato a todo o sistema." }
                    RowLayout {
                        Layout.topMargin: 24
                        Layout.fillWidth: true
                        spacing: 28
                        Repeater {
                            model: [
                                { name: "Escuro", note: "Maré à noite", dark: true, image: "images_dark" },
                                { name: "Claro", note: "Maré de manhã", dark: false, image: "images" }
                            ]
                            delegate: Item {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: width * 0.56 + 54
                                readonly property bool selected: win.dark === modelData.dark
                                Rectangle {
                                    id: thumbFrame
                                    width: parent.width
                                    height: width * 0.56
                                    radius: 16
                                    color: "transparent"
                                    border.width: parent.selected ? 3 : 1
                                    border.color: parent.selected ? win.accent : win.line
                                    scale: thumbArea.containsMouse ? 1.015 : 1
                                    Behavior on scale { NumberAnimation { duration: 140 } }
                                    Rectangle {
                                        id: thumbMask
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        radius: 12
                                        visible: false
                                        layer.enabled: true
                                    }
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        source: "file:///usr/share/wallpapers/DMOS-Mare/contents/" + modelData.image + "/3840x2160.jpg"
                                        sourceSize: Qt.size(640, 360)
                                        fillMode: Image.PreserveAspectCrop
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: thumbMask
                                        }
                                    }
                                    MouseArea {
                                        id: thumbArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.dark = modelData.dark
                                            shell.run("plasma-apply-lookandfeel --apply " + (modelData.dark ? "org.dmos.mare.dark" : "org.dmos.mare.light"))
                                        }
                                    }
                                }
                                Text {
                                    anchors.top: thumbFrame.bottom
                                    anchors.topMargin: 12
                                    text: modelData.name
                                    color: win.ink
                                    font.family: "Inter"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 17
                                }
                                Text {
                                    anchors.top: thumbFrame.bottom
                                    anchors.topMargin: 34
                                    text: modelData.note
                                    color: win.inkDim
                                    font.family: "Inter"
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Page {
                index: 2
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: "Ligação à internet" }
                    Body { text: "Precisa dela para as notícias, as atualizações e para instalar aplicações." }
                    Rectangle {
                        Layout.topMargin: 28
                        Layout.fillWidth: true
                        Layout.preferredHeight: 128
                        radius: 18
                        color: win.tile
                        border.color: win.line
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 26
                            spacing: 22
                            Kirigami.Icon {
                                source: win.network === "connected" ? "network-wireless-connected-100"
                                      : win.network.indexOf("connecting") === 0 ? "network-wireless-acquiring"
                                      : "network-wireless-disconnected"
                                implicitWidth: 64
                                implicitHeight: 64
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    text: win.network === "connected" ? "Está ligado à internet"
                                        : win.network.indexOf("connected") === 0 ? "Ligação limitada"
                                        : win.network.indexOf("connecting") === 0 ? "A ligar…"
                                        : "Sem ligação"
                                    color: win.ink
                                    font.family: "Inter"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 20
                                }
                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: win.network === "connected"
                                          ? "Pode continuar."
                                          : "Ligue um cabo de rede ou escolha uma rede Wi-Fi."
                                    color: win.inkDim
                                    font.family: "Inter"
                                    font.pixelSize: 15
                                }
                            }
                            Button {
                                secondary: true
                                label: "Redes Wi-Fi"
                                onActivated: shell.run("kcmshell6 kcm_networkmanagement")
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Page {
                index: 3
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: "As suas notícias" }
                    Body { text: "Escolha o que aparece no painel do ambiente de trabalho. Só as fontes que ligar são contactadas." }
                    GridLayout {
                        Layout.topMargin: 20
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 12
                        Repeater {
                            model: Sources.list
                            delegate: Rectangle {
                                id: newsTile
                                required property var modelData
                                readonly property bool on: !!win.chosen[modelData.id]
                                Layout.fillWidth: true
                                Layout.preferredHeight: 62
                                radius: 14
                                color: on ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, win.dark ? 0.18 : 0.14) : win.tile
                                border.width: 1
                                border.color: on ? win.accent : win.line
                                Behavior on color { ColorAnimation { duration: 150 } }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 18
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 2
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.name; color: win.ink; font.family: "Inter"; font.weight: Font.DemiBold; font.pixelSize: 16 }
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.kind; color: win.inkDim; font.family: "Inter"; font.pixelSize: 13 }
                                    }
                                    // Switch.
                                    Rectangle {
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                        Layout.preferredWidth: 44
                                        Layout.preferredHeight: 24
                                        radius: 12
                                        color: newsTile.on ? win.accent : win.line
                                        Rectangle {
                                            width: 18; height: 18; radius: 9
                                            y: 3
                                            x: newsTile.on ? 23 : 3
                                            color: newsTile.on ? win.onAccent : win.inkDim
                                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var copy = Object.assign({}, win.chosen)
                                        copy[modelData.id] = !copy[modelData.id]
                                        win.chosen = copy
                                    }
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Page {
                index: 4
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: "Aplicações populares" }
                    Body { text: "Instale com um clique a partir do Flathub. Cada uma abre no Discover, onde vê os detalhes antes de instalar." }
                    GridLayout {
                        Layout.topMargin: 20
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: 14
                        rowSpacing: 14
                        Repeater {
                            model: [
                                { name: "Spotify", icon: "spotify", id: "com.spotify.Client" },
                                { name: "Visual Studio Code", icon: "visual-studio-code", id: "com.visualstudio.code" },
                                { name: "Steam", icon: "steam", id: "com.valvesoftware.Steam" },
                                { name: "Discord", icon: "discord", id: "com.discordapp.Discord" },
                                { name: "GIMP", icon: "gimp", id: "org.gimp.GIMP" },
                                { name: "OBS Studio", icon: "obs", id: "com.obsproject.Studio" },
                                { name: "Telegram", icon: "telegram", id: "org.telegram.desktop" },
                                { name: "Google Chrome", icon: "google-chrome", id: "com.google.Chrome" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 128
                                radius: 16
                                color: appArea.containsMouse ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, win.dark ? 0.18 : 0.14) : win.tile
                                border.width: 1
                                border.color: appArea.containsMouse ? win.accent : win.line
                                Behavior on color { ColorAnimation { duration: 150 } }
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: parent.width - 20
                                    spacing: 10
                                    Kirigami.Icon {
                                        Layout.alignment: Qt.AlignHCenter
                                        source: modelData.icon
                                        implicitWidth: 52
                                        implicitHeight: 52
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: modelData.name
                                        color: win.ink
                                        font.family: "Inter"
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 14
                                    }
                                }
                                MouseArea {
                                    id: appArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shell.run("plasma-discover appstream://" + modelData.id)
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Page {
                index: 5
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: "Tudo pronto" }
                    Body { text: "Três atalhos para começar:" }
                    ColumnLayout {
                        Layout.topMargin: 26
                        spacing: 16
                        Repeater {
                            model: [
                                { keys: ["Super"], what: "Abre o menu de aplicações" },
                                { keys: ["Super", "W"], what: "Mostra todas as janelas e áreas de trabalho" },
                                { keys: ["Alt", "Espaço"], what: "Procura aplicações, ficheiros e definições" }
                            ]
                            delegate: RowLayout {
                                required property var modelData
                                spacing: 10
                                Repeater {
                                    model: modelData.keys
                                    delegate: Rectangle {
                                        required property string modelData
                                        implicitWidth: Math.max(46, keyLabel.implicitWidth + 26)
                                        implicitHeight: 38
                                        radius: 9
                                        color: win.tile
                                        border.color: win.line
                                        Text {
                                            id: keyLabel
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: win.ink
                                            font.family: "Inter"
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 15
                                        }
                                    }
                                }
                                Text {
                                    Layout.leftMargin: 12
                                    text: modelData.what
                                    color: win.ink
                                    font.family: "Inter"
                                    font.pixelSize: 17
                                }
                            }
                        }
                    }
                    Body {
                        Layout.topMargin: 26
                        text: win.chosenIds().length > 0
                              ? "As notícias que escolheu aparecem no painel à direita do ambiente de trabalho."
                              : "Pode escolher fontes de notícias quando quiser, no painel à direita do ambiente de trabalho."
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ---- Footer: progress dots and navigation ----
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 64
            anchors.rightMargin: 40
            anchors.bottomMargin: 36
            spacing: 12

            Row {
                spacing: 8
                Repeater {
                    model: win.pages.length
                    delegate: Rectangle {
                        required property int index
                        width: index === win.page ? 26 : 8
                        height: 8
                        radius: 4
                        color: index === win.page ? win.accent : win.line
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                visible: win.page > 0
                secondary: true
                label: "Voltar"
                onActivated: win.page--
            }
            Button {
                label: win.page === 0 ? "Começar" : win.page === win.pages.length - 1 ? "Começar a usar" : "Continuar"
                onActivated: win.page === win.pages.length - 1 ? win.finish() : win.page++
            }
        }
    }

    // ---- Small building blocks ----
    component Page: Item {
        required property int index
        anchors.fill: parent
        opacity: index === win.page ? 1 : 0
        visible: opacity > 0
        transform: Translate { x: (index - win.page) * 40 }
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    component Title: Text {
        color: win.ink
        font.family: "Inter Display"
        font.weight: Font.Light
        font.pixelSize: 38
    }

    component Body: Text {
        Layout.fillWidth: true
        color: win.inkDim
        wrapMode: Text.WordWrap
        font.family: "Inter"
        font.pixelSize: 17
        lineHeight: 1.25
    }

    component Button: Rectangle {
        id: button
        property string label
        property bool secondary: false
        signal activated()
        implicitWidth: buttonLabel.implicitWidth + 44
        implicitHeight: 44
        radius: 22
        color: secondary ? (buttonArea.containsMouse ? win.tile : "transparent")
                         : (buttonArea.containsMouse ? Qt.lighter(win.accent, 1.08) : win.accent)
        border.width: secondary ? 1 : 0
        border.color: win.line
        scale: buttonArea.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: button.label
            color: button.secondary ? win.ink : win.onAccent
            font.family: "Inter"
            font.weight: Font.DemiBold
            font.pixelSize: 15
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }
}
