#!/usr/bin/env bash
# Per-user tools that keep themselves current, outside pacman. Claude Code's native
# installer manages ~/.local/bin/claude and updates on upstream's release cadence; the
# AUR package pins it to pacman and turns updates off.
set -euo pipefail

if [ -x "$HOME/.local/bin/claude" ] || command -v claude >/dev/null 2>&1; then
  echo "claude already installed: $(claude --version 2>/dev/null || "$HOME/.local/bin/claude" --version)"
else
  curl -fsSL https://claude.ai/install.sh | bash
fi
