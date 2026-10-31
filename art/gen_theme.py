#!/usr/bin/env python3
"""Generates the DMOS "Mare" theme files: colour schemes, Plasma style,
Aurorae window decorations and the Konsole colour scheme.

Usage: gen_theme.py ROOT   (ROOT mirrors the target filesystem)
"""
import base64
import io
import os
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

DARK = dict(
    name="DMOS Maré Escuro", id="DMOSDark",
    window="#11172B", view="#0C1122", alt="#161D35", button="#1C2440", header="#10162A",
    tooltip="#161D35", text="#E8ECF5", text_inactive="#8D96B0", accent="#2DD4BF",
    on_accent="#04201C", accent_soft="#1B4F58", link="#7CC8FF", visited="#C4A5FF",
    negative="#FF6B6B", neutral="#FFB86B", positive="#4ADE80",
    title_active="#E8ECF5", title_inactive="#8D96B0", edge="#FFFFFF", edge_opacity=0.10,
    shadow_active=0.62, shadow_inactive=0.34,
)
LIGHT = dict(
    name="DMOS Maré Claro", id="DMOSLight",
    window="#F3F6FA", view="#FFFFFF", alt="#EAF0F6", button="#FFFFFF", header="#EDF2F7",
    tooltip="#FFFFFF", text="#1A2238", text_inactive="#66708A", accent="#0E8F88",
    on_accent="#FFFFFF", accent_soft="#BDE8E2", link="#1469C7", visited="#7A46C4",
    negative="#D63A3A", neutral="#C47A12", positive="#1C9A4F",
    title_active="#1A2238", title_inactive="#7C86A0", edge="#FFFFFF", edge_opacity=0.65,
    shadow_active=0.32, shadow_inactive=0.16,
)


def write(root, path, content):
    full = os.path.join(root, path.lstrip("/"))
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(content)


def rgb(value):
    value = value.lstrip("#")
    return ",".join(str(int(value[i:i + 2], 16)) for i in (0, 2, 4))


# --- Colour schemes -----------------------------------------------------------

def color_group(p, bg, alt, text=None, hover=None):
    text = text or p["text"]
    hover = hover or p["accent"]
    return (
        f"BackgroundAlternate={rgb(alt)}\nBackgroundNormal={rgb(bg)}\n"
        f"DecorationFocus={rgb(p['accent'])}\nDecorationHover={rgb(hover)}\n"
        f"ForegroundActive={rgb(p['accent'])}\nForegroundInactive={rgb(p['text_inactive'])}\n"
        f"ForegroundLink={rgb(p['link'])}\nForegroundNegative={rgb(p['negative'])}\n"
        f"ForegroundNeutral={rgb(p['neutral'])}\nForegroundNormal={rgb(text)}\n"
        f"ForegroundPositive={rgb(p['positive'])}\nForegroundVisited={rgb(p['visited'])}\n"
    )


def color_scheme(p):
    return (
        "[ColorEffects:Disabled]\nColor=56,56,56\nColorAmount=0\nColorEffect=0\n"
        "ContrastAmount=0.65\nContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2\n\n"
        "[ColorEffects:Inactive]\nChangeSelectionColor=true\nColor=112,111,110\n"
        "ColorAmount=0.025\nColorEffect=2\nContrastAmount=0.1\nContrastEffect=2\n"
        "Enable=false\nIntensityAmount=0\nIntensityEffect=0\n\n"
        f"[Colors:Button]\n{color_group(p, p['button'], p['alt'])}\n"
        f"[Colors:Complementary]\n{color_group(p, DARK['window'], DARK['alt'], DARK['text'])}\n"
        f"[Colors:Header]\n{color_group(p, p['header'], p['alt'])}\n"
        f"[Colors:Header][Inactive]\n{color_group(p, p['header'], p['alt'])}\n"
        f"[Colors:Selection]\n{color_group(p, p['accent'], p['accent_soft'], p['on_accent'])}\n"
        f"[Colors:Tooltip]\n{color_group(p, p['tooltip'], p['alt'])}\n"
        f"[Colors:View]\n{color_group(p, p['view'], p['alt'])}\n"
        f"[Colors:Window]\n{color_group(p, p['window'], p['alt'])}\n"
        f"[General]\nColorScheme={p['id']}\nName={p['name']}\nshadeSortColumn=true\n\n"
        "[KDE]\ncontrast=4\n\n"
        f"[WM]\nactiveBackground={rgb(p['header'])}\nactiveBlend={rgb(p['header'])}\n"
        f"activeForeground={rgb(p['title_active'])}\ninactiveBackground={rgb(p['header'])}\n"
        f"inactiveBlend={rgb(p['header'])}\ninactiveForeground={rgb(p['title_inactive'])}\n"
    )


