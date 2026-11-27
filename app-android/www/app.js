// DMOS para Android: interface. Corre numa WebView com a página local; a rede passa pela ponte
// nativa «DmosNative» (MainActivity.java). No navegador, para testes, usa fetch().
(function () {
  "use strict";

  var REPO = "diogomadail1000-ship-it/DMOS";
  var RAW = "https://raw.githubusercontent.com/" + REPO + "/main/";
  var DISCUSSIONS = "https://github.com/" + REPO + "/discussions";
  var DOWNLOAD = "https://dmos.cc/download/";
  var BUNDLE = window.DMOS_BUNDLE || {};
  var nativo = window.DmosNative || null;
  var $ = function (id) { return document.getElementById(id); };

  // ---------- Rede e memória ----------
  var pendentes = {}, contador = 0;
  function entregar(id, status, b64) {
    var feito = pendentes[id];
    if (!feito) return;
    delete pendentes[id];
    var texto = "";
    try {
      var bin = atob(b64), bytes = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      texto = new TextDecoder("utf-8").decode(bytes);
    } catch (e) { status = 0; }
    feito({ status: status, text: texto });
  }
  // Recolhe da ponte nativa a resposta de um pedido, se já chegou.
  function recolher(id) {
    if (!pendentes[id]) return;
    var r = "";
    try { r = nativo.take(id) || ""; } catch (e) {}
    var virgula = r.indexOf(",");
    if (virgula > 0) entregar(id, parseInt(r.slice(0, virgula), 10) || 0, r.slice(virgula + 1));
  }
  // A ponte avisa quando uma resposta está pronta; por segurança, a página também pergunta.
  window.__dmosReady = recolher;
  setInterval(function () { for (var id in pendentes) recolher(id); }, 400);
  // Pede um endereço. Devolve sempre { status, text }; status 0 é falha de rede.
  // No máximo quatro pedidos de cada vez (o mesmo que a ponte nativa); os outros esperam aqui,
  // e o limite de tempo só começa a contar quando o pedido arranca.
  var fila = [], ativos = 0;
  function seguinte() {
    if (ativos >= 4 || !fila.length) return;
    var p = fila.shift(), id = "p" + (++contador);
    ativos++;
    pendentes[id] = function (r) { ativos--; p.resolve(r); seguinte(); };
    setTimeout(function () { var f = pendentes[id]; if (f) { delete pendentes[id]; f({ status: 0, text: "" }); } }, 32000);
    try { nativo.fetch(id, p.url); } catch (e) { var f = pendentes[id]; delete pendentes[id]; if (f) f({ status: 0, text: "" }); }
  }
  function pedir(url) {
    return new Promise(function (resolve) {
      if (nativo) {
        fila.push({ url: url, resolve: resolve });
        seguinte();
      } else {
        fetch(url).then(function (r) { return r.text().then(function (t) { resolve({ status: r.status, text: t }); }); })
          .catch(function () { resolve({ status: 0, text: "" }); });
      }
    });
  }
  function abrir(url) {
    if (!/^https?:\/\//.test(url)) return;
    if (nativo) nativo.open(url); else window.open(url, "_blank", "noopener");
  }
  function guardar(chave, valor) { try { localStorage.setItem("dmos." + chave, JSON.stringify(valor)); } catch (e) {} }
  function ler(chave, omissao) {
    try { var v = localStorage.getItem("dmos." + chave); return v === null ? omissao : JSON.parse(v); } catch (e) { return omissao; }
  }
  // Uma versão nova da aplicação traz conteúdo mais recente do que o guardado pela anterior.
  if (ler("build", null) !== BUNDLE.build) {
    ["notas", "faq", "dados", "sha256"].forEach(function (c) { try { localStorage.removeItem("dmos." + c); } catch (e) {} });
    guardar("build", BUNDLE.build);
  }
  function el(tag, attrs, texto) {
    var e = document.createElement(tag);
    for (var k in attrs || {}) e.setAttribute(k, attrs[k]);
    if (texto !== undefined) e.textContent = texto;
    return e;
  }

  // ---------- Navegação ----------
  var PAGINAS = { inicio: "DMOS", noticias: "Notícias", ajuda: "Ajuda", guias: "Guias" };
  function mostrar() {
    var nome = location.hash.slice(1);
    if (!PAGINAS[nome]) nome = "inicio";
    Object.keys(PAGINAS).forEach(function (p) { $("p-" + p).hidden = p !== nome; });
    document.querySelectorAll(".abas a").forEach(function (a) {
      if (a.dataset.aba === nome) a.setAttribute("aria-current", "page"); else a.removeAttribute("aria-current");
    });
    $("titulo").textContent = PAGINAS[nome];
    window.scrollTo(0, 0);
    if (nome === "noticias") noticiasAoAbrir();
  }
  window.addEventListener("hashchange", mostrar);
  document.querySelector(".abas").addEventListener("click", function (e) {
    var a = e.target.closest("a[data-aba]");
    if (!a) return;
    e.preventDefault();
    var nome = a.dataset.aba, atual = location.hash.slice(1);
    if (!PAGINAS[atual]) atual = "inicio";
    if (nome === atual) return;
    if (nome === "inicio") history.back();
    else if (atual === "inicio") location.hash = nome;
    else location.replace("#" + nome);
  });
  document.addEventListener("click", function (e) {
    var alvo = e.target.closest("[data-abrir], .resposta a[href]");
    if (!alvo) return;
    e.preventDefault();
    abrir(alvo.dataset.abrir || alvo.getAttribute("href"));
  });

  // ---------- Início: versão atual, a partir do CHANGELOG.md ----------
  // Lê a primeira secção «## 1.2 «Maré» (16 de novembro de 2026)» e as suas novidades.
  function lerNotas(md) {
    var m = /^## +(\S+) +«([^»]+)» *\(([^)]+)\)/m.exec(md || "");
    if (!m) return null;
    var resto = md.slice(m.index + m[0].length), fim = resto.search(/^## /m);
    var seccao = fim < 0 ? resto : resto.slice(0, fim);
    var nov = /### Novidades\s*([\s\S]*?)(?=^### |$(?![\s\S]))/m.exec(seccao);
    var itens = [];
    (nov ? nov[1] : "").split(/\n(?=- )/).forEach(function (bloco) {
      var b = /^- \*\*(.+?)\*\*\s*([\s\S]*)$/.exec(bloco.trim());
      if (!b) return;
      var texto = b[2].replace(/\s+/g, " ").replace(/\*\*/g, "").trim();
      var frase = /^(.*?[.!?])(\s|$)/.exec(texto);
      itens.push({ titulo: b[1].replace(/[.:]$/, ""), texto: frase ? frase[1] : texto });
    });
    return { versao: m[1], nome: m[2], data: m[3], itens: itens };
  }
  function mostrarVersao(md) {
    var n = lerNotas(md);
    if (!n) return false;
    $("versao-nome").textContent = "DMOS " + n.versao + " «" + n.nome + "»";
    $("versao-data").textContent = "Lançada a " + n.data;
    var ul = $("versao-novidades");
    ul.textContent = "";
    n.itens.forEach(function (i) {
      var li = el("li");
      li.appendChild(el("strong", null, i.titulo));
      li.appendChild(el("span", null, i.texto));
      ul.appendChild(li);
    });
    return true;
  }
  function inicio() {
    mostrarVersao(ler("notas", BUNDLE.changelog || ""));
    pedir(RAW + "CHANGELOG.md").then(function (r) {
      if (r.status === 200 && mostrarVersao(r.text)) guardar("notas", r.text);
    });
    var sha = ler("sha256", "");
    function mostrarSha(s) { if (/^[0-9a-f]{64}$/.test(s)) { $("sha256").textContent = s; $("verificacao").hidden = false; } }
    mostrarSha(sha);
    pedir(DOWNLOAD).then(function (r) {
      var m = /id="sha256">\s*([0-9a-f]{64})\s*</.exec(r.text);
      if (r.status === 200 && m) { guardar("sha256", m[1]); mostrarSha(m[1]); }
    });
    $("enviar-ligacao").addEventListener("click", function () {
      var texto = "Descarregar o DMOS, um Linux português: " + DOWNLOAD;
      if (nativo) nativo.share(texto);
      else if (navigator.share) navigator.share({ text: texto }).catch(function () {});
      else abrir(DOWNLOAD);
    });
  }

  // ---------- Notícias: as fontes do DMOS Hub ----------
  var FONTES_HUB = BUNDLE.sources || [];
  var FONTES = FONTES_HUB.slice();
  // As fontes acrescentadas pelo utilizador ficam a seguir às do Hub.
  function fontesProprias() { return ler("proprias", []); }
  function refazerFontes() { FONTES = FONTES_HUB.concat(fontesProprias()); }
  refazerFontes();
  var MAX_NOTICIAS = 30;
  // Texto simples de um fragmento XML (como sources.js do Hub). Títulos, ligações e datas são
  // curtos, por isso o texto é cortado antes das expressões regulares.
  function ponto(n) { return n > 0 && n <= 0x10FFFF && (n < 0xD800 || n > 0xDFFF) ? String.fromCodePoint(n) : "\uFFFD"; }
  function limpar(t) {
    if (!t) return "";
    t = t.slice(0, 4000).replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1").replace(/<[^>]+>/g, "");
    t = t.replace(/&#(\d{1,8});/g, function (m, n) { return ponto(parseInt(n, 10)); })
      .replace(/&#x([0-9a-f]{1,6});/gi, function (m, n) { return ponto(parseInt(n, 16)); })
      .replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&");
    // Alguns títulos trazem etiquetas escritas como entidades (&lt;em&gt;): saem depois de descodificar.
    return t.replace(/<\/?[a-z][^>]*>/gi, "").replace(/\s+/g, " ").trim();
  }
  // Conteúdo da primeira etiqueta com este nome, procurado com indexOf (tempo linear).
  function etiqueta(bloco, nome) {
    var baixo = bloco.toLowerCase(), abre = "<" + nome.toLowerCase(), de = 0;
    while (true) {
      var i = baixo.indexOf(abre, de);
      if (i < 0) return "";
      var c = baixo.charAt(i + abre.length);
      de = i + abre.length;
      if (c !== ">" && c !== " " && c !== "\n" && c !== "\t" && c !== "\r") continue;
      var fimAbre = baixo.indexOf(">", i);
      if (fimAbre < 0 || baixo.charAt(fimAbre - 1) === "/") return "";
      var fecha = baixo.indexOf("</" + nome.toLowerCase(), fimAbre);
      return fecha < 0 ? "" : bloco.slice(fimAbre + 1, fecha);
    }
  }
  // Os primeiros blocos <item> (RSS) ou <entry> (Atom) de um documento, sem expressões regulares.
  function blocosDe(xml, nome, max) {
    var baixo = xml.toLowerCase(), abre = "<" + nome, fecha = "</" + nome + ">", saida = [], de = 0;
    while (saida.length < max) {
      var i = baixo.indexOf(abre, de);
      if (i < 0) break;
      var c = baixo.charAt(i + abre.length);
      de = i + abre.length;
      if (c !== ">" && c !== " " && c !== "\n" && c !== "\t" && c !== "\r") continue;
      var f = baixo.indexOf(fecha, de);
      if (f < 0) break;
      saida.push(xml.slice(i, Math.min(f, i + 30000)));
      de = f + fecha.length;
    }
    return saida;
  }
  function lerFonte(xml, fonte) {
    var itens = [];
    xml = xml.slice(0, 1500000);
    var blocos = blocosDe(xml, "item", 15);
    if (!blocos.length) blocos = blocosDe(xml, "entry", 15);
    for (var i = 0; i < blocos.length; i++) {
      var b = blocos[i], link = limpar(etiqueta(b, "link"));
      if (!link) {
        var href = b.slice(0, 30000).match(/<link[^>]{0,2000}href="([^"]{1,2000})"/i);
        link = href ? href[1].replace(/&amp;/g, "&") : "";
      }
      var quando = Date.parse(limpar(etiqueta(b, "pubDate") || etiqueta(b, "updated") || etiqueta(b, "published") || etiqueta(b, "dc:date")));
      var titulo = limpar(etiqueta(b, "title"));
      if (titulo && /^https?:\/\//.test(link)) itens.push({ titulo: titulo.slice(0, 300), link: link, hora: isNaN(quando) ? 0 : quando, fonte: fonte.name });
    }
    return itens;
  }
  function haQuanto(hora) {
    if (!hora) return "";
    var min = Math.max(1, Math.round((Date.now() - hora) / 60000));
    if (min < 60) return "há " + min + " min";
    var h = Math.round(min / 60);
    if (h < 24) return "há " + h + " h";
    var d = Math.round(h / 24);
    return d === 1 ? "ontem" : "há " + d + " dias";
  }
  function fontesLigadas() {
    var ids = ler("fontes", []);
    return FONTES.filter(function (f) { return ids.indexOf(f.id) >= 0; });
  }
  function desenharFontes() {
    var caixa = $("fontes"), ligadas = ler("fontes", []);
    caixa.textContent = "";
    FONTES.forEach(function (f) {
      var b = el("button", { type: "button", "aria-pressed": ligadas.indexOf(f.id) >= 0 ? "true" : "false", title: f.kind }, f.name);
      b.addEventListener("click", function () {
        var ids = ler("fontes", []), i = ids.indexOf(f.id);
        if (i >= 0) ids.splice(i, 1); else ids.push(f.id);
        guardar("fontes", ids);
        desenharFontes();
        atualizarNoticias();
      });
      caixa.appendChild(b);
      if (f.propria) {
        // Uma fonte própria pode ser retirada da lista.
        var x = el("button", { type: "button", "aria-label": "Retirar " + f.name }, "×");
        x.addEventListener("click", function () {
          guardar("proprias", fontesProprias().filter(function (p) { return p.id !== f.id; }));
          guardar("fontes", ler("fontes", []).filter(function (id) { return id !== f.id; }));
          refazerFontes(); desenharFontes(); atualizarNoticias();
        });
        caixa.appendChild(x);
      }
    });
  }
  // Acrescenta uma fonte a partir do endereço do feed.
  function acrescentarFonte(endereco) {
    var erro = $("fonte-erro");
    function falhar(texto) { erro.textContent = texto; erro.hidden = false; }
    erro.hidden = true;
    var url;
    try { url = new URL(endereco.trim()); } catch (e) { return falhar("Esse endereço não é válido."); }
    if (url.protocol !== "https:") return falhar("O endereço tem de começar por https://");
    if (FONTES.some(function (f) { return f.url === url.href; })) return falhar("Essa fonte já está na lista.");
    if (nativo && nativo.allowSource && !nativo.allowSource(url.href)) return falhar("Esse endereço não pode ser usado.");
    var botao = $("fonte-form").querySelector("button");
    botao.disabled = true;
    pedir(url.href).then(function (r) {
      botao.disabled = false;
      var nome = url.hostname.replace(/^www\./, "");
      var titulo = limpar(etiqueta(r.text.slice(0, 20000), "title"));
      var fonte = { id: "p" + Date.now().toString(36), name: (titulo || nome).slice(0, 40), kind: "A sua fonte", url: url.href, propria: true };
      var tem = false;
      try { tem = r.status === 200 && lerFonte(r.text, fonte).length > 0; } catch (e) {}
      if (!tem) return falhar("Não encontrei notícias nesse endereço. Confirme que é um feed RSS ou Atom.");
      guardar("proprias", fontesProprias().concat([fonte]));
      guardar("fontes", ler("fontes", []).concat([fonte.id]));
      $("fonte-url").value = "";
      refazerFontes(); desenharFontes(); atualizarNoticias();
    });
  }
  // Notícias guardadas para ler depois.
  var aVerGuardadas = false;
  function guardadas() { return ler("guardadas", []); }
  function estaGuardada(n) { return guardadas().some(function (g) { return g.link === n.link; }); }
  function alternarGuardada(n) {
    var lista = guardadas();
    if (estaGuardada(n)) lista = lista.filter(function (g) { return g.link !== n.link; });
    else lista.unshift({ titulo: n.titulo, link: n.link, hora: n.hora, fonte: n.fonte });
    guardar("guardadas", lista.slice(0, 200));
    $("ver-guardadas").textContent = "Guardadas (" + guardadas().length + ")";
  }
  function desenharNoticias(lista) {
    var caixa = $("noticias");
    caixa.textContent = "";
    lista.forEach(function (n) {
      var b = el("button", { type: "button", "class": "noticia" });
      var cab = el("small", null, n.fonte);
      var ha = haQuanto(n.hora);
      if (ha) cab.appendChild(el("span", null, " · " + ha));
      b.appendChild(cab);
      b.appendChild(document.createTextNode(n.titulo));
      b.addEventListener("click", function () { abrir(n.link); });
      var linha = el("div", { "class": "noticia-linha" });
      var g = el("button", { type: "button", "class": "guardar", "aria-pressed": estaGuardada(n) ? "true" : "false", "aria-label": "Guardar para ler depois" }, "★");
      g.addEventListener("click", function () {
        alternarGuardada(n);
        g.setAttribute("aria-pressed", estaGuardada(n) ? "true" : "false");
        if (aVerGuardadas) desenharNoticias(guardadas());
      });
      linha.appendChild(b); linha.appendChild(g);
      caixa.appendChild(linha);
    });
  }
  var aCarregar = false, ultimaVez = 0;
  function atualizarNoticias() {
    if (aVerGuardadas) return;
    var ligadas = fontesLigadas(), estado = $("noticias-estado");
    $("atualizar").hidden = ligadas.length === 0;
    if (ligadas.length === 0) {
      desenharNoticias([]);
      guardar("noticias", []);
      estado.textContent = "Escolha pelo menos uma fonte.";
      return;
    }
    if (aCarregar) return;
    aCarregar = true;
    estado.textContent = "A carregar…";
    Promise.all(ligadas.map(function (f) {
      return pedir(f.url).then(function (r) {
        if (r.status !== 200) return { erro: r.status };
        try {
          var itens = lerFonte(r.text, f);
          itens.sort(function (a, b) { return b.hora - a.hora; });
          return itens;
        } catch (e) { return { erro: -1 }; }
      });
    })).then(function (porFonte) {
      aCarregar = false;
      // A escolha pode ter mudado durante o pedido: nesse caso, repete com a escolha nova.
      if (fontesLigadas().map(function (f) { return f.id; }).join() !== ligadas.map(function (f) { return f.id; }).join()) return atualizarNoticias();
      var erros = porFonte.filter(function (l) { return !Array.isArray(l); });
      var falhas = erros.length;
      var listas = porFonte.filter(function (l) { return Array.isArray(l) && l.length; });
      // Uma de cada fonte à vez, para uma fonte muito ativa não encher a lista (como no Hub).
      var juntas = [];
      for (var volta = 0; juntas.length < MAX_NOTICIAS && volta < 15; volta++) {
        listas.forEach(function (l) { if (volta < l.length && juntas.length < MAX_NOTICIAS) juntas.push(l[volta]); });
      }
      if (falhas === ligadas.length) {
        // Nada chegou: mostra o que estava guardado das fontes que continuam ligadas, e deixa tentar de novo.
        var nomes = ligadas.map(function (f) { return f.name; });
        var antigas = ler("noticias", []).filter(function (n) { return nomes.indexOf(n.fonte) >= 0; });
        var semRede = erros.every(function (e) { return e.erro === 0; });
        estado.textContent = (semRede ? "Sem ligação à internet." : "As fontes não responderam.") + (antigas.length ? " A mostrar as últimas notícias guardadas." : "");
        desenharNoticias(antigas);
        return;
      }
      ultimaVez = Date.now();
      guardar("noticias", juntas);
      desenharNoticias(juntas);
      estado.textContent = juntas.length ? (falhas ? falhas + " fonte(s) não responderam." : "Atualizado agora.") : "Sem notícias de momento.";
    });
  }
  function noticiasAoAbrir() {
    if (Date.now() - ultimaVez > 10 * 60000) atualizarNoticias();
  }
  function noticias() {
    desenharFontes();
    desenharNoticias(ler("noticias", []));
    $("atualizar").hidden = fontesLigadas().length === 0;
    $("noticias-estado").textContent = fontesLigadas().length ? "" : "Escolha pelo menos uma fonte.";
    $("atualizar").addEventListener("click", atualizarNoticias);
    $("fonte-form").addEventListener("submit", function (e) { e.preventDefault(); acrescentarFonte($("fonte-url").value); });
    var ver = $("ver-guardadas");
    ver.textContent = "Guardadas (" + guardadas().length + ")";
    ver.addEventListener("click", function () {
      aVerGuardadas = !aVerGuardadas;
      ver.setAttribute("aria-pressed", aVerGuardadas ? "true" : "false");
      $("atualizar").hidden = aVerGuardadas || fontesLigadas().length === 0;
      if (aVerGuardadas) {
        desenharNoticias(guardadas());
        $("noticias-estado").textContent = guardadas().length ? "" : "Ainda não guardou nenhuma notícia.";
      } else {
        desenharNoticias(ler("noticias", []));
        $("noticias-estado").textContent = "";
        atualizarNoticias();
      }
    });
  }

  // ---------- Ajuda: perguntas frequentes (a mesma lógica do assistente do site) ----------
  function faqValido(f) {
    return !!f && Array.isArray(f.entradas) && f.entradas.length > 0 && f.entradas.every(function (x) {
      return x && typeof x.id === "string" && typeof x.titulo === "string" && typeof x.resposta === "string" &&
        Array.isArray(x.palavras) && x.palavras.every(function (p) { return typeof p === "string"; });
    });
  }
  var faq = ler("faq", null);
  if (!faqValido(faq)) faq = faqValido(BUNDLE.faq) ? BUNDLE.faq : { entradas: [] };
  var SUGESTOES = ["pen-usb", "maquina-virtual", "flathub", "ecra-preto", "descarregar"];
  function normalizar(t) { return t.toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, ""); }
  function escaparRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }
  function procurar(texto) {
    var norm = normalizar(texto), pontuadas = [];
    (faq.entradas || []).forEach(function (entrada, ordem) {
      var pontos = 0;
      entrada.palavras.forEach(function (palavra) {
        var p = normalizar(palavra);
        if (new RegExp("(^|[^\\w-])" + escaparRe(p) + "(?![\\w-])").test(norm)) pontos += p.length;
      });
      if (pontos) pontuadas.push({ pontos: pontos, ordem: ordem, entrada: entrada });
    });
    pontuadas.sort(function (a, b) { return b.pontos - a.pontos || a.ordem - b.ordem; });
    return pontuadas.slice(0, 2).map(function (p) { return p.entrada; });
  }
  // Markdown mínimo e seguro: o texto é escapado antes de qualquer marcação.
  function escapar(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }
  function ligacao(url, texto) { return '<a href="' + url + '">' + texto + "</a>"; }
  function emLinha(s) {
    var codigos = [];
    s = s.replace(/`([^`]+)`/g, function (_, c) { codigos.push("<code>" + c + "</code>"); return "\u0000" + (codigos.length - 1) + "\u0000"; });
    s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
    s = s.replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)|(^|[^\w"=>])(https?:\/\/[^\s<)]+)/g, function (m, texto, url, antes, solto) {
      return url ? ligacao(url, texto) : antes + ligacao(solto, solto);
    });
    return s.replace(/\u0000(\d+)\u0000/g, function (_, i) { return codigos[+i]; });
  }
  function markdown(texto) {
    var html = "", linhas = escapar(texto).split("\n"), i = 0, lista = null, par = [];
    function fechar() {
      if (par.length) { html += "<p>" + emLinha(par.join("<br>")) + "</p>"; par = []; }
      if (lista) { html += "</" + lista + ">"; lista = null; }
    }
    while (i < linhas.length) {
      var linha = linhas[i];
      if (/^```/.test(linha)) {
        fechar(); var codigo = [];
        i++;
        while (i < linhas.length && !/^```/.test(linhas[i])) codigo.push(linhas[i++]);
        html += "<pre><code>" + codigo.join("\n") + "</code></pre>";
      } else if (/^\s*[-*] /.test(linha) || /^\s*\d+\. /.test(linha)) {
        var tipo = /^\s*\d+\. /.test(linha) ? "ol" : "ul";
        if (lista !== tipo) { fechar(); lista = tipo; html += "<" + tipo + ">"; }
        html += "<li>" + emLinha(linha.replace(/^\s*([-*]|\d+\.) /, "")) + "</li>";
      } else if (!linha.trim()) {
        fechar();
      } else {
        if (lista) { html += "</" + lista + ">"; lista = null; }
        par.push(linha);
      }
      i++;
    }
    fechar();
    return html;
  }
  function ligacaoComunidade(pergunta) {
    var letras = Array.from(pergunta);
    var titulo = letras.length > 100 ? letras.slice(0, 97).join("") + "…" : pergunta;
    return DISCUSSIONS + "/new?category=q-a&title=" + encodeURIComponent(titulo) + "&body=" + encodeURIComponent(pergunta);
  }
  function perguntar(pergunta) {
    pergunta = pergunta.trim();
    if (!pergunta) return;
    var caixa = $("respostas");
    caixa.appendChild(el("p", { "class": "pergunta-feita" }, pergunta));
    var cartao = el("article", { "class": "cartao resposta" });
    var encontradas = procurar(pergunta);
    cartao.innerHTML = encontradas.length
      ? encontradas.map(function (e) { return "<h4>" + escapar(e.titulo) + "</h4>" + markdown(e.resposta); }).join("")
      : "<p>Ainda não tenho uma resposta pronta para isso.</p>";
    var b = el("button", { "class": "botao fantasma pequeno", type: "button", "data-abrir": ligacaoComunidade(pergunta) },
      encontradas.length ? "Não resolveu? Perguntar na comunidade" : "Perguntar na comunidade");
    cartao.appendChild(b);
    caixa.appendChild(cartao);
    $("pergunta").value = "";
    $("pergunta").blur(); // fecha o teclado, para a resposta ficar à vista
    cartao.scrollIntoView({ behavior: "smooth", block: "start" });
  }
  function sugestoes() {
    var caixa = $("sugestoes");
    caixa.textContent = "";
    SUGESTOES.forEach(function (id) {
      var e = (faq.entradas || []).filter(function (x) { return x.id === id; })[0];
      if (!e) return;
      var b = el("button", { type: "button" }, e.titulo);
      b.addEventListener("click", function () { perguntar(e.titulo); });
      caixa.appendChild(b);
    });
  }
  function ajuda() {
    sugestoes();
    $("pergunta-form").addEventListener("submit", function (e) { e.preventDefault(); perguntar($("pergunta").value); });
    pedir(RAW + ".github/assistente/faq.json").then(function (r) {
      if (r.status !== 200) return;
      try { var novo = JSON.parse(r.text); if (faqValido(novo)) { faq = novo; guardar("faq", novo); sugestoes(); } } catch (e) {}
    });
  }

  // ---------- Guias: vídeos e atalhos ----------
  function desenharGuias(dados) {
    if (!dados || !Array.isArray(dados.videos) || !Array.isArray(dados.atalhos)) return false;
    var certo = dados.videos.every(function (v) { return v && typeof v.id === "string" && typeof v.titulo === "string" && typeof v.nota === "string" && typeof v.duracao === "string"; }) &&
      dados.atalhos.every(function (a) { return a && typeof a.faz === "string" && Array.isArray(a.teclas) && a.teclas.every(function (t) { return typeof t === "string"; }); });
    if (!certo) return false;
    var v = $("videos");
    v.textContent = "";
    dados.videos.forEach(function (video) {
      if (!/^[A-Za-z0-9_-]{11}$/.test(video.id)) return;
      var b = el("button", { type: "button", "data-abrir": "https://youtu.be/" + video.id }, video.titulo);
      b.appendChild(el("span", null, video.nota + " · " + video.duracao));
      v.appendChild(b);
    });
    var a = $("atalhos");
    a.textContent = "";
    dados.atalhos.forEach(function (atalho) {
      var linha = el("div", { "class": "atalho" }), teclas = el("span", { "class": "teclas" });
      atalho.teclas.forEach(function (t) { teclas.appendChild(el("kbd", null, t)); });
      linha.appendChild(teclas);
      linha.appendChild(el("span", null, atalho.faz));
      a.appendChild(linha);
    });
    return true;
  }
  function guias() {
    desenharGuias(ler("dados", BUNDLE.dados));
    pedir("https://dmos.cc/app/dados.json").then(function (r) {
      if (r.status !== 200) return;
      try { var d = JSON.parse(r.text); if (desenharGuias(d)) guardar("dados", d); } catch (e) {}
    });
  }

  // ---------- Cor de destaque ----------
  var CORES = [["turquesa", "Turquesa", "#2DD4BF"], ["coral", "Coral", "#FF8A70"], ["azul", "Azul", "#6DB3FF"], ["violeta", "Violeta", "#B79CFF"], ["verde", "Verde", "#5EDC8A"], ["ambar", "Âmbar", "#FFC15E"]];
  function aplicarCor(id) {
    if (id && id !== "turquesa") document.documentElement.dataset.cor = id; else delete document.documentElement.dataset.cor;
    document.querySelectorAll("#cores button").forEach(function (b) { b.setAttribute("aria-checked", b.dataset.cor === (id || "turquesa") ? "true" : "false"); });
  }
  function cores() {
    CORES.forEach(function (c) {
      var b = el("button", { type: "button", role: "radio", "aria-label": c[1], "data-cor": c[0] });
      b.style.setProperty("--amostra", c[2]);
      b.addEventListener("click", function () { guardar("cor", c[0]); aplicarCor(c[0]); });
      $("cores").appendChild(b);
    });
    aplicarCor(ler("cor", "turquesa"));
  }

  [cores, inicio, noticias, ajuda, guias, mostrar].forEach(function (f) { try { f(); } catch (e) {} });
})();
