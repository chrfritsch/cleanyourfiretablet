#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034,SC2329,SC2001  # check strings are eval'd on purpose
# disable.sh, status.sh, privacy.sh, speed.sh, keyboard.sh, restore.sh and gplay.sh against a fake tablet (tests/fake-adb). No real device.
set -uo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/repo" "$T/fake" "$T/gapps"
cp "$SRC/tests/fake-adb" "$T/bin/adb"; chmod +x "$T/bin/adb"
printf '#!/bin/sh\nexit 1\n' > "$T/bin/curl"; chmod +x "$T/bin/curl"  # no network in tests: browser.sh must fall back to Play
cp -R "$SRC/tools" "$T/repo/"  # tools write backup/ next to themselves; keep that out of the real repo
export PATH="$T/bin:$PATH" FAKE="$T/fake" FAKE_RECORD="$T/repo/backup/FAKE123/applied.txt"
R="$T/repo"; B="$R/backup/FAKE123"; fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
state() { awk -v p="$1" '$1==p{print $2}' "$FAKE/packages"; }
# "unset" only when the row is gone; a literal "null" value is a different (wrong) state.
setting() { awk -v n="$1" -v k="$2" '$1==n && $2==k{print $3; f=1} END{if(!f) print "unset"}' "$FAKE/settings"; }

cat > "$FAKE/packages" <<EOF
com.example.home enabled
com.example.keyboard enabled
com.example.settings enabled
com.amazon.weather enabled
com.amazon.kindle.kso enabled
com.amazon.mp3 disabled
com.amazon.device.metrics enabled
com.example.a11y enabled
com.amazon.cloud9 enabled
EOF
echo com.amazon.device.metrics > "$FAKE/protected"
echo com.example.home > "$FAKE/home"
echo com.amazon.cloud9 > "$FAKE/browser"
cat > "$FAKE/settings" <<EOF
secure default_input_method com.example.keyboard/.Ime
secure limit_ad_tracking 0
secure enabled_accessibility_services com.example.a11y/.Svc:com.other/.Svc
EOF
cat > "$FAKE/props" <<EOF
ro.serialno FAKE123
ro.build.version.sdk 30
ro.build.mktg.fireos 8.3.2.4
ro.product.cpu.abi arm64-v8a
ro.product.cpu.abilist armeabi-v7a,armeabi
EOF
cat > "$T/list.txt" <<EOF
com.amazon.weather
com.amazon.kindle.kso
com.amazon.weather          # listed twice
com.example.a11y
com.amazon.mp3              # already disabled by the owner
com.amazon.device.metrics   # protected
com.example.home
com.example.keyboard
com.example.settings
com.amazon.notinstalled
EOF

echo "--- disable"
out=$("$R/tools/disable.sh" "$T/list.txt" 2>&1); echo "$out" | sed 's/^/    /'
check "listed packages disabled"             '[ "$(state com.amazon.weather)$(state com.amazon.kindle.kso)" = disableddisabled ]'
check "Home, keyboard, Settings, a11y kept"  '[ "$(state com.example.home)$(state com.example.keyboard)$(state com.example.settings)$(state com.example.a11y)" = enabledenabledenabledenabled ]'
check "record under ro.serialno, not Wi-Fi id" '[ -d "$B/before" ] && [ "$(ls "$R/backup")" = FAKE123 ]'
check "protected failure did not stop run"   'grep -q "FAILED   com.amazon.device.metrics" <<<"$out"'
check "summary counts printed"               'grep -q "^2 disabled, 1 failed (of 3 tried)" <<<"$out"'
check "record written before each disable"   '[ ! -s "$FAKE/violations" ]'
check "record skips owner-disabled package"  '! grep -qx com.amazon.mp3 "$B/applied.txt"'
check "record skips kept and missing ones"   '! grep -qE "com\.example|notinstalled" "$B/applied.txt"'
check "backup saw the original state"        'grep -qx package:com.amazon.mp3 "$B/before/disabled.txt" && ! grep -q weather "$B/before/disabled.txt"'

check "status counts the list"               'grep -q "^3 disabled, 1 not on this tablet" <<<"$("$R/tools/status.sh" "$T/list.txt")"'

echo "--- disable again"
out=$("$R/tools/disable.sh" "$T/list.txt" 2>&1)
check "backup not overwritten"               '! grep -q weather "$B/before/disabled.txt" && grep -q "backup already taken" <<<"$out"'

echo "--- privacy"
"$R/tools/privacy.sh" dns.example.org >/dev/null
check "settings applied"                     '[ "$(setting secure limit_ad_tracking) $(setting global private_dns_specifier)" = "1 dns.example.org" ]'
check "bad DNS hostname refused"             '! "$R/tools/privacy.sh" "x;reboot" >/dev/null 2>&1'

