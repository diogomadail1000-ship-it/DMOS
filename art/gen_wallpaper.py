#!/usr/bin/env python3
"""Procedural "Mare" wallpaper: layered tidal ribbons with silk filaments.

Usage: gen_wallpaper.py {dark,light} WIDTH HEIGHT OUTPUT
Everything is deterministic, so the art can be rebuilt from source at any size.
"""
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter


def hexc(value):
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def lin(value):
    return srgb_to_linear(hexc(value))


THEMES = {
    "dark": dict(
        sky_top=lin("#05070F"), sky_mid=lin("#0A0F24"), sky_low=lin("#0E1C3A"),
        glow=lin("#FF7A60"), glow_strength=0.34, glow_pos=(0.70, 0.44),
        ribbon_left=[lin("#10306C"), lin("#0C4F78"), lin("#0D7A86"), lin("#17AD9E")],
        ribbon_right=[lin("#44207C"), lin("#9A3478"), lin("#E0565E"), lin("#FF8F68")],
        body=0.46, crest=0.95, filament=0.62, blend="screen",
    ),
    "light": dict(
        sky_top=lin("#CFE6F5"), sky_mid=lin("#EAF3F8"), sky_low=lin("#FFF1E6"),
        glow=lin("#FFC9AE"), glow_strength=0.30, glow_pos=(0.70, 0.44),
        ribbon_left=[lin("#BFE3F2"), lin("#7CCBD9"), lin("#3FB2B4"), lin("#1B8FA0")],
        ribbon_right=[lin("#F6D2DA"), lin("#F7A9A0"), lin("#FF8F73"), lin("#E9674F")],
        body=0.58, crest=0.75, filament=0.30, blend="normal",
    ),
}


def smooth_noise(rng, h, w, sigma):
    """Low-frequency noise in [-1, 1]; computed small and scaled up for speed."""
    scale = max(1, int(sigma / 4))
    sh, sw = max(4, h // scale), max(4, w // scale)
    field = gaussian_filter(rng.standard_normal((sh, sw)), sigma / scale, mode="reflect")
    field /= max(1e-6, np.abs(field).max())
    img = Image.fromarray(field.astype(np.float32), mode="F").resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32)


def curve(rng, x, amplitude):
    """A sum of a few detuned sines: gives organic, non-repeating swells."""
    y = np.zeros_like(x)
    for k, freq in enumerate((0.55, 1.15, 2.3, 4.1)):
        y += amplitude / (1.0 + k * 1.1) * np.sin(2 * np.pi * freq * (x + rng.uniform(0, 1)))
    return y


def render(theme_name, width, height, seed=20261030):
    theme = THEMES[theme_name]
    rng = np.random.default_rng(seed)
    aspect = width / height
    ys, xs = np.mgrid[0:height, 0:width].astype(np.float32)
    x = xs / width
    y = ys / height

    # Sky: a vertical gradient and a low, warm sun bleeding into the water.
    t = y[..., None]
    sky = np.where(
        t < 0.55,
        theme["sky_top"] + (theme["sky_mid"] - theme["sky_top"]) * (t / 0.55),
        theme["sky_mid"] + (theme["sky_low"] - theme["sky_mid"]) * ((t - 0.55) / 0.45),
    )
    gx, gy = theme["glow_pos"]
    dist = np.sqrt(((x - gx) * aspect * 0.62) ** 2 + ((y - gy) * 1.25) ** 2)
    sun = (0.86 * np.exp(-(dist / 0.20) ** 2) + 0.14 * np.exp(-(dist / 0.42) ** 2))[..., None]
    img = sky + theme["glow"] * sun * theme["glow_strength"]

    # Domain warp: bends every ribbon by the same current so they flow together.
    warp = 0.075 * smooth_noise(rng, height, width, height / 3.2)
    warp += 0.018 * smooth_noise(rng, height, width, height / 9)
    yw = y + warp

    n_ribbons = 9
    for i in range(n_ribbons):
        p = i / (n_ribbons - 1)
        base = 0.42 + 0.60 * p ** 1.15
        c = base + curve(rng, x[0], 0.040 + 0.030 * p)
        d = yw - c[None, :]

        # Hue travels along the ribbon, from teal on the left to coral on the right.
        idx = min(3, int(p * 4))
        mix = np.clip(x + 0.18 * np.sin(2 * np.pi * (x * 0.9 + p)) + 0.35 * (warp / 0.075) * 0.3, 0, 1)
        mix = (mix * mix * (3 - 2 * mix))[..., None]
        color = theme["ribbon_left"][idx] * (1 - mix) + theme["ribbon_right"][idx] * mix

        # Ribbon body: crisp upper edge melting into the water below.
        falloff = 0.075 + 0.05 * p
        edge = np.clip(d / (0.0028), 0, 1)
        edge = edge * edge * (3 - 2 * edge)
        alpha = edge * np.exp(-np.maximum(d, 0) / falloff) * theme["body"]
        img = img * (1 - alpha[..., None]) + color * alpha[..., None]

        # Luminous crest.
        shimmer = (0.5 + 0.5 * np.sin(2 * np.pi * (x * (1.1 + 0.6 * p) + rng.uniform(0, 1)))) ** 2
        crest = np.exp(-(d / 0.0017) ** 2) * (0.18 + 0.82 * shimmer) * (0.45 + 0.75 * sun[..., 0] + 0.25 * x)
        crest_color = color * 0.72 + np.array([1.0, 0.96, 0.92], dtype=np.float32) * 0.28
        if theme["blend"] == "screen":
            img = 1 - (1 - img) * (1 - crest_color * (crest * theme["crest"])[..., None])
        else:
            a = (crest * theme["crest"] * 0.8)[..., None]
            img = img * (1 - a) + np.array([1.0, 1.0, 1.0], dtype=np.float32) * a

        # Silk filaments that follow the crest and slowly drift apart.
        spread = 0.5 + 0.5 * np.sin(2 * np.pi * (x * (0.7 + p) + rng.uniform(0, 1)))
        for j in range(1, 27):
            offset = j * (0.0045 + 0.0060 * spread) * (1 + 0.012 * j)
            line = np.exp(-((d - offset) / 0.00085) ** 2)
            fade = np.exp(-j / 10.0) * (0.25 + 0.75 * spread) * (0.45 + 0.55 * sun[..., 0] ** 0.5)
            a = (line * fade * theme["filament"])[..., None]
            if theme["blend"] == "screen":
                img = 1 - (1 - img) * (1 - color * 1.25 * a)
            else:
                img = img * (1 - a) + (color * 0.75 + 0.25) * a

    # Vignette keeps the eye centred and gives panels something calm to sit on.
    vx = (x - 0.5) * 1.12
    vy = (y - 0.5) * 1.12
    if theme_name == "dark":
        vignette = 1 - 0.55 * np.clip(vx * vx + vy * vy, 0, 1) ** 1.2
        img = img * vignette[..., None]

    out = linear_to_srgb(img)
    # Triangular-PDF dither: long dark gradients stay free of banding.
    dither = (rng.random(out.shape, dtype=np.float32) - rng.random(out.shape, dtype=np.float32)) * 1.6 / 255.0
    out = np.clip(out + dither, 0, 1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGB")


def main():
    theme, width, height, output = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    image = render(theme, width, height)
    if output.lower().endswith((".jpg", ".jpeg")):
        image.save(output, quality=93, subsampling=0, optimize=True)
    else:
        image.save(output, optimize=True)


if __name__ == "__main__":
    main()
