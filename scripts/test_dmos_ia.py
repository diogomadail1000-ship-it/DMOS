#!/usr/bin/env python3
"""Exercises the DMOS IA backend against scripts/fake_claude.py, without a window.

Run it where PySide6 and the Anthropic SDK are installed (a DMOS session):

    python3 scripts/test_dmos_ia.py [path/to/dmos_ia.py]

It uses a temporary configuration directory, so a real key on the machine is never touched.
"""
import importlib.util
import json
import os
import stat
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
APP = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/usr/lib/dmos-ia/dmos_ia.py")
PORT = 8399

config = tempfile.mkdtemp(prefix="dmos-ia-test-")
os.environ.update(XDG_CONFIG_HOME=config, QT_QPA_PLATFORM="offscreen",
                  ANTHROPIC_BASE_URL="http://127.0.0.1:%d" % PORT)
os.environ.pop("ANTHROPIC_API_KEY", None)

server = subprocess.Popen([sys.executable, str(HERE / "fake_claude.py"), str(PORT)],
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
server.stdout.readline()  # it prints its address once it listens

spec = importlib.util.spec_from_file_location("dmos_ia", APP)
dmos_ia = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dmos_ia)

app = dmos_ia.QApplication(sys.argv[:1])
backend = dmos_ia.Backend()

log = []
for name in ("keyRejected", "conversationCleared", "answerStarted", "answerText", "answerStatus",
             "answerSources", "answerFinished", "answerFailed"):
    getattr(backend, name).connect(lambda *args, name=name: log.append((name, args)))

failures = 0


def check(what, ok, detail=""):
    global failures
    failures += not ok
    print("%s  %s%s" % ("ok  " if ok else "FAIL", what, "  -> %s" % (detail,) if detail and not ok else ""))


def spin(until, timeout=45):
    deadline = time.monotonic() + timeout
    while not until() and time.monotonic() < deadline:
        app.processEvents()
        time.sleep(0.01)
    return until()


def seen(name):
    return [args for event, args in log if event == name]


def requests():
    with urllib.request.urlopen("http://127.0.0.1:%d/_requests" % PORT) as response:
        return json.load(response)


def ask(question, timeout=45):
    del log[:]
    backend.ask(question)
    spin(lambda: seen("answerFinished") or seen("answerFailed"), timeout)
    # Each report carries the whole answer so far, as rich text.
    return seen("answerText")[-1][0] if seen("answerText") else ""


