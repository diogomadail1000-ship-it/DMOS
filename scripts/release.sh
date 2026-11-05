#!/bin/bash
# Gathers a finished build into dist/<version>/, ready to upload to SourceForge:
# the ISO, the source archives, SHA256SUMS and the folder's README.md.
#   release.sh 1.1
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: release.sh <version>}"
OUT="$SRC/dist/$VERSION"

shopt -s nullglob
files=("$SRC"/dist/dmos-"$VERSION"-*)
if [ ${#files[@]} -eq 0 ]; then
    echo "Não há ficheiros dmos-$VERSION-* em dist/. Compile primeiro com build.sh iso." >&2
    exit 1
fi
mkdir -p "$OUT"
mv -v "${files[@]}" "$OUT/"
rm -f "$SRC/dist/SHA256SUMS"

cd "$OUT"
sha256sum dmos-"$VERSION"-* > SHA256SUMS
sha256sum -c --quiet SHA256SUMS
echo "SHA256SUMS verificado."

# The release notes for this version, from CHANGELOG.md, become the folder's README on SourceForge.
notes="$(awk -v v="## $VERSION " 'index($0, v) == 1 { on = 1; next } on && /^## / { exit } on' "$SRC/CHANGELOG.md")"
iso="dmos-$VERSION-mare-amd64.hybrid.iso"
size="$(awk -v b="$(stat -c %s "$iso")" 'BEGIN { printf "%.1f GB", b / 1e9 }' | tr . ,)"
cat > README.md <<EOF
# DMOS $VERSION «Maré»

Distribuição Linux baseada no Debian 13 «trixie», com KDE Plasma 6 e identidade visual própria.

**Descarregar:** \`$iso\` ($size). Arranca em BIOS e UEFI, com sessão de demonstração.
Grave-a numa pen com o Rufus (modo DD) ou o balenaEtcher, ou use-a numa máquina virtual.

Para confirmar que a ISO chegou inteira, descarregue também o \`SHA256SUMS\` para a mesma pasta:

    sha256sum -c SHA256SUMS --ignore-missing

No Windows: \`Get-FileHash $iso\` no PowerShell, e compare com a linha da ISO no \`SHA256SUMS\`.

## O que mudou
$notes

## Código-fonte

Os ficheiros \`dmos-$VERSION-mare-source.*\` têm o código-fonte de todos os pacotes da ISO, como pede a GPL.
O código do próprio DMOS está em https://github.com/diogomadail1000-ship-it/DMOS

Site: https://diogomadail1000-ship-it.github.io/DMOS/
EOF

ls -la "$OUT"
