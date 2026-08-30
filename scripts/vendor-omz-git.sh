#!/usr/bin/env bash
# Vendor oh-my-zsh's git aliases as a single file (MIT). Its only external
# dependency, `git_current_branch`, is defined in config/zsh/.zshrc.
set -euo pipefail
REV=4b657407c98bbc8830ae66c2ac7ff3d737c55a83
DEST="$(cd "$(dirname "$0")/.." && pwd)/config/zsh/git-aliases.zsh"
curl -fsSL -o "$DEST" "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/$REV/plugins/git/git.plugin.zsh"
echo "vendored git-aliases.zsh @ $REV"
