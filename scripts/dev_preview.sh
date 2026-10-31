#!/bin/bash
# Theme development rig: runs the real desktop from a chroot copy under Xvfb and
# takes screenshots, without building an ISO. Runs as root in "dmos-builder".
#   dev_preview.sh desktop|sddm|splash [output.png]
# Environment: WAIT (seconds before the shot), HOST_CMD (run on the builder with
# DISPLAY set, e.g. xdotool), POST_CMD (run inside the chroot), POST_WAIT, LNF.
set -uo pipefail

# All mounts live in a private namespace: they disappear with this script and
# can never propagate back to the WSL instance.
if [ -z "${DMOS_NS:-}" ]; then
    exec env DMOS_NS=1 unshare --mount --propagation private bash "$0" "$@"
fi

SRC="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${DMOS_WORK:-/root/dmos-build}"
DEV=/root/dmos-dev
MODE="${1:-desktop}"
SHOT="${2:-$SRC/art/preview/$MODE.png}"
WAIT="${WAIT:-45}"
LNF="${LNF:-org.dmos.mare.dark}"
DISPLAY_NUM=:7

if [ ! -d "$DEV/usr" ]; then
    cp -a "$WORK/chroot" "$DEV"
fi

# Refresh the theme: static files, then generated ones.
rsync -a "$SRC/live/config/includes.chroot_after_packages/" "$WORK/config/includes.chroot_after_packages/"
bash "$SRC/art/gen_assets.sh" "$WORK" 2>&1 | grep -v 'font feature' || true
rsync -a "$WORK/config/includes.chroot_after_packages/" "$DEV/"

cleanup() {
    pkill -f "Xvfb $DISPLAY_NUM" 2>/dev/null
    chroot "$DEV" pkill -u dmos 2>/dev/null
    [ -f "$DEV/run/dbus/pid" ] && kill "$(cat "$DEV/run/dbus/pid")" 2>/dev/null
    sleep 1
}
trap cleanup EXIT

mount -t proc proc "$DEV/proc"
mount --rbind /sys "$DEV/sys"
mount --rbind /dev "$DEV/dev"
mount -t tmpfs tmpfs "$DEV/run"
mkdir -p "$DEV/tmp/.X11-unix" /tmp/.X11-unix
mount --bind /tmp/.X11-unix "$DEV/tmp/.X11-unix"

chroot "$DEV" id dmos >/dev/null 2>&1 || chroot "$DEV" useradd -m -s /bin/bash -c "DMOS" dmos
if [ "${FRESH:-1}" = 1 ]; then
    rm -rf "$DEV/home/dmos"
    cp -a "$DEV/etc/skel" "$DEV/home/dmos"
    chroot "$DEV" chown -R dmos:dmos /home/dmos
fi
chroot "$DEV" sh -c 'mkdir -p /run/dbus /run/user/1000; chown dmos /run/user/1000; chmod 700 /run/user/1000; dbus-daemon --system --fork 2>/dev/null; true'

Xvfb "$DISPLAY_NUM" -screen 0 1920x1080x24 +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
sleep 2

in_chroot() {
    chroot --userspec=dmos "$DEV" env -i HOME=/home/dmos USER=dmos LOGNAME=dmos SHELL=/bin/bash DISPLAY="$DISPLAY_NUM" \
        XDG_RUNTIME_DIR=/run/user/1000 LANG=pt_PT.UTF-8 PATH=/usr/local/bin:/usr/bin:/bin \
        XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=x11 LIBGL_ALWAYS_SOFTWARE=1 "$@"
}

case "$MODE" in
    desktop)
        if [ "$LNF" = org.dmos.mare.light ]; then
            mkdir -p "$DEV/home/dmos/.config"
            printf '[General]\nColorScheme=DMOSLight\n\n[Icons]\nTheme=Papirus-Light\n\n[KDE]\nLookAndFeelPackage=%s\n' "$LNF" > "$DEV/home/dmos/.config/kdeglobals"
            printf '[org.kde.kdecoration2]\nlibrary=org.kde.kwin.aurorae\ntheme=__aurorae__svg__DMOS-Light\n' > "$DEV/home/dmos/.config/kwinrc"
            chroot "$DEV" chown -R dmos:dmos /home/dmos/.config
        fi
        in_chroot dbus-run-session startplasma-x11 >/tmp/plasma.log 2>&1 &
        ;;
    sddm)
        in_chroot sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/dmos >/tmp/plasma.log 2>&1 &
        ;;
    splash)
        in_chroot dbus-run-session ksplashqml "$LNF" --test >/tmp/plasma.log 2>&1 &
        ;;
esac

sleep "$WAIT"
if [ -n "${POST_CMD:-}" ]; then
    in_chroot bash -c "$POST_CMD" >>/tmp/plasma.log 2>&1 &
    sleep "${POST_WAIT:-12}"
fi
if [ -n "${HOST_CMD:-}" ]; then
    DISPLAY="$DISPLAY_NUM" bash -c "$HOST_CMD"
fi
DISPLAY="$DISPLAY_NUM" import -window root "$SHOT"
echo "screenshot: $SHOT"
tail -n "${LOG_LINES:-25}" /tmp/plasma.log | cut -c1-220
