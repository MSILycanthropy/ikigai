#!/usr/bin/env bash
# Build icons/Ikigai, a symbolic icon theme made of Phosphor's regular-weight SVGs (MIT),
# from the freedesktop-name → Phosphor-name table in icons/phosphor.map. Phosphor's SVGs
# are already fill="currentColor", which is all a symbolic icon needs. Names not in the
# table fall back to Cosmic through Inherits.
set -euo pipefail
REV=2b75f3ad12b420c9504ef05df8d2564a28f8500e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAP="$ROOT/icons/phosphor.map"
DEST="$ROOT/icons/Ikigai"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL "https://github.com/phosphor-icons/core/archive/$REV.tar.gz" | tar -xzf - -C "$WORK" --strip-components=1 --wildcards '*/assets/regular/*.svg'
rm -rf "$DEST"
context=""; contexts=(); count=0
while read -r a b; do
  case "$a" in ""|"#"*) continue ;; esac
  if [[ "$a" == \[*\] ]]; then context="${a#[}"; context="${context%]}"; contexts+=("$context"); continue; fi
  install -Dm644 "$WORK/assets/regular/$b.svg" "$DEST/scalable/$context/$a-symbolic.svg"
  count=$((count + 1))
done < "$MAP"

dirs=$(printf 'scalable/%s,' "${contexts[@]}")
{
  printf '[Icon Theme]\nName=Ikigai\nComment=Phosphor as a symbolic icon theme\nInherits=Cosmic,Pop,hicolor\nDirectories=%s\n' "${dirs%,}"
  for c in "${contexts[@]}"; do
    printf '\n[scalable/%s]\nContext=%s\nSize=16\nMinSize=8\nMaxSize=512\nType=Scalable\n' "$c" "${c^}"
  done
} > "$DEST/index.theme"
echo "vendored icons/Ikigai ($count icons) @ $REV"
