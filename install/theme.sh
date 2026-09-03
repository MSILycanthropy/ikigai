#!/usr/bin/env bash
set -euo pipefail
exec "$IKIGAI_PATH/bin/ikigai-theme-set" "${IKIGAI_THEME:-ikigai}"
