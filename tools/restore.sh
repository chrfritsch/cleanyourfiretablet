#!/usr/bin/env bash
# Undo disable.sh and privacy.sh on the plugged-in tablet, from backup/<serial>/.
# Only what this repo changed is reverted; packages you had disabled before stay disabled.
set -euo pipefail
cd "$(dirname "$0")/.."; . tools/lib.sh; need_device
TS=$(date +%Y%m%d-%H%M%S)
[ -s "$STATE/applied.txt" ] || [ -s "$STATE/settings-before.txt" ] || [ -s "$STATE/notifications-before.txt" ] || [ -s "$STATE/browser-before.txt" ] ||
  die "nothing to restore: no record for this tablet in $STATE/ (ran the tools from another computer or clone?)"
if [ -s "$STATE/applied.txt" ]; then
  sort -u "$STATE/applied.txt" | while read -r p; do echo "$p: $(sh_ pm enable --user 0 "$p" 2>&1 || true)"; done
  mv "$STATE/applied.txt" "$STATE/applied.restored-$TS.txt"
fi
if [ -s "$STATE/settings-before.txt" ]; then
  # One failed setting must not stop the rest; values are quoted for the tablet's shell.
  while read -r ns key val; do
    if [ -z "$val" ] || [ "$val" = null ]; then sh_ settings delete "$ns" "$key" >/dev/null || echo "FAILED $ns $key"
    else sh_ settings put "$ns" "$key" "'${val//\'/}'" || echo "FAILED $ns $key"; fi
    echo "$ns $key -> ${val:-null}"
  done < "$STATE/settings-before.txt"
  mv "$STATE/settings-before.txt" "$STATE/settings-before.restored-$TS.txt"
fi
if [ -s "$STATE/notifications-before.txt" ]; then
  while read -r p mode; do
    sh_ cmd appops set "$p" POST_NOTIFICATION "$mode" >/dev/null || echo "FAILED $p"
    echo "$p notifications -> $mode"
  done < "$STATE/notifications-before.txt"
  mv "$STATE/notifications-before.txt" "$STATE/notifications-before.restored-$TS.txt"
fi
if [ -s "$STATE/browser-before.txt" ]; then
  p=$(cat "$STATE/browser-before.txt")
  sh_ cmd role add-role-holder android.app.role.BROWSER "$p" >/dev/null || echo "FAILED browser role -> $p"
  echo "default browser -> $p"
  mv "$STATE/browser-before.txt" "$STATE/browser-before.restored-$TS.txt"
fi
echo "restored. Google Play stays installed; remove it with: adb uninstall com.android.vending (then gms, gsf)"
