#!/usr/bin/env python3
"""DMOS IA: the research assistant of the DMOS desktop.

Questions are answered by Claude (Anthropic), which searches the web and cites what it
found. Every user brings their own API key: it is kept in ~/.config/dmos/ia.key, readable
by that user only, and is sent nowhere but to the Anthropic API.

Usage: dmos-ia [--ask "question"]
"""
import json
import os
import sys
import threading
import time
from datetime import date
from pathlib import Path
from urllib.parse import urlsplit

# Debian does not package the Anthropic SDK; the image carries it next to this file.
VENDOR = os.environ.get("DMOS_IA_VENDOR", "/usr/lib/dmos-ia/vendor")
if os.path.isdir(VENDOR):
    sys.path.insert(0, VENDOR)

import anthropic
from PySide6.QtCore import Property, QLocale, QObject, Qt, QUrl, Signal, Slot
from PySide6.QtGui import QColor, QFont, QIcon, QTextCursor, QTextDocument, QTextFormat
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

QML = os.environ.get("DMOS_IA_QML", "/usr/share/dmos/ia/Main.qml")
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "dmos"
KEY_FILE = CONFIG / "ia.key"
SETTINGS_FILE = CONFIG / "ia.json"

MODELS = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
DEFAULT_MODEL = MODELS[0]
# A long web search can pause a turn; it is resumed this many times at most.
MAX_CONTINUATIONS = 5

SYSTEM = """\
You are DMOS IA, the research assistant built into DMOS, a Linux desktop based on Debian 13 \
with KDE Plasma 6. People come to you to learn about something, compare options and decide.

Answer in the language the person writes in. When that is Portuguese, write European \
Portuguese (pt-PT).

Search the web whenever the answer depends on current or specific facts: news, prices, \
software versions, schedules, people, places, anything that may have changed. Answer from \
what you know when the question is timeless, such as explaining a concept, doing arithmetic \
or helping with a text. When you search, build the answer on what you found and cite it. If \
sources disagree, or you could not confirm something, say so plainly instead of guessing.

Lead with the answer, then give the detail that supports it, and keep it as short as the \
question allows. The app renders Markdown: use short paragraphs and lists for steps or \
options. Avoid tables, which the app shows poorly. Do not end with a list of sources: the \
app shows the pages you cited below your answer.

When a question is about using this computer, answer for DMOS: KDE Plasma 6, applications \
installed from Discover (Flathub is enabled), and apt on the command line.

Today's date is {today}."""


def load_key():
    try:
        key = KEY_FILE.read_text(encoding="utf-8").strip()
    except OSError:
        key = ""
    return key or os.environ.get("ANTHROPIC_API_KEY", "").strip()


