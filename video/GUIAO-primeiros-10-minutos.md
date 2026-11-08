# Guião: «Os primeiros 10 minutos depois de instalar o DMOS»

Vídeo longo da semana de 14 de novembro. Substitui, com um só título de pesquisa, os três vídeos
pós-instalação (programas, dicas, personalizar), que separados não tiveram alcance. Duração alvo:
3 min 30 s a 4 min. Formato: cenas HTML como `programas.html` (motor `lista.css` e `lista.js`),
com capturas reais do DMOS 1.1 sempre que possível.

## Título e miniatura

- **Título:** «Acabei de instalar Linux, e agora? Os primeiros 10 minutos no DMOS (Debian 13 + KDE Plasma 6)»
- **Miniatura:** captura do ambiente de trabalho, logótipo, faixa «Tutorial», texto grande «E agora?»
  e um relógio «10 min», no mesmo padrão das miniaturas dos tutoriais de máquina virtual.

## Estrutura (com os tempos aproximados)

| Tempo | Cena | O que se vê | O que se diz (legenda) |
|---|---|---|---|
| 0:00 | Gancho | Ambiente de trabalho acabado de instalar | «Instalou o DMOS. O que fazer nos primeiros 10 minutos para ficar tudo a seu gosto e seguro.» |
| 0:08 | Minuto 1: atualizações | Discover › Atualizações | «Primeiro, as atualizações. Abra o Discover, separador Atualizações, Atualizar tudo. Demora uns minutos: deixe correr enquanto faz o resto.» Terminal em alternativa: `sudo apt update && sudo apt full-upgrade`. |
| 0:35 | Minuto 2: Wi-Fi e Bluetooth | Ícone de rede na barra, lista de redes; Bluetooth | «Ligue-se à sua rede e emparelhe o rato ou os auscultadores. O DMOS traz firmware Intel, Realtek, Atheros, Broadcom e MediaTek.» |
| 0:55 | Minuto 3: o assistente | Bem-vindo ao DMOS, páginas Tema e Aplicações populares | «Se saltou o assistente, volte a ele no menu: tema claro ou escuro e oito aplicações a um clique.» |
| 1:20 | Minuto 4 e 5: programas | Discover com Flathub; mostrar 4 instalações | «O Flathub já vem ligado. Os quatro que quase toda a gente quer: Firefox já lá está; Spotify, Steam, GIMP e OBS instalam-se no Discover ou com `flatpak install flathub …`.» Identificadores no ecrã. |
| 2:00 | Minuto 6: ficheiros e contas | Dolphin; Definições › Contas Online (opcional) | «Os seus ficheiros do Windows: se partilha o disco, aparecem no Dolphin em Dispositivos. Para o Google Drive ou Nextcloud, Definições › Contas Online.» |
| 2:25 | Minuto 7: três atalhos | Animação dos atalhos | «Só três para já: Alt + Espaço procura tudo; Super + ← e → encaixam janelas; Super + W mostra tudo o que está aberto.» |
| 2:50 | Minuto 8: dock e menu | Fixar aplicações na dock; favoritos | «Fixe na dock o que usa todos os dias: botão direito no ícone › Fixar.» |
| 3:05 | Minuto 9: luz noturna e energia | Definições › Cores e temas › Luz noturna; Energia | «Luz noturna automática, e em portáteis o perfil de energia na barra.» |
| 3:20 | Minuto 10: cópia de segurança | Definições › Cópia de segurança, ou Pontos de verificação na máquina virtual | «Antes de experimentar mais: uma cópia de segurança. Em máquina virtual, um ponto de verificação chega.» |
| 3:35 | Fecho | Logótipo, site, Discussões | «Dúvidas? O assistente do site responde na hora. Próximo vídeo: DMOS ao lado do Windows, em dual boot.» |

## Notas de produção

- Cada «minuto» é um cartão numerado 1 a 10, com o número grande à esquerda, como em `programas.html`.
- Capturas novas necessárias (tirar na 1.1, tema escuro, 1920x1080): Discover › Atualizações; menu de
  redes aberto; Dolphin com Dispositivos; Definições › Luz noturna. As restantes já existem em
  `docs/screenshots`.
- Comandos sempre em bloco de terminal e também na descrição.
- Não prometer datas da versão 1.2.

## Descrição para o YouTube (rascunho)

Acabou de instalar o DMOS? Estes são os dez primeiros passos: atualizações, rede, assistente, programas
do Flathub, ficheiros, atalhos, dock, luz noturna e cópia de segurança. Em 10 minutos fica tudo a seu
gosto.

Capítulos: um por minuto, com os tempos finais do vídeo.

⬇️ Descarregar o DMOS: https://sourceforge.net/projects/dmos/files/latest/download
🛠️ Tutorial de instalação: https://youtu.be/glLq_Hi9V1A
🪟 No VMware: https://youtu.be/j-9vXxhwyh4 · No Hyper-V: https://youtu.be/NariiOTl-0o
🌊 Site: https://diogomadail1000-ship-it.github.io/DMOS/
💬 Dúvidas: https://github.com/diogomadail1000-ship-it/DMOS/discussions

Etiquetas: DMOS, depois de instalar Linux, primeiros passos Linux, Debian 13, KDE Plasma 6, Flathub,
Discover, tutorial Linux, Linux português