# --- SVG helpers --------------------------------------------------------------

STYLE = (
    '<style id="current-color-scheme" type="text/css">'
    ".ColorScheme-Background{color:#11172B}.ColorScheme-Text{color:#E8ECF5}"
    "</style>"
)


def corner_path(cx, cy, r, sx, sy):
    """Pie slice of radius r around (cx, cy), opening towards (sx, sy)."""
    x1, y1 = cx + sx * r, cy
    x2, y2 = cx, cy + sy * r
    sweep = 1 if sx * sy > 0 else 0
    return f"M{cx} {cy}L{x1} {y1}A{r} {r} 0 0 {sweep} {x2} {y2}Z"


def invisible(x, y, w, h):
    """Forces the element bounds, so the 9-slice grid stays exact."""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000" opacity="0.001"/>'


def ring_path(cx, cy, r, sx, sy, width=1):
    """Quarter ring along the outer edge of a corner; a filled shape, so bounds stay exact."""
    inner = r - width
    sweep = 1 if sx * sy > 0 else 0
    return (f"M{cx + sx * r} {cy}A{r} {r} 0 0 {sweep} {cx} {cy + sy * r}"
            f"L{cx} {cy + sy * inner}A{inner} {inner} 0 0 {1 - sweep} {cx + sx * inner} {cy}Z")


def frame(prefix, radius, fill, border=None, center=40):
    """9-slice rounded frame in the KSvg element-naming convention.

    No strokes anywhere: a stroke inflates the element bounds, and KSvg then
    scales each slice into the wrong box, which opens gaps at the corners.
    """
    pre = f"{prefix}-" if prefix else ""
    r, c = radius, center
    x1, x2 = r, r + c
    out = []
    corners = [("topleft", x1, x1, -1, -1), ("topright", x2, x1, 1, -1),
               ("bottomleft", x1, x2, -1, 1), ("bottomright", x2, x2, 1, 1)]
    for name, cx, cy, sx, sy in corners:
        ring = f'<path d="{ring_path(cx, cy, r, sx, sy)}" {border}/>' if border else ""
        out.append(f'<g id="{pre}{name}"><path d="{corner_path(cx, cy, r, sx, sy)}" {fill}/>{ring}</g>')
    edges = [
        ("top", x1, 0, c, r, (x1, 0, c, 1)),
        ("bottom", x1, x2, c, r, (x1, x2 + r - 1, c, 1)),
        ("left", 0, x1, r, c, (0, x1, 1, c)),
        ("right", x2, x1, r, c, (x2 + r - 1, x1, 1, c)),
    ]
    for name, x, y, w, h, line in edges:
        lx, ly, lw, lh = line
        highlight = f'<rect x="{lx}" y="{ly}" width="{lw}" height="{lh}" {border}/>' if border else ""
        out.append(f'<g id="{pre}{name}"><rect x="{x}" y="{y}" width="{w}" height="{h}" {fill}/>{highlight}</g>')
    out.append(f'<rect id="{pre}center" x="{x1}" y="{x1}" width="{c}" height="{c}" {fill}/>')
    return "".join(out)


