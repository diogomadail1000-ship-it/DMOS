#!/bin/bash
# Boots the ISO in QEMU (software emulation: WSL has no /dev/kvm here) with a QMP
# socket, and takes screenshots. Runs inside "dmos-builder".
#   test_vm.sh start bios|uefi [disk.qcow2]   boots; stays in the foreground
#   test_vm.sh shot FILE.png                  screenshot of the VM's screen
#   test_vm.sh key KEY [KEY...]               presses keys (QEMU qcode names)
#   test_vm.sh type "text"                    types plain lowercase text
#   test_vm.sh click X Y [right]              clicks at screen pixels (1920x1080)
#   test_vm.sh move X Y                       moves the pointer
#   test_vm.sh stop                           powers off the VM
# With BOOT_DISK=1, "start" boots the given disk without the ISO; ATTACH_ISO=1 keeps
# the ISO in the virtual drive while booting from the disk.
# VGA_DEVICE overrides the virtual graphics card (default: virtio-vga at 1920x1080).
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
RUN=/root/dmos-vm
QMP="$RUN/qmp.sock"
mkdir -p "$RUN"

qmp() {
    python3 -I - "$QMP" "$1" <<'EOF'
import json, socket, sys
sock = socket.socket(socket.AF_UNIX)
sock.connect(sys.argv[1])
stream = sock.makefile("rw")
stream.readline()
def send(obj):
    stream.write(json.dumps(obj) + "\n"); stream.flush()
    while True:
        reply = json.loads(stream.readline())
        if "return" in reply or "error" in reply:
            return reply
send({"execute": "qmp_capabilities"})
for command in json.loads(sys.argv[2]):
    reply = send(command)
    if "error" in reply:
        print(reply, file=sys.stderr); sys.exit(1)
EOF
}

abs_pos() { echo $(( $1 * 32767 / 1919 )); }

case "$1" in
    start)
        MODE="$2"
        ISO="$(ls -1 "$SRC"/dist/dmos-*.iso | head -1)"
        ARGS=(-machine q35 -smp 8 -m 6144 -accel tcg,thread=multi -cpu max
              -device "${VGA_DEVICE:-virtio-vga,xres=1920,yres=1080}" -display none
              -device qemu-xhci -device usb-tablet -device usb-kbd
              -netdev user,id=n0 -device virtio-net-pci,netdev=n0
              -qmp "unix:$QMP,server,nowait" -serial "file:$RUN/serial.log")
        if [ "$MODE" = uefi ]; then
            # An installed system keeps its firmware boot entry between boots.
            if [ "${BOOT_DISK:-0}" = 0 ]; then
                cp /usr/share/OVMF/OVMF_VARS_4M.fd "$RUN/vars.fd"
            fi
            ARGS+=(-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd
                   -drive if=pflash,format=raw,file="$RUN/vars.fd")
        fi
        if [ -n "${3:-}" ]; then
            [ -f "$3" ] || qemu-img create -f qcow2 "$3" 40G >/dev/null
            ARGS+=(-drive "file=$3,if=virtio,format=qcow2")
        fi
        if [ "${BOOT_DISK:-0}" = 0 ]; then
            ARGS+=(-drive "file=$ISO,media=cdrom,readonly=on" -boot d)
        elif [ "${ATTACH_ISO:-0}" = 1 ]; then
            ARGS+=(-drive "file=$ISO,media=cdrom,readonly=on" -boot c)
        fi
        rm -f "$QMP"
        # Foreground on purpose: WSL ends background processes with their session.
        exec qemu-system-x86_64 "${ARGS[@]}" >"$RUN/qemu.log" 2>&1
        ;;
    shot)
        qmp "[{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$RUN/shot.ppm\"}}]"
        sleep 1
        convert "$RUN/shot.ppm" "$2"
        ;;
    key)
        shift
        keys=""
        for k in "$@"; do keys="$keys{\"type\":\"qcode\",\"data\":\"$k\"},"; done
        qmp "[{\"execute\":\"send-key\",\"arguments\":{\"keys\":[${keys%,}],\"hold-time\":15}}]"
        ;;
    type)
        # The guest uses a Portuguese keyboard, so symbols sit on different keys.
        text="$2"
        for ((i = 0; i < ${#text}; i++)); do
            c="${text:$i:1}"
            case "$c" in
                " ") keys=(spc) ;;
                "/") keys=(shift 7) ;;
                "-") keys=(slash) ;;
                "_") keys=(shift slash) ;;
                ".") keys=(dot) ;;
                ":") keys=(shift dot) ;;
                ";") keys=(shift comma) ;;
                ">") keys=(shift less) ;;
                "=") keys=(shift 0) ;;
                [A-Z]) keys=(shift "${c,}") ;;
                *) keys=("$c") ;;
            esac
            bash "$0" key "${keys[@]}"
            sleep 0.12
        done
        ;;
    move)
        qmp "[{\"execute\":\"input-send-event\",\"arguments\":{\"events\":[{\"type\":\"abs\",\"data\":{\"axis\":\"x\",\"value\":$(abs_pos "$2")}},{\"type\":\"abs\",\"data\":{\"axis\":\"y\",\"value\":$(( $3 * 32767 / 1079 ))}}]}}]"
        ;;
    click)
        bash "$0" move "$2" "$3"
        sleep 0.4
        button="${4:-left}"
        qmp "[{\"execute\":\"input-send-event\",\"arguments\":{\"events\":[{\"type\":\"btn\",\"data\":{\"down\":true,\"button\":\"$button\"}}]}}]"
        sleep 0.15
        qmp "[{\"execute\":\"input-send-event\",\"arguments\":{\"events\":[{\"type\":\"btn\",\"data\":{\"down\":false,\"button\":\"$button\"}}]}}]"
        ;;
    stop)
        qmp '[{"execute":"quit"}]' || true
        ;;
    *)
        echo "usage: see the header of $0" >&2
        exit 2
        ;;
esac
