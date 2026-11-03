#!/usr/bin/env bash
# Disable the packages in a list for user 0. Nothing is uninstalled or cleared; tools/restore.sh undoes it.
# Usage: tools/disable.sh <list>           apply to the plugged-in tablet
#        tools/disable.sh --check <list>   only validate the list, no tablet needed
set -euo pipefail
CHECK=; [ "${1:-}" = --check ] && { CHECK=1; shift; }
LIST="${1:?usage: disable.sh [--check] <list>}"
[ -r "$LIST" ] || { echo "cannot read $LIST" >&2; exit 1; }
LIST="$(cd "$(dirname "$LIST")" && pwd)/$(basename "$LIST")"
cd "$(dirname "$0")/.."; . tools/lib.sh

PKGS=$(parse_list "$LIST")
[ -n "$PKGS" ] || die "refusing $LIST: no package names in it"
BAD=$(grep -vE "$PKG_RE" <<<"$PKGS" || true)
[ -z "$BAD" ] || die "refusing $LIST, not package names: $(tr '\n' ' ' <<<"$BAD")"
CORE=$(grep -E "$NEVER_RE" <<<"$PKGS" || true)
[ -z "$CORE" ] || die "refusing $LIST, core packages the tablet needs: $(tr '\n' ' ' <<<"$CORE")"
[ -z "$CHECK" ] || { echo "ok: $LIST ($(grep -c . <<<"$PKGS") packages)"; exit 0; }

need_device
tools/backup.sh
resolve() { sh_ cmd package resolve-activity --brief "$@" | tail -n 1 | cut -d/ -f1; }
KEEP="$(resolve -a android.intent.action.MAIN -c android.intent.category.HOME)
$(resolve -a android.settings.SETTINGS)
$(sh_ settings get secure default_input_method | cut -d/ -f1)
$(sh_ settings get secure enabled_accessibility_services | tr ':' '\n' | cut -d/ -f1)"
ENABLED=$(sh_ pm list packages -e | sed 's/^package://')

TODO=()
for p in $PKGS; do
  if has "$p" "$KEEP"; then echo "keeping $p: it is the current Home, Settings, keyboard or an active accessibility service"; continue; fi
  has "$p" "$ENABLED" && TODO+=("$p")  # ponytail: missing or already disabled = silently skipped
done
[ ${#TODO[@]} -gt 0 ] || { echo "nothing to do: every listed package is already disabled or not on this tablet"; exit 0; }

# Record before touching anything, so restore.sh knows even if this run dies halfway.
printf '%s\n' "${TODO[@]}" >> "$STATE/applied.txt"
done_=0; failed=0
for p in "${TODO[@]}"; do
  out=$(sh_ pm disable-user --user 0 "$p" 2>&1 || true)
  case "$out" in *disabled-user*) echo "disabled $p"; done_=$((done_+1));; *) echo "FAILED   $p: $out"; failed=$((failed+1));; esac
done
echo "$done_ disabled, $failed failed (of ${#TODO[@]} tried)"