def mask_frame(prefix, radius):
    return frame(prefix, radius, 'fill="#000"')


def rounded_sdf(w, h, x, y, rw, rh, r_top, r_bottom, scale):
    """Signed distance (in device pixels) to a rounded rect; negative inside."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    px, py = xs - (x + rw / 2) * scale, ys - (y + rh / 2) * scale
    hw, hh = rw * scale / 2, rh * scale / 2
    r = np.where(py < 0, r_top * scale, r_bottom * scale)
    qx, qy = np.abs(px) - hw + r, np.abs(py) - hh + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def png_uri(rgba):
    buffer = io.BytesIO()
    Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(buffer, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def image_slice(name, rgba, x, y, w, h, scale):
    crop = rgba[y * scale:(y + h) * scale, x * scale:(x + w) * scale]
    return f'<image id="{name}" x="{x}" y="{y}" width="{w}" height="{h}" xlink:href="{png_uri(crop)}"/>'


def shadow_alpha(sdf, sigma, opacity, shift_y=0):
    """Gaussian soft shadow of a shape, shifted downwards."""
    mask = np.clip(0.5 - sdf, 0, 1)
    if shift_y:
        mask = np.roll(mask, shift_y, axis=0)
    return gaussian_filter(mask, sigma) * opacity


def shadow_frame(prefix, radius, pad, opacity, shift=5, middle=40, scale=2):
    """Shadow tiles for KWindowShadow: corners overlap the rounded corner, edges sit outside."""
    pre = f"{prefix}-" if prefix else ""
    pad_top, pad_bottom = pad - shift, pad + shift
    inner = 2 * radius + middle
    w, h = (pad + inner + pad) * scale, (pad_top + inner + pad_bottom) * scale
    sdf = rounded_sdf(w, h, pad, pad_top, inner, inner, radius, radius, scale)
    alpha = shadow_alpha(sdf, pad * scale / 2.8, opacity, shift * scale)
    alpha = alpha * np.clip(0.5 + sdf, 0, 1)  # nothing under the surface itself
    rgba = np.zeros((h, w, 4), np.float32)
    rgba[..., 3] = alpha
    left, top = pad + radius, pad_top + radius
    x2, y2 = left + middle, top + middle
    right, bottom = pad + radius, pad_bottom + radius
    out = [
        image_slice(f"{pre}topleft", rgba, 0, 0, left, top, scale),
        image_slice(f"{pre}topright", rgba, x2, 0, right, top, scale),
        image_slice(f"{pre}bottomleft", rgba, 0, y2, left, bottom, scale),
        image_slice(f"{pre}bottomright", rgba, x2, y2, right, bottom, scale),
        image_slice(f"{pre}top", rgba, left, 0, middle, pad_top, scale),
        image_slice(f"{pre}bottom", rgba, left, y2 + radius, middle, pad_bottom, scale),
        image_slice(f"{pre}left", rgba, 0, top, pad, middle, scale),
        image_slice(f"{pre}right", rgba, x2 + radius, top, pad, middle, scale),
    ]
    margins = {"top": pad_top, "bottom": pad_bottom, "left": pad, "right": pad}
    for side, size in margins.items():
        out.append(f'<rect id="{pre}hint-{side}-margin" width="{size}" height="{size}" fill="none"/>')
    return "".join(out)


def hints(prefix, margin):
    pre = f"{prefix}-" if prefix else ""
    out = f'<rect id="{pre}hint-stretch-borders" width="1" height="1" fill="none"/>'
    for side in ("top", "bottom", "left", "right"):
        out += f'<rect id="{pre}hint-{side}-margin" width="{margin}" height="{margin}" fill="none"/>'
    return out


def svg(body, size=400):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{size}" height="{size}" viewBox="0 0 {size} {size}"><defs>{STYLE}</defs>{body}</svg>\n'
    )


# --- Plasma style -------------------------------------------------------------

def plasma_surface(radius, margin, opacity, shadow_size=30, prefixes=("",), shadow_opacity=0.5):
    """One surface file: frames for every prefix, plus mask and shadow."""
    fill = f'class="ColorScheme-Background" fill="currentColor" fill-opacity="{opacity}"'
    border = 'class="ColorScheme-Text" fill="currentColor" fill-opacity="0.14"'
    body = ""
    for prefix in prefixes:
        body += frame(prefix, radius, fill, border) + hints(prefix, margin)
        mask = f"mask-{prefix}" if prefix else "mask"
        body += mask_frame(mask, radius) + hints(mask, margin)
    body += shadow_frame("shadow", radius, shadow_size, shadow_opacity)
    if len(prefixes) > 1:
        # Panels read their applet padding from this hint-only "thick" prefix.
        body += '<rect id="thick-center" width="32" height="32" fill="none"/>' + hints("thick", 4)
    return svg(body)


def plasma_style(root):
    base = "/usr/share/plasma/desktoptheme/dmos"
    write(root, f"{base}/metadata.json", """{
    "KPlugin": {
        "Authors": [{ "Name": "DMOS" }],
        "Description": "Vidro escuro e claro, inspirado na maré.",
        "Id": "dmos",
        "License": "GPL-3.0-or-later",
        "Name": "DMOS Maré",
        "Version": "1.0"
    },
    "X-Plasma-API": "5.0"
}
""")
    write(root, f"{base}/plasmarc", """[ContrastEffect]
