#!/usr/bin/env bash
# Where the seeded user configs stand against this tree (`just config-diff`): for each
# seed in install/configs.sh, whether the file in $HOME is still what the installer wrote
# (the sha in ~/.local/state/ikigai/seeds), edited by hand, or behind the repo. A diff for
# each hand-edited one with --diff, so a change made on the box can go back into config/.
set -euo pipefail

tree="$(cd "$(dirname "$0")/.." && pwd)"
seeds="${IKIGAI_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/ikigai}/seeds"
show=${1:-}

# Same lines install/configs.sh feeds seed(); $HOME expands here.
sed -n 's/^seed \([^ ]*\) *\(.*\)$/\1 \2/p' "$tree/install/configs.sh" | while read -r from to; do
  to=$(eval echo "$to")
  repo="$tree/config/$from"
  state=missing
  if [ -e "$to" ]; then
    now=$(sha256sum "$to" | cut -d' ' -f1)
    rs=$(sha256sum "$repo" | cut -d' ' -f1)
    seeded=$(cat "$seeds/${to//\//%}" 2>/dev/null || true)
    if [ "$now" = "$rs" ]; then state=current
    elif [ -n "$seeded" ] && [ "$now" = "$seeded" ]; then state=behind
    else state=edited; fi
  fi
  printf '%-8s %s\n' "$state" "$to"
  if [ "$show" = --diff ] && [ "$state" = edited ]; then
    diff -u --color=auto "$repo" "$to" | sed 's/^/    /' || true
  fi
done
echo
echo "current: matches config/  behind: untouched since seeding, repo moved on (just install configs -- IKIGAI_FORCE=1)"
echo "edited:  changed by hand (--diff shows it)  missing: never seeded"
