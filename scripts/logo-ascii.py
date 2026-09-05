#!/usr/bin/env python3
# Render the black holes of a wallpaper as fastfetch logo text: brightness picks the
# glyph, hue picks $1 (orange) or $2 (blue) for logo.color in config/fastfetch/config.jsonc.
#   scripts/logo-ascii.py themes/ikigai/wallpaper.jpg 48 > config/fastfetch/logo.txt
import colorsys
import sys

from PIL import Image

RAMP = " .:-=+*#%@"
FLOOR = 0.15                      # below this the faint filaments become dot noise
BOX = (902, 365, 2842, 1728)      # the two holes, tight, in the 3840x2160 source
CELL_ASPECT = 2                   # a terminal cell is about twice as tall as wide


def main(path, width):
    im = Image.open(path).convert("RGB").crop(BOX)
    w, h = im.size
    height = round(width * (h / w) / CELL_ASPECT)
    im = im.resize((width, height), Image.BOX)
    for y in range(height):
        row, colour = "", None
        for x in range(width):
            hue, _, value = colorsys.rgb_to_hsv(*(c / 255 for c in im.getpixel((x, y))))
            value = 0 if value < FLOOR else (value - FLOOR) / (1 - FLOOR)
            glyph = RAMP[min(int(value * len(RAMP)), len(RAMP) - 1)]
            if glyph == " ":
                row += " "
                continue
            wanted = "$2" if 0.5 < hue < 0.75 else "$1"
            if wanted != colour:
                row += wanted
                colour = wanted
            row += glyph
        print(row.rstrip())


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: logo-ascii.py <wallpaper> <width>")
    main(sys.argv[1], int(sys.argv[2]))
