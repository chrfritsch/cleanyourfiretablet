#!/usr/bin/env bash
# Read-only: how much of a list is still disabled, and what came back (a Fire OS update, say).
# Usage: tools/status.sh <list>
set -euo pipefail
LIST="${1:?usage: status.sh <list>}"
[ -r "$LIST" ] || { echo "cannot read $LIST" >&2; exit 1; }
LIST="$(cd "$(dirname "$LIST")" && pwd)/$(basename "$LIST")"
cd "$(dirname "$0")/.."; . tools/lib.sh; need_device
ALL=$(sh_ pm list packages | sed 's/^package://')
OFF=$(sh_ pm list packages -d | sed 's/^package://')
off=0 missing=0 on=""
for p in $(parse_list "$LIST"); do
  if has "$p" "$OFF"; then off=$((off+1)); elif has "$p" "$ALL"; then on="$on $p"; else missing=$((missing+1)); fi
done
echo "$off disabled, $missing not on this tablet"
[ -z "$on" ] || echo "enabled:$on
  (protected and kept ones always show here; to disable the rest again: tools/disable.sh $1)"
