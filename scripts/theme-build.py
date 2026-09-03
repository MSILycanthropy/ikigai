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


OUTPUTS = {
    "shell.json": shell_json,
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
