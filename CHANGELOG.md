# Notas de versão

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
