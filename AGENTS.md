# Rules for coding agents

This repo debloats Amazon Fire tablets over ADB. The person's walkthrough is `PROMPT.md`; these rules
apply whether or not it was pasted.

## Hard rules on a real tablet

- Use `tools/`, never your own loop of `adb shell pm ...`. The scripts take the backup, keep the restore
  record in `backup/<serial>/` and refuse core packages. Writing your own skips all of that.
- Never `pm clear`, `pm uninstall` or `pm uninstall --user 0`. Disable only (`tools/disable.sh`).
- Never disable `com.amazon.firelauncher`; there is no launcher swap in this project (Fire OS 8 blocks it).
- Ask before disabling anything the person might use (Kindle, Prime Video, Music, Audible, Photos,
  Appstore, Alexa, Kids profiles, casting, OTA updates). The lists' "ask" and "left on" tiers say which.
- Apply in batches of a few dozen at most. After each: press Home, `adb exec-out screencap -p > shots/<step>.png`,
  look at the screenshot, open Settings and one app the person uses. Something broke → `pm enable` the
  last batch and halve it to find the package.
- Never delete or edit `backup/`. It is the only undo record and lives only on this computer.
- Don't download or commit Google's APKs; the person downloads them into `gapps/` (gitignored). `gplay.sh` verifies them against `gapps.sha256` or Google's signature (apksigner); never bypass that with `ALLOW_UNVERIFIED` unless the person asks.

## Changing the repo

- Run `tests/test_tools.sh`, `tests/test_device.sh` (fake tablet, `tests/fake-adb`) and
  `shellcheck -x -s bash tools/*.sh tests/*.sh tests/fake-adb` before committing. CI runs all three.
- Changed what a tool sends to the tablet? Teach `tests/fake-adb` the new command; it fails on unknown ones.
- Scripts must run on macOS's bash 3.2: no `mapfile`, no `${var,,}`, no associative arrays.
- Anything sent to `adb shell` is parsed by the tablet's shell: validate package names against `PKG_RE`
  (`tools/lib.sh`) and quote values.
- A new list goes in `examples/<model-code>/debloat.txt` with the header described in `CONTRIBUTING.md`.
  Only use package names you saw on a real tablet with `pm list packages`.
