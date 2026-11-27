#!/usr/bin/env bash
# Compila a aplicação DMOS para iPhone e iPad. Precisa de um Mac com o Xcode e do Node.js.
# Não usa projeto do Xcode: compila o Swift e monta o pacote à mão, como a aplicação Android.
#
#   app-ios/build.sh             → app-ios/build/dmos-ios-<versão>.ipa (para iPhone e iPad, sem assinatura)
#   app-ios/build.sh simulador   → app-ios/build/simulador/DMOS.app (para o simulador do Xcode)
#
# O .ipa não vai assinado: quem o instala assina-o com a sua conta Apple (AltStore, Sideloadly).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
VERSAO="1.0"
NUMERO="1"
MINIMO="15.0"

if [ "${1:-}" = "simulador" ]; then
  SDK=iphonesimulator; ALVO="$(uname -m)-apple-ios$MINIMO-simulator"; PLATAFORMA=iPhoneSimulator; OUT="$HERE/build/simulador"
else
  SDK=iphoneos; ALVO="arm64-apple-ios$MINIMO"; PLATAFORMA=iPhoneOS; OUT="$HERE/build/aparelho"
fi
APP="$OUT/DMOS.app"
rm -rf "$OUT"
mkdir -p "$APP/www"

# 1. A interface é a da aplicação Android, e os dados vêm do resto do repositório.
cp -R "$ROOT/app-android/www/." "$APP/www/"
DMOS_BUILD="ios-$NUMERO-$(date -u +%Y%m%d%H%M)" node "$ROOT/app-android/gerar-dados.js" "$ROOT" "$APP/www/data"

# 2. O programa.
xcrun -sdk "$SDK" swiftc -target "$ALVO" -O -parse-as-library -module-name DMOS "$HERE/DMOS.swift" -o "$APP/DMOS"

# 3. O ícone e a ficha da aplicação.
xcrun actool "$HERE/Assets.xcassets" --compile "$APP" --platform "$SDK" --minimum-deployment-target "$MINIMO" \
  --app-icon AppIcon --target-device iphone --target-device ipad --output-partial-info-plist "$OUT/icone.plist" >/dev/null
sed -e "s/__VERSAO__/$VERSAO/" -e "s/__NUMERO__/$NUMERO/" -e "s/__PLATAFORMA__/$PLATAFORMA/" "$HERE/Info.plist" > "$APP/Info.plist"
/usr/libexec/PlistBuddy -c "Merge $OUT/icone.plist" "$APP/Info.plist"
plutil -lint "$APP/Info.plist" >/dev/null
printf 'APPL????' > "$APP/PkgInfo"

if [ "$SDK" = iphonesimulator ]; then
  codesign --force --sign - "$APP"
  echo "Feito: $APP"
else
  IPA="$HERE/build/dmos-ios-$VERSAO.ipa"
  rm -rf "$OUT/Payload" "$IPA"
  mkdir "$OUT/Payload"
  cp -R "$APP" "$OUT/Payload/"
  (cd "$OUT" && zip -qry "$IPA" Payload)
  echo "Feito: $IPA ($(stat -f %z "$IPA") bytes)"
  shasum -a 256 "$IPA"
fi