try:
    # ---- API key ----
    check("starts without a key", not backend.hasKey)
    backend.saveKey("sk-ant-chave-invalida")
    spin(lambda: seen("keyRejected"))
    check("a wrong key is rejected", seen("keyRejected") == [("invalid",)], seen("keyRejected"))
    check("and is not stored", not dmos_ia.KEY_FILE.exists())
    backend.saveKey("  sk-ant-teste\n")
    spin(lambda: backend.hasKey)
    check("a good key is accepted", backend.hasKey)
    mode = stat.S_IMODE(dmos_ia.KEY_FILE.stat().st_mode) if dmos_ia.KEY_FILE.exists() else None
    check("the key file is private (0600)", mode == 0o600, oct(mode or 0))
    check("the key is stored without the pasted spaces",
          dmos_ia.KEY_FILE.read_text().strip() == "sk-ant-teste")

    # ---- A cited answer ----
    text = ask("o que e o dmos")
    check("an answer arrives", "resposta de teste" in text and seen("answerFinished") == [("", "")],
          (text[:80], seen("answerFinished"), seen("answerFailed")))
    statuses = [args[0] for args in seen("answerStatus")]
    check("thinking, searching and writing are reported",
          statuses[:1] == ["thinking"] and "searching" in statuses and "writing" in statuses, statuses)
    check("the search query is shown", ("searching", "o que e o dmos") in seen("answerStatus"))
    pages, cited = seen("answerSources")[0]
    check("cited pages are numbered in order of appearance",
          cited and [(page["n"], page["host"]) for page in pages] == [(1, "debian.org"), (2, "flathub.org")], pages)
    check("markers link to the cited pages, repeating a page's number",
          text.count('href="https://www.debian.org/releases/trixie/"') == 2
          and text.count('href="https://flathub.org/pt/about"') == 1 and "[1]" in text and "[2]" in text, text)
    check("Markdown is laid out: bold, list, heading, code",
          "font-weight:" in text and "<li" in text and "<h2" in text and "sudo apt install vlc" in text, text)

    sent = requests()[-1]
    body = sent["body"]
    check("request: Opus 5.5, streaming, web search with dynamic filtering",
          body["model"] == "claude-opus-5-5" and body.get("stream") is True
          and body["tools"] == [{"type": "web_search_20260209", "name": "web_search", "max_uses": 5}], body.get("tools"))
    check("request: refusal fallback is on", body.get("fallbacks") == "default"
          and "server-side-fallback-2026-07-01" in sent["beta"], (body.get("fallbacks"), sent["beta"]))
    check("request: effort and caching", body.get("output_config") == {"effort": "medium"}
          and body.get("cache_control") == {"type": "ephemeral"} and "thinking" not in body)

    # ---- A follow-up carries the whole earlier turn ----
    ask("e mais?")
    messages = requests()[-1]["body"]["messages"]
    kinds = [block["type"] for block in messages[1]["content"]] if len(messages) == 3 else []
    check("the follow-up sends back thinking, search and cited text",
          [m["role"] for m in messages] == ["user", "assistant", "user"]
          and kinds[:3] == ["thinking", "server_tool_use", "web_search_tool_result"] and "text" in kinds, kinds)
    check("the system prompt did not change between turns",
          requests()[-1]["body"]["system"] == requests()[-2]["body"]["system"])

    # ---- Things that go wrong ----
    before = len(backend._messages)
    ask("isto da erro")
    check("an overloaded service is reported", [args[0] for args in seen("answerFailed")] == ["overloaded"], seen("answerFailed"))
    ask("sem saldo")
    check("an account without credit is reported", [args[0] for args in seen("answerFailed")] == ["credit"], seen("answerFailed"))
    ask("uma recusa")
    check("a refusal is reported", seen("answerFinished") == [("refused", "")], seen("answerFinished"))
    check("failed questions leave the conversation as it was", len(backend._messages) == before, len(backend._messages))

    # ---- Stopping half-way ----
    del log[:]
    backend.ask("resposta longa")
    spin(lambda: len(seen("answerText")) > 3)
    backend.stop()
    check("stop ends the answer at once", seen("answerFinished") == [("stopped", "")] and not backend.busy)
    shown = len(seen("answerText"))
    spin(lambda: False, timeout=1.5)
    check("nothing more arrives after stop", len(seen("answerText")) == shown)
    check("what was shown stays in the conversation", backend._messages[-1]["role"] == "assistant")
    text = ask("continua")
    check("the conversation goes on after a stop", "resposta de teste" in text, seen("answerFailed"))

    # ---- Another model ----
    del log[:]
    backend.setModel("claude-haiku-5-5")
    check("changing the model starts a new conversation", seen("conversationCleared") and not backend._messages)
    ask("pergunta ao haiku")
    body = requests()[-1]
    check("Haiku: basic web search and no fallback", body["body"]["model"] == "claude-haiku-5-5"
          and body["body"]["tools"][0]["type"] == "web_search_20250305" and "fallbacks" not in body["body"]
          and "server-side-fallback" not in body["beta"] and len(body["body"]["messages"]) == 1, body["body"].get("tools"))
    check("the chosen model is remembered", dmos_ia.load_model() == "claude-haiku-5-5")

    backend.forgetKey()
    check("forgetting the key removes it", not backend.hasKey and not dmos_ia.KEY_FILE.exists())
finally:
    server.terminate()

print("\n%s" % ("ALL PASSED" if not failures else "%d FAILED" % failures))
sys.exit(1 if failures else 0)
