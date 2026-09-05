#!/usr/bin/env bash
# Arch ships no firewall; bin/ikigai-firewall sets one up with ufw. It needs the nf_tables
# module, which the running kernel cannot load once pacman has upgraded it (its modules are
# gone from disk until a reboot), and never inside archinstall's chroot. Apply now when the
# kernel can take it, otherwise on first boot through the oneshot unit.
set -euo pipefail

sudo install -Dm644 "$IKIGAI_PATH/firewall/ikigai-firewall.service" /usr/local/lib/systemd/system/ikigai-firewall.service
sudo systemctl enable -q ikigai-firewall

if sudo iptables -V >/dev/null 2>&1; then
  sudo ikigai-firewall
else
  echo "firewall: kernel upgraded, rules apply on first boot"
fi
