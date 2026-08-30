#!/usr/bin/env bash
set -euo pipefail

PACMAN=(
  base-devel git
  cosmic cosmic-greeter
  ghostty zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship
  zed neovim lazygit
  docker docker-compose lazydocker mise
  zellij yazi btop
  ripgrep fd fzf bat eza dust git-delta tealdeer jq wl-clipboard
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

# Build on disk, not /tmp: tmpfs is RAM-limited and a Rust build needs GBs.
BUILD_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/ikigai/build"
mkdir -p "$BUILD_ROOT"

aur() {
  local build; build="$(mktemp -d -p "$BUILD_ROOT")"
  git clone -q "https://aur.archlinux.org/$1.git" "$build/$1"
  (cd "$build/$1" && makepkg -si --noconfirm --needed)
  rm -rf "$build"
}

paru --version >/dev/null 2>&1 || aur paru
for pkg in "${AUR[@]}"; do pacman -Q "$pkg" >/dev/null 2>&1 || aur "$pkg"; done
