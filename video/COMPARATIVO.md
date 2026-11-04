# Vídeo comparativo de desempenho

O vídeo `desempenho.html` só mostra números medidos. Sem medições, `render.js` recusa-se a gerá-lo.

## 1. Medir

Para cada distribuição a comparar (o DMOS e pelo menos mais uma):

1. Crie uma máquina virtual **sempre com as mesmas definições**: por exemplo 4 GB de RAM, 2 CPUs, disco de
   40 GB, a mesma aceleração 3D e o mesmo programa de virtualização.
2. Instale a distribuição com as opções por omissão e a área de trabalho que vem com ela.
3. Reinicie, entre na sessão e espere 2 minutos sem abrir nada.
4. Copie `video/medir.sh` para a máquina virtual, abra um terminal e corra:

   ```bash
   bash medir.sh "Nome a mostrar no vídeo"
   ```

5. Repita os passos 3 e 4 mais duas vezes. São três medições, e o vídeo usa a mediana.

Cada medição acrescenta uma linha a `medicoes.jsonl`, na pasta onde correu o script. Traga esses
ficheiros para o computador onde gera os vídeos.

## 2. Gerar os dados e o vídeo

```bash
python3 video/medicoes-para-video.py "4 GB de RAM, 2 CPUs, VirtualBox" dmos.jsonl outra.jsonl
```

```bash
node video/render.js video/out desempenho.html dmos-desempenho
```

O primeiro comando escreve `video/desempenho-dados.js`. O texto entre aspas descreve as condições e aparece
no vídeo. O DMOS fica destacado a verde-água quando o nome tem «DMOS».

## O que é medido

| Medida | Como |
|---|---|
| Memória usada | coluna `used` do `free -m`, 2 minutos depois de entrar |
| Tempo de arranque | total do `systemd-analyze` |
| Espaço ocupado | `df` da partição raiz |
| Pacotes | `dpkg-query`, `rpm -qa` ou `pacman -Q` |

Numa máquina virtual, os resultados servem para comparar sistemas entre si, não para prometer números num
computador real. Diga isso no vídeo e na descrição.
