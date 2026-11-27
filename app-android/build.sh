#!/usr/bin/env bash
# Compila a aplicação DMOS para Android sem Gradle: aapt2, javac, d8, zipalign e apksigner.
# Precisa de um JDK 17 ou mais recente e do Android SDK (plataforma 35 e build-tools 35.0.0).
#
#   ANDROID_HOME=/caminho/para/android-sdk ./build.sh
#
# Assinatura: defina DMOS_KEYSTORE, DMOS_KEY_ALIAS e DMOS_KEYSTORE_PASS para assinar com a chave de
# publicação. Sem elas, o APK é assinado com uma chave de teste criada na hora, que serve para
# experimentar mas não para publicar: as atualizações têm de ter sempre a mesma chave.
set -euo pipefail

VERSION_NAME="1.0"
VERSION_CODE=1
MIN_SDK=24
TARGET_SDK=34

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SDK="${ANDROID_HOME:?defina ANDROID_HOME com a pasta do Android SDK}"
BT="$SDK/build-tools/35.0.0"
JAR="$SDK/platforms/android-35/android.jar"
OUT="$HERE/build"
rm -rf "$OUT"
mkdir -p "$OUT/gen" "$OUT/classes" "$OUT/dex" "$OUT/assets/www/data"

# 1. Dados que acompanham a aplicação, para funcionar sem rede: as fontes do DMOS Hub, as perguntas
#    frequentes, as notas de versão e os guias. Vêm do resto do repositório, para não haver duas cópias.
cp -r "$HERE/www/." "$OUT/assets/www/"
node - "$ROOT" "$OUT/assets/www/data" <<'NODE'
const fs = require("fs"), path = require("path");
const [root, out] = process.argv.slice(2);
const hub = fs.readFileSync(path.join(root, "live/config/includes.chroot_after_packages/usr/share/plasma/plasmoids/org.dmos.hub/contents/code/sources.js"), "utf8");
const list = new Function(hub.replace(".pragma library", "") + "; return list;")();
const sources = list.map(({ id, name, kind, url }) => ({ id, name, kind, url }));
if (!sources.length || sources.some(s => !/^https:\/\//.test(s.url))) throw new Error("fontes inválidas");
const bundle = {
  sources,
  faq: JSON.parse(fs.readFileSync(path.join(root, ".github/assistente/faq.json"), "utf8")),
  changelog: fs.readFileSync(path.join(root, "CHANGELOG.md"), "utf8"),
  dados: JSON.parse(fs.readFileSync(path.join(root, "docs/app/dados.json"), "utf8")),
};
fs.writeFileSync(path.join(out, "sources.json"), JSON.stringify(sources));
fs.writeFileSync(path.join(out, "bundle.js"), "window.DMOS_BUNDLE = " + JSON.stringify(bundle).replace(/</g, "\\u003c") + ";\n");
NODE

# 2. Recursos e manifesto.
"$BT/aapt2" compile --dir "$HERE/res" -o "$OUT/res.zip"
"$BT/aapt2" link -o "$OUT/dmos.unaligned.apk" -I "$JAR" --manifest "$HERE/AndroidManifest.xml" -A "$OUT/assets" \
  --min-sdk-version "$MIN_SDK" --target-sdk-version "$TARGET_SDK" \
  --version-code "$VERSION_CODE" --version-name "$VERSION_NAME" --java "$OUT/gen" "$OUT/res.zip"

# 3. Código: Java simples, sem bibliotecas, por isso o APK serve qualquer processador.
mkdir -p "$OUT/gen/cc/dmos/app"
printf 'package cc.dmos.app;\n\nfinal class BuildInfo {\n    static final String VERSION = "%s";\n    private BuildInfo() {}\n}\n' "$VERSION_NAME" > "$OUT/gen/cc/dmos/app/BuildInfo.java"
javac -nowarn -source 11 -target 11 -classpath "$JAR" -d "$OUT/classes" $(find "$HERE/src" "$OUT/gen" -name '*.java') 2>&1 | grep -v "bootstrap class path\|^1 warning\|JAVA_TOOL_OPTIONS" || true
"$BT/d8" --release --min-api "$MIN_SDK" --lib "$JAR" --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')
(cd "$OUT/dex" && zip -q -j "$OUT/dmos.unaligned.apk" classes.dex)

# 4. Alinhar e assinar.
"$BT/zipalign" -p -f 4 "$OUT/dmos.unaligned.apk" "$OUT/dmos.aligned.apk"
if [ -n "${DMOS_KEYSTORE:-}" ]; then
  KS="$DMOS_KEYSTORE"; ALIAS="${DMOS_KEY_ALIAS:?defina DMOS_KEY_ALIAS}"; export KS_PASS="${DMOS_KEYSTORE_PASS:?defina DMOS_KEYSTORE_PASS}"
else
  echo "AVISO: sem DMOS_KEYSTORE; a assinar com uma chave de teste. Este APK não é para publicar." >&2
  KS="$OUT/teste.keystore"; ALIAS="teste"; export KS_PASS="teste-dmos"
  keytool -genkeypair -keystore "$KS" -alias "$ALIAS" -storepass "$KS_PASS" -keypass "$KS_PASS" -keyalg RSA -keysize 2048 \
    -validity 365 -dname "CN=DMOS teste" >/dev/null 2>&1
fi
APK="$OUT/dmos-android-$VERSION_NAME.apk"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias "$ALIAS" --ks-pass env:KS_PASS --key-pass env:KS_PASS --out "$APK" "$OUT/dmos.aligned.apk"
"$BT/apksigner" verify "$APK"
rm -f "$OUT/dmos.unaligned.apk" "$OUT/dmos.aligned.apk" "$APK.idsig"
echo "Feito: $APK ($(du -h "$APK" | cut -f1))"
