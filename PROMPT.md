# The prompt

Paste everything below the line into Claude Code (or Codex, Gemini CLI) opened in a clone of this repo.

Before you start, on the tablet: **Settings → Device Options → About Fire Tablet → tap Serial Number
seven times**, back → **Developer Options → USB debugging** on (some builds call it "Enable ADB").
Plug the tablet into the computer with a USB cable that carries data.

---

I want to debloat my Amazon Fire tablet and install Google Play. My tablet is: <MODEL, e.g. Fire HD 10>.
Work on the real device, step by step, reuse this repo's `tools/` instead of writing your own, and
check each step with a screenshot (`adb exec-out screencap -p > shots/<step>.png`, then look at it).
Ask me before anything that depends on how I use the tablet.

Connect
- If the tablet is asleep screenshots come out black: `input keyevent KEYCODE_WAKEUP`, then `input keyevent 82`.
- Settings you change only for testing (for example `stay_on_while_plugged_in`): write down the old value
  and put it back before you finish.
- `adb devices`. Tell me when "Allow USB debugging?" appears on the tablet so I can accept it (tick "Always").
- Missing adb: `brew install android-platform-tools` (macOS) or `apt install adb`.
- Read `getprop ro.product.model`, `ro.build.mktg.fireos`, `ro.build.version.sdk`, `ro.product.cpu.abilist` and tell
  me the model, generation and Fire OS version.

Back up
- Ask whether the tablet has other profiles (household or child). `pm disable-user --user 0` only cleans the
  main profile; say so.
- `tools/backup.sh`. It saves packages, settings and getprop to `backup/<serial>/before/` once and never overwrites it.

Decide what goes
- Start from the closest list in `examples/` (`examples/fire-hd-10/debloat.txt` if none matches my model).
  Copy it to `examples/<model-code>/debloat.txt` and work on the copy.
- Compare it with `pm list packages`: drop what is not installed, and look at Amazon packages on my tablet
  that the list does not mention (`pm list packages | grep -i amazon`). Use `dumpsys package <pkg>` to see what
  a package provides (HOME, input method, accounts, accessibility, device admin) before suggesting it.
- Ask me, as one checklist: which Amazon apps I use (Kindle, Prime Video, Music, Audible, Photos, Appstore),
  whether I use Alexa, Kids profiles, casting to a Fire TV, and whether OTA updates should stay on
  (off keeps the debloat from being undone, on keeps security fixes). Comment out what I keep.
- Before disabling `com.amazon.kindle.otter.oobe`, make sure the timezone is right: Date & time stops opening.

Apply in batches
- Split the list into three or four batches (ads, telemetry, Alexa, apps), and run `tools/disable.sh <batch>` for
  each one. After each batch: press Home, take a screenshot, open Settings and one app I use. If something
  breaks, re-enable the last batch with `pm enable` and find the package by halving the batch.
- `tools/privacy.sh`, and ask me whether I want Private DNS ad blocking (for example `dns.adguard-dns.com`,
  `adblock.dns.mullvad.net`). Pass it as the argument if yes.
- Ask whether animations should be shorter (`tools/speed.sh`, 0.5 by default; snappier, not faster).
- Home screen ads: ADB cannot reach these toggles, so ask me to switch off **Recommendations** and **Continue and
  Discover Row** myself: Settings → Apps & Notifications → Amazon App Settings → Home Screens.
- If Silk is my browser: its own Settings → Home / Product Recommendations has more switches (sponsored products,
  buy-it-again, recently-viewed) on by default, and ADB can't reach those either (the app isn't debuggable). Ask
  me whether I'd rather just replace Silk with **Brave** instead of toggling those by hand. `tools/browser.sh`
  installs Brave itself (Brave's own GitHub release, checksum verified, no Play Store or unlocking needed) and
  makes it the default browser; if that download fails it falls back to opening Brave's Play Store page instead.
  It doesn't disable Silk itself — ask before adding `com.amazon.cloud9` to a `tools/disable.sh` batch.
- Notification spam from an app that refuses `pm disable` (or that you want quieter without disabling): `tools/notifications.sh <pkg>`
  mutes it via `appops`, a separate check from the protected-package one. Ask me first if the app is one I might use.
- Lockscreen ads: if they are still there after a reboot, tell me they are tied to the Amazon account
  (Amazon support often removes them; otherwise Manage Your Content and Devices → Remove offers, paid).

Google Play
- Tell me exactly which files to download from apkmirror.com for this tablet's SDK and ABI (run
  `tools/gplay.sh gapps/` with an empty `gapps/` folder; it prints the list). I download them into `gapps/`; the script checks each against `gapps.sha256` or Google's signature (needs Android build-tools for new versions) and refuses the rest.
- `tools/gplay.sh gapps/`, reboot, and have me sign in to Play Store myself. Stuck on "Checking info"? Reboot once more.
  Screenshot the store; sign-in is mine to confirm, not yours to assume.
- Ask whether I want Gboard instead of the Amazon keyboard: `tools/keyboard.sh` opens its Play page if it is
  missing; once I installed it, run it again.

Finish
- Report the counts `tools/disable.sh` prints ("N disabled, M failed"), not your own tally. After the reboot,
  `tools/status.sh <list>` must still show them disabled.
- Reboot, then check: Home, Settings, Wi-Fi, Play Store, and every app I said I use. Screenshot each.
- Put the model, generation, Fire OS build, date and what I kept in the header of the new list, and mark
  packages that failed as protected. Offer to open a pull request with it.
- Remind me: the record lives in `backup/<serial>/` on this computer only, so keep that folder.
  `tools/restore.sh` undoes everything, and
  turn USB debugging off when we are done.
