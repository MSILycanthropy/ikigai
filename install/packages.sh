#!/usr/bin/env bash
set -euo pipefail

PACMAN=(
  base-devel git rust quickshell qt6-shadertools cmake ninja ccache vulkan-headers
  cosmic cosmic-greeter greetd
  ghostty zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions starship
  zed neovim lazygit github-cli just discord
  docker docker-compose lazydocker mise
  zellij yazi btop
  grim slurp satty gpu-screen-recorder mpv
  ripgrep fd fzf bat eza dust git-delta tealdeer jq wl-clipboard ufw
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji adw-gtk-theme
  pipewire pipewire-pulse wireplumber
  xdg-user-dirs
)
AUR=(zen-browser-bin vicinae-bin pear-desktop-bin ttf-phosphor-icons ufw-docker)

case "$(cat "$IKIGAI_STATE/gpu")" in
  nvidia) PACMAN+=(nvidia-open-dkms nvidia-utils linux-headers) ;;
  amd)    PACMAN+=(mesa vulkan-radeon) ;;
  intel)  PACMAN+=(mesa vulkan-intel) ;;
esac

[ "$(systemd-detect-virt)" = microsoft ] && PACMAN+=(hyperv)

# 32-bit packages (Steam and its drivers) come from multilib; enable it once, up front.
sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

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
