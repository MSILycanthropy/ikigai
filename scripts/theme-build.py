#!/usr/bin/env python3
"""Render a theme's app files from themes/<name>/palette.json.

Stdlib only; outputs are committed next to the palette. palette.json is the single
source of truth for colour, so every app file here is regenerated, never hand-edited.
"""
import json
import sys
from pathlib import Path

FONT = {"family": "Noto Sans", "size": 12, "icons": "Phosphor", "iconsFill": "Phosphor-Fill"}
RADIUS = 8

# QML reserves on<Capital> identifiers for signal handlers, so M3's on* tokens get a Fg suffix.
SHELL_TOKENS = {
    "surface": "surface", "surfaceContainerLow": "surfaceContainerLow", "surfaceContainer": "surfaceContainer",
    "surfaceContainerHigh": "surfaceContainerHigh", "surfaceContainerHighest": "surfaceContainerHighest",
    "fg": "onSurface", "fgVariant": "onSurfaceVariant", "outline": "outline", "outlineVariant": "outlineVariant",
    "primary": "primary", "primaryFg": "onPrimary", "primaryContainer": "primaryContainer",
    "primaryContainerFg": "onPrimaryContainer", "error": "error",
}


def shell_json(palette):
    colors = {k: palette["m3"][v] for k, v in SHELL_TOKENS.items()}
    colors["success"] = palette["ansi"]["green"]
    colors["warning"] = palette["ansi"]["yellow"]
    return json.dumps({"font": FONT, "radius": RADIUS, "colors": colors}, indent=2) + "\n"


def ron(colour):
    return f'"{colour}ff"'


def builder_ron(palette):
    m3, ansi, extra, tones = palette["m3"], palette["ansi"], palette["extra"], palette["neutralTones"]
    neutrals = "".join(f"        neutral_{i}: {ron(t)},\n" for i, t in enumerate(tones))
    accents = {
        "blue": m3["primary"], "indigo": extra["indigo"], "purple": extra["purple"], "pink": extra["pink"],
        "red": ansi["red"], "orange": extra["orange"], "yellow": ansi["yellow"], "green": ansi["green"],
        "warm_grey": m3["onSurfaceVariant"],
    }
    accent_lines = "".join(f"        accent_{k}: {ron(v)},\n" for k, v in accents.items())
    ext = {"warm_grey": m3["outline"], "orange": extra["orange"], "yellow": ansi["yellow"],
           "blue": ansi["cyan"], "purple": extra["purple"], "pink": extra["pink"], "indigo": extra["indigo"]}
    ext_lines = "".join(f"        ext_{k}: {ron(v)},\n" for k, v in ext.items())
    return f"""(
    palette: Dark((
        name: "{palette["name"]}",
        bright_red: {ron(ansi["brightRed"])},
        bright_green: {ron(ansi["brightGreen"])},
        bright_orange: {ron(extra["orange"])},
        gray_1: {ron(m3["surface"])},
        gray_2: {ron(m3["surfaceContainer"])},
{neutrals}{accent_lines}{ext_lines}    )),
    spacing: (space_none: 0, space_xxxs: 4, space_xxs: 8, space_xs: 12, space_s: 16, space_m: 24, space_l: 32, space_xl: 48, space_xxl: 64, space_xxxl: 128),
    corner_radii: (radius_0: (0.0, 0.0, 0.0, 0.0), radius_xs: (4.0, 4.0, 4.0, 4.0), radius_s: (8.0, 8.0, 8.0, 8.0), radius_m: (16.0, 16.0, 16.0, 16.0), radius_l: (32.0, 32.0, 32.0, 32.0), radius_xl: (160.0, 160.0, 160.0, 160.0)),
    neutral_tint: Some({ron(m3["onSurface"])}),
    bg_color: Some({ron(m3["surface"])}),
    primary_container_bg: Some({ron(m3["surfaceContainerLow"])}),
    secondary_container_bg: Some({ron(m3["surfaceContainer"])}),
    text_tint: Some({ron(m3["onSurface"])}),
    accent: Some({ron(m3["primary"])}),
    success: Some({ron(ansi["green"])}),
    warning: Some({ron(ansi["yellow"])}),
    destructive: Some({ron(m3["error"])}),
    frosted: Medium,
    gaps: (0, 8),
    active_hint: 1,
    window_hint: Some({ron(m3["primary"])}),
    frosted_windows: false,
    frosted_system_interface: false,
    frosted_panel: false,
    frosted_applets: false,
    frosted_maximized_apps: false,
)
"""


OUTPUTS = {
    "shell.json": shell_json,
    "cosmic/builder.ron": builder_ron,
}


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: theme-build.py themes/<name>")
    theme = Path(sys.argv[1])
    palette = json.loads((theme / "palette.json").read_text())
    for rel, render in OUTPUTS.items():
        out = theme / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(render(palette))
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
