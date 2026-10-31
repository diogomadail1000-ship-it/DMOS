#!/bin/bash
# Generates every derived asset (images, fonts, theme files) into the live-build tree.
# Usage: gen_assets.sh WORKDIR
set -euo pipefail

ART="$(cd "$(dirname "$0")" && pwd)"
WORK="$1"
OUT="$WORK/config/includes.chroot_after_packages"
CACHE="${DMOS_ART_CACHE:-/root/dmos-art-cache}"
TOOL_STAMP="$(sha256sum "$ART/gen_wallpaper.py" | cut -c1-16)"
mkdir -p "$CACHE"

# Wallpapers take about a minute at 4K, so they are cached against the generator's hash.
for theme in dark light; do
    cached="$CACHE/$theme-$TOOL_STAMP.jpg"
    if [ ! -f "$cached" ]; then
        python3 -I "$ART/gen_wallpaper.py" "$theme" 3840 2160 "$cached"
    fi
done
WP="$OUT/usr/share/wallpapers/DMOS-Mare"
mkdir -p "$WP/contents/images" "$WP/contents/images_dark"
cp "$CACHE/light-$TOOL_STAMP.jpg" "$WP/contents/images/3840x2160.jpg"
cp "$CACHE/dark-$TOOL_STAMP.jpg" "$WP/contents/images_dark/3840x2160.jpg"
convert "$CACHE/dark-$TOOL_STAMP.jpg" -resize 640x360 -quality 90 "$WP/contents/screenshot.jpg"
cat > "$WP/metadata.json" <<'EOF'
{
    "KPlugin": {
        "Authors": [{ "Name": "DMOS" }],
        "Id": "DMOS-Mare",
        "License": "CC-BY-SA-4.0",
        "Name": "Maré"
    }
}
EOF

python3 -I "$ART/gen_theme.py" "$OUT"

# The light look-and-feel differs from the dark one only by its names and defaults.
LNF="$OUT/usr/share/plasma/look-and-feel"
rm -rf "$LNF/org.dmos.mare.light"
cp -r "$LNF/org.dmos.mare.dark" "$LNF/org.dmos.mare.light"
sed -i -e 's/org\.dmos\.mare\.dark/org.dmos.mare.light/' -e 's/Maré Escuro/Maré Claro/' \
    -e 's/em tons de noite sobre o mar/em tons de manhã sobre o mar/' "$LNF/org.dmos.mare.light/metadata.json"
sed -i -e 's/DMOSDark/DMOSLight/' -e 's/Papirus-Dark/Papirus-Light/' -e 's/DMOS-Dark/DMOS-Light/' \
    -e 's/org\.dmos\.mare\.dark/org.dmos.mare.light/' "$LNF/org.dmos.mare.light/contents/defaults"

# Logo everywhere it is needed.
ICON="$OUT/usr/share/icons/hicolor"
mkdir -p "$ICON/scalable/apps" "$OUT/usr/share/pixmaps" "$OUT/usr/share/sddm/themes/dmos/assets"
install -m 644 "$ART/logo.svg" "$ICON/scalable/apps/dmos-logo.svg"
install -m 644 "$ART/logo.svg" "$OUT/usr/share/sddm/themes/dmos/assets/logo.svg"
for flavour in dark light; do
    mkdir -p "$LNF/org.dmos.mare.$flavour/contents/splash/images"
    install -m 644 "$ART/logo.svg" "$LNF/org.dmos.mare.$flavour/contents/splash/images/logo.svg"
done
rsvg-convert -w 256 -h 256 "$ART/logo.svg" -o "$OUT/usr/share/pixmaps/dmos-logo.png"

# Default account picture: the mark on a dark disc, instead of the distribution default.
mkdir -p "$OUT/etc/skel"
cat > "$CACHE/avatar.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 256 256">
<circle cx="128" cy="128" r="128" fill="#11172B"/>
<image x="64" y="64" width="128" height="128" xlink:href="data:image/svg+xml;base64,$(base64 -w0 "$ART/logo.svg")"/>
</svg>
EOF
rsvg-convert -w 256 -h 256 "$CACHE/avatar.svg" -o "$OUT/etc/skel/.face.icon"

# Plymouth.
PLY="$OUT/usr/share/plymouth/themes/dmos"
mkdir -p "$PLY"
rsvg-convert -w 300 -h 300 "$ART/logo.svg" -o "$PLY/logo.png"
convert "$CACHE/dark-$TOOL_STAMP.jpg" -resize 1920x1080 -modulate 55,90 "$PLY/background.png"
convert -size 8x8 xc:'#FFFFFF30' "$PLY/track.png"
convert -size 8x512 gradient:'#5EEAD4-#FF8A70' -rotate -90 "$PLY/tide.png"

# GRUB: one theme for the live menu and one for installed systems.
make_grub_theme() {
    local dir="$1"
    rm -rf "$dir"
    # Latin only: gfxterm sizes its grid by the widest glyph, and Inter's widest ones
    # leave no columns on screens below 1920 pixels, which drops GRUB to a text menu.
    local range="0x20-0x7E,0xA0-0x17F,0x2010-0x2027"
    mkdir -p "$dir"
    cp "$ART/grub-theme.txt" "$dir/theme.txt"
    # JPEG: a dithered 1080p PNG takes seconds to load from a CD or a slow disk.
    convert "$CACHE/dark-$TOOL_STAMP.jpg" -resize 1920x1080 -modulate 62,95 -quality 88 "$dir/background.jpg"
    rsvg-convert -w 88 -h 88 "$ART/logo.svg" -o "$dir/logo.png"
    # The name GRUB matches is "<family> <style> <size>", hence -n "Inter" for "Inter Regular 24".
    grub-mkfont -r "$range" -n "Inter" -s 24 -o "$dir/inter-regular-24.pf2" /usr/share/fonts/opentype/inter/Inter-Regular.otf
    grub-mkfont -r "$range" -n "Inter" -s 16 -o "$dir/inter-regular-16.pf2" /usr/share/fonts/opentype/inter/Inter-Regular.otf
    grub-mkfont -r "$range" -n "Inter Light" -s 40 -o "$dir/inter-light-40.pf2" /usr/share/fonts/opentype/inter/InterDisplay-Light.otf
    python3 -I "$ART/gen_grub_select.py" "$dir"
}
make_grub_theme "$WORK/config/bootloaders/grub-pc/live-theme"
make_grub_theme "$OUT/boot/grub/themes/dmos"

# Calamares branding images.
CAL="$OUT/etc/calamares/branding/dmos"
mkdir -p "$CAL"
rsvg-convert -w 128 -h 128 "$ART/logo.svg" -o "$CAL/logo.png"
convert "$CACHE/dark-$TOOL_STAMP.jpg" -gravity center -crop 3000x1500+300+250 +repage -resize 1200x600 "$CAL/welcome.png"
