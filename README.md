# Clean Your Fire Tablet

**Your Fire tablet, minus Amazon's ads, with Google Play.** Strip the bloat and telemetry from an Amazon
Fire tablet (Fire 7, HD 8, HD 10, Max 11) with your coding agent, and add the Play Store.
No root, nothing uninstalled, no app data cleared, and one command to undo all of it.

Tested end to end on a Fire HD 10 (13th gen) running Fire OS 8.3.3.8. What worked and what Fire OS
blocks is listed under [What it can't do](#what-it-cant-do).

Inspired by [cleanyourtv](https://github.com/Gathin23/cleanyourtv). Built on what
[Fire Tools](https://github.com/mrhaydendp/Fire-Tools) learned about Fire OS.

## How it works

| Step | What happens |
|---|---|
| **Back up** | Package list, settings and device info, saved once to `backup/<serial>/before/`. |
| **Disable** | Ads, telemetry, Alexa and the Amazon apps you don't use, with `pm disable-user`. Each change is recorded for restore. |
| **Privacy** | Ad tracking and usage uploads off, lockscreen ads setting off, optional Private DNS ad blocker. |
| **Notifications** | Mute an app's notifications via `appops`, independent of the protected-package check. |
| **Google Play** | Framework, services and store, installed in the right order for your Fire OS version and CPU. You download Google's APKs in a browser (APKMirror blocks scripts); the script installs only files listed in `gapps.sha256` or signed by Google. |

Your agent finds the bloat on *your* tablet and asks before disabling anything you might use.

## Quick start

1. **On the tablet:** Settings → Device Options → About Fire Tablet → tap **Serial Number** 7 times →
   back → Developer Options → **USB debugging** on. Plug it into your computer.
2. **On your computer:** clone this repo and `cd` into it, open your coding agent
   (Claude Code, Codex, Gemini CLI) there and paste [`PROMPT.md`](PROMPT.md) with your model filled in.
3. **Follow along:** accept "Allow USB debugging?", answer the checklist, download the Google APKs it names.

### Without an agent

```sh
tools/disable.sh examples/fire-hd-10/debloat.txt   # review and edit the list first
tools/privacy.sh dns.adguard-dns.com               # DNS argument optional
tools/speed.sh                                     # animations at half length: feels snappier
tools/gplay.sh gapps/                              # prints what to download if gapps/ is empty
tools/install.sh apps/                             # install every APK / .apkm bundle in a folder
tools/keyboard.sh                                  # Gboard instead of the Amazon keyboard (after Play)
tools/notifications.sh com.amazon.venezia          # mute an app's notifications even if pm can't disable it
tools/browser.sh                                   # install Brave (checksum verified) and make it the default browser
tools/status.sh examples/fire-hd-10/debloat.txt    # read-only: what is still disabled
tools/restore.sh                                   # undo everything above
```

Several devices plugged in? Set `ANDROID_SERIAL`.

**After a Fire OS update**, `tools/status.sh <list>` shows what came back; run `tools/disable.sh` with the
same list again. It only touches what is enabled again.

## Compared with Fire Tools

| | Fire Tools | Clean Your Fire Tablet |
|---|---|---|
| Debloat | One fixed list | Your agent checks your tablet and asks; lists sorted into tiers by risk |
| App data | `pm clear` on each disabled app | Never cleared |
| Undo | Re-enable the whole list, or factory reset | Reverts exactly what was changed, settings included |
| Guards | — | Refuses core Android and WebView, keeps current Home, keyboard, Settings and accessibility services |
| Google APKs | Bundled in releases | You download them; the script tells you which variant and refuses files that aren't known-good or Google-signed |
| Verification | — | Screenshot after each batch, reboot check |

## What it can't do

Learned on a Fire HD 10 (13th gen), Fire OS 8.3.3.8:

- **Protected packages refuse to be disabled.** 9 of the 28 listed (`kindle.kso`, the Amazon metrics and usage-stats
  packages, the Help app, the casting service) answer "Cannot disable a protected package". That is harmless: the
  script reports FAILED and carries on, and the tested list has them commented out.
- **Lockscreen ads stay.** Special Offers is protected, and the `LOCKSCREEN_AD_ENABLED` setting is switched back on
  at every reboot (forum reports say the same for the 13th gen). The reliable fix is Amazon's own: Manage Your
  Content and Devices → Devices → remove Special Offers. It costs about 15 EUR, and Amazon support sometimes waives it.
  An exploit route exists for older firmware (Exploits, below).
- **No launcher swap.** Fire Launcher is protected and Fire OS 8 ignores `set-home-activity`. Three workarounds were
  tried on the tablet (Lawnchair, Kvaesitso, the Home on Fire accessibility service) and none was satisfying, so they were dropped.
- **Home screen recommendations are a manual switch.** Settings → Apps & Notifications → Amazon App Settings →
  Home Screens → turn off Recommendations and Continue and Discover Row. They live in the Amazon app, not in
  Android settings, so ADB can't set them (checked by diffing the settings dump around the toggles). Decompiling
  `firelauncher` confirmed why: the home-screen sponsored tile is driven by Amazon's server-side Arcus config, not
  a local setting — same story as lockscreen ads.
- **Silk browser's sponsored/recommended content is also a manual switch**, if Silk is your browser: its own
  Settings has a "Product Recommendations" page (sponsored products, buy-it-again, recently-viewed, video
  recommendations, all on by default) and a "Home" page (Just For You, News). Found by decompiling
  `com.amazon.cloud9`; it isn't debuggable, so these SharedPreferences can't be flipped over ADB either. Your agent
  should ask whether you'd rather replace Silk with Brave instead — `tools/browser.sh` downloads Brave itself from
  its official GitHub releases, checksum-verified, no Play Store or unlocking needed (falls back to opening its
  Play Store page if the download fails), and switches the default-browser role to it. It leaves Silk itself alone.
- **Notification spam from a protected package has a separate fix.** `pm disable-user`'s "protected package"
  check and Android's **appops** are independent controls — appops isn't blocked by it. `tools/notifications.sh <pkg>`
  runs `cmd appops set <pkg> POST_NOTIFICATION deny`, the same thing Settings → Apps → *app* → Notifications → off
  does, and it works even on packages `disable.sh` reports FAILED for. No root. `tools/restore.sh` undoes it.
- **Other profiles** (household, kids) are separate Android users and keep their apps; only the main one is cleaned.
- **Undo needs `backup/`**: the restore record is kept on the computer you ran this from.
- **OTA updates** can re-enable packages. Keeping them off is your call: it also means no security fixes.
- **Exploits.** A "system user" exploit from September 2025, used by Fire Toolbox's Exploit Mode
  (Windows and Linux), can disable protected packages, Fire Launcher, lockscreen ads and OTA updates. It works up to
  Fire OS 8.3.3.6 and 7.3.3.1; 8.3.3.8 is patched. This repo does not use it: one wrong command can boot-loop the
  tablet, and the gain is gone after the next update unless OTA is blocked too.
- **Not Google-free.** microG can't replace Google Play here: it needs signature spoofing, which needs root or a custom ROM.

## Tested tablets

| Model | Fire OS | List |
|---|---|---|
| Fire HD 10 (13th gen, 2023), KFTUWI | 8.3.3.8 | [`examples/kftuwi`](examples/kftuwi/debloat.txt): 19 of 28 disabled, survived a reboot, Play installed ([notes](docs/devices/kftuwi.md)) |
| Fire HD 10 (11th gen, 2021) | 7 / 8 | [`examples/fire-hd-10`](examples/fire-hd-10/debloat.txt): starter list, **untested** |

Tested a tablet? See [CONTRIBUTING.md](CONTRIBUTING.md): copy the list to `examples/<model-code>/`, describe
the test in its header, and open a pull request.

## Help

[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) covers connection, protected packages, ads and Google Play. Security reports: [SECURITY.md](SECURITY.md).

## Development

`tests/test_tools.sh` runs offline checks (list parsing and validation, script syntax);
`tests/test_device.sh` runs disable, status, privacy, speed, keyboard, browser, notifications, restore and the
Google Play ABI choice against a fake tablet.
CI runs both on Linux and macOS, plus shellcheck. No tablet needed. Coding agents: read [AGENTS.md](AGENTS.md).

## License

MIT. The starter list's package names come from Fire Tools (MIT, © 2023 Hayden Plumley).
