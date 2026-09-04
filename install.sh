#!/usr/bin/env bash
set -euo pipefail

export IKIGAI_PATH="${IKIGAI_PATH:-$HOME/.local/share/ikigai}"
export IKIGAI_STATE="${IKIGAI_STATE:-$HOME/.local/state/ikigai}"
mkdir -p "$IKIGAI_STATE"
LOG="$IKIGAI_STATE/install.log"

STEPS=(preflight packages qt configs tools theme services firewall session greeter)
CURRENT=setup

step() { echo; echo "==> [$1]"; }
fail() { echo; echo "!!! install failed in step '$CURRENT' (see $LOG)" >&2; }
trap fail ERR

sudo true
( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill $SUDO_KEEPALIVE 2>/dev/null' EXIT

exec > >(tee -a "$LOG") 2>&1
commit="$(git -C "$IKIGAI_PATH" rev-parse HEAD 2>/dev/null || echo unversioned)"
echo "ikigai install $(date -Is) — ${commit:0:7}"
echo "$commit" > "$IKIGAI_STATE/installed_commit"

for CURRENT in "${STEPS[@]}"; do
  step "$CURRENT"
  bash "$IKIGAI_PATH/install/$CURRENT.sh"
done

echo
echo "==> Ikigai installed. Reboot to start COSMIC:  sudo reboot"
