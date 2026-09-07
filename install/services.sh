#!/usr/bin/env bash
set -euo pipefail

sudo systemctl enable docker NetworkManager bluetooth
# pacman hygiene: paccache trims the package cache weekly (three versions kept); kernel-modules-hook
# keeps the running kernel's modules through an upgrade until reboot, the cleanup unit drops them after.
sudo systemctl enable paccache.timer linux-modules-cleanup.service
# The ssh agent is gcr's, for every user: passphrases land in the login keyring, which the
# greeter's PAM stack unlocks. ikigai-session points SSH_AUTH_SOCK at its socket.
sudo systemctl --global enable gcr-ssh-agent.socket
# systemd-oomd kills one runaway app scope (config/system/etc/systemd) before the box thrashes.
sudo systemctl enable systemd-oomd
# Nothing in the session waits on the network; without this graphical.target holds for DHCP or
# Wi-Fi association after a cold boot.
sudo systemctl mask NetworkManager-wait-online.service
# Outside archinstall's chroot, bring the new units up now rather than at the next boot:
# oomd, zram0 (its generator ran with the daemon-reload in configs.sh), plocate's first index.
if ! systemd-detect-virt -rq; then
  sudo systemctl start systemd-oomd
  [ -e /sys/block/zram0 ] || sudo systemctl start systemd-zram-setup@zram0.service || echo "zram0 comes up at the next boot"
  sudo systemctl start --no-block plocate-updatedb.service
fi
[ "$(systemd-detect-virt)" = microsoft ] && sudo systemctl enable hv_kvp_daemon
sudo usermod -aG docker "$USER"

[ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ] || sudo chsh -s "$(command -v zsh)" "$USER"
xdg-user-dirs-update

for b in "$IKIGAI_PATH"/bin/*; do sudo install -Dm755 "$b" "/usr/local/bin/$(basename "$b")"; done
