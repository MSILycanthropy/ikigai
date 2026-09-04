#!/usr/bin/env bash
# The Ikigai greeter (greeter/): greetd runs `ikigai-greeter` as its own user. Takes over
# display-manager.service from cosmic-greeter, which stays installed for its locker.
set -euo pipefail

G="$IKIGAI_PATH/greeter"
sudo install -Dm644 "$G/sysusers.conf" /etc/sysusers.d/ikigai-greeter.conf
sudo install -Dm644 "$G/tmpfiles.conf" /etc/tmpfiles.d/ikigai-greeter.conf
sudo systemd-sysusers ikigai-greeter.conf
sudo systemd-tmpfiles --create ikigai-greeter.conf
sudo install -Dm644 "$G/ikigai-greeter.toml" /etc/greetd/ikigai-greeter.toml
sudo install -Dm644 "$G/ikigai-greeter.service" /usr/local/lib/systemd/system/ikigai-greeter.service
sudo systemctl daemon-reload

# Both units alias display-manager.service; only one can hold it.
sudo systemctl disable -q cosmic-greeter 2>/dev/null || true
sudo systemctl enable -q ikigai-greeter
echo "greeter: ikigai-greeter enabled (cosmic-greeter disabled)"
