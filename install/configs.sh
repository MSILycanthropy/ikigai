#!/usr/bin/env bash
# Seed user configs. Never overwrites an existing file unless IKIGAI_FORCE=1.
set -euo pipefail

SRC="$IKIGAI_PATH/config"
SEEDS="$IKIGAI_STATE/seeds"
mkdir -p "$SEEDS"
skipped=()

seed() {
  local from="$SRC/$1" to="$2"
  if [ -e "$to" ] && [ "${IKIGAI_FORCE:-0}" != 1 ]; then
    skipped+=("$to"); return
  fi
  mkdir -p "$(dirname "$to")"
  cp "$from" "$to"
  sha256sum "$to" | cut -d' ' -f1 > "$SEEDS/${to//\//%}"
  echo "seeded $to"
}

seed zsh/.zshrc              "$HOME/.zshrc"
seed zsh/git-aliases.zsh     "$HOME/.config/zsh/git-aliases.zsh"
seed starship/starship.toml  "$HOME/.config/starship.toml"
seed git/config              "$HOME/.config/git/config"
seed ghostty/config          "$HOME/.config/ghostty/config"
seed zellij/config.kdl       "$HOME/.config/zellij/config.kdl"
seed zed/settings.json       "$HOME/.config/zed/settings.json"
seed yazi/yazi.toml          "$HOME/.config/yazi/yazi.toml"
seed nvim/init.lua           "$HOME/.config/nvim/init.lua"
seed bat/config              "$HOME/.config/bat/config"
seed btop/btop.conf          "$HOME/.config/btop/btop.conf"

if [ ${#skipped[@]} -gt 0 ]; then
  echo "kept existing (IKIGAI_FORCE=1 to overwrite):"
  printf '  %s\n' "${skipped[@]}"
fi

# COSMIC defaults go in cosmic-config's system layer, not ~/.config:
# user edits in Settings override per key and never conflict with ours.
(cd "$SRC/cosmic" && find . -type f) | while read -r f; do
  sudo install -Dm644 "$SRC/cosmic/$f" "/usr/local/share/cosmic/$f"
done
echo "installed COSMIC defaults → /usr/local/share/cosmic"