enabled=true
contrast=0.85
intensity=0.9
saturation=1.6

[AdaptiveTransparency]
enabled=false

[BlurBehindEffect]
enabled=true

[Wallpaper]
defaultWallpaperTheme=DMOS-Mare
""")
    panel_prefixes = ("", "north", "south", "east", "west")
    surfaces = {
        "widgets/panel-background.svg": dict(radius=18, margin=6, prefixes=panel_prefixes),
        "widgets/background.svg": dict(radius=18, margin=12),
        "widgets/tooltip.svg": dict(radius=12, margin=8, shadow_size=20, shadow_opacity=0.4),
        "dialogs/background.svg": dict(radius=18, margin=12, shadow_size=40, shadow_opacity=0.55),
    }
    # translucent/ is used with blur on, the base files without blur, opaque/ without a compositor.
    for variant, opacity in (("translucent/", 0.62), ("", 0.92), ("opaque/", 1.0)):
        for path, args in surfaces.items():
            write(root, f"{base}/{variant}{path}", plasma_surface(opacity=opacity, **args))


# --- Aurorae window decoration ------------------------------------------------

def button_svg(color, hover, glyph):
    """Soft pill-round buttons; the glyph only shows on hover or press."""
    size = 18
    center = size / 2
    circle = lambda fill, opacity=1.0: (
        f'<circle cx="{center}" cy="{center}" r="6.5" fill="{fill}" fill-opacity="{opacity}"/>'
    )
    bounds = invisible(0, 0, size, size)
    states = {
        "active-center": circle(color),
        "inactive-center": circle("#7F88A3", 0.45),
        "hover-center": circle(hover) + glyph,
        "pressed-center": circle(hover, 0.75) + glyph,
        "deactivated-center": circle("#7F88A3", 0.25),
    }
    body = "".join(f'<g id="{key}">{bounds}{value}</g>' for key, value in states.items())
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
            f'viewBox="0 0 {size} {size}">{body}</svg>\n')


def aurorae_frame(state, p, r_top, r_bottom, pad, opacity, scale=2, middle=40):
    """One decoration state rendered to pixels, with its shadow baked in, then sliced."""
    side = pad + r_top
    top, bottom = pad + r_top, pad + r_bottom
    w, h = (side * 2 + middle) * scale, (top + middle + bottom) * scale
    rw, rh = side * 2 + middle - pad * 2, top + middle + bottom - pad * 2
    sdf = rounded_sdf(w, h, pad, pad, rw, rh, r_top, r_bottom, scale)
    shadow = shadow_alpha(sdf, pad * scale / 2.8, opacity, 4 * scale)

    def color(value):
        return np.array([int(value.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)

    fill = color(p["header"])
    edge = color(p["edge"])
    coverage = np.clip(0.5 - sdf, 0, 1)
    border = np.clip(1 - np.abs(sdf + 1.0 * scale / 2) / (0.5 * scale), 0, 1) * p["edge_opacity"]
    rgb_out = fill[None, None, :] * (1 - border[..., None]) + edge[None, None, :] * border[..., None]
    alpha = coverage + shadow * (1 - coverage)
    rgb_final = rgb_out * (coverage / np.maximum(alpha, 1e-4))[..., None]
    rgba = np.dstack([rgb_final, alpha])
    x2, y2 = side + middle, top + middle
    pieces = {
        "topleft": (0, 0, side, top), "top": (side, 0, middle, top), "topright": (x2, 0, side, top),
        "left": (0, top, side, middle), "center": (side, top, middle, middle), "right": (x2, top, side, middle),
        "bottomleft": (0, y2, side, bottom), "bottom": (side, y2, middle, bottom), "bottomright": (x2, y2, side, bottom),
    }
    return "".join(image_slice(f"{state}-{name}", rgba, *box, scale) for name, box in pieces.items())


def aurorae(root, p, folder):
    base = f"/usr/share/aurorae/themes/{folder}"
    r_top, r_bottom, border, title, pad, top_edge = 12, 5, 3, 26, 28, 5
    body = aurorae_frame("decoration", p, r_top, r_bottom, pad, p["shadow_active"])
    body += aurorae_frame("decoration-inactive", p, r_top, r_bottom, pad, p["shadow_inactive"])
    # Maximized windows have no corners and no shadow.
    for state in ("decoration-maximized", "decoration-maximized-inactive"):
        body += f'<rect id="{state}-center" x="0" y="0" width="32" height="32" fill="{p["header"]}"/>'
    write(root, f"{base}/decoration.svg",
          '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
          f'width="240" height="240" viewBox="0 0 240 240"><rect id="hint-stretch-borders" width="1" height="1" fill="none"/>'
          f'<rect id="decoration-hint-stretch-borders" width="1" height="1" fill="none"/>'
          f'<rect id="decoration-inactive-hint-stretch-borders" width="1" height="1" fill="none"/>{body}</svg>\n')

    glyph_color = "#3A1A16" if p is DARK else "#FFFFFF"
    stroke = f'stroke="{glyph_color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" fill="none"'
    glyphs = {
        "close": (f'<path d="M6.8 6.8L11.2 11.2M11.2 6.8L6.8 11.2" {stroke}/>', "#FF7A6B", "#FF9486"),
        "minimize": (f'<path d="M6.3 9H11.7" {stroke}/>', "#F5BE5B", "#FFD27D"),
        "maximize": (f'<path d="M6.6 11.4V6.6H11.4M11.4 6.6V11.4H6.6" {stroke}/>', "#2DD4BF", "#5EEAD4"),
        "restore": (f'<path d="M7 9H11M9 7V11" {stroke}/>', "#2DD4BF", "#5EEAD4"),
        "alldesktops": (f'<circle cx="9" cy="9" r="1.6" fill="{glyph_color}"/>', "#7F88A3", "#9AA3BC"),
        "keepabove": (f'<path d="M6.5 10.2L9 7.7L11.5 10.2" {stroke}/>', "#7F88A3", "#9AA3BC"),
        "keepbelow": (f'<path d="M6.5 7.8L9 10.3L11.5 7.8" {stroke}/>', "#7F88A3", "#9AA3BC"),
        "shade": (f'<path d="M6.5 7.5H11.5" {stroke}/>', "#7F88A3", "#9AA3BC"),
        "help": (f'<circle cx="9" cy="9" r="1.2" fill="{glyph_color}"/>', "#7F88A3", "#9AA3BC"),
    }
    for name, (glyph, color, hover) in glyphs.items():
        write(root, f"{base}/{name}.svg", button_svg(color, hover, glyph))

    write(root, f"{base}/metadata.desktop", f"""[Desktop Entry]
