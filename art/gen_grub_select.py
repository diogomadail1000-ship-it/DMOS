#!/usr/bin/env python3
"""Renders the 9-slice selection pill for the GRUB menu. Usage: gen_grub_select.py DIR"""
import os
import sys

from PIL import Image, ImageDraw

RADIUS = 10
SCALE = 4
SIDE = RADIUS * 2 + 4


def main():
    out = sys.argv[1]
    big = Image.new("RGBA", (SIDE * SCALE, SIDE * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    draw.rounded_rectangle(
        (0, 0, SIDE * SCALE - 1, SIDE * SCALE - 1), RADIUS * SCALE,
        fill=(45, 212, 191, 58), outline=(94, 234, 212, 150), width=SCALE,
    )
    pill = big.resize((SIDE, SIDE), Image.LANCZOS)
    r, s = RADIUS, SIDE
    slices = {
        "nw": (0, 0, r, r), "n": (r, 0, s - r, r), "ne": (s - r, 0, s, r),
        "w": (0, r, r, s - r), "c": (r, r, s - r, s - r), "e": (s - r, r, s, s - r),
        "sw": (0, s - r, r, s), "s": (r, s - r, s - r, s), "se": (s - r, s - r, s, s),
    }
    for name, box in slices.items():
        pill.crop(box).save(os.path.join(out, f"select_{name}.png"))


if __name__ == "__main__":
    main()
