#!/bin/bash
# Installs the build and art tools in the builder. Safe to run repeatedly.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    live-build debootstrap squashfs-tools xorriso mtools dosfstools \
    grub-pc-bin grub-efi-amd64-bin grub-common rsync \
    python3 python3-numpy python3-pil python3-scipy librsvg2-bin fonts-inter imagemagick \
    qemu-system-x86 qemu-utils ovmf \
    xvfb xdotool x11-utils libgl1-mesa-dri libglx-mesa0 >/dev/null
