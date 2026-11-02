# Vídeo de apresentação

Vídeo de cerca de 65 segundos, em 1920x1080 a 30 fps, feito a partir das capturas de `docs/screenshots/`.

- `scene.html`: as cenas, as legendas e a miniatura, desenhadas em HTML. `seek(t)` mostra o instante `t`.
- `music.py`: gera a música, original e sem direitos de terceiros (cerca de -14 LUFS).
- `render.js`: desenha cada fotograma no Chromium com o Playwright e junta tudo com o ffmpeg.
- `youtube.txt`: título, descrição, capítulos e etiquetas para o YouTube.

Precisa de Node.js com o Playwright, do Chromium, do ffmpeg, do Python 3 com o NumPy e das fontes
Inter e JetBrains Mono instaladas.

```bash
node video/render.js video/out
```

Cria `video/out/dmos-mare.mp4`, `video/out/miniatura.png` e `video/out/musica.wav`. A pasta `video/out/`
não entra no repositório.
