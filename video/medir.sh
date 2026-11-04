#!/usr/bin/env bash
# Mede uma distribuição Linux para o vídeo comparativo (video/desempenho.html).
#
# Como usar, em cada distribuição a comparar:
#   1. Crie a máquina virtual SEMPRE com as mesmas definições (por exemplo 4 GB de RAM, 2 CPUs,
#      disco de 40 GB, aceleração 3D igual) e instale a distribuição com as opções por omissão.
#   2. Reinicie, entre na sessão e espere 2 minutos sem abrir nada.
#   3. Abra um terminal e corra:  bash medir.sh "Nome a mostrar"
#   4. Repita o passo 2 e 3 mais duas vezes (reinicie antes de cada uma). O script guarda as três
#      medições e o vídeo usa a mediana.
# O resultado vai para medicoes.jsonl, na pasta atual.
set -euo pipefail

name="${1:-$(. /etc/os-release && echo "${PRETTY_NAME}")}"

# Memória usada (MB), como a coluna "used" do free.
ram=$(free -m | awk '/^Mem:/ {print $3}')

# Tempo de arranque (s) até ao fim do systemd. Inclui firmware e loader quando o systemd os conhece.
boot=$(systemd-analyze 2>/dev/null | sed -n 's/.*= \([0-9.]*\)\(min \)\?\([0-9.]*\)s.*/\1 \3/p' | head -1 | awk '{ if (NF == 2) print $1 * 60 + $2; else print $1 }')
if [ -z "$boot" ]; then boot=null; fi

# Espaço usado na partição raiz (MB).
disk=$(df -BM --output=used / | tail -1 | tr -dc '0-9')

# Pacotes instalados pelo gestor do sistema.
if command -v dpkg-query >/dev/null; then pkgs=$(dpkg-query -f '.\n' -W | wc -l)
elif command -v rpm >/dev/null; then pkgs=$(rpm -qa | wc -l)
elif command -v pacman >/dev/null; then pkgs=$(pacman -Q | wc -l)
else pkgs=null; fi

kernel=$(uname -r)
desktop="${XDG_CURRENT_DESKTOP:-?} ${XDG_SESSION_TYPE:-}"
when=$(date -u +%Y-%m-%dT%H:%M:%SZ)

line=$(printf '{"name":"%s","ram_mb":%s,"boot_s":%s,"disk_mb":%s,"packages":%s,"kernel":"%s","desktop":"%s","when":"%s"}' \
  "$name" "$ram" "$boot" "$disk" "$pkgs" "$kernel" "$desktop" "$when")
echo "$line" | tee -a medicoes.jsonl
