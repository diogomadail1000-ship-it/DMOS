// DMOS — assistente do site. Responde no próprio navegador com as perguntas frequentes do
// repositório (.github/assistente/faq.json, a mesma fonte do assistente das Discussões e dos Issues)
// e, quando não sabe, leva a pergunta para as Discussões, onde o GitHub Copilot responde.
(function () {
  "use strict";

  var REPO = "diogomadail1000-ship-it/DMOS";
  var FAQ_URL = "https://raw.githubusercontent.com/" + REPO + "/main/.github/assistente/faq.json";
  var DISCUSSIONS = "https://github.com/" + REPO + "/discussions";
  var MAX = 2; // no máximo, quantas perguntas frequentes entram numa resposta
  var SUGGESTIONS = ["pen-usb", "maquina-virtual", "flathub", "ecra-preto", "hardware"];

  var root = document.querySelector(".assistente");
  if (!root) return;
  var openBtn = root.querySelector(".assistente-abrir");
  var panel = root.querySelector(".assistente-painel");
  var closeBtn = root.querySelector(".assistente-fechar");
  var log = root.querySelector(".assistente-conversa");
  var form = root.querySelector("form");
  var input = form.querySelector("input");
  var chips = root.querySelector(".assistente-sugestoes");
  var faq = null, loading = null;

  // Minúsculas e sem acentos, para comparar palavras-chave (igual a responder.py).
  function normalize(text) {
    return text.toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, "");
  }
  function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }

  function matches(text) {
    var norm = normalize(text), scored = [];
    faq.entradas.forEach(function (entry, order) {
      var hits = 0;
      entry.palavras.forEach(function (word) {
        var re = new RegExp("(?<![\\w-])" + escapeRe(normalize(word)) + "(?![\\w-])");
        if (re.test(norm)) hits++;
      });
      if (hits) scored.push({ hits: hits, order: order, entry: entry });
    });
    scored.sort(function (a, b) { return b.hits - a.hits || a.order - b.order; });
    return scored.slice(0, MAX).map(function (s) { return s.entry; });
  }

  // Markdown mínimo e seguro: o texto é escapado antes de qualquer marcação.
  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }
  function inline(s) {
    return s
      .replace(/`([^`]+)`/g, function (_, c) { return "<code>" + c + "</code>"; })
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
      .replace(/(^|[^"=>])(https?:\/\/[^\s<)]+)/g, '$1<a href="$2" target="_blank" rel="noopener">$2</a>');
  }
  function markdown(text) {
    var html = "", lines = escapeHtml(text).split("\n"), i = 0, list = null, para = [];
    function flush() {
      if (para.length) { html += "<p>" + inline(para.join(" ")) + "</p>"; para = []; }
      if (list) { html += "</" + list + ">"; list = null; }
    }
    while (i < lines.length) {
      var line = lines[i];
      if (/^```/.test(line)) {
        flush(); var code = [];
        i++;
        while (i < lines.length && !/^```/.test(lines[i])) code.push(lines[i++]);
        html += "<pre><code>" + code.join("\n") + "</code></pre>";
      } else if (/^\s*[-*] /.test(line) || /^\s*\d+\. /.test(line)) {
        var kind = /^\s*\d+\. /.test(line) ? "ol" : "ul";
        if (list !== kind) { flush(); list = kind; html += "<" + kind + ">"; }
        html += "<li>" + inline(line.replace(/^\s*([-*]|\d+\.) /, "")) + "</li>";
      } else if (!line.trim()) {
        flush();
      } else {
        if (list) { html += "</" + list + ">"; list = null; }
        para.push(line);
      }
      i++;
    }
    flush();
    return html;
  }

  function discussionLink(question) {
    var title = question.length > 100 ? question.slice(0, 97) + "…" : question;
    return DISCUSSIONS + "/new?category=q-a&title=" + encodeURIComponent(title) +
      "&body=" + encodeURIComponent(question) + "&pergunta=" + encodeURIComponent(question);
  }

  function add(role, html) {
    var el = document.createElement("div");
    el.className = "assistente-msg " + role;
    el.innerHTML = html;
    log.appendChild(el);
    log.scrollTop = log.scrollHeight;
    return el;
  }

  function communityRow(question, lead) {
    return '<p class="assistente-mais">' + lead + ' <a class="btn btn-small btn-primary" target="_blank" rel="noopener" href="' +
      discussionLink(question) + '">Perguntar na comunidade</a></p>';
  }

  function answer(question) {
    var found = matches(question);
    if (!found.length) {
      add("bot", "<p>Ainda não tenho uma resposta pronta para isso.</p>" +
        communityRow(question, "Leve a pergunta para as Discussões: o assistente do projeto responde em minutos e um humano vê a conversa."));
      return;
    }
    var html = found.map(function (e) { return "<h4>" + escapeHtml(e.titulo) + "</h4>" + markdown(e.resposta); }).join("");
    add("bot", html + communityRow(question, "Não resolveu?"));
  }

  function load() {
    if (faq) return Promise.resolve(faq);
    if (!loading) {
      loading = fetch(FAQ_URL, { cache: "no-cache" }).then(function (r) {
        if (!r.ok) throw new Error(r.status);
        return r.json();
      }).then(function (data) {
        faq = data;
        SUGGESTIONS.forEach(function (id) {
          var entry = faq.entradas.filter(function (e) { return e.id === id; })[0];
          if (!entry) return;
          var b = document.createElement("button");
          b.type = "button"; b.textContent = entry.titulo;
          b.addEventListener("click", function () { ask(entry.titulo); });
          chips.appendChild(b);
        });
        return faq;
      }).catch(function () {
        loading = null;
        add("bot", "<p>Não consegui carregar as perguntas frequentes. Pode perguntar diretamente nas " +
          '<a href="' + DISCUSSIONS + '/new?category=q-a" target="_blank" rel="noopener">Discussões</a>.</p>');
        throw new Error("faq");
      });
    }
    return loading;
  }

  function ask(question) {
    question = question.trim();
    if (!question) return;
    add("user", "<p>" + escapeHtml(question) + "</p>");
    root.classList.add("perguntou");
    input.value = "";
    load().then(function () { answer(question); }, function () {});
  }

  function open() {
    root.classList.add("aberto");
    openBtn.setAttribute("aria-expanded", "true");
    panel.hidden = false;
    load().then(null, function () {});
    setTimeout(function () { input.focus(); }, 50);
  }
  function close() {
    root.classList.remove("aberto");
    openBtn.setAttribute("aria-expanded", "false");
    panel.hidden = true;
    openBtn.focus();
  }

  openBtn.addEventListener("click", function () { root.classList.contains("aberto") ? close() : open(); });
  closeBtn.addEventListener("click", close);
  document.addEventListener("keydown", function (e) { if (e.key === "Escape" && root.classList.contains("aberto")) close(); });
  form.addEventListener("submit", function (e) { e.preventDefault(); ask(input.value); });
  // As ligações «Perguntar» do site abrem o assistente.
  document.querySelectorAll('a[href="#perguntar"]').forEach(function (a) {
    a.addEventListener("click", function (e) { e.preventDefault(); open(); });
  });
  if (location.hash === "#perguntar") open();
})();
