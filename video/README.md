# Vídeos

Os vídeos do canal, em 1920x1080 a 30 fps (o Short em 1080x1920), feitos a partir das capturas de `docs/screenshots/`:

- **Apresentação** (cerca de 65 s): `scene.html`, texto em `youtube.txt`.
- **Tutorial** «Como experimentar e instalar o DMOS» (cerca de 2 min 50 s): `tutorial.html`, texto em
  `youtube-tutorial.txt`. As cenas, os destaques e as legendas estão na lista `SCENES`.
- **7 dicas para o dia a dia** (cerca de 1 min 52 s): `dicas.html`, texto em `youtube-dicas.txt`. Os atalhos são
  os do KDE Plasma 6. As ilustrações animadas estão em `artHtml` e `animateArt`.
- **Programas essenciais** (cerca de 2 min 12 s): `programas.html`, texto em `youtube-programas.txt`.
- **Personalizar o DMOS** (cerca de 1 min 51 s): `personalizar.html`, texto em `youtube-personalizar.txt`.
  Estes dois vídeos usam o estilo e o motor partilhados `lista.css` e `lista.js`.
- **Comparativo de desempenho**: `desempenho.html`. Só usa números medidos com `medir.sh`. Veja `COMPARATIVO.md`.

- `scene.html`: as cenas, as legendas e a miniatura, desenhadas em HTML. `seek(t)` mostra o instante `t`.
- `music.py`: gera a música, original e sem direitos de terceiros (cerca de -14 LUFS).
- `render.js`: desenha cada fotograma no Chromium com o Playwright e junta tudo com o ffmpeg.
- `youtube.txt`: título, descrição, capítulos e etiquetas para o YouTube.

Precisa de Node.js com o Playwright, do Chromium, do ffmpeg, do Python 3 com o NumPy e das fontes
Inter e JetBrains Mono instaladas.

```bash
node video/render.js video/out
```

```bash
node video/render.js video/out tutorial.html dmos-tutorial
```

```bash
node video/render.js video/out dicas.html dmos-dicas
```

```bash
node video/render.js video/out programas.html dmos-programas
```

```bash
node video/render.js video/out personalizar.html dmos-personalizar
```

Cada um cria, em `video/out/`, o vídeo (`NOME.mp4`), a miniatura (`NOME-miniatura.png`) e a música
(`NOME-musica.wav`). A pasta `video/out/`
não entra no repositório.

## Imagens do canal

`canal.html` desenha a imagem de faixa (2560x1440, com o texto na área de 1546x423 que o YouTube
mostra em todos os ecrãs) e a foto do perfil (800x800). O fundo é o wallpaper "Maré", que tem de ser
gerado primeiro:

```bash
python3 art/gen_wallpaper.py dark 2560 1440 video/out/wallpaper-2560.png
node video/render-canal.js
```

Cria `video/out/faixa-canal.png` e `video/out/perfil-canal.png`.

## Short

`short.html` é um Short vertical (1080x1920, cerca de 30 s), com cortes rápidos e música a 100 bpm. O
texto fica fora das zonas que o YouTube tapa com botões. O título e a descrição estão em
`youtube-short.txt`.

```bash
node video/render.js video/out short.html dmos-short
```
