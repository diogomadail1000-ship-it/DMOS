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
- **Lançamento da 1.1** (cerca de 63 s): `lancamento-1-1.html`, texto em `youtube-lancamento-1-1.txt`. Usa as
  novidades do `CHANGELOG.md` e as capturas 12 a 15.
- **Instalar no VMware** (cerca de 2 min 16 s): `vmware.html`, texto em `youtube-vmware.txt`. As janelas do VMware são
  ilustrações (cenas do tipo `dialog`); a configuração é a testada na 1.1.
- **Instalar no Hyper-V** (cerca de 2 min 10 s): `hyperv.html`, texto em `youtube-hyperv.txt`. Gémeo do tutorial do
  VMware, com as janelas do Windows em português; a configuração é a usada no teste da 1.1 (geração 2, Arranque
  Seguro desligado, memória dinâmica desligada).
- **Comunidade**: `comunidade-tutorial.txt` e `comunidade-distrowatch.txt` têm as publicações e sondagens para o
  separador Comunidade do canal. `GUIAO-primeiros-10-minutos.md` é o guião do próximo vídeo longo.
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

## Short «Escuro ou claro?»

`short-tema.html` é um segundo Short (1080x1920, 20 s) que compara os temas DMOS Maré Escuro e Claro com as
capturas reais e acaba a pedir uma resposta nos comentários. Texto em `youtube-short-tema.txt`.

```bash
node video/render.js video/out short-tema.html dmos-short-tema
```

## Short «Linux sem apagar o Windows»

`short-vmware.html` é um terceiro Short (1080x1920, 23 s) para quem tem Windows e quer experimentar o DMOS sem
risco: mostra o DMOS numa janela do VMware, os três passos e remete para o tutorial do VMware. Texto em
`youtube-short-vmware.txt`.

```bash
node video/render.js video/out short-vmware.html dmos-short-vmware
```
