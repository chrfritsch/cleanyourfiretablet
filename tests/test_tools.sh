#!/usr/bin/env bash
# Offline checks: shipped lists validate, bad lists are refused. No tablet needed.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0
ok()     { tools/disable.sh --check "$1" >/dev/null 2>&1 || { echo "FAIL: should pass: $1"; fail=1; }; }
refuse() { printf '%b' "$2" > "$T/$1"; ! tools/disable.sh --check "$T/$1" >/dev/null 2>&1 || { echo "FAIL: should refuse: $1"; fail=1; }; }

for l in examples/*/debloat.txt; do ok "$l"; done
printf '\357\273\277# BOM and CRLF\r\ncom.amazon.weather  # x\r\n' > "$T/crlf.txt"; ok "$T/crlf.txt"
. tools/lib.sh
[ "$(parse_list "$T/crlf.txt")" = com.amazon.weather ] || { echo "FAIL: BOM/CRLF parse"; fail=1; }

# verify_gapp: a pinned hash passes, any other file is refused when apksigner is missing
printf 'known' > "$T/good.apk"; printf 'tampered' > "$T/bad.apk"
echo "$(sha256_of "$T/good.apk")  good.apk" > "$T/pins"
( GAPPS_SHA256="$T/pins" APKSIGNER=/nonexistent; verify_gapp "$T/good.apk" >/dev/null 2>&1 ) || { echo "FAIL: pinned file refused"; fail=1; }
( GAPPS_SHA256="$T/pins" APKSIGNER=/nonexistent; ! verify_gapp "$T/bad.apk" >/dev/null 2>&1 ) || { echo "FAIL: unpinned file accepted"; fail=1; }
[ "$(grep -cE '^[0-9a-f]{64} ' gapps.sha256)" -ge 3 ] || { echo "FAIL: gapps.sha256 empty"; fail=1; }

# README and list header claim "N of M": N = active packages, M = N + commented-out protected ones
L=examples/kftuwi/debloat.txt
n=$(parse_list "$L" | wc -l | tr -d ' '); m=$((n + $(grep -cE '^# [A-Za-z][A-Za-z0-9_.]+( +#.*)?$' "$L")))
for f in README.md "$L"; do grep -q "$n of $m" "$f" || { echo "FAIL: $f does not say '$n of $m'"; fail=1; }; done

# no personal details in tracked or new files: serials of local backups, private IPs, home paths
files=(); while IFS= read -r f; do files+=("$f"); done < <(git ls-files -co --exclude-standard | grep -v '^tests/test_tools.sh$')
if [ ${#files[@]} -gt 0 ]; then
  for d in backup/*/; do
    s=${d#backup/}; s=${s%/}; [ -d "$d" ] || continue
    ! grep -l -- "$s" "${files[@]}" || { echo "FAIL: backup serial in tracked files"; fail=1; }
  done
  ! grep -nE '(192\.168|10\.[0-9]+)\.[0-9]+\.[0-9]+|/Users/[a-z]|/home/[a-z]' "${files[@]}" || { echo "FAIL: personal detail above"; fail=1; }
fi

refuse shell.txt 'com.amazon.weather; reboot\n'
refuse core.txt 'com.android.systemui\n'
refuse launcher.txt 'com.amazon.firelauncher\n'
refuse play.txt 'com.android.vending\n'
refuse webview.txt 'com.amazon.webview.chromium\n'
refuse empty.txt '# nothing\n\n'
for f in tools/*.sh tests/*.sh; do bash -n "$f" || fail=1; done
[ $fail = 0 ] && echo "all ok"
exit $fail
