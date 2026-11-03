#!/usr/bin/env bash
# Install Google Play on a Fire tablet from APKs you downloaded yourself (Google's APKs are not ours to ship).
# Each file must match a hash in gapps.sha256 or be signed by Google, checked before anything is installed.
# ALLOW_UNVERIFIED=1 skips that check.
# Usage: tools/gplay.sh gapps/        a folder holding the three files below (.apk or APKMirror .apkm)
set -euo pipefail
DIR="${1:?usage: gplay.sh <folder with the Google APKs>}"
[ -d "$DIR" ] || { echo "no folder: $DIR" >&2; exit 1; }
DIR="$(cd "$DIR" && pwd)"
cd "$(dirname "$0")/.."; . tools/lib.sh; need_device

SDK=$(sh_ getprop ro.build.version.sdk)
# Some Fire tablets report arm64 in ro.product.cpu.abi while only 32-bit apps run; the abilist is what counts.
ABILIST=$(sh_ getprop ro.product.cpu.abilist)
case ",$ABILIST," in *,arm64-v8a,*) ABI=arm64-v8a;; *) ABI=armeabi-v7a;; esac
echo "$(sh_ getprop ro.build.mktg.fireos), Android SDK $SDK, ABI list $ABILIST -> use $ABI"
[ "$SDK" -ge 28 ] || die "needs Fire OS 7 or newer (Android 9, SDK 28)"
GSF=9; [ "$SDK" -ge 29 ] && GSF=10

need() {
  cat >&2 <<EOF
missing in $DIR: $1
Download from apkmirror.com (versions tested on a Fire HD 10 with Fire OS 8.3.3.8 in brackets):
  Google Services Framework  $GSF-*          (10-6494331; Fire OS 7: 9-6957767)
  Google Play services       $ABI, minAPI <= $SDK, nodpi   (26.43.30, the 150400 variant)
  Google Play Store          any recent APK, nodpi   (53.7.24-24)
Files listed in gapps.sha256 are known good; any other must be signed by Google (needs apksigner).
EOF
  exit 1
}

pick() {  # filename pattern, package: prints the path of the matching file in $DIR
  local c
  for c in "$DIR"/*.apk "$DIR"/*.apkm "$DIR"/*.apks "$DIR"/*.xapk; do
    [ -e "$c" ] && grep -iqE "$1" <<<"${c##*/}" && { echo "$c"; return; }
  done
  need "$2 (file name matching $1)"
}

install_one() {  # package, file
  local f=$2 out tmp
  echo "installing $1 from ${f##*/}"
  case "$f" in
    *.apk) out=$(adb install -r -g "$f" 2>&1) || true ;;
    *) tmp=$(mktemp -d)
       unzip -qo "$f" '*.apk' -d "$tmp" || { rm -rf "$tmp"; die "  cannot unpack ${f##*/} (an encrypted .apkm? get the .apk or a plain bundle)"; }
       out=$(adb install-multiple -r -g "$tmp"/*.apk 2>&1) || true; rm -rf "$tmp" ;;
  esac
  # adb's own verdict, not pm path: a failed upgrade over an existing install would still pass pm path
  case "$out" in *Success*) echo "  ok"; return;; esac
  case "$out" in
    *NO_MATCHING_ABIS*) die "  wrong variant: this tablet needs $ABI";;
    *OLDER_SDK*)        die "  too new: pick a build with minAPI <= $SDK";;
    *)                  die "  failed: $out";;
  esac
}

F_GSF=$(pick 'gsf|services.?framework' com.google.android.gsf)
F_GMS=$(pick 'gms|play.?services' com.google.android.gms)
F_VEN=$(pick 'vending|play.?store' com.android.vending)
# Check all three before the first install, so a bad file never leaves a half-installed set.
for f in "$F_GSF" "$F_GMS" "$F_VEN"; do
  echo "checking ${f##*/}"
  if ! verify_gapp "$f"; then
    [ -n "${ALLOW_UNVERIFIED:-}" ] || die "  refusing ${f##*/}"
    echo "  ALLOW_UNVERIFIED set, installing anyway"
  fi
done

# Order matters: the framework, then services, then the store that needs both.
install_one com.google.android.gsf "$F_GSF"
install_one com.google.android.gms "$F_GMS"
install_one com.android.vending   "$F_VEN"
echo "done. Reboot (adb reboot), open Play Store and sign in. Stuck on 'Checking info'? Reboot once more."
