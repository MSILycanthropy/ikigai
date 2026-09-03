#!/usr/bin/env bash
# Vendor caelestia-shell's blob renderer (GPL-3.0): a Qt Quick plugin that draws rounded
# rects as signed distance fields joined by smooth minimums, with velocity-driven
# deformation. Sources stay verbatim so a re-sync is a re-run; only the CMake is ours.
set -euo pipefail
REV=750e67d93ac12b264cb8cbc3a1f2b8f429c923c2
BASE="https://raw.githubusercontent.com/caelestia-dots/shell/$REV"
DEST="$(cd "$(dirname "$0")/.." && pwd)/shell/plugin/blobs"
mkdir -p "$DEST/shaders"
for f in blobgroup.cpp blobgroup.hpp blobinvertedrect.cpp blobinvertedrect.hpp \
         blobmaterial.cpp blobmaterial.hpp blobrect.cpp blobrect.hpp blobshape.cpp blobshape.hpp \
         shaders/blob.frag shaders/blob.vert; do
  curl -fsSL -o "$DEST/$f" "$BASE/plugin/src/Caelestia/Blobs/$f"
done
curl -fsSL -o "$DEST/LICENSE" "$BASE/LICENSE"
echo "vendored blobs @ $REV"
