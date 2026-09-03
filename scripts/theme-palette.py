#!/usr/bin/env python3
"""Generate themes/<name>/palette.json: Material 3 tokens plus a designed ANSI 16.

Dev-only. Needs materialyoucolor (pip install --target .venv-m3 materialyoucolor;
PYTHONPATH=.venv-m3 scripts/theme-palette.py themes/ikigai). The output is committed;
nothing at install time depends on this.

Neutrals come from M3's neutral scheme (near-black, chroma ~2) seeded with one colour,
accents from the vibrant scheme seeded with another, so the chrome can be black with an
accent that is not the neutral's hue. ANSI colours are built in OKLCH at one lightness and
chroma per row so no hue is louder than its neighbours.
"""
import json
import math
import sys
from pathlib import Path

from materialyoucolor.dynamiccolor.dynamic_color import DynamicColor
from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors
from materialyoucolor.hct import Hct
from materialyoucolor.scheme.scheme_neutral import SchemeNeutral
from materialyoucolor.scheme.scheme_vibrant import SchemeVibrant

SEEDS = {"neutral": "#f04501", "accent": "#036ce7"}
ACCENT_WORDS = ("primary", "secondary", "tertiary", "error", "surfaceTint")
ANSI_HUES = {"red": 25, "green": 145, "yellow": 85, "blue": 255, "magenta": 335, "cyan": 205}
ANSI_ROWS = {"normal": (0.76, 0.12), "bright": (0.84, 0.13)}
EXTRA_HUES = {"orange": 55, "indigo": 275, "purple": 305, "pink": 355}
TONES = range(0, 101, 10)


def scheme_tokens(scheme):
    return {
        name: "#%02x%02x%02x" % tuple(getattr(MaterialDynamicColors, name).get_hct(scheme).to_rgba()[:3])
        for name in dir(MaterialDynamicColors)
        if isinstance(getattr(MaterialDynamicColors, name), DynamicColor)
    }


def hct(hex_colour):
    return Hct.from_int(int("ff" + hex_colour.lstrip("#"), 16))


def m3_tokens():
    neutral_scheme = SchemeNeutral(hct(SEEDS["neutral"]), True, 0.0)
    neutral = scheme_tokens(neutral_scheme)
    accent = scheme_tokens(SchemeVibrant(hct(SEEDS["accent"]), True, 0.0))
    is_accent = lambda name: any(w.lower() in name.lower() for w in ACCENT_WORDS)
    tokens = {name: (accent if is_accent(name) else neutral)[name] for name in sorted(neutral)}
    tones = ["#%06x" % (neutral_scheme.neutral_palette.tone(t) & 0xFFFFFF) for t in TONES]
    return tokens, tones


def oklch_to_hex(L, C, h):
    a, b = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    lin = (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )
    gamma = lambda x: 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
    return "#%02x%02x%02x" % tuple(round(gamma(max(0.0, min(1.0, v))) * 255) for v in lin)


def ansi_tokens(m3):
    ansi = {
        "black": m3["surfaceContainerHighest"],
        "white": m3["onSurfaceVariant"],
        "brightBlack": m3["outline"],
        "brightWhite": m3["onSurface"],
    }
    for row, (L, C) in ANSI_ROWS.items():
        for name, hue in ANSI_HUES.items():
            key = name if row == "normal" else "bright" + name.capitalize()
            ansi[key] = oklch_to_hex(L, C, hue)
    extra = {name: oklch_to_hex(*ANSI_ROWS["normal"], hue) for name, hue in EXTRA_HUES.items()}
    return ansi, extra


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: theme-palette.py themes/<name>")
    theme = Path(sys.argv[1])
    m3, tones = m3_tokens()
    ansi, extra = ansi_tokens(m3)
    palette = {
        "name": theme.name,
        "seed": {**SEEDS, "schemes": {"neutral": "SchemeNeutral", "accent": "SchemeVibrant"},
                 "ansi": {"hues": {**ANSI_HUES, **EXTRA_HUES}, "rows": {k: list(v) for k, v in ANSI_ROWS.items()}}},
        "m3": m3,
        "neutralTones": tones,
        "ansi": ansi,
        "extra": extra,
    }
    out = theme / "palette.json"
    out.write_text(json.dumps(palette, indent=2) + "\n")
    print(f"wrote {out}: {len(m3)} m3 tokens, {len(tones)} neutral tones, {len(ansi)} ansi, {len(extra)} extra")


if __name__ == "__main__":
    main()
