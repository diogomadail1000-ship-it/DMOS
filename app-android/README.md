# DMOS para Android

Aplicação companheira do DMOS para o telemóvel. Não é o DMOS em si: serve para acompanhar o projeto e
ter à mão o que ajuda a usar o DMOS no computador.

- **Início:** a versão atual e as novidades, lidas das [notas de versão](../CHANGELOG.md), e a ligação de
  descarga pronta a enviar para o computador, com o código SHA-256 da ISO.
- **Notícias:** as mesmas dez fontes do painel DMOS Hub. Só as que ligar são contactadas, diretamente a
  partir do telemóvel, sem servidor do DMOS pelo meio.
- **Ajuda:** as perguntas frequentes do projeto, com a mesma lógica do assistente do site, e a passagem
  para as Discussões quando não há resposta.
- **Guias:** os vídeos do canal e os atalhos de teclado do DMOS.

Só pede a permissão de internet, não recolhe dados e não tem publicidade nem rastreio.

## Como está feita

Uma `Activity` com uma `WebView` que mostra uma página local (`www/`). O código Java
(`src/cc/dmos/app/MainActivity.java`) dá à página o que um navegador não dá: ler as fontes de notícias
sem as restrições de origem, abrir ligações no navegador e partilhar texto. Nenhuma página da internet
é carregada dentro da aplicação. Os pedidos à rede só são aceites em HTTPS e para o site do DMOS, o
repositório no GitHub e as fontes de notícias.

Não usa bibliotecas nem código nativo, por isso o APK tem cerca de 80 KB e serve qualquer processador.
Funciona a partir do Android 7.

O conteúdo vem do resto do repositório, para não haver duas cópias: as fontes de
`org.dmos.hub/contents/code/sources.js`, as perguntas de `.github/assistente/faq.json`, as notas de
`CHANGELOG.md` e os guias de `docs/app/dados.json`. A aplicação traz uma cópia de tudo para funcionar
sem rede e atualiza-a quando há ligação. Os vídeos e os atalhos mudam-se em `docs/app/dados.json`, sem
publicar uma versão nova.

## Compilar

Precisa de um JDK 17 ou mais recente, do Node.js e do Android SDK com `platforms;android-35` e
`build-tools;35.0.0`.

```bash
ANDROID_HOME=/caminho/para/android-sdk app-android/build.sh
```

O APK fica em `app-android/build/`. Sem mais nada, é assinado com uma chave de teste criada na hora.
Para publicar, assine com a chave do projeto:

```bash
DMOS_KEYSTORE=/caminho/dmos-android.keystore DMOS_KEY_ALIAS=dmos DMOS_KEYSTORE_PASS=... ANDROID_HOME=... app-android/build.sh
```

A chave **não está no repositório** e não pode estar. Todas as versões têm de ser assinadas com a
mesma chave, senão o Android recusa a atualização.

## Estado dos testes

A interface foi testada no Chromium com uma ponte simulada, incluindo notícias reais de quatro fontes.
O APK foi verificado com o `aapt2` e o `apksigner`. **Ainda não foi experimentado num telemóvel nem num
emulador.**
