#!/usr/bin/env python3
"""Rasterise a scalable cursor theme (cursors_scalable/, as scripts/theme-build.py writes it)
into a complete cursor theme dir: the SVGs as they are, plus cursors/ of Xcursor files at
the sizes toolkits ask for, aliases as symlinks in both. rsvg-convert and xcursorgen.

usage: cursor-raster.py <theme dir> <out dir>
"""
import json
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

SIZES = (24, 32, 48, 64, 96)  # 24 at 1x-4x, 32 at 2x-3x; loaders take the nearest


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    theme, out = Path(sys.argv[1]), Path(sys.argv[2])
    scalable = theme / "cursors_scalable"
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(scalable, out / "cursors_scalable", symlinks=True)
    for f in ("cursor.theme", "LICENSE"):
        if (theme / f).exists():
            shutil.copy(theme / f, out / f)
    cursors = out / "cursors"
    cursors.mkdir()

    shapes = sorted(d for d in scalable.iterdir() if d.is_dir() and not d.is_symlink())
    with tempfile.TemporaryDirectory() as tmp, ThreadPoolExecutor() as pool:
        tmp = Path(tmp)
        configs = {}
        jobs = []
        for shape in shapes:
            lines = []
            for frame in json.loads((shape / "metadata.json").read_text()):
                for size in SIZES:
                    factor = size / frame["nominal_size"]
                    png = tmp / f"{shape.name}-{Path(frame['filename']).stem}-{size}.png"
                    jobs.append(pool.submit(subprocess.run, [
                        "rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(png),
                        str(shape / frame["filename"])], check=True))
                    lines.append(f"{size} {int(frame['hotspot_x'] * factor)} {int(frame['hotspot_y'] * factor)} "
                                 f"{png} {frame.get('delay', 0)}")
            configs[shape.name] = "\n".join(lines) + "\n"
        for job in jobs:
            job.result()
        for name, config in configs.items():
            subprocess.run(["xcursorgen", "-", str(cursors / name)], input=config, text=True, check=True)
    aliases = [d for d in scalable.iterdir() if d.is_symlink()]
    for alias in aliases:
        (cursors / alias.name).symlink_to(alias.readlink())
    print(f"rasterised {len(shapes)} cursors + {len(aliases)} aliases at {', '.join(map(str, SIZES))} px → {out}")


if __name__ == "__main__":
    main()
