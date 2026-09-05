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
seed lazygit/config.yml      "$HOME/.config/lazygit/config.yml"
seed ikigai/shell.json       "$HOME/.config/ikigai/shell.json"
seed vicinae/settings.json   "$HOME/.config/vicinae/settings.json"
seed satty/config.toml       "$HOME/.config/satty/config.toml"
seed mpv/mpv.conf            "$HOME/.config/mpv/mpv.conf"
seed gtk-3.0/settings.ini    "$HOME/.config/gtk-3.0/settings.ini"
seed gtk-4.0/settings.ini    "$HOME/.config/gtk-4.0/settings.ini"
seed fastfetch/config.jsonc  "$HOME/.config/fastfetch/config.jsonc"
seed fastfetch/logo.txt      "$HOME/.config/fastfetch/logo.txt"

if [ ${#skipped[@]} -gt 0 ]; then
  echo "kept existing (IKIGAI_FORCE=1 to overwrite):"
  printf '  %s\n' "${skipped[@]}"
fi

# The Ikigai icon theme (Phosphor, see scripts/vendor-icon-theme.sh). COSMIC and Qt read
# it from CosmicTk's icon_theme; GTK apps read it through the settings portal, which
# serves gsettings, so it is also a system dconf default. The session runs with
# DCONF_PROFILE=cosmic, whose stock profile has no system db, so ship our own profile
# under that name too: cosmic-settings-daemon's db first, the user's, then our defaults.
(cd "$IKIGAI_PATH/icons/Ikigai" && find . -type f) | while read -r f; do
  sudo install -Dm644 "$IKIGAI_PATH/icons/Ikigai/$f" "/usr/local/share/icons/Ikigai/$f"
done
sudo install -Dm644 "$SRC/dconf/00-ikigai" /etc/dconf/db/local.d/00-ikigai
for profile in cosmic user; do
  printf 'user-db:cosmic\nuser-db:user\nsystem-db:local\n' | sudo install -Dm644 /dev/stdin "/etc/dconf/profile/$profile"
done
sudo dconf update

# COSMIC defaults go in cosmic-config's system layer, not ~/.config:
# user edits in Settings override per key and never conflict with ours.
(cd "$SRC/cosmic" && find . -type f) | while read -r f; do
  sudo install -Dm644 "$SRC/cosmic/$f" "/usr/local/share/cosmic/$f"
done
# cosmic-config takes the first data dir holding a config's directory and reads every key
# from it, so our Shortcuts overlay would hide COSMIC's own defaults. Link them in.
SHORTCUTS=com.system76.CosmicSettings.Shortcuts/v1
sudo ln -sfn "/usr/share/cosmic/$SHORTCUTS/defaults" "/usr/local/share/cosmic/$SHORTCUTS/defaults"
echo "installed COSMIC defaults → /usr/local/share/cosmic"

# Vicinae runs as XDG_CURRENT_DESKTOP=Ikigai (see session/systemd/vicinae.service.d), so
# Settings' OnlyShowIn=COSMIC would hide it from the launcher. Same entry, one line fewer,
# earlier in XDG_DATA_DIRS.
sed '/^OnlyShowIn=/d' /usr/share/applications/com.system76.CosmicSettings.desktop \
  | sudo install -Dm644 /dev/stdin /usr/local/share/applications/com.system76.CosmicSettings.desktop
