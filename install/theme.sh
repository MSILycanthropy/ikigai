#!/usr/bin/env bash
# Place theme files. These are Ikigai-owned and always overwritten.
set -euo pipefail

THEME="${IKIGAI_THEME:-tokyo-night}"
T="$IKIGAI_PATH/themes/$THEME"
[ -d "$T" ] || { echo "theme.sh: no such theme '$THEME'" >&2; exit 1; }

put() { mkdir -p "$(dirname "$2")"; cp "$T/$1" "$2"; }

put ghostty/tokyonight_night          "$HOME/.config/ghostty/themes/tokyonight_night"
put zellij/tokyonight_night.kdl       "$HOME/.config/zellij/themes/tokyonight_night.kdl"
put yazi/tokyonight_night.toml        "$HOME/.config/yazi/theme.toml"
put eza/tokyonight_night.yml          "$HOME/.config/eza/theme.yml"
put fzf/tokyonight_night.sh           "$HOME/.config/fzf/theme.sh"
put delta/tokyonight_night.gitconfig  "$HOME/.config/git/tokyonight.gitconfig"
put lazygit/tokyonight_night.yml      "$HOME/.config/lazygit/config.yml"
put btop/tokyonight_night.theme       "$HOME/.config/btop/themes/tokyonight_night.theme"
put sublime/tokyonight_night.tmTheme  "$(bat --config-dir)/themes/tokyonight_night.tmTheme"
bat cache --build >/dev/null

NVIM_PACK="$HOME/.local/share/nvim/site/pack/ikigai/start/tokyonight.nvim"
if [ ! -d "$NVIM_PACK" ]; then
  git clone -q --depth 1 https://github.com/folke/tokyonight.nvim "$NVIM_PACK"
fi
git -C "$NVIM_PACK" fetch -q --depth 1 origin "$(cat "$T/UPSTREAM_REV")" && git -C "$NVIM_PACK" checkout -q FETCH_HEAD

echo "theme: $THEME"
