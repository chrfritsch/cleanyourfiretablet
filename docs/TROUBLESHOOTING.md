# Troubleshooting

## Connecting

- **`adb devices` shows nothing:** USB debugging is off, the cable is charge-only, or Developer Options is hidden.
  Settings → Device Options → About Fire Tablet → tap Serial Number 7 times, then turn on USB debugging.
- **`unauthorized`:** unlock the tablet and accept "Allow USB debugging?". Tick "Always allow". Still stuck:
  `adb kill-server`, replug, or Developer Options → Revoke USB debugging authorizations.
- **Several devices:** set `ANDROID_SERIAL=<serial>`.
- **Screenshots are black:** the tablet is asleep. `adb shell input keyevent KEYCODE_WAKEUP`, then `keyevent 82`.

## Disabling

- **`Cannot disable a protected package`:** Fire OS 8 protects some Amazon packages (Special Offers, the metrics
  and usage-stats services, Help, casting). Nothing is wrong and nothing changed: `disable.sh` reports FAILED and
  carries on. Comment those lines out of your list.
- **A package from an older list does not exist:** skipped silently. Fire OS 8 renamed or dropped many Fire OS 7 names.
- **Something broke after a batch:** `tools/restore.sh` re-enables everything this repo disabled. To find the culprit,
  re-enable the last batch with `adb shell pm enable <package>` and halve it.
- **Packages came back after a system update:** run `tools/disable.sh` with the same list again.
- **Other profiles (household, kids) still show the apps:** `disable-user --user 0` cleans only the main profile.

## Ads

- **Lockscreen ads are back after a reboot:** `LOCKSCREEN_AD_ENABLED=0` is reset at every boot by Special Offers,
  which is protected on Fire OS 8. Fixes: Amazon's paid opt-out, or Fire Toolbox's Exploit Mode on Fire OS 8.3.3.6 or older (patched on 8.3.3.8). See the README.
- **Ads on the home screen:** switch off Recommendations and Continue and Discover Row by hand (Settings → Apps &
  Notifications → Amazon App Settings → Home Screens). ADB cannot reach them.
- **Sponsored products / Just For You in Silk's new-tab page:** Silk (`com.amazon.cloud9`) has its own
  "Product Recommendations" and "Home" settings pages with switches, on by default. ADB cannot reach them either
  (the app isn't debuggable). Simpler than toggling each one: ask whether you'd rather replace Silk with Brave —
  `tools/browser.sh` downloads and verifies Brave itself (no Play Store or unlocking needed) and switches the
  default-browser role to it; it leaves Silk installed and enabled, so disable it yourself with `tools/disable.sh`
  if you want it gone too.
- **A package keeps posting notifications and `pm disable` refuses it:** `tools/notifications.sh <pkg>` mutes it
  via `appops`, a check separate from the protected-package one. Same effect as Settings → Apps → *app* →
  Notifications → off. `tools/restore.sh` reverts it.

## Google Play

- **`wrong variant` / `NO_MATCHING_ABIS`:** you need the build for the CPU list the script prints (`abilist`, not `abi`).
- **`too new` / `OLDER_SDK`:** pick a Play services build whose minAPI is not above the tablet's SDK.
- **`refusing <file>`:** the file is not in `gapps.sha256` and not signed by Google (or apksigner is missing).
  Download it again from APKMirror in a browser. `ALLOW_UNVERIFIED=1` skips the check; don't, unless you know the file.
- **Play Store stuck on "Checking info":** reboot once more, then wait a minute on Wi-Fi.
- **Sign-in:** you do it yourself; this repo never handles your password.
- **Links open the Amazon Appstore instead of Play:** Fire OS catches `market://` links. `tools/keyboard.sh` sends
  them to Play directly; for anything else, search in the Play Store app.

## Launcher

Not supported: Fire OS 8 protects Fire Launcher. The three workarounds tried are listed in the README.
