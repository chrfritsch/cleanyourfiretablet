#!/usr/bin/env bash
# Shorter animations: the tablet feels snappier, it does not get faster. tools/restore.sh undoes it.
# Usage: tools/speed.sh [scale]   0.5 by default; 0 = off, 1 = Fire OS default
set -euo pipefail
S="${1:-0.5}"
[[ "$S" =~ ^[0-9](\.[0-9]+)?$ ]] || { echo "not a scale: $S (e.g. 0.5)" >&2; exit 1; }
cd "$(dirname "$0")/.."; . tools/lib.sh; need_device
tools/backup.sh
for k in window_animation_scale transition_animation_scale animator_duration_scale; do put global "$k" "$S"; done
