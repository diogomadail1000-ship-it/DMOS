# DMOS para iPhone e iPad

A mesma aplicação companheira do DMOS que existe para [Android](../app-android/), para o iOS 15 ou mais
recente. A interface é exatamente a mesma (`../app-android/www`): aqui está só a parte nativa.

## Como está feita

Uma janela com uma `WKWebView` que mostra a página local. O código Swift (`DMOS.swift`) dá à página o
mesmo que o código Java dá no Android, com o mesmo nome (`window.DmosNative`): ler as fontes de notícias
sem as restrições de origem, abrir ligações no Safari e partilhar texto. Nenhuma página da internet é
carregada dentro da aplicação. Os pedidos à rede só são aceites em HTTPS, para endereços públicos, e para
o site do DMOS, o repositório no GitHub, as fontes de notícias do Hub e as que o utilizador acrescentar.

Não há projeto do Xcode: `build.sh` compila o Swift com `swiftc`, o ícone com `actool`, e monta o pacote.

## Compilar

Precisa de um Mac com o Xcode e do Node.js.

```bash
app-ios/build.sh
```

```bash
app-ios/build.sh simulador
```

O primeiro cria `app-ios/build/dmos-ios-<versão>.ipa`; o segundo, uma aplicação para o simulador do Xcode.
Sem Mac, o fluxo [«Aplicação iOS»](../.github/workflows/ios.yml) faz as duas coisas num Mac do GitHub
sempre que este código muda, experimenta a aplicação no simulador e guarda o `.ipa` como artefacto.

## Instalar

O `.ipa` **não vai assinado**. O iOS só corre aplicações assinadas com uma conta Apple, por isso quem
instala assina: o [Sideloadly](https://sideloadly.io/) e a [AltStore](https://altstore.io/) fazem-no com
o ID Apple de cada um. Com um ID Apple gratuito a assinatura dura sete dias.

Para instalar sem computador (pela App Store, pelo TestFlight ou por uma ligação com perfil de
instalação) é preciso inscrever o projeto no Apple Developer Program, que é pago (99 USD por ano), e
assinar o `.ipa` com o certificado dessa conta. O código está pronto para isso; falta só a conta.

## Estado dos testes

- O fluxo do GitHub compila para iPhone e para o simulador e experimenta a aplicação no simulador de
  iPhone: a página abre, a ponte nativa responde, a versão do DMOS e o código SHA-256 chegam pela rede,
  três fontes de notícias são ligadas e têm de aparecer notícias, e as preferências ficam guardadas.
- **Ainda não foi experimentada num iPhone verdadeiro**, nem a instalação com o Sideloadly ou a AltStore.
