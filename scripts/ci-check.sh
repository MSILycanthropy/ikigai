#!/usr/bin/env bash
# Runs inside an archlinux container in CI: syntax-check every script and
# verify every curated package name resolves in the official repos.
set -euo pipefail
cd "$(dirname "$0")/.."

for f in boot.sh install.sh install/*.sh bin/* scripts/*.sh; do bash -n "$f"; done
echo "syntax ok"

[ "$(id -u)" -eq 0 ] && pacman -Sy --noconfirm >/dev/null
eval "$(sed -n '/^PACMAN=(/,/^)/p' install/packages.sh)"
pacman -Sp --noconfirm "${PACMAN[@]}" >/dev/null
echo "all ${#PACMAN[@]} repo packages resolve"

for p in nvidia-open-dkms nvidia-utils linux-headers mesa vulkan-radeon vulkan-intel hyperv; do
  pacman -Si "$p" >/dev/null
done
echo "gpu/vm packages resolve"

find themes config -type f \( -name '*.ron' -o -path '*/v[0-9]/*' \) | while read -r f; do
  grep -q . "$f" || { echo "empty config file: $f"; exit 1; }
done
echo "config files non-empty"
