// DMOS — site: tema claro/escuro, galeria ampliada, copiar comandos e animação ao rolar.
(function () {
  "use strict";

  var root = document.documentElement;

  // Tema claro / escuro, como em Definições do Sistema > Tema Global.
  var toggle = document.querySelector(".theme-toggle");
  var themeColor = document.querySelector('meta[name="theme-color"]');
  function applyTheme(theme) {
    root.dataset.theme = theme;
    if (themeColor) themeColor.content = theme === "light" ? "#F3F6FA" : "#0C1122";
  }
  applyTheme(root.dataset.theme || "dark");
  toggle.addEventListener("click", function () {
    var next = root.dataset.theme === "light" ? "dark" : "light";
    applyTheme(next);
    try { localStorage.setItem("dmos-theme", next); } catch (e) {}
  });

  // Galeria ampliada.
  var shots = Array.prototype.slice.call(document.querySelectorAll(".shot"));
  var box = document.querySelector(".lightbox");
  var boxImg = box.querySelector("img");
  var boxCap = box.querySelector("figcaption");
  var current = 0;

  function show(i) {
    current = (i + shots.length) % shots.length;
    var s = shots[current];
    boxImg.src = s.dataset.src;
    boxImg.alt = s.querySelector("img").alt;
    boxCap.textContent = s.dataset.caption;
  }
  shots.forEach(function (s, i) {
    s.addEventListener("click", function () {
      show(i);
      if (typeof box.showModal === "function") box.showModal();
      else window.open(s.dataset.src, "_blank");
    });
  });
  box.querySelector(".lightbox-close").addEventListener("click", function () { box.close(); });
  box.querySelector(".prev").addEventListener("click", function () { show(current - 1); });
  box.querySelector(".next").addEventListener("click", function () { show(current + 1); });
  box.addEventListener("click", function (e) { if (e.target === box) box.close(); });
  box.addEventListener("keydown", function (e) {
    if (e.key === "ArrowLeft") show(current - 1);
    if (e.key === "ArrowRight") show(current + 1);
  });

  // Vídeo: os capítulos põem o leitor do YouTube a tocar a partir desse ponto.
  document.querySelectorAll(".video").forEach(function (box) {
    var frame = box.querySelector("iframe");
    box.closest(".video-layout").querySelectorAll(".chapters button").forEach(function (b) {
      b.addEventListener("click", function () {
        frame.src = "https://www.youtube.com/embed/" + box.dataset.id +
          "?rel=0&autoplay=1&start=" + parseInt(b.dataset.start, 10);
        if (box.getBoundingClientRect().top < 0) box.scrollIntoView({ behavior: "smooth", block: "center" });
      });
    });
  });

  // Publicidade: um banner no fim da página, no maior tamanho que couber no ecrã. Fica numa
  // moldura isolada: o anúncio não acede à página, não a pode redirecionar e só abre ligações
  // num separador novo.
  var ad = document.querySelector(".ad");
  if (ad) {
    var units = ad.dataset.units.split(" ").map(function (u) {
      var m = /^(\d+)x(\d+):([0-9a-f]{32})$/.exec(u);
      return m && { w: +m[1], h: +m[2], key: m[3] };
    }).filter(Boolean).sort(function (a, b) { return b.w - a.w; });
    var unit = units.filter(function (u) { return window.innerWidth >= u.w + 32; })[0];
    if (unit) {
      var adFrame = document.createElement("iframe");
      adFrame.width = unit.w; adFrame.height = unit.h; adFrame.title = "Publicidade";
      adFrame.setAttribute("sandbox", "allow-scripts allow-popups allow-popups-to-escape-sandbox");
      adFrame.setAttribute("referrerpolicy", "no-referrer");
      adFrame.srcdoc = '<!doctype html><html><body style="margin:0;overflow:hidden"><script>atOptions={key:"' + unit.key +
        '",format:"iframe",height:' + unit.h + ',width:' + unit.w + ',params:{}};<\/script><script src="' +
        ad.dataset.host.replace(/"/g, "") + unit.key + '"><\/script>' +
        // A moldura avisa a página se o anúncio chegou; sem anúncio, o espaço não aparece.
        '<script>setTimeout(function(){parent.postMessage({dmosAd:document.querySelectorAll("iframe,img,a,ins").length},"*")},4000)<\/script></body></html>';
      ad.classList.add("ad-vazio");
      window.addEventListener("message", function (e) {
        if (e.source === adFrame.contentWindow && e.data && e.data.dmosAd > 0) ad.classList.remove("ad-vazio");
      });
      ad.appendChild(adFrame);
      ad.hidden = false;
    }
  }

  // Copiar comandos do terminal.
  document.querySelectorAll(".copy").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var text = btn.parentNode.querySelector("code").textContent;
      var done = function () {
        btn.textContent = "Copiado";
        btn.classList.add("done");
        setTimeout(function () { btn.textContent = "Copiar"; btn.classList.remove("done"); }, 1500);
      };
      if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, function () {});
    });
  });

  // Entrada suave das secções.
  if ("IntersectionObserver" in window && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    var targets = document.querySelectorAll(".section-head, .card, .shot, .app-group, .feature-text, .mini, .try-card, .specs, .table-wrap, .pending, .terminal, .palette");
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
          io.unobserve(entry.target);
        }
      });
    }, { rootMargin: "0px 0px -8% 0px" });
    targets.forEach(function (el) { el.classList.add("reveal"); io.observe(el); });
  }
})();