def store_key(key):
    CONFIG.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(KEY_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as file:
        file.write(key + "\n")
    # The mode above only applies to a new file.
    os.chmod(KEY_FILE, 0o600)


def load_model():
    try:
        model = json.loads(SETTINGS_FILE.read_text(encoding="utf-8")).get("model")
    except (OSError, ValueError, AttributeError):
        model = None
    return model if model in MODELS else DEFAULT_MODEL


def store_model(model):
    CONFIG.mkdir(mode=0o700, parents=True, exist_ok=True)
    SETTINGS_FILE.write_text(json.dumps({"model": model}) + "\n", encoding="utf-8")


def render(markdown):
    """An answer's Markdown as rich text for the window.

    Qt lays Markdown out with no space at all between paragraphs, so the space is added here.
    """
    document = QTextDocument()
    font = QFont("Inter")
    font.setPixelSize(15)
    document.setDefaultFont(font)
    document.setMarkdown(markdown)

    def is_code(block):
        return block.blockFormat().hasProperty(QTextFormat.Property.BlockCodeFence.value) \
            or block.charFormat().fontFixedPitch()

    cursor = QTextCursor(document)
    block = document.begin()
    while block.isValid():
        following = block.next()
        layout = block.blockFormat()
        if layout.headingLevel():
            layout.setTopMargin(12 if block.blockNumber() else 0)
            layout.setBottomMargin(6)
        elif is_code(block):
            layout.setBackground(QColor(128, 128, 128, 46))
            layout.setBottomMargin(0 if following.isValid() and is_code(following) else 10)
        elif block.textList() is not None:
            layout.setBottomMargin(3 if following.isValid() and following.textList() is not None else 10)
        else:
            layout.setBottomMargin(10)
        if not following.isValid():
            layout.setBottomMargin(0)
        cursor.setPosition(block.position())
        cursor.setBlockFormat(layout)
        block = following
    return document.toHtml()


def echo_content(blocks):
    """An assistant turn as it goes back to the API in the next request.

    It goes back unchanged, except after a mid-answer fallback to another model: what the
    first model produced before the switch keeps only its text and its completed searches.
    """
    switch = max((i for i, block in enumerate(blocks) if block.type == "fallback"), default=-1)
    if switch < 0:
        return blocks
    answered = {getattr(block, "tool_use_id", None)
                for block in blocks[:switch] if block.type.endswith("_tool_result")}
    kept = []
    for i, block in enumerate(blocks):
        if (i >= switch or block.type in ("text", "fallback") or block.type.endswith("_tool_result")
                or (block.type == "server_tool_use" and block.id in answered)):
            kept.append(block)
    return kept


class Sources:
    """Web pages behind an answer. Cited ones are numbered in the order they first appear."""

    def __init__(self):
        self.cited = []
        self.found = []

    def add_results(self, content):
        # A failed search carries an error object here instead of a list of results.
        if not isinstance(content, list):
            return
        for result in content:
            url = getattr(result, "url", None)
            if url and all(url != seen for seen, _ in self.found):
                self.found.append((url, getattr(result, "title", None) or ""))

    def cite(self, citations):
        """Markdown markers such as " [[1]](url)" for the citations of one piece of text."""
        marks = []
        for citation in citations:
            url = getattr(citation, "url", None)
            if not url:
                continue
            known = [seen for seen, _ in self.cited]
            if url not in known:
                self.cited.append((url, getattr(citation, "title", None) or ""))
                known.append(url)
            target = url.replace(" ", "%20").replace("(", "%28").replace(")", "%29")
            mark = "[[%d]](%s)" % (known.index(url) + 1, target)
            if mark not in marks:
                marks.append(mark)
        return " " + " ".join(marks) if marks else ""

    def listing(self):
        """What the app shows under the answer: the cited pages, or else the first ones found."""
        pages = self.cited or self.found[:5]
        listing = []
        for number, (url, title) in enumerate(pages, 1):
            host = (urlsplit(url).hostname or "").removeprefix("www.")
            listing.append({"n": number if self.cited else 0, "url": url, "host": host,
                            "title": title or host or url})
        return listing


class Backend(QObject):
    hasKeyChanged = Signal()
    checkingKeyChanged = Signal()
    modelChanged = Signal()
    busyChanged = Signal()

    keyRejected = Signal(str)           # "empty" | "invalid" | "network"
    conversationCleared = Signal()
    answerStarted = Signal()
    answerText = Signal(str)            # the answer so far, as rich text
    answerStatus = Signal(str, str)     # "thinking" | "searching" | "writing", search query
    answerSources = Signal(list, bool)  # [{n, url, host, title}], whether they were cited
    answerFinished = Signal(str, str)   # "" | "cut" | "refused" | "stopped", other model that answered
    answerFailed = Signal(str, str)     # error code, detail

    # Worker threads report here; the queued connection moves each report to the GUI thread.
    _report = Signal(int, str, object)

    def __init__(self):
        super().__init__()
        self._key = load_key()
        self._client = anthropic.Anthropic(api_key=self._key) if self._key else None
        self._model = load_model()
        self._busy = False
        self._checking = False
        self._messages = []
        self._system = ""
        self._partial = ""  # what the model wrote so far in the answer under way
        self._shown = ""    # the same, with the citation markers the window shows
        self._run = 0
        self._cancel = threading.Event()
        self._report.connect(self._on_report, Qt.QueuedConnection)

    # ---- State shown by the window ----

    @Property(bool, notify=hasKeyChanged)
    def hasKey(self):
        return bool(self._key)

    @Property(bool, notify=checkingKeyChanged)
    def checkingKey(self):
        return self._checking

    @Property(str, notify=modelChanged)
    def model(self):
        return self._model

    @Property(bool, notify=busyChanged)
    def busy(self):
        return self._busy

    def _set_busy(self, busy):
        if busy != self._busy:
            self._busy = busy
            self.busyChanged.emit()

    def _set_checking(self, checking):
        if checking != self._checking:
            self._checking = checking
            self.checkingKeyChanged.emit()

    # ---- API key ----

    @Slot(str)
    def saveKey(self, key):
        key = "".join(key.split())
        if not key:
            self.keyRejected.emit("empty")
        elif not key.isascii():
            self.keyRejected.emit("invalid")
        elif not self._checking:
            self._set_checking(True)
            threading.Thread(target=self._check_key, args=(key, self._model), daemon=True).start()

    def _check_key(self, key, model):
        try:
            anthropic.Anthropic(api_key=key, max_retries=1).models.retrieve(model)
        except anthropic.AuthenticationError:
            self._report.emit(-1, "key-bad", "invalid")
        except anthropic.APIConnectionError:
            self._report.emit(-1, "key-bad", "network")
        except anthropic.APIError:
            # The key itself was accepted; any other problem shows when a question is asked.
            self._report.emit(-1, "key-ok", key)
        else:
            self._report.emit(-1, "key-ok", key)

    @Slot()
    def forgetKey(self):
        self.newConversation()
        try:
            KEY_FILE.unlink()
        except OSError:
            pass
        self._key = ""
        self._client = None
        self.hasKeyChanged.emit()

    # ---- Conversation ----

    @Slot(str)
    def setModel(self, model):
        if model not in MODELS or model == self._model:
            return
        # Another model cannot continue this one's reasoning, so the conversation starts over.
        self.newConversation()
        self._model = model
        try:
            store_model(model)
        except OSError:
            pass
        self.modelChanged.emit()

    @Slot()
    def newConversation(self):
        if self._busy:
            self._cancel.set()
            self._run += 1
            self._set_busy(False)
        self._messages = []
        self.conversationCleared.emit()

    @Slot(str)
    def ask(self, question):
        question = question.strip()
        if not question or self._busy or not self._client:
            return
        if not self._messages:
            # Fixed for the whole conversation: earlier turns stay valid only while the
            # system prompt they were answered under does not change.
            self._system = SYSTEM.replace("{today}", date.today().isoformat())
        self._messages.append({"role": "user", "content": question})
        self._partial = ""
        self._shown = ""
        self._run += 1
        self._cancel = threading.Event()
        self._set_busy(True)
        self.answerStarted.emit()
        threading.Thread(
            target=self._answer, daemon=True,
            args=(self._run, self._cancel, self._client, self._model, self._system, list(self._messages)),
        ).start()

    @Slot()
    def stop(self):
        if not self._busy:
            return
        self._cancel.set()
        self._run += 1  # anything the stopped run still reports is ignored
        partial = self._partial.rstrip()
        if partial:
            self._messages.append({"role": "assistant", "content": [{"type": "text", "text": partial}]})
        else:
            self._messages.pop()
        self._set_busy(False)
        self.answerFinished.emit("stopped", "")

    def _on_report(self, run, kind, payload):
        if kind == "key-ok":
            self._set_checking(False)
            try:
                store_key(payload)
            except OSError as error:
                self.keyRejected.emit("storage:" + str(error))
                return
            self._key = payload
            self._client = anthropic.Anthropic(api_key=payload)
            self.hasKeyChanged.emit()
        elif kind == "key-bad":
            self._set_checking(False)
            self.keyRejected.emit(payload)
        elif run != self._run:
            return
        elif kind in ("text", "mark"):
            if kind == "text":
                self._partial += payload
            self._shown += payload
            self.answerText.emit(render(self._shown))
        elif kind == "status":
            self.answerStatus.emit(*payload)
        elif kind == "sources":
            self.answerSources.emit(*payload)
        elif kind == "done":
            turns, note, served = payload
            if note == "refused":
                # The declined question is left out, so the conversation can go on.
                self._messages.pop()
            else:
                self._messages.extend(turns)
            self._set_busy(False)
            self.answerFinished.emit(note, served)
        elif kind == "error":
            self._messages.pop()
            self._set_busy(False)
            self.answerFailed.emit(*payload)

    # ---- Worker thread ----

    def _answer(self, run, cancel, client, model, system, messages):
        def report(kind, payload=None):
            self._report.emit(run, kind, payload)

        sources = Sources()
        turns = []
        try:
            final = None
            for _ in range(MAX_CONTINUATIONS + 1):
                final = self._stream_turn(client, model, system, messages + turns, cancel, report, sources)
                if final is None:
                    return  # stopped by the user
                if final.stop_reason == "refusal":
                    report("done", ([], "refused", ""))
                    return
                turns.append({"role": "assistant", "content": echo_content(final.content)})
                if final.stop_reason != "pause_turn":
                    break
            report("sources", (sources.listing(), bool(sources.cited)))
            note = "cut" if final.stop_reason in ("max_tokens", "pause_turn") else ""
            served = "" if final.model.startswith(model) else final.model
            report("done", (turns, note, served))
        except anthropic.BadRequestError as error:
            code = "credit" if "credit balance" in str(error).lower() else "other"
            report("error", (code, str(error)))
        except anthropic.AuthenticationError as error:
            report("error", ("auth", str(error)))
        except anthropic.PermissionDeniedError as error:
            report("error", ("model", str(error)))
        except anthropic.NotFoundError as error:
            report("error", ("model", str(error)))
        except anthropic.RateLimitError as error:
            report("error", ("rate", str(error)))
        except anthropic.APIStatusError as error:
            report("error", ("overloaded" if error.status_code >= 500 else "other", str(error)))
        except anthropic.APIConnectionError as error:
            report("error", ("network", str(error)))
        except Exception as error:  # a worker thread must always report back
            report("error", ("other", "%s: %s" % (type(error).__name__, error)))

    def _stream_turn(self, client, model, system, messages, cancel, report, sources):
        """Streams one response; returns the final message, or None when the user stopped it."""
        haiku = model == "claude-haiku-5-5"
        request = dict(
            model=model,
            max_tokens=64000,
            system=system,
            messages=messages,
            tools=[{"type": "web_search_20250305" if haiku else "web_search_20260209",
                    "name": "web_search", "max_uses": 5}],
            output_config={"effort": "medium"},
            cache_control={"type": "ephemeral"},
        )
        if not haiku:
            # If the model declines a request, Anthropic retries it on the model it
            # recommends for that case, inside the same call.
            request.update(betas=["server-side-fallback-2026-07-01"], fallbacks="default")

        queries = {}    # search input being streamed, by content block
        citations = {}  # citations of the text being streamed, by content block
        pending = []
        flushed = time.monotonic()

        def flush():
            nonlocal flushed
            if pending:
                report("text", "".join(pending))
                pending.clear()
            flushed = time.monotonic()

        with client.beta.messages.stream(**request) as stream:
            for event in stream:
                if cancel.is_set():
                    return None
                if event.type == "content_block_start":
                    block = event.content_block
                    if block.type == "thinking":
                        report("status", ("thinking", ""))
                    elif block.type == "server_tool_use":
                        queries[event.index] = ""
                        report("status", ("searching", ""))
                    elif block.type == "web_search_tool_result":
                        sources.add_results(block.content)
                    elif block.type == "text":
                        citations[event.index] = []
                        report("status", ("writing", ""))
                elif event.type == "content_block_delta":
                    delta = event.delta
                    if delta.type == "text_delta":
                        pending.append(delta.text)
                        # The window re-renders the answer on every report; keep them apart.
                        if time.monotonic() - flushed > 0.05:
                            flush()
                    elif delta.type == "input_json_delta" and event.index in queries:
                        queries[event.index] += delta.partial_json
                    elif delta.type == "citations_delta" and event.index in citations:
                        citations[event.index].append(delta.citation)
                elif event.type == "content_block_stop":
                    if event.index in queries:
                        try:
                            query = json.loads(queries.pop(event.index) or "{}").get("query")
                        except (ValueError, AttributeError):
                            query = None
                        if isinstance(query, str) and query:
                            report("status", ("searching", query))
                    elif event.index in citations:
                        flush()
                        marks = sources.cite(citations.pop(event.index))
                        if marks:
                            report("mark", marks)
            flush()
            return stream.get_final_message()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("dmos-ia")
    # The same rule as the window: Portuguese by default, English in any other session.
    app.setApplicationDisplayName("DMOS IA" if QLocale().name().startswith("pt") else "DMOS AI")
    app.setDesktopFileName("org.dmos.ia")
    app.setWindowIcon(QIcon.fromTheme("dmos-ia"))

    arguments = app.arguments()
    question = ""
    if "--ask" in arguments[1:-1]:
        question = arguments[arguments.index("--ask") + 1]

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("firstQuestion", question)
    engine.load(QUrl.fromLocalFile(QML))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
