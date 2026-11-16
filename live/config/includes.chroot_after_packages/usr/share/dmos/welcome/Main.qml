import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import "file:///usr/share/plasma/plasmoids/org.dmos.hub/contents/code/sources.js" as Sources

// "Bem-vindo ao DMOS": first-run setup in a few short pages.
// Portuguese by default; any other session language gets English.
Window {
    id: win
    width: 1040
    height: 700
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Window
    title: t("Bem-vindo ao DMOS", "Welcome to DMOS")

    readonly property var pages: ["inicio", "aparencia", "personalizar", "ligacao", "noticias", "aplicacoes", "pronto"]
    property int page: 0
    property bool dark: true
    property bool live: false
    property string network: "unknown"
    property var chosen: ({})
    property string accentId: "mare"
    property string wallpaperId: "mare"

    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0
    function t(portuguese, english) { return pt ? portuguese : english }

    readonly property var accents: [
        { id: "mare", name: "Maré", en: "Tide", color: dark ? "#2DD4BF" : "#0E8F88" },
        { id: "coral", name: "Coral", en: "Coral", color: "#FF7A66" },
        { id: "azul", name: "Azul", en: "Blue", color: "#4C9BFF" },
        { id: "violeta", name: "Violeta", en: "Violet", color: "#A78BFA" },
        { id: "verde", name: "Verde", en: "Green", color: "#3FCF7A" },
        { id: "ambar", name: "Âmbar", en: "Amber", color: "#F5B14C" }
    ]
    readonly property var wallpapers: [
        { id: "mare", name: "Maré", en: "Tide", pkg: "/usr/share/wallpapers/DMOS-Mare",
          image: "/usr/share/wallpapers/DMOS-Mare/contents/" + (dark ? "images_dark" : "images") + "/3840x2160.jpg" },
        { id: "aurora", name: "Aurora", en: "Aurora", pkg: "/usr/share/wallpapers/DMOS-Aurora",
          image: "/usr/share/wallpapers/DMOS-Aurora/contents/images/3840x2160.jpg" },
        { id: "ambar", name: "Âmbar", en: "Amber", pkg: "/usr/share/wallpapers/DMOS-Ambar",
          image: "/usr/share/wallpapers/DMOS-Ambar/contents/images/3840x2160.jpg" }
    ]
    function byId(list, id) {
        for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
        return list[0]
    }

    // Palette follows the chosen look, so the choice is visible straight away.
    readonly property color ink: dark ? "#F5F7FC" : "#1A2238"
    readonly property color inkDim: dark ? "#A8B2C9" : "#5B6580"
    readonly property color glass: dark ? Qt.rgba(0.04, 0.06, 0.13, 0.72) : Qt.rgba(0.97, 0.98, 1.0, 0.74)
    readonly property color line: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0.1, 0.13, 0.22, 0.10)
    readonly property color tile: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.65)
    readonly property color accent: byId(accents, accentId).color
    // Dark text on bright accents, white on deep ones. (Not "onAccent": QML reads a name
    // of that shape as a signal handler, and the colour silently stays black.)
    readonly property color accentText: (0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b) > 0.55 ? "#0B1020" : "#FFFFFF"
    readonly property string wallpaper: "file://" + byId(wallpapers, wallpaperId).image

    function chosenIds() {
        return Sources.list.filter(function (s) { return chosen[s.id] }).map(function (s) { return s.id })
    }

    function applyTheme(isDark) {
        dark = isDark
        // The global theme brings its own accent back, so the choice below starts over.
        accentId = "mare"
        shell.run("plasma-apply-lookandfeel --apply " + (isDark ? "org.dmos.mare.dark" : "org.dmos.mare.light")
                  + "; kwriteconfig6 --file dmosrc --group Appearance --key Accent mare")
    }
    function applyAccent(entry) {
        accentId = entry.id
        shell.run("dmos-accent " + (entry.id === "mare" ? "default" : "'" + entry.color + "'")
                  + "; kwriteconfig6 --file dmosrc --group Appearance --key Accent " + entry.id)
    }
    function applyWallpaper(entry) {
        wallpaperId = entry.id
        shell.run("plasma-apply-wallpaperimage " + entry.pkg
                  + "; kwriteconfig6 --file dmosrc --group Appearance --key Wallpaper " + entry.id)
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
            } else if (source.indexOf("kreadconfig6 --file dmosrc --group Appearance --key Accent") === 0) {
                if (out) win.accentId = win.byId(win.accents, out).id
            } else if (source.indexOf("kreadconfig6 --file dmosrc --group Appearance --key Wallpaper") === 0) {
                if (out) win.wallpaperId = win.byId(win.wallpapers, out).id
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
        shell.run("kreadconfig6 --file dmosrc --group Appearance --key Accent")
        shell.run("kreadconfig6 --file dmosrc --group Appearance --key Wallpaper")
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
        Qt.application.name = t("Bem-vindo ao DMOS", "Welcome to DMOS")
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
                name: "inicio"
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
                    Title { text: win.t("Bem-vindo ao DMOS", "Welcome to DMOS"); Layout.alignment: Qt.AlignHCenter; font.pixelSize: 44 }
                    Body {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: 560
                        text: win.live
                              ? win.t("Está a experimentar o DMOS sem alterar o seu computador. Em poucos passos fica com tudo a seu gosto, ou pode instalá-lo já.",
                                      "You are trying DMOS without changing your computer. A few steps make it yours, or you can install it right away.")
                              : win.t("Vamos deixar o sistema a seu gosto em poucos passos. Pode mudar tudo mais tarde nas Definições.",
                                      "A few steps make the system yours. You can change everything later in System Settings.")
                    }
                    Button {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 10
                        visible: win.live
                        secondary: true
                        label: win.t("Instalar o DMOS", "Install DMOS")
                        onActivated: shell.run("calamares-install-debian")
                    }
                }
            }

            Page {
                name: "aparencia"
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: win.t("Escolha o seu visual", "Choose your look") }
                    Body { text: win.t("O tema aplica-se de imediato a todo o sistema.", "The theme applies to the whole system at once.") }
                    RowLayout {
                        Layout.topMargin: 24
                        Layout.fillWidth: true
                        spacing: 28
                        Repeater {
                            model: [
                                { name: win.t("Escuro", "Dark"), note: win.t("Maré à noite", "Tide at night"), dark: true, image: "images_dark" },
                                { name: win.t("Claro", "Light"), note: win.t("Maré de manhã", "Tide in the morning"), dark: false, image: "images" }
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
                                        onClicked: win.applyTheme(modelData.dark)
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
                name: "personalizar"
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: win.t("Cor e fundo", "Colour and wallpaper") }
                    Body { text: win.t("Escolha o fundo do ambiente de trabalho e a cor de destaque. Aplicam-se de imediato.",
                                       "Pick the desktop wallpaper and the accent colour. Both apply at once.") }
                    RowLayout {
                        Layout.topMargin: 18
                        Layout.fillWidth: true
                        spacing: 20
                        Repeater {
                            model: win.wallpapers
                            delegate: Item {
                                id: wallTile
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: width * 0.5625 + 34
                                readonly property bool selected: win.wallpaperId === modelData.id
                                Rectangle {
                                    id: wallFrame
                                    width: parent.width
                                    height: width * 0.5625
                                    radius: 14
                                    color: "transparent"
                                    border.width: wallTile.selected ? 3 : 1
                                    border.color: wallTile.selected ? win.accent : win.line
                                    scale: wallArea.containsMouse ? 1.02 : 1
                                    Behavior on scale { NumberAnimation { duration: 140 } }
                                    Rectangle {
                                        id: wallMask
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        radius: 10
                                        visible: false
                                        layer.enabled: true
                                    }
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        source: "file://" + wallTile.modelData.image
                                        sourceSize: Qt.size(480, 270)
                                        fillMode: Image.PreserveAspectCrop
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: wallMask
                                        }
                                    }
                                    MouseArea {
                                        id: wallArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.applyWallpaper(wallTile.modelData)
                                    }
                                }
                                Text {
                                    anchors.top: wallFrame.bottom
                                    anchors.topMargin: 10
                                    text: win.pt ? wallTile.modelData.name : wallTile.modelData.en
                                    color: win.ink
                                    font.family: "Inter"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 15
                                }
                            }
                        }
                    }
                    Text {
                        Layout.topMargin: 14
                        text: win.t("Cor de destaque", "Accent colour")
                        color: win.ink
                        font.family: "Inter"
                        font.weight: Font.DemiBold
                        font.pixelSize: 16
                    }
                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 16
                        Repeater {
                            model: win.accents
                            delegate: Item {
                                id: dot
                                required property var modelData
                                readonly property bool selected: win.accentId === modelData.id
                                implicitWidth: 46
                                implicitHeight: 46
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: dot.selected ? 2 : 0
                                    border.color: win.ink
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 34; height: 34; radius: 17
                                    color: dot.modelData.color
                                    scale: dotArea.containsMouse ? 1.1 : 1
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    id: dotArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.applyAccent(dot.modelData)
                                }
                            }
                        }
                        Text {
                            Layout.leftMargin: 6
                            text: win.pt ? win.byId(win.accents, win.accentId).name : win.byId(win.accents, win.accentId).en
                            color: win.inkDim
                            font.family: "Inter"
                            font.pixelSize: 15
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Page {
                name: "ligacao"
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: win.t("Ligação à internet", "Internet connection") }
                    Body { text: win.t("Precisa dela para as notícias, as atualizações e para instalar aplicações.",
                                       "You need it for news, updates and installing apps.") }
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
                                    text: win.network === "connected" ? win.t("Está ligado à internet", "You are online")
                                        : win.network.indexOf("connected") === 0 ? win.t("Ligação limitada", "Limited connection")
                                        : win.network.indexOf("connecting") === 0 ? win.t("A ligar…", "Connecting…")
                                        : win.t("Sem ligação", "Offline")
                                    color: win.ink
                                    font.family: "Inter"
                                    font.weight: Font.DemiBold
                                    font.pixelSize: 20
                                }
                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: win.network === "connected"
                                          ? win.t("Pode continuar.", "You can go on.")
                                          : win.t("Ligue um cabo de rede ou escolha uma rede Wi-Fi.", "Plug in a network cable or pick a Wi-Fi network.")
                                    color: win.inkDim
                                    font.family: "Inter"
                                    font.pixelSize: 15
                                }
                            }
                            Button {
                                secondary: true
                                label: win.t("Redes Wi-Fi", "Wi-Fi networks")
                                onActivated: shell.run("kcmshell6 kcm_networkmanagement")
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            Page {
                name: "noticias"
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: win.t("As suas notícias", "Your news") }
                    Body { text: win.t("Escolha o que aparece no painel do ambiente de trabalho. Só as fontes que ligar são contactadas.",
                                       "Choose what shows in the desktop panel. Only the sources you turn on are contacted.") }
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
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: win.pt ? modelData.kind : modelData.kindEn; color: win.inkDim; font.family: "Inter"; font.pixelSize: 13 }
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
                                            color: newsTile.on ? win.accentText : win.inkDim
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
                name: "aplicacoes"
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: win.t("Aplicações populares", "Popular apps") }
                    Body { text: win.t("Instale com um clique a partir do Flathub. Cada uma abre no Discover, onde vê os detalhes antes de instalar.",
                                       "Install with one click from Flathub. Each one opens in Discover, where you see the details before installing.") }
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
                name: "pronto"
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    Title { text: win.t("Tudo pronto", "All set") }
                    Body { text: win.t("Quatro atalhos para começar:", "Four shortcuts to get started:") }
                    ColumnLayout {
                        Layout.topMargin: 20
                        spacing: 14
                        Repeater {
                            model: [
                                { keys: ["Super"], what: win.t("Abre o menu de aplicações", "Opens the application menu") },
                                { keys: ["Super", "A"], what: win.t("Mostra todas as aplicações em ecrã inteiro", "Shows every app, full screen") },
                                { keys: ["Super", "W"], what: win.t("Mostra todas as janelas e áreas de trabalho", "Shows all windows and desktops") },
                                { keys: ["Alt", win.t("Espaço", "Space")], what: win.t("Procura aplicações, ficheiros e definições", "Searches apps, files and settings") }
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
                        Layout.topMargin: 20
                        text: (win.chosenIds().length > 0
                               ? win.t("As notícias que escolheu aparecem no painel à direita do ambiente de trabalho.",
                                       "The news you chose shows in the panel on the right of the desktop.")
                               : win.t("Pode escolher fontes de notícias quando quiser, no painel à direita do ambiente de trabalho.",
                                       "You can pick news sources whenever you like, in the panel on the right of the desktop."))
                              + " " + win.t("Para pesquisar com inteligência artificial, abra a DMOS IA na dock.",
                                            "To research with artificial intelligence, open DMOS AI in the dock.")
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
                label: win.t("Voltar", "Back")
                onActivated: win.page--
            }
            Button {
                label: win.page === 0 ? win.t("Começar", "Start")
                     : win.page === win.pages.length - 1 ? win.t("Começar a usar", "Start using DMOS")
                     : win.t("Continuar", "Continue")
                onActivated: win.page === win.pages.length - 1 ? win.finish() : win.page++
            }
        }
    }

    // ---- Small building blocks ----
    component Page: Item {
        required property string name
        readonly property int index: win.pages.indexOf(name)
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
            color: button.secondary ? win.ink : win.accentText
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
