// Motor partilhado dos vídeos em lista (personalizar.html, programas.html).
// A página define window.VIDEO = { mark, intro, index, items, bonus, outro, artHtml(art), animateArt(s, el, a, local) }
// antes de carregar este ficheiro. Cada item: { label, title, desc, keys?, where?, cmd?, art }.
// pre: cenas extra antes dos itens; bonus: cenas extra depois (ambas sem número).
(function () {
  var V = window.VIDEO;
  var FADE = 0.7;
  var ACT = V.act || 3.0; // instante, dentro da cena, em que a ilustração começa a agir

  document.getElementById("wm").innerHTML = '<img src="../art/logo.svg" alt="">' + V.mark;
  var ICON_WHERE = '<svg viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5L21 21"/></svg>';

  var SCENES = [{ type: "intro", dur: V.introDur || 5.5 }, { type: "index", dur: 7 }];
  (V.pre || []).forEach(function (b) { b.type = "bonus"; b.dur = b.dur || 10; SCENES.push(b); });
  V.items.forEach(function (it, i) { it.type = "tip"; it.n = i + 1; it.dur = it.dur || V.itemDur || 11.5; SCENES.push(it); });
  (V.bonus || []).forEach(function (b) { b.type = "bonus"; b.dur = b.dur || 10; SCENES.push(b); });
  SCENES.push({ type: "outro", dur: 8 });
  window.SCENES = SCENES;

  function keysHtml(keys) {
    return keys.map(function (k) { return '<div class="key">' + k + '</div>'; }).join('<span class="plus">+</span>');
  }
  function pad(n) { return n < 10 ? "0" + n : "" + n; }

  var total = V.items.length;
  var stage = document.getElementById("stage");
  var start = 0;
  SCENES.forEach(function (s) {
    s.start = start;
    start += s.dur - FADE;
    var el = document.createElement("div");
    el.className = "scene";
    var bg = '<div class="backdrop"></div><div class="dim"></div>';
    if (s.type === "tip" || s.type === "bonus") {
      el.innerHTML = bg + '<div class="left"><div class="num tide-text">' + (s.type === "tip" ? pad(s.n) : (s.num || "+")) + '</div>' +
        '<div class="label">' + (s.type === "tip" ? V.itemWord + " " + s.n + " de " + total + " · " : "") + s.label + '</div><div class="title">' + s.title + '</div>' +
        '<div class="desc">' + s.desc + '</div>' +
        (s.keys ? '<div class="keys">' + keysHtml(s.keys) + '</div>' : "") +
        (s.where ? '<div><div class="where">' + ICON_WHERE + '<span>' + s.where + '</span></div></div>' : "") +
        (s.cmd ? '<div class="cmd">' + s.cmd + '</div>' : "") + '</div>' +
        '<div class="stagebox">' + V.artHtml(s.art, s) + '</div>';
    } else if (s.type === "intro") {
      el.innerHTML = bg + '<div class="center"><img class="logo" src="../art/logo.svg" alt=""><div class="big">' + V.intro.title + '</div><div class="sub">' + V.intro.sub + '</div></div>';
    } else if (s.type === "index") {
      el.innerHTML = bg + '<div class="center"><div class="big" style="font-size:72px;margin-top:0">' + (V.index || "Neste vídeo") + '</div><div class="grid7">' +
        V.items.map(function (t, i) { return '<div class="gi"><b>' + (i + 1) + '</b>' + (t.short || t.title) + '</div>'; }).join("") +
        (V.bonus && V.bonus.length ? '<div class="gi"><b>+</b>' + V.bonusIndex + '</div>' : "") + '</div></div>';
    } else {
      el.innerHTML = bg + '<div class="center"><img class="logo" src="../art/logo.svg" alt="" style="width:140px;height:140px"><div class="big" style="font-size:84px">' + V.outro.title + '</div>' +
        '<div class="sub">' + V.outro.sub + '</div>' +
        '<div class="links"><div class="link"><em>Site</em>diogomadail1000-ship-it.github.io/DMOS</div><div class="link"><em>Código</em>github.com/diogomadail1000-ship-it/DMOS</div></div></div>';
    }
    stage.appendChild(el);
    s.el = el;
  });
  window.TOTAL = start + FADE;

  function clamp(x) { return Math.max(0, Math.min(1, x)); }
  function ease(x) { x = clamp(x); return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; }
  function out(x) { x = clamp(x); return 1 - Math.pow(1 - x, 3); }
  function lerp(a, b, k) { return a + (b - a) * k; }
  function rise(el, local, t0, dist) {
    if (!el) return;
    var k = out((local - t0) / 0.7);
    el.style.opacity = k;
    el.style.transform = "translateY(" + ((1 - k) * (dist || 30)) + "px)";
  }
  window.L = { clamp: clamp, ease: ease, out: out, lerp: lerp, rise: rise,
    box: function (el, x, y, w, h) { el.style.left = x + "px"; el.style.top = y + "px"; el.style.width = w + "px"; el.style.height = h + "px"; } };

  window.seek = function (t) {
    SCENES.forEach(function (s, i) {
      var local = t - s.start, el = s.el;
      if (local < 0 || local > s.dur) { el.style.display = "none"; return; }
      el.style.display = "block";
      var fin = i === 0 ? clamp(local / 0.6) : clamp(local / FADE);
      var fout = i === SCENES.length - 1 ? clamp((s.dur - local) / 1.0) : clamp((s.dur - local) / FADE);
      el.style.opacity = Math.min(ease(fin), ease(fout));
      el.style.zIndex = i;
      var p = local / s.dur;
      el.querySelector(".backdrop").style.transform = "scale(" + lerp(1.05, 1.15, p) + ") translateX(" + lerp(-20, 20, p) + "px)";
      if (s.type === "tip" || s.type === "bonus") {
        var num = el.querySelector(".num");
        var kn = out((local - 0.15) / 0.6);
        num.style.opacity = kn;
        num.style.transform = "scale(" + lerp(0.7, 1, kn) + ")";
        num.style.transformOrigin = "left center";
        rise(el.querySelector(".label"), local, 0.35, 20);
        rise(el.querySelector(".title"), local, 0.5, 26);
        rise(el.querySelector(".desc"), local, 0.75, 22);
        rise(el.querySelector(".keys"), local, 1.0, 20);
        rise(el.querySelector(".where"), local, 1.2, 20);
        rise(el.querySelector(".cmd"), local, 1.2, 20);
        el.querySelectorAll(".key").forEach(function (k, j) {
          k.classList.toggle("down", local > 1.8 + j * 0.35 && local < ACT + 0.9);
        });
        var box = el.querySelector(".stagebox");
        var kb = out((local - 0.4) / 0.8);
        box.style.opacity = kb;
        box.style.transform = "translateX(" + (1 - kb) * 60 + "px)";
        if (V.animateArt) V.animateArt(s, el, local - ACT, local);
      } else if (s.type === "index") {
        rise(el.querySelector(".big"), local, 0.2, 26);
        el.querySelectorAll(".gi").forEach(function (g, j) { rise(g, local, 0.6 + j * 0.16, 24); });
      } else {
        var logo = el.querySelector(".logo");
        var kl = out((local - 0.2) / 1.0);
        logo.style.opacity = kl;
        logo.style.transform = "scale(" + lerp(0.7, 1, kl) + ")";
        rise(el.querySelector(".big"), local, 0.7, 40);
        rise(el.querySelector(".sub"), local, 1.3, 30);
        el.querySelectorAll(".link").forEach(function (l, j) { rise(l, local, 2.0 + j * 0.35, 30); });
      }
    });
    var wm = document.getElementById("wm");
    var first = SCENES[2 + (V.pre ? V.pre.length : 0)].start, last = SCENES[SCENES.length - 1].start;
    wm.style.opacity = 0.8 * Math.min(clamp((t - first - 0.5) / 0.8), clamp((last - t) / 0.8));
  };
  window.thumbnail = function () { document.body.classList.add("thumb"); };
  window.seek(location.hash ? parseFloat(location.hash.slice(1)) || 0 : 0);
})();
