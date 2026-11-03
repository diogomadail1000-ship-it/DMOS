// Gera as imagens do canal do YouTube a partir de canal.html.
// Antes: python3 art/gen_wallpaper.py dark 2560 1440 video/out/wallpaper-2560.png
// Uso: node video/render-canal.js            (faixa e foto do perfil)
//      node video/render-canal.js publicacao (imagem da publicação da comunidade)
const { chromium } = require("playwright");
const path = require("path");

const out = path.join(__dirname, "out");

(async () => {
  const browser = await chromium.launch();
  const jobs = process.argv[2] === "publicacao"
    ? [["publicacao.html", "", 1080, 1080, "publicacao-tutorial.png"]]
    : [["canal.html", "faixa", 2560, 1440, "faixa-canal.png"], ["canal.html", "perfil", 800, 800, "perfil-canal.png"]];
  for (const [html, name, w, h, file] of jobs) {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    await page.goto("file://" + path.join(__dirname, html) + (name ? "#" + name : ""));
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(out, file) });
    await page.close();
    console.log("Feito:", path.join(out, file));
  }
  await browser.close();
})();
