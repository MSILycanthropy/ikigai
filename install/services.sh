#!/usr/bin/env bash
set -euo pipefail

sudo systemctl enable cosmic-greeter docker NetworkManager
[ "$(systemd-detect-virt)" = microsoft ] && sudo systemctl enable hv_kvp_daemon
sudo usermod -aG docker "$USER"

[ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ] || sudo chsh -s "$(command -v zsh)" "$USER"
xdg-user-dirs-update

for b in "$IKIGAI_PATH"/bin/*; do sudo ln -sf "$b" "/usr/local/bin/$(basename "$b")"; done
