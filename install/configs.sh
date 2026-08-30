#!/usr/bin/env bash
# Seed user configs. Never overwrites an existing file unless IKIGAI_FORCE=1.
set -euo pipefail

SRC="$IKIGAI_PATH/config"
skipped=()

seed() {
  local from="$SRC/$1" to="$2"
  if [ -e "$to" ] && [ "${IKIGAI_FORCE:-0}" != 1 ]; then
    skipped+=("$to"); return
  fi
  mkdir -p "$(dirname "$to")"
  cp "$from" "$to"
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
