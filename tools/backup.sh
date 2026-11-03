#!/usr/bin/env bash
# Save the tablet's untouched state once, to backup/<serial>/before/. Later runs keep that first copy.
set -euo pipefail
cd "$(dirname "$0")/.."; . tools/lib.sh; need_device
B="$STATE/before"
[ -d "$B" ] && { echo "backup already taken: $B"; exit 0; }
mkdir -p "$B.tmp"
sh_ pm list packages -f > "$B.tmp/packages.txt"
sh_ pm list packages -d > "$B.tmp/disabled.txt"
sh_ getprop > "$B.tmp/getprop.txt"
for ns in global secure system; do sh_ settings list "$ns" > "$B.tmp/settings-$ns.txt"; done
sh_ cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME > "$B.tmp/home.txt"
mv "$B.tmp" "$B"
echo "backed up to $B"
