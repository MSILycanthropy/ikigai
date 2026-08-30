#!/usr/bin/env bash
set -euo pipefail

die() { echo "preflight: $*" >&2; exit 1; }

[ -f /etc/arch-release ] || die "Ikigai requires Arch Linux"
[ "$(id -u)" -ne 0 ] || die "run as a regular user with sudo, not root"
command -v sudo >/dev/null || die "sudo is not installed"
sudo -n true 2>/dev/null || die "user $(id -un) cannot sudo"
[ -d /sys/firmware/efi ] || die "UEFI boot required (cosmic-greeter/systemd-boot assumptions)"
curl -fsS --max-time 10 https://archlinux.org >/dev/null || die "no network"

gpu=none
for vendor in /sys/class/drm/card[0-9]/device/vendor; do
  [ -r "$vendor" ] || continue
  case "$(cat "$vendor")" in
    0x10de) gpu=nvidia ;;
    0x1002) [ "$gpu" = nvidia ] || gpu=amd ;;
    0x8086) [ "$gpu" = none ] && gpu=intel ;;
  esac
done
echo "$gpu" > "$IKIGAI_STATE/gpu"
echo "arch: ok  user: $(id -un)  uefi: ok  network: ok  gpu: $gpu"
