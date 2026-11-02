// Gera o vídeo do DMOS: desenha cada fotograma de scene.html no Chromium e junta-os com o ffmpeg.
// Uso: node video/render.js PASTA_DE_SAIDA
const { chromium } = require("playwright");
const { spawn, execFileSync } = require("child_process");
const path = require("path");

const FPS = 30;
const outDir = path.resolve(process.argv[2] || "video/out");
const here = __dirname;

(async () => {
  require("fs").mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  page.on("pageerror", (e) => console.error("Erro na página:", e.message));
  await page.goto("file://" + path.join(here, "scene.html"));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(500);
  const total = await page.evaluate(() => window.TOTAL);

  const music = path.join(outDir, "musica.wav");
  execFileSync("python3", [path.join(here, "music.py"), String(total), music], { stdio: "inherit" });

  const video = path.join(outDir, "dmos-mare.mp4");
  const ff = spawn("ffmpeg", [
    "-y", "-loglevel", "error",
    "-f", "image2pipe", "-framerate", String(FPS), "-c:v", "mjpeg", "-i", "-",
    "-i", music,
    "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", String(FPS),
    "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart",
    video,
  ], { stdio: ["pipe", "inherit", "inherit"] });

  const frames = Math.round(total * FPS);
  for (let i = 0; i < frames; i++) {
    await page.evaluate((t) => window.seek(t), i / FPS);
    const buf = await page.screenshot({ type: "jpeg", quality: 95 });
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once("drain", r));
    if (i % 150 === 0) console.log(`fotograma ${i}/${frames}`);
  }
  ff.stdin.end();
  await new Promise((r) => ff.on("close", r));

  // Miniatura para o YouTube (1280x720).
  await page.evaluate(() => window.thumbnail());
  const big = path.join(outDir, "miniatura-1920.png");
  await page.screenshot({ path: big });
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", big, "-vf", "scale=1280:720:flags=lanczos", path.join(outDir, "miniatura.png")]);
  require("fs").unlinkSync(big);

  await browser.close();
  console.log("Feito:", video);
})();
