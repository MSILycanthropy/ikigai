#!/usr/bin/env bash
# Vendor generated Tokyo Night (night) app themes from folke/tokyonight.nvim.
set -euo pipefail

REV=cdc07ac78467a233fd62c493de29a17e0cf2b2b6
BASE="https://raw.githubusercontent.com/folke/tokyonight.nvim/$REV/extras"
DEST="$(dirname "$0")/../themes/tokyo-night"

FILES=(
  ghostty/tokyonight_night
  btop/tokyonight_night.theme
  lazygit/tokyonight_night.yml
  fzf/tokyonight_night.sh
  eza/tokyonight_night.yml
  sublime/tokyonight_night.tmTheme
  yazi/tokyonight_night.toml
  delta/tokyonight_night.gitconfig
  zellij/tokyonight_night.kdl
)

for f in "${FILES[@]}"; do
  mkdir -p "$DEST/$(dirname "$f")"
  curl -fsSL -o "$DEST/$f" "$BASE/$f"
  echo "vendored $f"
done
echo "$REV" > "$DEST/UPSTREAM_REV"
