#!/usr/bin/env bash
set -euo pipefail

sudo systemctl enable docker NetworkManager bluetooth
# pacman hygiene: paccache trims the package cache weekly (three versions kept); kernel-modules-hook
# keeps the running kernel's modules through an upgrade until reboot, the cleanup unit drops them after.
sudo systemctl enable paccache.timer linux-modules-cleanup.service
# The ssh agent is gcr's, for every user: passphrases land in the login keyring, which the
# greeter's PAM stack unlocks. ikigai-session points SSH_AUTH_SOCK at its socket.
sudo systemctl --global enable gcr-ssh-agent.socket
[ "$(systemd-detect-virt)" = microsoft ] && sudo systemctl enable hv_kvp_daemon
sudo usermod -aG docker "$USER"

[ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ] || sudo chsh -s "$(command -v zsh)" "$USER"
xdg-user-dirs-update

for b in "$IKIGAI_PATH"/bin/*; do sudo install -Dm755 "$b" "/usr/local/bin/$(basename "$b")"; done
