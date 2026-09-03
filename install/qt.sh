#!/usr/bin/env bash
# Rebuild Qt's Wayland client with Ikigai's layer-shell fix (packages/qt6-base/README.md)
# and keep it rebuilt across qt6-base upgrades.
set -euo pipefail

QT="$IKIGAI_PATH/packages/qt6-base"
sudo install -Dm644 "$QT/wayland-unmap-before-role-destroy.patch" /usr/local/share/ikigai/qt6-base/wayland-unmap-before-role-destroy.patch
sudo install -Dm755 "$QT/ikigai-qt-wayland" /usr/local/lib/ikigai/ikigai-qt-wayland
sudo install -Dm644 "$QT/ikigai-qt-wayland.hook" /etc/pacman.d/hooks/ikigai-qt-wayland.hook
sudo /usr/local/lib/ikigai/ikigai-qt-wayland
