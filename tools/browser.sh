#!/usr/bin/env bash
# Make Brave the default browser; Fire OS has no menu for it. Installs Brave itself first if it's missing:
# Brave's own GitHub release, checksum verified against the .sha256 file Brave publishes alongside it (same
# official source, fetched fresh each run - ponytail: no pinned signing cert like gapps.sha256's Google
# pin, add one if that ever turns out not to be enough). Falls back to opening Brave's Play Store page if
# curl is missing or GitHub can't be reached; a checksum mismatch always stops, never falls back silently.
# Does not touch Silk; run tools/disable.sh separately once Brave works if you want it gone.
# tools/restore.sh switches the browser role back.
set -euo pipefail
cd "$(dirname "$0")/.."; . tools/lib.sh; need_device
tools/backup.sh
PKG=com.brave.browser

install_from_play() {
  # -p: Fire OS would otherwise offer the Amazon Appstore for market:// links
  sh_ am start -a android.intent.action.VIEW -d "market://details?id=$PKG" -p com.android.vending >/dev/null
  die "Brave is not installed: install it from the Play Store page just opened on the tablet (sign in first), then run this again"
}

install_sideload() {
  command -v curl >/dev/null || return 1
  local abilist abi tag base apk got want tmp out
  abilist=$(sh_ getprop ro.product.cpu.abilist)
  case ",$abilist," in
    *,arm64-v8a,*)   abi=arm64;;
    *,armeabi-v7a,*) abi=arm;;
    *,x86_64,*)      abi=x64;;
    *,x86,*)         abi=x86;;
    *) return 1;;
  esac
  tag=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/brave/brave-browser/releases/latest 2>/dev/null | sed 's#.*/tag/##') || return 1
  [ -n "$tag" ] || return 1
  base="https://github.com/brave/brave-browser/releases/download/$tag/BraveMono$abi.apk"
  tmp=$(mktemp -d); apk="$tmp/brave.apk"
  echo "downloading Brave $tag ($abi) from Brave's GitHub releases"
  if ! curl -fsSL -o "$apk" "$base" || ! curl -fsSL -o "$apk.sha256" "$base.sha256"; then rm -rf "$tmp"; return 1; fi
  got=$(sha256_of "$apk"); want=$(awk '{print $1}' "$apk.sha256")
  [ "$got" = "$want" ] || die "refusing $apk: checksum does not match Brave's published $base.sha256 ($got != $want)"
  out=$(adb install "$apk" 2>&1) || true
  rm -rf "$tmp"
  case "$out" in *Success*) return 0;; *) echo "  sideload install failed: $out" >&2; return 1;; esac
}

if ! sh_ pm path "$PKG" | grep -q package:; then
  install_sideload || install_from_play
fi
role_holder() { sh_ dumpsys role | awk '/name=android.app.role.BROWSER/{f=1} f&&/holders=/{sub(/^ *holders=/,"");print;exit}'; }
BEFORE=$(role_holder)
[ -s "$STATE/browser-before.txt" ] || printf '%s\n' "$BEFORE" > "$STATE/browser-before.txt"
sh_ cmd role add-role-holder android.app.role.BROWSER "$PKG" >/dev/null
[ "$(role_holder)" = "$PKG" ] || die "Fire OS did not switch the browser role to Brave (still: $(role_holder))"
echo "default browser is now Brave"
