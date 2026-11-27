// Gera os dados que acompanham a aplicação (data/bundle.js e data/sources.json) a partir do resto
// do repositório: as fontes do DMOS Hub, as perguntas frequentes, as notas de versão e os guias.
// Uso: DMOS_BUILD=<carimbo> node gerar-dados.js <raiz do repositório> <pasta de saída>
const fs = require("fs"), path = require("path");
const [root, out] = process.argv.slice(2);
const hub = fs.readFileSync(path.join(root, "live/config/includes.chroot_after_packages/usr/share/plasma/plasmoids/org.dmos.hub/contents/code/sources.js"), "utf8");
const list = new Function(hub.replace(".pragma library", "") + "; return list;")();
const sources = list.map(({ id, name, kind, url }) => ({ id, name, kind, url }));
if (!sources.length || sources.some(s => !/^https:\/\//.test(s.url))) throw new Error("fontes inválidas");
const bundle = {
  build: process.env.DMOS_BUILD,
  sources,
  faq: JSON.parse(fs.readFileSync(path.join(root, ".github/assistente/faq.json"), "utf8")),
  changelog: fs.readFileSync(path.join(root, "CHANGELOG.md"), "utf8"),
  dados: JSON.parse(fs.readFileSync(path.join(root, "docs/app/dados.json"), "utf8")),
};
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, "sources.json"), JSON.stringify(sources));
fs.writeFileSync(path.join(out, "bundle.js"), "window.DMOS_BUNDLE = " + JSON.stringify(bundle).replace(/</g, "\\u003c") + ";\n");
