#!/usr/bin/env bash
# Install every .apk and bundle (.apkm/.apks/.xapk) in a folder. Nothing is verified: only use files you trust.
# Usage: tools/install.sh <folder>      (Google Play: use tools/gplay.sh, it checks the files)
set -uo pipefail
DIR="${1:?usage: install.sh <folder with APKs>}"
[ -d "$DIR" ] || { echo "no folder: $DIR" >&2; exit 1; }
DIR="$(cd "$DIR" && pwd)"
cd "$(dirname "$0")/.." || exit 1; . tools/lib.sh; need_device

ok=0; bad=0
for f in "$DIR"/*.apk "$DIR"/*.apkm "$DIR"/*.apks "$DIR"/*.xapk; do
  [ -e "$f" ] || continue
  echo "installing ${f##*/}"
  case "$f" in
    *.apk) out=$(adb install -r "$f" 2>&1);;
    *) tmp=$(mktemp -d)
       if unzip -qo "$f" '*.apk' -d "$tmp" && compgen -G "$tmp/*.apk" >/dev/null; then out=$(adb install-multiple -r "$tmp"/*.apk 2>&1)
       else out="cannot unpack (encrypted bundle?)"; fi
       rm -rf "$tmp";;
  esac
  case "$out" in *Success*) echo "  ok"; ok=$((ok+1));; *) echo "  failed: $out" >&2; bad=$((bad+1));; esac
done
[ $((ok+bad)) -gt 0 ] || die "no .apk/.apkm/.apks/.xapk files in $DIR"
echo "$ok installed, $bad failed"
[ "$bad" = 0 ]
