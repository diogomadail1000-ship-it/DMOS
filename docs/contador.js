// DMOS — contador anónimo de descargas. Conta quantas vezes os botões de descarga são usados e
// quantas vezes a página de descarga é aberta. Não usa cookies, não guarda nada no navegador e não
// envia nenhum identificador: é só um pedido que soma um a um número. Com «Não rastrear» ou o
// Controlo de Privacidade Global ligados no navegador, não conta nada.
// Os totais veem-se em https://dmos.cc/estatisticas/.
(function () {
  "use strict";
  var BASE = "https://abacus.jasoncameron.dev/hit/dmos-cc/";
  if (navigator.doNotTrack === "1" || window.doNotTrack === "1" || navigator.globalPrivacyControl) return;

  function contar(chave) {
    try {
      // keepalive: o pedido termina mesmo que a página mude logo a seguir ao clique.
      fetch(BASE + chave, { keepalive: true, credentials: "omit", referrerPolicy: "no-referrer", cache: "no-store" }).catch(function () {});
    } catch (e) {}
  }

  var pagina = document.documentElement.getAttribute("data-contador") || "inicio";
  if (pagina === "download") contar("pagina-download");
  if (pagina === "app") contar("pagina-app");

  document.addEventListener("click", function (e) {
    var a = e.target.closest ? e.target.closest("a[href]") : null;
    if (!a) return;
    var destino = a.getAttribute("href");
    if (/drive\.usercontent\.google\.com\/download|drive\.google\.com\/file/.test(destino)) contar(/1Nmlq_qE3JB/.test(destino) ? "iso-" + pagina : "iso-anterior");
    else if (/\.apk$/.test(destino)) contar("apk");
    else if (/\.ipa$/.test(destino)) contar("ipa");
  }, true);
})();
