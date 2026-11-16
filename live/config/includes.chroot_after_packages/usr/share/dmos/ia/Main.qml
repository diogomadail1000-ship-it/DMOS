import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami

// DMOS IA: ask a question, get an answer with its sources. The work is done by dmos_ia.py,
// reached here as "backend". Portuguese by default; any other session language gets English.
Window {
    id: win
    width: 960
    height: 760
    minimumWidth: 640
    minimumHeight: 540
    visible: true
    title: t("DMOS IA", "DMOS AI")
    color: pal.window

    SystemPalette { id: pal }

    readonly property bool pt: Qt.locale().name.indexOf("pt") === 0
    function t(portuguese, english) { return pt ? portuguese : english }

    // Colours come from the desktop theme, so the window follows light, dark and the accent.
    readonly property color ink: pal.windowText
    readonly property color inkDim: Qt.rgba(ink.r, ink.g, ink.b, 0.64)
    readonly property color line: Qt.rgba(ink.r, ink.g, ink.b, 0.13)
    readonly property color tile: Qt.rgba(ink.r, ink.g, ink.b, 0.06)
    readonly property color accent: pal.highlight
    // Not "onAccent": QML reads a name of that shape as a signal handler.
    readonly property color accentText: pal.highlightedText
    readonly property real column: Math.min(width - 56, 780)

    readonly property var models: [
        { id: "claude-opus-5-5", name: "Claude Opus 5.5",
          note: t("O mais capaz. Recomendado para pesquisas.", "The most capable. Recommended for research.") },
        { id: "claude-sonnet-5-5", name: "Claude Sonnet 5.5",
          note: t("Equilíbrio entre qualidade, rapidez e custo.", "A balance of quality, speed and cost.") },
        { id: "claude-haiku-5-5", name: "Claude Haiku 5.5",
          note: t("O mais rápido e económico.", "The fastest and cheapest.") }
    ]
    function modelName(id) {
        for (var i = 0; i < models.length; i++) if (models[i].id === id) return models[i].name
        return id
    }

    property bool settingsOpen: false
    property string keyProblem: ""

    function openLink(url) {
        if (/^https?:\/\//i.test(url)) Qt.openUrlExternally(url)
    }

    function entry(who, body) {
        return { who: who, body: body, status: who === "ai" ? "thinking" : "", detail: "", sources: "[]",
                 cited: true, note: "", served: "", problem: "", problemDetail: "", done: who !== "ai" }
    }
    function send(text) {
        text = text.trim()
        if (!text || backend.busy || !backend.hasKey) return false
        chat.append(entry("user", text))
        backend.ask(text)
        return true
    }
    function submit() {
        if (send(input.text)) input.text = ""
    }
    function retry(index) {
        // The failed answer and its question leave the list, and the question is asked again.
        var question = chat.get(index - 1).body
        chat.remove(index - 1, 2)
        send(question)
    }
    function setLast(name, value) {
        if (chat.count > 0 && chat.get(chat.count - 1).who === "ai") chat.setProperty(chat.count - 1, name, value)
    }

    function noteText(note) {
        return note === "cut" ? t("A resposta ficou incompleta por ser muito longa. Peça para continuar.",
                                  "The answer was cut short for being too long. Ask it to continue.")
             : note === "refused" ? t("O Claude não respondeu a este pedido.", "Claude did not answer this request.")
             : note === "stopped" ? t("Resposta interrompida.", "Answer stopped.")
             : ""
    }
    function problemText(code, detail) {
        return code === "auth" ? t("A Anthropic não aceitou a sua chave. Pode ter sido revogada: indique uma nova nas definições.",
                                   "Anthropic did not accept your key. It may have been revoked: enter a new one in the settings.")
             : code === "credit" ? t("A sua conta na Anthropic não tem saldo. Carregue-a em platform.claude.com e tente de novo.",
                                     "Your Anthropic account has no credit. Top it up at platform.claude.com and try again.")
             : code === "rate" ? t("Demasiados pedidos em pouco tempo. Aguarde um momento e tente de novo.",
                                   "Too many requests in a short time. Wait a moment and try again.")
             : code === "network" ? t("Sem ligação à internet, ou a Anthropic não respondeu.",
                                      "No internet connection, or Anthropic did not respond.")
             : code === "overloaded" ? t("O serviço do Claude está sobrecarregado. Tente de novo daqui a pouco.",
                                         "The Claude service is overloaded. Try again in a little while.")
             : code === "model" ? t("Este modelo não está disponível para a sua chave. Escolha outro nas definições.",
                                    "This model is not available for your key. Pick another one in the settings.")
             : t("Algo correu mal: ", "Something went wrong: ") + detail
    }
    function keyProblemText(why) {
        return why === "" ? ""
             : why === "empty" ? t("Cole a chave no campo acima.", "Paste the key in the field above.")
             : why === "invalid" ? t("A Anthropic não reconhece esta chave. Confirme que a copiou inteira.",
                                     "Anthropic does not recognise this key. Check that you copied all of it.")
             : why === "network" ? t("Sem ligação à internet: não foi possível verificar a chave.",
                                     "No internet connection: the key could not be checked.")
             : t("Não foi possível guardar a chave: ", "The key could not be saved: ") + why.replace("storage:", "")
    }

    ListModel { id: chat }

    Connections {
        target: backend
        function onAnswerStarted() {
            chat.append(win.entry("ai", ""))
            view.follow = true
        }
        function onAnswerText(richText) { win.setLast("body", richText) }
        function onAnswerStatus(kind, detail) {
            win.setLast("status", kind)
            win.setLast("detail", detail)
        }
        function onAnswerSources(list, cited) {
            win.setLast("sources", JSON.stringify(list))
            win.setLast("cited", cited)
        }
        function onAnswerFinished(note, served) {
            win.setLast("note", note)
            win.setLast("served", served)
            win.setLast("done", true)
        }
        function onAnswerFailed(code, detail) {
            win.setLast("problem", code)
            win.setLast("problemDetail", detail)
            win.setLast("done", true)
        }
        function onConversationCleared() { chat.clear() }
        function onKeyRejected(why) { win.keyProblem = why }
        function onHasKeyChanged() {
            win.keyProblem = ""
            keyField.text = ""
            if (backend.hasKey) {
                input.forceActiveFocus()
                // A question that came with the launch (from the Hub) was waiting for the key.
                win.submit()
            }
        }
    }

    Component.onCompleted: {
        if (firstQuestion && !send(firstQuestion)) input.text = firstQuestion
        if (backend.hasKey) input.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Top bar ----
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 14
            Layout.topMargin: 12
            Layout.bottomMargin: 6
            spacing: 10
            Kirigami.Icon { source: "dmos-ia"; implicitWidth: 30; implicitHeight: 30 }
            Text {
                text: win.title
                color: win.ink
                font.family: "Inter"
                font.weight: Font.DemiBold
                font.pixelSize: 17
            }
            Rectangle {
                visible: backend.hasKey
                implicitWidth: modelLabel.implicitWidth + 22
                implicitHeight: 26
                radius: 13
                color: modelArea.containsMouse ? win.line : win.tile
                Text {
                    id: modelLabel
                    anchors.centerIn: parent
                    text: win.modelName(backend.model)
                    color: win.inkDim
                    font.family: "Inter"
                    font.pixelSize: 12
                }
                MouseArea {
                    id: modelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.settingsOpen = true
                }
            }
            Item { Layout.fillWidth: true }
            Pill {
                visible: chat.count > 0
                secondary: true
                compact: true
                label: win.t("Nova conversa", "New conversation")
                onActivated: backend.newConversation()
            }
            Rectangle {
                visible: backend.hasKey
                implicitWidth: 36; implicitHeight: 36; radius: 18
                color: gearArea.containsMouse ? win.tile : "transparent"
                Kirigami.Icon { anchors.centerIn: parent; source: "configure"; width: 20; height: 20 }
                MouseArea {
                    id: gearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.settingsOpen = true
                }
            }
        }

        // ---- Middle: connect a key, an empty conversation, or the conversation ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // No key yet.
            ColumnLayout {
                visible: !backend.hasKey
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 600)
                spacing: 14
                Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; source: "dmos-ia"; implicitWidth: 84; implicitHeight: 84 }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: win.t("Ligue a DMOS IA ao Claude", "Connect DMOS AI to Claude")
                    color: win.ink
                    font.family: "Inter Display"
                    font.weight: Font.Light
                    font.pixelSize: 34
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.25
                    text: win.t("A DMOS IA usa o Claude, da Anthropic, para pesquisar na web e responder com as fontes. Precisa de uma chave da API da Anthropic: é sua, e paga apenas o que usar.",
                                "DMOS AI uses Claude, by Anthropic, to search the web and answer with sources. You need an Anthropic API key: it is yours, and you pay only for what you use.")
                    color: win.inkDim
                    font.family: "Inter"
                    font.pixelSize: 15
                }
                Rectangle {
                    Layout.topMargin: 10
                    Layout.fillWidth: true
                    implicitHeight: steps.implicitHeight + 40
                    radius: 18
                    color: win.tile
                    border.color: win.line
                    ColumnLayout {
                        id: steps
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 20
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: win.t("1.  Crie uma conta e uma chave em platform.claude.com",
                                            "1.  Create an account and a key at platform.claude.com")
                                color: win.ink
                                font.family: "Inter"
                                font.pixelSize: 15
                            }
                            Pill {
                                secondary: true
                                compact: true
                                label: win.t("Abrir a página", "Open the page")
                                onActivated: win.openLink("https://platform.claude.com/settings/keys")
                            }
                        }
                        Text {
                            text: win.t("2.  Cole a chave aqui", "2.  Paste the key here")
                            color: win.ink
                            font.family: "Inter"
                            font.pixelSize: 15
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 44
                                radius: 22
                                color: pal.base
                                border.width: keyField.activeFocus ? 2 : 1
                                border.color: keyField.activeFocus ? win.accent : win.line
                                TextInput {
                                    id: keyField
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 18
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    echoMode: TextInput.Password
                                    selectByMouse: true
                                    color: pal.text
                                    selectionColor: win.accent
                                    selectedTextColor: win.accentText
                                    font.family: "Inter"
                                    font.pixelSize: 15
                                    onTextEdited: win.keyProblem = ""
                                    onAccepted: backend.saveKey(text)
                                }
                                Text {
                                    anchors.fill: keyField
                                    verticalAlignment: Text.AlignVCenter
                                    visible: keyField.text.length === 0
                                    text: "sk-ant-…"
                                    color: win.inkDim
                                    font: keyField.font
                                }
                            }
                            Pill {
                                enabled: !backend.checkingKey
                                label: backend.checkingKey ? win.t("A verificar…", "Checking…") : win.t("Guardar", "Save")
                                onActivated: backend.saveKey(keyField.text)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: win.keyProblem !== ""
                            wrapMode: Text.WordWrap
                            text: win.keyProblemText(win.keyProblem)
                            // Light text means a dark theme.
                            color: win.ink.hslLightness > 0.5 ? "#FF8A70" : "#B3261E"
                            font.family: "Inter"
                            font.pixelSize: 14
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                    text: win.t("A chave fica guardada só neste computador e é enviada apenas à Anthropic. As perguntas que fizer também seguem para a Anthropic, para serem respondidas.",
                                "The key is stored on this computer only and is sent to Anthropic alone. The questions you ask also go to Anthropic, to be answered.")
                    color: win.inkDim
                    font.family: "Inter"
                    font.pixelSize: 13
                }
            }

            // Nothing asked yet.
            ColumnLayout {
                visible: backend.hasKey && chat.count === 0
                anchors.centerIn: parent
                width: win.column
                spacing: 12
                Kirigami.Icon { Layout.alignment: Qt.AlignHCenter; source: "dmos-ia"; implicitWidth: 76; implicitHeight: 76 }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: win.t("O que quer saber?", "What would you like to know?")
                    color: win.ink
                    font.family: "Inter Display"
                    font.weight: Font.Light
                    font.pixelSize: 38
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: win.t("Pergunte por palavras suas. A resposta traz as páginas em que se baseia.",
                                "Ask in your own words. The answer comes with the pages it is based on.")
                    color: win.inkDim
                    font.family: "Inter"
                    font.pixelSize: 16
                }
                GridLayout {
                    Layout.topMargin: 16
                    Layout.fillWidth: true
                    columns: win.column > 600 ? 2 : 1
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: win.pt
                               ? ["Quais são as notícias de tecnologia de hoje?", "O que mudou no Debian 13?",
                                  "Compara o Firefox e o Chrome em privacidade", "Explica-me o que é um Flatpak"]
                               : ["What is today's technology news?", "What changed in Debian 13?",
                                  "Compare Firefox and Chrome on privacy", "Explain what a Flatpak is"]
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 46
                            radius: 14
                            color: chipArea.containsMouse ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.16) : win.tile
                            border.color: chipArea.containsMouse ? win.accent : win.line
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: chip.modelData
                                color: win.ink
                                font.family: "Inter"
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.send(chip.modelData)
                            }
                        }
                    }
                }
            }

            // The conversation.
            ListView {
                id: view
                anchors.fill: parent
                visible: backend.hasKey && chat.count > 0
                clip: true
                model: chat
                spacing: 22
                topMargin: 14
                bottomMargin: 18
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 4000
                QQC.ScrollBar.vertical: QQC.ScrollBar {}

                // Follows the answer as it grows, until the reader scrolls away from the end.
                property bool follow: true
                onContentHeightChanged: if (follow) Qt.callLater(positionViewAtEnd)
                onMovingChanged: if (!moving) follow = atYEnd

                delegate: Item {
                    id: row
                    required property int index
                    required property string who
                    required property string body
                    required property string status
                    required property string detail
                    required property string sources
                    required property bool cited
                    required property string note
                    required property string served
                    required property string problem
                    required property string problemDetail
                    required property bool done
                    readonly property var pages: JSON.parse(sources)
                    readonly property real gutter: (view.width - win.column) / 2

                    width: view.width
                    height: who === "user" ? bubble.height : answer.height

                    // A question.
                    Rectangle {
                        id: bubble
                        visible: row.who === "user"
                        x: row.gutter + win.column - width
                        width: Math.min(question.implicitWidth + 36, win.column * 0.82)
                        height: question.contentHeight + 24
                        radius: 18
                        color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.18)
                        TextEdit {
                            id: question
                            x: 18
                            y: 12
                            width: bubble.width - 36
                            text: row.who === "user" ? row.body : ""
                            textFormat: TextEdit.PlainText
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            color: win.ink
                            selectionColor: win.accent
                            selectedTextColor: win.accentText
                            font.family: "Inter"
                            font.pixelSize: 15
                        }
                    }

                    // An answer.
                    Column {
                        id: answer
                        visible: row.who === "ai"
                        x: row.gutter
                        width: win.column
                        spacing: 12

                        TextEdit {
                            width: parent.width
                            visible: row.body.length > 0
                            text: row.who === "ai" ? row.body : ""
                            textFormat: TextEdit.RichText
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            color: win.ink
                            selectionColor: win.accent
                            selectedTextColor: win.accentText
                            font.family: "Inter"
                            font.pixelSize: 15
                            onLinkActivated: function (link) { win.openLink(link) }
                            HoverHandler {
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
                            }
                        }

                        // What is going on while the answer is not there yet.
                        Row {
                            id: working
                            visible: !row.done && row.status !== "writing"
                            spacing: 10
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        required property int index
                                        width: 7; height: 7; radius: 3.5
                                        color: win.accent
                                        opacity: 0.3
                                        SequentialAnimation on opacity {
                                            loops: Animation.Infinite
                                            running: working.visible
                                            PauseAnimation { duration: index * 160 }
                                            NumberAnimation { to: 1; duration: 320 }
                                            NumberAnimation { to: 0.3; duration: 320 }
                                            PauseAnimation { duration: (2 - index) * 160 }
                                        }
                                    }
                                }
                            }
                            Text {
                                width: Math.min(implicitWidth, win.column - 60)
                                elide: Text.ElideRight
                                text: row.status === "searching"
                                      ? (row.detail ? win.t("A pesquisar: ", "Searching: ") + row.detail
                                                    : win.t("A pesquisar na web…", "Searching the web…"))
                                      : win.t("A pensar…", "Thinking…")
                                color: win.inkDim
                                font.family: "Inter"
                                font.pixelSize: 14
                            }
                        }

                        // The pages behind the answer.
                        Text {
                            visible: row.pages.length > 0
                            text: row.cited ? win.t("Fontes", "Sources") : win.t("Páginas consultadas", "Pages consulted")
                            color: win.inkDim
                            font.family: "Inter"
                            font.weight: Font.DemiBold
                            font.pixelSize: 12
                            font.letterSpacing: 0.6
                            font.capitalization: Font.AllUppercase
                        }
                        Flow {
                            visible: row.pages.length > 0
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: row.pages
                                delegate: Rectangle {
                                    id: page
                                    required property var modelData
                                    width: Math.min(pageRow.implicitWidth + 24, 330)
                                    height: 46
                                    radius: 12
                                    color: pageArea.containsMouse ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.14) : win.tile
                                    border.color: pageArea.containsMouse ? win.accent : win.line
                                    RowLayout {
                                        id: pageRow
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10
                                        Text {
                                            visible: page.modelData.n > 0
                                            text: page.modelData.n
                                            color: win.accent
                                            font.family: "Inter"
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 14
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: 1
                                            Text {
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: page.modelData.title
                                                color: win.ink
                                                font.family: "Inter"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                                text: page.modelData.host
                                                color: win.inkDim
                                                font.family: "Inter"
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: pageArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.openLink(page.modelData.url)
                                    }
                                }
                            }
                        }

                        Text {
                            visible: text.length > 0
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: [win.noteText(row.note),
                                   row.served ? win.t("Respondeu outro modelo do Claude: ", "Another Claude model answered: ") + row.served : ""]
                                  .filter(function (s) { return s.length > 0 }).join("  ·  ")
                            color: win.inkDim
                            font.family: "Inter"
                            font.italic: true
                            font.pixelSize: 13
                        }

                        // Something went wrong.
                        Rectangle {
                            visible: row.problem !== ""
                            width: parent.width
                            height: problemRow.implicitHeight + 28
                            radius: 14
                            color: Qt.rgba(1, 0.42, 0.36, 0.12)
                            border.color: Qt.rgba(1, 0.42, 0.36, 0.5)
                            RowLayout {
                                id: problemRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 16
                                spacing: 14
                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: win.problemText(row.problem, row.problemDetail)
                                    color: win.ink
                                    font.family: "Inter"
                                    font.pixelSize: 14
                                }
                                Pill {
                                    secondary: true
                                    compact: true
                                    visible: row.index === chat.count - 1
                                    label: row.problem === "auth" || row.problem === "model"
                                           ? win.t("Definições", "Settings") : win.t("Tentar de novo", "Try again")
                                    onActivated: row.problem === "auth" || row.problem === "model"
                                                 ? win.settingsOpen = true : win.retry(row.index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- Question box ----
        Rectangle {
            visible: backend.hasKey
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: win.column
            Layout.preferredHeight: Math.min(Math.max(54, input.contentHeight + 32), 170)
            Layout.topMargin: 6
            radius: 27
            color: pal.base
            border.width: input.activeFocus ? 2 : 1
            border.color: input.activeFocus ? win.accent : win.line

            Flickable {
                id: inputFlick
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 62
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                contentHeight: input.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: input
                    width: inputFlick.width
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    color: pal.text
                    selectionColor: win.accent
                    selectedTextColor: win.accentText
                    font.family: "Inter"
                    font.pixelSize: 15
                    // Enter sends; Shift+Enter starts a new line.
                    Keys.onPressed: function (event) {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            event.accepted = true
                            win.submit()
                        }
                    }
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y < inputFlick.contentY) inputFlick.contentY = cursorRectangle.y
                        else if (cursorRectangle.y + cursorRectangle.height > inputFlick.contentY + inputFlick.height)
                            inputFlick.contentY = cursorRectangle.y + cursorRectangle.height - inputFlick.height
                    }
                }
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0 && !input.inputMethodComposing
                text: win.t("Pergunte qualquer coisa…", "Ask anything…")
                color: win.inkDim
                font: input.font
            }
            // Send, or stop while an answer is on its way.
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                width: 38; height: 38; radius: 19
                readonly property bool usable: backend.busy || input.text.trim().length > 0
                color: !usable ? win.tile : sendArea.containsMouse ? Qt.lighter(win.accent, 1.1) : win.accent
                Rectangle {
                    visible: backend.busy
                    anchors.centerIn: parent
                    width: 12; height: 12; radius: 3
                    color: win.accentText
                }
                Text {
                    visible: !backend.busy
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: "↑"
                    color: parent.usable ? win.accentText : win.inkDim
                    font.family: "Inter"
                    font.weight: Font.DemiBold
                    font.pixelSize: 20
                }
                MouseArea {
                    id: sendArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: backend.busy ? backend.stop() : win.submit()
                }
            }
        }
        Text {
            visible: backend.hasKey
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.bottomMargin: 12
            horizontalAlignment: Text.AlignHCenter
            text: win.t("A IA pode errar. Confirme nas fontes o que for importante.",
                        "AI can be wrong. Check the sources for anything important.")
            color: win.inkDim
            font.family: "Inter"
            font.pixelSize: 12
        }
        Item { visible: !backend.hasKey; Layout.preferredHeight: 20 }
    }

    // ---- Settings ----
    Rectangle {
        anchors.fill: parent
        visible: win.settingsOpen
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: win.settingsOpen = false
            onWheel: function (wheel) { wheel.accepted = true }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 500)
            height: settings.implicitHeight + 48
            radius: 20
            color: pal.window
            border.color: win.line
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                id: settings
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 24
                spacing: 10
                Text {
                    text: win.t("Definições", "Settings")
                    color: win.ink
                    font.family: "Inter Display"
                    font.weight: Font.Light
                    font.pixelSize: 28
                }
                Text {
                    Layout.topMargin: 6
                    text: win.t("Modelo", "Model")
                    color: win.ink
                    font.family: "Inter"
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                }
                Repeater {
                    model: win.models
                    delegate: Rectangle {
                        id: choice
                        required property var modelData
                        readonly property bool chosen: backend.model === modelData.id
                        Layout.fillWidth: true
                        implicitHeight: 58
                        radius: 14
                        color: chosen ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.16)
                             : choiceArea.containsMouse ? win.line : win.tile
                        border.color: chosen ? win.accent : win.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            anchors.topMargin: 9
                            anchors.bottomMargin: 9
                            spacing: 2
                            Text { text: choice.modelData.name; color: win.ink; font.family: "Inter"; font.weight: Font.DemiBold; font.pixelSize: 15 }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: choice.modelData.note; color: win.inkDim; font.family: "Inter"; font.pixelSize: 13 }
                        }
                        MouseArea {
                            id: choiceArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.setModel(choice.modelData.id)
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: win.t("Mudar de modelo começa uma conversa nova. O preço de cada modelo está em platform.claude.com.",
                                "Changing the model starts a new conversation. Each model's price is at platform.claude.com.")
                    color: win.inkDim
                    font.family: "Inter"
                    font.pixelSize: 13
                }
                Text {
                    Layout.topMargin: 10
                    text: win.t("Chave da API", "API key")
                    color: win.ink
                    font.family: "Inter"
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: win.t("Guardada só neste computador. Para a trocar, esqueça-a e indique outra.",
                                    "Stored on this computer only. To change it, forget it and enter another.")
                        color: win.inkDim
                        font.family: "Inter"
                        font.pixelSize: 13
                    }
                    Pill {
                        secondary: true
                        compact: true
                        label: win.t("Esquecer a chave", "Forget the key")
                        onActivated: {
                            backend.forgetKey()
                            win.settingsOpen = false
                        }
                    }
                }
                Pill {
                    Layout.topMargin: 8
                    Layout.alignment: Qt.AlignRight
                    label: win.t("Fechar", "Close")
                    onActivated: win.settingsOpen = false
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.settingsOpen
        onActivated: win.settingsOpen = false
    }
    Shortcut {
        sequence: StandardKey.New
        enabled: backend.hasKey
        onActivated: backend.newConversation()
    }

    // ---- Building block ----
    component Pill: Rectangle {
        id: pill
        property string label
        property bool secondary: false
        property bool compact: false
        signal activated()
        implicitWidth: pillLabel.implicitWidth + (compact ? 30 : 44)
        implicitHeight: compact ? 34 : 44
        radius: height / 2
        opacity: enabled ? 1 : 0.55
        color: secondary ? (pillArea.containsMouse ? win.tile : "transparent")
                         : (pillArea.containsMouse ? Qt.lighter(win.accent, 1.08) : win.accent)
        border.width: secondary ? 1 : 0
        border.color: win.line
        scale: pillArea.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pill.label
            color: pill.secondary ? win.ink : win.accentText
            font.family: "Inter"
            font.weight: Font.DemiBold
            font.pixelSize: pill.compact ? 13 : 15
        }
        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.activated()
        }
    }
}
