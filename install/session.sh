#!/usr/bin/env bash
# Build ikigai-session + ikigai-bridge from session/, install them with their units,
# and copy the Quickshell shell to /usr/local/share/ikigai/shell.
set -euo pipefail

export CARGO_TARGET_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ikigai/build/session"
cargo build --release --locked --manifest-path "$IKIGAI_PATH/session/Cargo.toml"

for b in ikigai-session ikigai-bridge; do
  sudo install -Dm755 "$CARGO_TARGET_DIR/release/$b" "/usr/local/bin/$b"
done
(cd "$IKIGAI_PATH/session/systemd" && find . -type f) | while read -r u; do
  sudo install -Dm644 "$IKIGAI_PATH/session/systemd/$u" "/usr/local/lib/systemd/user/$u"
done
sudo install -Dm644 "$IKIGAI_PATH/session/ikigai.desktop" /usr/share/wayland-sessions/ikigai.desktop
# Enable Vicinae the way its [Install] section intends (its upgrade hook checks is-enabled);
# a Wants= from the target would form an ordering cycle through graphical-session.target.
sudo systemctl --global enable -q vicinae.service

(cd "$IKIGAI_PATH/shell" && find . -type f) | while read -r f; do
  sudo install -Dm644 "$IKIGAI_PATH/shell/$f" "/usr/local/share/ikigai/shell/$f"
done
# The blob renderer is a Qt Quick plugin (shell/plugin); the shell unit adds
# /usr/local/lib/qt6/qml to the QML import path.
BLOBS_BUILD="${XDG_CACHE_HOME:-$HOME/.cache}/ikigai/build/blobs"
cmake -S "$IKIGAI_PATH/shell/plugin" -B "$BLOBS_BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_INSTALL_LIBDIR=lib >/dev/null
cmake --build "$BLOBS_BUILD" >/dev/null
sudo cmake --install "$BLOBS_BUILD" >/dev/null
echo "installed ikigai-session + ikigai-bridge + shell; 'Ikigai' session entry in the greeter"