echo "--- speed"
check "bad scale refused"                    '! "$R/tools/speed.sh" "1;reboot" >/dev/null 2>&1'
"$R/tools/speed.sh" >/dev/null
check "animations at 0.5"                    '[ "$(setting global window_animation_scale)$(setting global animator_duration_scale)" = 0.50.5 ]'

echo "--- keyboard"
G=com.google.android.inputmethod.latin
out=$("$R/tools/keyboard.sh" 2>&1)
check "no Gboard: Play page opened, refused"  'grep -q "market://details?id=$G" "$FAKE/log" && grep -q "not installed" <<<"$out" && [ "$(setting secure default_input_method)" = com.example.keyboard/.Ime ]'
echo "$G enabled" >> "$FAKE/packages"
"$R/tools/keyboard.sh" >/dev/null
check "Gboard is the keyboard"               '[ "$(setting secure default_input_method)" = $G/com.android.inputmethod.latin.LatinIME ]'

echo "--- browser"
out=$("$R/tools/browser.sh" 2>&1)
check "no Brave: Play page opened, refused"  'grep -q "market://details?id=com.brave.browser" "$FAKE/log" && grep -q "not installed" <<<"$out" && [ "$(cat "$FAKE/browser")" = com.amazon.cloud9 ]'
echo "com.brave.browser enabled" >> "$FAKE/packages"
"$R/tools/browser.sh" >/dev/null
check "Brave is the default browser"         '[ "$(cat "$FAKE/browser")" = com.brave.browser ]'

echo "--- notifications"
out=$("$R/tools/notifications.sh" com.amazon.device.metrics com.amazon.notinstalled 2>&1); echo "$out" | sed 's/^/    /'
check "protected package still mutes (different check than pm)" 'grep -qx "com.amazon.device.metrics allow" "$B/notifications-before.txt"'
check "missing package skipped"              'grep -q "skipping com.amazon.notinstalled" <<<"$out"'
check "core package refused"                 '! "$R/tools/notifications.sh" com.android.systemui >/dev/null 2>&1'

echo "--- restore"
"$R/tools/restore.sh" >/dev/null
check "disabled packages re-enabled"         '[ "$(state com.amazon.weather)$(state com.amazon.kindle.kso)" = enabledenabled ]'
check "owner-disabled package stays off"     '[ "$(state com.amazon.mp3)" = disabled ]'
check "changed setting back to old value"    '[ "$(setting secure limit_ad_tracking)" = 0 ]'
check "keyboard and animations back"         '[ "$(setting secure default_input_method) $(setting global window_animation_scale)" = "com.example.keyboard/.Ime unset" ]'
check "status shows what came back"          'grep -q "enabled:.*com.amazon.weather" <<<"$("$R/tools/status.sh" "$T/list.txt")"'
check "unset settings deleted again"         '[ "$(setting global private_dns_mode)$(setting global LOCKSCREEN_AD_ENABLED)" = unsetunset ]'
check "notifications unmuted again"          '! grep -qx "com.amazon.device.metrics deny" "$FAKE/appops" 2>/dev/null'
check "browser role back to Silk"            '[ "$(cat "$FAKE/browser")" = com.amazon.cloud9 ]'
check "records archived"                     '[ ! -e "$B/applied.txt" ] && [ ! -e "$B/settings-before.txt" ] && [ ! -e "$B/notifications-before.txt" ] && [ ! -e "$B/browser-before.txt" ]'
check "second restore says nothing to do"    '! "$R/tools/restore.sh" 2>&1 | grep -q "^restored" && ! "$R/tools/restore.sh" >/dev/null 2>&1'

echo "--- gplay ABI"
out=$("$R/tools/gplay.sh" "$T/gapps" 2>&1)
check "32-bit list wins over arm64 abi prop" 'grep -q "use armeabi-v7a" <<<"$out" && grep -q "missing in" <<<"$out"'
sed -i.bak 's/^ro.product.cpu.abilist .*/ro.product.cpu.abilist arm64-v8a,armeabi-v7a,armeabi/' "$FAKE/props"
check "arm64 when the list has it"           'grep -q "use arm64-v8a" <<<"$("$R/tools/gplay.sh" "$T/gapps" 2>&1)"'

echo "--- install"
mkdir "$T/apps"; touch "$T/apps/a.apk" "$T/apps/bad.apk"
(cd "$T/apps" && touch b1.apk && zip -q b.apkm b1.apk && rm b1.apk)
out=$("$R/tools/install.sh" "$T/apps" 2>&1); rc=$?
check "installs apk and bundle, reports the failure" '[ $rc = 1 ] && grep -q "2 installed, 1 failed" <<<"$out" && grep -q "install-multiple" "$FAKE/log"'
check "empty folder refused"                 '! "$R/tools/install.sh" "$T/gapps/none" >/dev/null 2>&1'

[ $fail = 0 ] && echo "all ok"
exit $fail
