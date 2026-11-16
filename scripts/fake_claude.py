#!/usr/bin/env python3
"""A stand-in for the Anthropic API, to try DMOS IA without an account or a key.

It speaks just enough of the Messages API (streaming, web search, citations) for the
window to be exercised. Nothing here reaches the internet.

    python3 scripts/fake_claude.py [port]
    ANTHROPIC_BASE_URL=http://127.0.0.1:8377 ANTHROPIC_API_KEY=sk-ant-teste dmos-ia

The last question decides what comes back:
    "erro"     an overloaded error (HTTP 529)
    "saldo"    the error of an account without credit (HTTP 400)
    "recusa"   a refusal
    "longa"    a long answer, to test scrolling and the stop button
    anything else: a search, then a short cited answer
A key that ends in "invalida" is rejected (HTTP 401).
"""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PAGES = [
    {"url": "https://www.debian.org/releases/trixie/", "title": "Debian 13 «trixie» — notas de lançamento"},
    {"url": "https://kde.org/announcements/plasma/6/6.3.0/", "title": "KDE Plasma 6.3"},
    {"url": "https://flathub.org/pt/about", "title": "Sobre o Flathub"},
]
REQUESTS = []


def last_question(body):
    for message in reversed(body.get("messages", [])):
        if message.get("role") == "user":
            content = message.get("content")
            if isinstance(content, str):
                return content
            return " ".join(part.get("text", "") for part in content if isinstance(part, dict))
    return ""


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, pattern, *args):
        sys.stderr.write("fake_claude: " + pattern % args + "\n")

    def reply(self, status, payload):
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def error(self, status, kind, message):
        self.reply(status, {"type": "error", "error": {"type": kind, "message": message}})

    def bad_key(self):
        # Depending on its version, the SDK sends the key in one header or the other.
        key = self.headers.get("x-api-key") or self.headers.get("authorization", "")
        if key.endswith("invalida"):
            self.error(401, "authentication_error", "invalid x-api-key")
            return True
        return False

    def do_GET(self):
        if self.path == "/_requests":
            # For tests: what the app sent so far.
            self.reply(200, REQUESTS)
            return
        if self.bad_key():
            return
        if self.path.startswith("/v1/models/"):
            model = self.path.split("/v1/models/")[1].split("?")[0]
            self.reply(200, {"type": "model", "id": model, "display_name": model,
                             "created_at": "2026-01-01T00:00:00Z"})
        else:
            self.error(404, "not_found_error", self.path)

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
        if self.bad_key():
            return
        if not self.path.startswith("/v1/messages"):
            self.error(404, "not_found_error", self.path)
            return
        REQUESTS.append({"beta": self.headers.get("anthropic-beta", ""), "body": body})
        question = last_question(body).lower()
        if "erro" in question:
            self.error(529, "overloaded_error", "Overloaded")
            return
        if "saldo" in question:
            self.error(400, "invalid_request_error",
                       "Your credit balance is too low to access the Anthropic API.")
            return

        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("cache-control", "no-cache")
        self.send_header("connection", "close")
        self.end_headers()
        self.close_connection = True
        try:
            self.stream(body, question)
        except (BrokenPipeError, ConnectionResetError):
            pass  # the app stopped the answer

    def event(self, kind, **fields):
        payload = json.dumps({"type": kind, **fields})
        self.wfile.write(("event: %s\ndata: %s\n\n" % (kind, payload)).encode())
        self.wfile.flush()

    def block(self, index, start, deltas=(), pause=0.0):
        self.event("content_block_start", index=index, content_block=start)
        for delta in deltas:
            time.sleep(pause)
            self.event("content_block_delta", index=index, delta=delta)
        self.event("content_block_stop", index=index)

    def text(self, index, words, citation=None):
        deltas = [{"type": "text_delta", "text": word + " "} for word in words.split(" ")]
        deltas[-1]["text"] = deltas[-1]["text"][:-1]
        if citation is not None:
            page = PAGES[citation]
            deltas.insert(0, {"type": "citations_delta", "citation": {
                "type": "web_search_result_location", "url": page["url"], "title": page["title"],
                "encrypted_index": "ZmFrZQ==", "cited_text": words[:80]}})
        self.block(index, {"type": "text", "text": "", "citations": [] if citation is not None else None},
                   deltas, pause=0.03)

    def stream(self, body, question):
        model = body.get("model", "claude-opus-5-5")
        self.event("message_start", message={
            "id": "msg_fake", "type": "message", "role": "assistant", "model": model, "content": [],
            "stop_reason": None, "stop_sequence": None, "usage": {"input_tokens": 40, "output_tokens": 1}})
        self.block(0, {"type": "thinking", "thinking": "", "signature": ""},
                   [{"type": "signature_delta", "signature": "ZmFrZQ=="}], pause=1.0)

        stop = "end_turn"
        if "recusa" in question:
            stop = "refusal"
        elif "longa" in question:
            paragraph = ("Este é um parágrafo de enchimento, para ver como a janela acompanha uma "
                         "resposta longa e se o botão de parar funciona a meio.")
            for index in range(1, 41):
                self.text(index, "**Parte %d.** %s\n\n" % (index, paragraph))
        else:
            self.block(1, {"type": "server_tool_use", "id": "srvtoolu_fake", "name": "web_search", "input": {}},
                       [{"type": "input_json_delta", "partial_json": json.dumps({"query": question[:60]})}],
                       pause=0.4)
            time.sleep(1.5)
            self.block(2, {"type": "web_search_tool_result", "tool_use_id": "srvtoolu_fake", "content": [
                {"type": "web_search_result", "url": page["url"], "title": page["title"],
                 "encrypted_content": "ZmFrZQ==", "page_age": None} for page in PAGES]})
            self.text(3, "Esta é uma **resposta de teste**, vinda do servidor de ensaio e não do Claude.\n\n")
            self.text(4, "O DMOS assenta no Debian 13 «trixie».", citation=0)
            self.text(5, " O ambiente de trabalho é o KDE Plasma 6:\n\n- painel superior flutuante\n- dock ao centro\n- tema claro e escuro\n\n## Aplicações\n\n")
            self.text(6, "As aplicações extra chegam pelo Flathub.", citation=2)
            self.text(7, " Volta a citar-se a primeira página, para confirmar que o número se repete.", citation=0)
            self.text(8, "\n\nPara instalar pela linha de comandos:\n\n```\nsudo apt install vlc\n```\n")

        self.event("message_delta", delta={"stop_reason": stop, "stop_sequence": None},
                   usage={"output_tokens": 180})
        self.event("message_stop")


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8377
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print("fake_claude: http://127.0.0.1:%d" % port, flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
