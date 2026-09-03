#!/usr/bin/env bash
# Runs inside an archlinux container in CI: syntax-check every script and
# verify every curated package name resolves in the official repos.
set -euo pipefail
cd "$(dirname "$0")/.."

for f in boot.sh install.sh install/*.sh bin/* scripts/*.sh packages/qt6-base/ikigai-qt-wayland; do bash -n "$f"; done
echo "syntax ok"

[ "$(id -u)" -eq 0 ] && pacman -Sy --noconfirm >/dev/null
eval "$(sed -n '/^PACMAN=(/,/^)/p' install/packages.sh)"
pacman -Sp --noconfirm "${PACMAN[@]}" >/dev/null
echo "all ${#PACMAN[@]} repo packages resolve"

for p in nvidia-open-dkms nvidia-utils linux-headers mesa vulkan-radeon vulkan-intel hyperv; do
  pacman -Si "$p" >/dev/null
done
echo "gpu/vm packages resolve"

[ "$(id -u)" -eq 0 ] && pacman -S --noconfirm --needed rust >/dev/null
(cd session && cargo test --locked -q && cargo clippy --locked -q --all-targets -- -D warnings)
echo "session crate ok"

find themes config -type f \( -name '*.ron' -o -path '*/v[0-9]/*' \) | while read -r f; do
  grep -q . "$f" || { echo "empty config file: $f"; exit 1; }
done
echo "config files non-empty"

[ "$(id -u)" -eq 0 ] && pacman -S --noconfirm --needed python >/dev/null
python -c '
import json; d = json.load(open("archinstall.json"))
assert d["profile_config"]["profile"]["main"] == "Minimal"
assert d["bootloader_config"]["bootloader"] == "Systemd-boot"
assert d["network_config"]["type"] == "nm"
assert any("boot.sh" in c for c in d["custom_commands"])
'
echo "archinstall.json ok"

python -c '
import json, glob
for f in ["config/ikigai/shell.json", *glob.glob("themes/*/shell.json")]: json.load(open(f))
'
echo "shell json ok"
