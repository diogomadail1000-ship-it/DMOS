# Notas de versão

## 1.2 «Maré» (16 de novembro de 2026)

### Novidades

- **DMOS IA, um assistente de pesquisa.** Aplicação nova, na dock: faz-se a pergunta por palavras
  nossas e a resposta vem com as páginas em que se baseia, numeradas e a um clique. Quem responde
  é o Claude, da Anthropic, que pesquisa na web quando a pergunta o pede. Cada pessoa usa a sua
  própria chave da API da Anthropic, paga à utilização: a ISO não traz chave nenhuma, e sem chave
  nada é enviado. A chave fica só no computador, num ficheiro que só o utilizador consegue ler.
  Pode escolher-se o modelo (Claude Opus 5.5, Sonnet 5.5 ou Haiku 5.5), e o DMOS Hub ganhou o
  campo «Pergunte à IA…».
- **Cor e fundo no assistente.** Página nova no Bem-vindo ao DMOS, com três fundos (o Maré e os
  novos Aurora e Âmbar) e seis cores de destaque, que se aplicam de imediato a todo o sistema. O
  assistente passa a ter seis passos.
- **Painel de aplicações em ecrã inteiro.** É o primeiro botão da dock e abre também com
  **Super + A**: todas as aplicações, por categoria, com pesquisa.
- **Em inglês na sessão em inglês.** O assistente, o DMOS Hub e a DMOS IA aparecem em inglês
  quando a sessão está nessa língua, por exemplo com «Try DMOS (English)» no menu de arranque.

### Correções

- **Favoritos do menu de aplicações.** Passam a ser os do DMOS: Firefox, DMOS IA, Dolphin, Konsole,
  LibreOffice Writer, Discover e Definições. Desde a 1.0 o menu mostrava os favoritos de origem do
  Plasma, porque a configuração do DMOS chegava tarde demais para ser lida.
- No menu e no painel de aplicações, a categoria «Ajuda» aparecia em inglês, tal como o campo de
  pesquisa do painel.
- No tema claro, o texto dos botões principais do assistente saía a preto sobre o verde-azulado;
  passou a branco.

### Testes

- Testada no VMware Workstation com cliques e teclado reais dentro da sessão, e não só com
  comandos: o assistente de ponta a ponta, a DMOS IA (chave, perguntas, parar, mudar de modelo), o
  painel de aplicações com **Super + A** e o campo do DMOS Hub.
- Instalação completa a partir da ISO publicada, com «Apagar disco», e arranque do sistema
  instalado: a conta nova recebe o assistente, a dock, os favoritos e a DMOS IA.
- A DMOS IA foi testada contra um servidor de ensaio incluído no repositório, sem chave real. A
  ligação ao serviço da Anthropic propriamente dita não foi experimentada.

### Atualizações

- Pacotes do Debian 13 «trixie» atualizados até à data da compilação, com as correções de
  segurança publicadas desde a 1.1.

## 1.1 «Maré» (4 de novembro de 2026)

### Novidades

- **Flathub ativado de origem.** O Discover mostra as aplicações do Flathub logo no primeiro
  arranque, sem comandos no terminal. A ISO já traz o catálogo do Flathub, por isso as
  aplicações aparecem mesmo antes da primeira atualização, que o Discover faz sozinho.
- **Página "Aplicações populares" no assistente Bem-vindo ao DMOS.** Oito aplicações a um clique:
  Spotify, Visual Studio Code, Steam, Discord, GIMP, OBS Studio, Telegram e Google Chrome. Cada
  uma abre no Discover, onde se veem os detalhes antes de instalar. O assistente passa a ter
  cinco passos.

### Correções

- **Instalador:** a legenda das partições lê-se. O Calamares desenha esse texto sempre a preto, e
  no tema escuro ficava sobre um fundo escuro; agora fica sobre uma faixa clara.

### Testes

- Primeira versão testada também no VMware Workstation, com aceleração 3D: sessão de
  demonstração, instalação completa e arranque do sistema instalado.

### Atualizações

- Pacotes do Debian 13 «trixie» atualizados até à data da compilação, com as correções de
  segurança publicadas desde a 1.0.

## 1.0 «Maré» (2 de novembro de 2026)

Primeira versão.

- Debian 13 «trixie» com KDE Plasma 6 em Wayland, em português de Portugal.
- Identidade visual própria, gerada a partir do código: menu de arranque (GRUB), animação de
  arranque (Plymouth), ecrã de início de sessão (SDDM), estilo Plasma em vidro com variantes
  clara e escura, decoração de janelas, wallpaper procedural «Maré» e instalador Calamares.
- Assistente **Bem-vindo ao DMOS** e painel **DMOS Hub** com hora, saudação e notícias das fontes
  escolhidas.
- Traduções em falta nos ecrãs de bloqueio e de sair.
- ISO híbrida para BIOS e UEFI, com sessão de demonstração.
