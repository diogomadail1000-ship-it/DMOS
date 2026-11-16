#!/usr/bin/env python3
"""Real mouse and keyboard input inside a DMOS test session (run as root, needs python3-evdev).

vmrun cannot click or type in a guest. This creates a virtual pointer and keyboard through
uinput, which the Wayland session treats like any other device.

    sudo python3 guest_input.py click 960 540  sleep 1  type "ola"  key enter

Commands, in any number and order:
    click X Y     left click at that pixel of a WIDTHxHEIGHT screen (default 1920x1080;
                  change it with: screen 1280 800)
    move X Y      move the pointer there
    type TEXT     letters, digits and spaces
    key NAME      enter, tab, esc, backspace, up, down, left, right, space, or a combination
                  such as super+a or alt+f4
    sleep SECONDS
"""
import sys
import time

from evdev import AbsInfo, UInput, ecodes as e

NAMES = {"enter": e.KEY_ENTER, "tab": e.KEY_TAB, "esc": e.KEY_ESC, "backspace": e.KEY_BACKSPACE,
         "up": e.KEY_UP, "down": e.KEY_DOWN, "left": e.KEY_LEFT, "right": e.KEY_RIGHT,
         "space": e.KEY_SPACE, "super": e.KEY_LEFTMETA, "alt": e.KEY_LEFTALT,
         "ctrl": e.KEY_LEFTCTRL, "shift": e.KEY_LEFTSHIFT}
for char in "abcdefghijklmnopqrstuvwxyz0123456789":
    NAMES[char] = getattr(e, "KEY_" + char.upper())
for number in range(1, 13):
    NAMES["f%d" % number] = getattr(e, "KEY_F%d" % number)

RANGE = 32767
size = [1920, 1080]

pointer = UInput({
    e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT],
    e.EV_ABS: [(e.ABS_X, AbsInfo(0, 0, RANGE, 0, 0, 0)), (e.ABS_Y, AbsInfo(0, 0, RANGE, 0, 0, 0))],
}, name="DMOS test pointer")
keyboard = UInput({e.EV_KEY: sorted(set(NAMES.values()))}, name="DMOS test keyboard")
time.sleep(1.5)  # the compositor needs a moment to pick the devices up


def move(x, y):
    pointer.write(e.EV_ABS, e.ABS_X, round(x * RANGE / (size[0] - 1)))
    pointer.write(e.EV_ABS, e.ABS_Y, round(y * RANGE / (size[1] - 1)))
    pointer.syn()
    time.sleep(0.15)


def press(codes):
    for code in codes:
        keyboard.write(e.EV_KEY, code, 1)
        keyboard.syn()
        time.sleep(0.03)
    for code in reversed(codes):
        keyboard.write(e.EV_KEY, code, 0)
        keyboard.syn()
        time.sleep(0.03)


args = sys.argv[1:]
while args:
    command = args.pop(0)
    if command == "screen":
        size[:] = [int(args.pop(0)), int(args.pop(0))]
    elif command in ("click", "move"):
        move(int(args.pop(0)), int(args.pop(0)))
        if command == "click":
            for value in (1, 0):
                pointer.write(e.EV_KEY, e.BTN_LEFT, value)
                pointer.syn()
                time.sleep(0.08)
    elif command == "type":
        for char in args.pop(0):
            if char == " ":
                press([e.KEY_SPACE])
            elif char.isupper():
                press([e.KEY_LEFTSHIFT, NAMES[char.lower()]])
            else:
                press([NAMES[char]])
    elif command == "key":
        press([NAMES[name] for name in args.pop(0).lower().split("+")])
    elif command == "sleep":
        time.sleep(float(args.pop(0)))
    else:
        sys.exit("unknown command: " + command)
time.sleep(0.3)
pointer.close()
keyboard.close()
