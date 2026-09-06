#!/usr/bin/env bash
# Rebuild cosmic-comp with Ikigai's patches (packages/cosmic-comp/README.md) and keep it
# rebuilt across cosmic-comp upgrades.
set -euo pipefail

CC="$IKIGAI_PATH/packages/cosmic-comp"
for p in "$CC"/*.patch; do
  sudo install -Dm644 "$p" "/usr/local/share/ikigai/cosmic-comp/$(basename "$p")"
done
sudo install -Dm755 "$CC/ikigai-cosmic-comp" /usr/local/lib/ikigai/ikigai-cosmic-comp
sudo install -Dm644 "$CC/ikigai-cosmic-comp.hook" /etc/pacman.d/hooks/ikigai-cosmic-comp.hook
sudo /usr/local/lib/ikigai/ikigai-cosmic-comp --progress
