#!/usr/bin/env bash
set -euo pipefail

PACMAN=(
  base-devel git
  cosmic cosmic-greeter
  ghostty zsh starship
  zed neovim lazygit
  docker docker-compose mise
  btop ripgrep fd fzf bat eza wl-clipboard
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
  pipewire pipewire-pulse wireplumber
  xdg-user-dirs
)
AUR=(zen-browser-bin)

case "$(cat "$IKIGAI_STATE/gpu")" in
  nvidia) PACMAN+=(nvidia-open-dkms nvidia-utils linux-headers) ;;
  amd)    PACMAN+=(mesa vulkan-radeon) ;;
  intel)  PACMAN+=(mesa vulkan-intel) ;;
esac

[ "$(systemd-detect-virt)" = microsoft ] && PACMAN+=(hyperv)

sudo pacman -Syu --needed --noconfirm "${PACMAN[@]}"

aur() {
  local build; build="$(mktemp -d)"
  git clone -q "https://aur.archlinux.org/$1.git" "$build/$1"
  (cd "$build/$1" && makepkg -si --noconfirm --needed)
  rm -rf "$build"
}

paru --version >/dev/null 2>&1 || {
  stale=$(pacman -Qq paru-bin paru-bin-debug 2>/dev/null || true)
  [ -z "$stale" ] || sudo pacman -Rns --noconfirm $stale
  aur paru
}
for pkg in "${AUR[@]}"; do pacman -Q "$pkg" >/dev/null 2>&1 || aur "$pkg"; done
