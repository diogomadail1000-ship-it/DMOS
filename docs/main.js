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
    var targets = document.querySelectorAll(".section-head, .card, .shot, .app-group, .try-card, .specs, .table-wrap, .pending, .terminal, .palette");
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
