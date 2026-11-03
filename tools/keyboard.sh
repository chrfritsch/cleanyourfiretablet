#!/usr/bin/env bash
# Make Gboard the keyboard; Fire OS has no menu for it. Needs Google Play (tools/gplay.sh).
# tools/restore.sh switches back to the Amazon keyboard.
set -euo pipefail
cd "$(dirname "$0")/.."; . tools/lib.sh; need_device
tools/backup.sh
IME=com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME
if ! sh_ pm path "${IME%%/*}" | grep -q package:; then
  # -p: Fire OS would otherwise offer the Amazon Appstore for market:// links
  sh_ am start -a android.intent.action.VIEW -d "market://details?id=${IME%%/*}" -p com.android.vending >/dev/null
  die "Gboard is not installed: install it from the Play Store page just opened on the tablet (sign in first), then run this again"
fi
record secure default_input_method; record secure enabled_input_methods
sh_ ime enable "$IME" >/dev/null; sh_ ime set "$IME" >/dev/null
[ "$(sh_ settings get secure default_input_method)" = "$IME" ] || die "Fire OS did not switch to Gboard"
echo "keyboard is now Gboard"
