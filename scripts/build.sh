#!/bin/bash
# Builds the DMOS ISO. Runs as root inside the "dmos-builder" WSL instance.
#   build.sh chroot   only install the system (useful for theme development)
#   build.sh iso      full build; the ISO and the source archive are copied to <project>/dist
#                     (then scripts/release.sh <version> gathers them for SourceForge)
#   build.sh clean    drops the chroot and binary trees but keeps the package cache
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${DMOS_WORK:-/root/dmos-build}"
ACTION="${1:-iso}"

sync_tree() {
    mkdir -p "$WORK/config"
    rsync -a --delete "$SRC/live/auto/" "$WORK/auto/"
    chmod +x "$WORK"/auto/*
    for dir in package-lists hooks bootloaders includes.chroot_after_packages includes.binary; do
        if [ -d "$SRC/live/config/$dir" ]; then
            rsync -a --delete "$SRC/live/config/$dir/" "$WORK/config/$dir/"
        fi
    done
    # Files coming from a Windows folder have meaningless modes: set them explicitly.
    find "$WORK/config/hooks" -type f -exec chmod 755 {} + 2>/dev/null || true
    INCLUDES="$WORK/config/includes.chroot_after_packages"
    find "$INCLUDES" -type d -exec chmod 755 {} +
    find "$INCLUDES" -type f -exec chmod 644 {} +
    chmod 755 "$INCLUDES"/usr/bin/* "$INCLUDES"/usr/lib/live/config/*
    if [ -x "$SRC/art/gen_assets.sh" ] || [ -f "$SRC/art/gen_assets.sh" ]; then
        bash "$SRC/art/gen_assets.sh" "$WORK"
    fi
    (cd "$WORK" && lb config)
}

case "$ACTION" in
    chroot)
        sync_tree
        cd "$WORK"
        lb bootstrap
        lb chroot
        ;;
    iso)
        sync_tree
        cd "$WORK"
        lb build
        mkdir -p "$SRC/dist"
        cp -v "$WORK"/dmos-*.iso "$SRC/dist/"
        # Code-source of every package in the ISO (lb config --source true). It must be published next to
        # the ISO: the GPL asks that whoever distributes the binaries also offers the matching sources.
        shopt -s nullglob
        sources=("$WORK"/dmos-*source*)
        if [ ${#sources[@]} -gt 0 ]; then
            cp -v "${sources[@]}" "$SRC/dist/"
        else
            echo "Aviso: não encontrei o arquivo de código-fonte em $WORK." >&2
        fi
        (cd "$SRC/dist" && sha256sum dmos-* > SHA256SUMS)
        ;;
    clean)
        cd "$WORK"
        lb clean
        ;;
    *)
        echo "usage: $0 {chroot|iso|clean}" >&2
        exit 2
        ;;
esac
