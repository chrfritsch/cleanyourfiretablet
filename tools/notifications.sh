#!/usr/bin/env bash
# Mute a package's notifications via appops. This is a different, separate check from pm disable-user's
# "protected package" one, so it also works on packages that refuse to be disabled. No root. tools/restore.sh undoes it.
# Usage: tools/notifications.sh <package> [package...]
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: notifications.sh <package> [package...]" >&2; exit 1; }
cd "$(dirname "$0")/.."; . tools/lib.sh
BAD=$(printf '%s\n' "$@" | grep -vE "$PKG_RE" || true)
[ -z "$BAD" ] || die "refusing, not package names: $(tr '\n' ' ' <<<"$BAD")"
CORE=$(printf '%s\n' "$@" | grep -E "$NEVER_RE" || true)
[ -z "$CORE" ] || die "refusing, core packages the tablet needs: $(tr '\n' ' ' <<<"$CORE")"

need_device
tools/backup.sh
INSTALLED=$(sh_ pm list packages | sed 's/^package://')
for p in "$@"; do
  if ! has "$p" "$INSTALLED"; then echo "skipping $p: not on this tablet"; continue; fi
  before=$(sh_ cmd appops get "$p" POST_NOTIFICATION)
  case "$before" in *"No operations."*) mode=allow;; *) mode=${before#POST_NOTIFICATION: };; esac
  grep -q "^$p " "$STATE/notifications-before.txt" 2>/dev/null || echo "$p $mode" >> "$STATE/notifications-before.txt"
  sh_ cmd appops set "$p" POST_NOTIFICATION deny
  echo "muted $p (was: $mode)"
done
