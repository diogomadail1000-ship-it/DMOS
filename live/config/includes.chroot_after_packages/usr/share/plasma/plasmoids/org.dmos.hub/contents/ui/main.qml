import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami
import "../code/sources.js" as Sources

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: fullRepresentation

    property var enabledSources: []
    property var news: []
    property bool loading: false
    property bool offline: false
    property date now: new Date()

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color dimColor: fade(Kirigami.Theme.textColor, 0.62)
    readonly property color accent: Kirigami.Theme.highlightColor

    function fade(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function greeting() {
        var h = now.getHours()
        var who = (kuser.fullName || kuser.loginName || "").split(" ")[0]
        var hello = h < 6 ? "Boa noite" : h < 12 ? "Bom dia" : h < 20 ? "Boa tarde" : "Boa noite"
        return who ? hello + ", " + who : hello
    }

    function ago(time) {
        if (!time) return ""
        var minutes = Math.max(1, Math.round((now.getTime() - time) / 60000))
        if (minutes < 60) return "há " + minutes + " min"
        var hours = Math.round(minutes / 60)
        if (hours < 24) return "há " + hours + " h"
        var days = Math.round(hours / 24)
        return days === 1 ? "ontem" : "há " + days + " dias"
    }

    // Fetches every enabled feed, merges them and keeps the most recent headlines.
    function refresh() {
        if (enabledSources.length === 0) {
            news = []
            return
        }
        loading = true
        var pending = enabledSources.length
        var perSource = []
        var failures = 0
        enabledSources.forEach(function (id) {
            var source = Sources.byId(id)
            if (!source) {
                pending--
                return
            }
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 200) {
                    var items = Sources.parse(xhr.responseText, source)
                    items.sort(function (a, b) { return b.time - a.time })
                    if (items.length > 0) perSource.push(items)
                } else {
                    failures++
                }
                if (--pending === 0) {
                    // Round-robin, so one busy source cannot fill the whole list.
                    var merged = []
                    for (var round = 0; merged.length < 8 && round < 6; round++) {
                        perSource.forEach(function (list) {
                            if (round < list.length && merged.length < 8) merged.push(list[round])
                        })
                    }
                    news = merged
                    offline = failures === enabledSources.length
                    loading = false
                }
            }
            xhr.open("GET", source.url)
            xhr.send()
        })
    }

    KCoreAddons.KUser { id: kuser }

    // The welcome app writes the chosen sources to ~/.config/dmosrc.
    P5Support.DataSource {
        id: shell
        engine: "executable"
        onNewData: function (source, data) {
            disconnectSource(source)
            if (source.indexOf("kreadconfig6") === 0) {
                var ids = data.stdout.trim().split(",").filter(function (s) { return s.length > 0 })
                if (ids.join(",") !== root.enabledSources.join(",")) {
                    root.enabledSources = ids
                    root.refresh()
                }
            }
        }
        function run(command) { connectSource(command) }
    }

    function readSources() {
        shell.run("kreadconfig6 --file dmosrc --group News --key Sources")
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root.now = new Date()
    }
    Timer {
        // Picks up a new choice from the welcome app quickly; feeds refresh less often.
        interval: 15000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.readSources()
    }
    Timer {
        interval: 20 * 60 * 1000; running: true; repeat: true
        onTriggered: root.refresh()
    }

    fullRepresentation: Item {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 34
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.minimumHeight: Kirigami.Units.gridUnit * 20

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: 0

            Text {
                text: Qt.formatTime(root.now, "HH:mm")
                color: root.textColor
                font.family: "Inter Display"
                font.weight: Font.Light
                font.pixelSize: Kirigami.Units.gridUnit * 4.4
                font.letterSpacing: -2
            }
            Text {
                Layout.fillWidth: true
                text: Qt.locale().toString(root.now, Qt.locale().name.indexOf("pt") === 0 ? "dddd, d 'de' MMMM" : "dddd, d MMMM")
                color: root.dimColor
                font.family: "Inter"
                font.pixelSize: Kirigami.Units.gridUnit * 1.0
            }
            Text {
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.fillWidth: true
                text: root.greeting()
                color: root.textColor
                font.family: "Inter"
                font.weight: Font.DemiBold
                font.pixelSize: Kirigami.Units.gridUnit * 1.35
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing * 1.5
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                height: 1
                color: root.fade(root.textColor, 0.12)
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Notícias"
                    color: root.textColor
                    font.family: "Inter"
                    font.weight: Font.DemiBold
                    font.pixelSize: Kirigami.Units.gridUnit * 1.0
                }
                Kirigami.Icon {
                    visible: root.enabledSources.length > 0
                    source: "view-refresh"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    opacity: refreshArea.containsMouse ? 1 : 0.6
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 900
                        loops: Animation.Infinite
                        running: root.loading
                        onRunningChanged: if (!running) parent.rotation = 0
                    }
                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: root.refresh()
                    }
                }
            }

            // Headlines.
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                clip: true
                visible: root.news.length > 0
                model: root.news
                spacing: Kirigami.Units.smallSpacing
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: column.implicitHeight + Kirigami.Units.largeSpacing * 1.4
                    radius: 10
                    color: area.containsMouse ? root.fade(root.textColor, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    ColumnLayout {
                        id: column
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Kirigami.Units.largeSpacing * 0.7
                        spacing: 3
                        Text {
                            Layout.fillWidth: true
                            text: modelData.source.toUpperCase() + (modelData.time ? "  ·  " + root.ago(modelData.time) : "")
                            color: root.accent
                            font.family: "Inter"
                            font.weight: Font.DemiBold
                            font.pixelSize: Kirigami.Units.gridUnit * 0.66
                            font.letterSpacing: 0.6
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: root.textColor
                            font.family: "Inter"
                            font.pixelSize: Kirigami.Units.gridUnit * 0.92
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally(modelData.link)
                    }
                }
            }

            // No sources yet, still loading, or no network.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.news.length === 0
                spacing: Kirigami.Units.largeSpacing
                Item { Layout.fillHeight: true }
                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    source: root.offline ? "network-offline" : "akregator"
                    implicitWidth: Kirigami.Units.iconSizes.large
                    implicitHeight: implicitWidth
                    opacity: 0.8
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: root.dimColor
                    font.family: "Inter"
                    font.pixelSize: Kirigami.Units.gridUnit * 0.9
                    text: root.enabledSources.length === 0
                          ? "Escolha as fontes de notícias que quer ver aqui. Só essas são contactadas."
                          : root.offline ? "Sem ligação à internet." : "A carregar as notícias…"
                }
                Rectangle {
                    visible: root.enabledSources.length === 0
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: chooseLabel.implicitWidth + Kirigami.Units.gridUnit * 2
                    implicitHeight: Kirigami.Units.gridUnit * 2
                    radius: height / 2
                    color: chooseArea.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                    Text {
                        id: chooseLabel
                        anchors.centerIn: parent
                        text: "Escolher fontes"
                        color: Kirigami.Theme.highlightedTextColor
                        font.family: "Inter"
                        font.weight: Font.DemiBold
                        font.pixelSize: Kirigami.Units.gridUnit * 0.85
                    }
                    MouseArea {
                        id: chooseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.run("dmos-welcome --page noticias")
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