Name={p['name']}
Comment=Decoração de janelas DMOS
X-KDE-PluginInfo-Author=DMOS
X-KDE-PluginInfo-Name={folder}
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL
X-KDE-ServiceTypes=KWin/Decoration
""")
    write(root, f"{base}/{folder}rc", f"""[General]
ActiveTextColor={rgb(p['title_active'])}
InactiveTextColor={rgb(p['title_inactive'])}
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=140
Shadow=true
DecorationPosition=0

[Layout]
BorderLeft={border}
BorderRight={border}
BorderBottom={border}
TitleEdgeTop={top_edge}
TitleEdgeBottom={top_edge}
TitleEdgeLeft=12
TitleEdgeRight=12
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={title}
ButtonWidth=18
ButtonHeight=18
ButtonSpacing=4
ButtonMarginTop=4
ExplicitButtonSpacer=8
PaddingLeft={pad}
PaddingRight={pad}
PaddingTop={pad}
PaddingBottom={pad}
""")


# --- Konsole ------------------------------------------------------------------

def konsole(root):
    colors = [
        ("Background", "0C1122"), ("BackgroundFaint", "0C1122"), ("BackgroundIntense", "161D35"),
        ("Foreground", "E8ECF5"), ("ForegroundFaint", "8D96B0"), ("ForegroundIntense", "FFFFFF"),
        ("Color0", "1C2440"), ("Color0Intense", "4A5472"), ("Color0Faint", "151B31"),
        ("Color1", "FF6B6B"), ("Color1Intense", "FF8F8F"), ("Color1Faint", "B84D4D"),
        ("Color2", "4ADE80"), ("Color2Intense", "86EFAC"), ("Color2Faint", "35A05C"),
        ("Color3", "FFB86B"), ("Color3Intense", "FFD29B"), ("Color3Faint", "B8854D"),
        ("Color4", "7CC8FF"), ("Color4Intense", "A8DAFF"), ("Color4Faint", "5990B8"),
        ("Color5", "C4A5FF"), ("Color5Intense", "DAC6FF"), ("Color5Faint", "8D77B8"),
        ("Color6", "2DD4BF"), ("Color6Intense", "5EEAD4"), ("Color6Faint", "209989"),
        ("Color7", "E8ECF5"), ("Color7Intense", "FFFFFF"), ("Color7Faint", "A7AAB1"),
    ]
    out = ""
    for key, value in colors:
        out += f"[{key}]\nColor={rgb(value)}\n\n"
    out += "[General]\nBlur=true\nColorRandomization=false\nDescription=DMOS Maré\nOpacity=0.86\nWallpaper=\n"
    write(root, "/usr/share/konsole/DMOS.colorscheme", out)
    write(root, "/usr/share/konsole/DMOS.profile", """[Appearance]
ColorScheme=DMOS
Font=JetBrains Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1

[Cursor Options]
CursorShape=1

[General]
Name=DMOS
Parent=FALLBACK/
TerminalMargin=14

[Scrolling]
ScrollBarPosition=2
""")


def main():
    root = sys.argv[1]
    write(root, "/usr/share/color-schemes/DMOSDark.colors", color_scheme(DARK))
    write(root, "/usr/share/color-schemes/DMOSLight.colors", color_scheme(LIGHT))
    plasma_style(root)
    aurorae(root, DARK, "DMOS-Dark")
    aurorae(root, LIGHT, "DMOS-Light")
    konsole(root)


if __name__ == "__main__":
    main()
