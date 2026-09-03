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
echo "installed ikigai-session + ikigai-bridge + shell; 'Ikigai' session entry in the greeter"
