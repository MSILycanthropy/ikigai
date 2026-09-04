#!/usr/bin/env bash
# The Ikigai greeter (greeter/): greetd runs `ikigai-greeter` as its own user. Takes over
# display-manager.service from cosmic-greeter on a box that already had stock COSMIC.
set -euo pipefail

G="$IKIGAI_PATH/greeter"
sudo install -Dm644 "$G/sysusers.conf" /etc/sysusers.d/ikigai-greeter.conf
sudo install -Dm644 "$G/tmpfiles.conf" /etc/tmpfiles.d/ikigai-greeter.conf
sudo systemd-sysusers ikigai-greeter.conf
sudo systemd-tmpfiles --create ikigai-greeter.conf
sudo install -Dm644 "$G/ikigai-greeter.toml" /etc/greetd/ikigai-greeter.toml
sudo install -Dm644 "$G/ikigai-greeter.service" /usr/local/lib/systemd/system/ikigai-greeter.service
sudo systemctl daemon-reload

# Display managers alias display-manager.service and only one can hold it: step aside
# whichever is enabled (cosmic-greeter, gdm, sddm) or our enable fails.
current="$(readlink /etc/systemd/system/display-manager.service 2>/dev/null || true)"
if [ -n "$current" ] && [ "$(basename "$current")" != ikigai-greeter.service ]; then
  sudo systemctl disable -q "$(basename "$current")"
fi
sudo systemctl enable -q ikigai-greeter
echo "greeter: ikigai-greeter enabled"
