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


ANSI_ORDER = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
              "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue", "brightMagenta", "brightCyan", "brightWhite")


def ghostty(palette):
    m3, ansi = palette["m3"], palette["ansi"]
    lines = [f"palette = {i}={ansi[name]}" for i, name in enumerate(ANSI_ORDER)]
    lines += ["", f"background = {m3['surface']}", f"foreground = {m3['onSurface']}",
              f"cursor-color = {m3['primary']}", f"cursor-text = {m3['onPrimary']}",
              f"selection-background = {m3['surfaceContainerHighest']}", f"selection-foreground = {m3['onSurface']}"]
    return "\n".join(lines) + "\n"


def btop(palette):
    m3, ansi = palette["m3"], palette["ansi"]
    graph = lambda a, b, c: {"start": a, "mid": b, "end": c}
    values = {
        "main_bg": m3["surface"], "main_fg": m3["onSurface"], "title": m3["onSurface"], "hi_fg": m3["primary"],
        "selected_bg": m3["surfaceContainerHighest"], "selected_fg": m3["primary"], "proc_misc": m3["onSurfaceVariant"],
        "cpu_box": m3["outlineVariant"], "mem_box": m3["outlineVariant"], "net_box": m3["outlineVariant"],
        "proc_box": m3["outlineVariant"], "div_line": m3["outlineVariant"],
    }
    gradients = {
        "temp": graph(ansi["green"], ansi["yellow"], ansi["red"]),
        "cpu": graph(ansi["blue"], ansi["cyan"], ansi["magenta"]),
        "free": graph(ansi["green"], ansi["green"], ansi["brightGreen"]),
        "cached": graph(ansi["cyan"], ansi["cyan"], ansi["brightCyan"]),
        "available": graph(ansi["yellow"], ansi["yellow"], ansi["brightYellow"]),
        "used": graph(ansi["red"], ansi["red"], ansi["brightRed"]),
        "download": graph(ansi["blue"], ansi["blue"], ansi["brightBlue"]),
        "upload": graph(ansi["magenta"], ansi["magenta"], ansi["brightMagenta"]),
    }
    for name, g in gradients.items():
        values.update({f"{name}_{k}": v for k, v in g.items()})
    return "".join(f'theme[{k}]="{v}"\n' for k, v in values.items())


def vicinae(palette):
    m3, ansi, extra = palette["m3"], palette["ansi"], palette["extra"]
    return f"""[meta]
version = 1
name = "Ikigai"
description = "Ikigai's desktop palette: near-black warm greys with the wallpaper's blue."
variant = "dark"

[colors.core]
background = "{m3["surface"]}"
foreground = "{m3["onSurface"]}"
secondary_background = "{m3["surfaceContainerLow"]}"
border = "{m3["outlineVariant"]}"
accent = "{m3["primary"]}"

[colors.accents]
blue = "{m3["primary"]}"
green = "{ansi["green"]}"
magenta = "{ansi["magenta"]}"
orange = "{extra["orange"]}"
purple = "{extra["purple"]}"
red = "{ansi["red"]}"
yellow = "{ansi["yellow"]}"
cyan = "{ansi["cyan"]}"

[colors.list.item.selection]
background = "{m3["surfaceContainerHigh"]}"
secondary_background = "{m3["surfaceContainerHighest"]}"

[colors.grid.item]
background = "{m3["surfaceContainer"]}"
"""


OUTPUTS = {
    "shell.json": shell_json,
    "cosmic/builder.ron": builder_ron,
    "ghostty/ikigai": ghostty,
    "btop/ikigai.theme": btop,
    "vicinae/ikigai.toml": vicinae,
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
