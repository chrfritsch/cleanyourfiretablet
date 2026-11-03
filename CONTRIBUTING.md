# Contributing

The most useful contribution is a **tested list for your tablet**.

## Add your tablet

1. Clean your tablet with `PROMPT.md`. Your agent works on a copy of the closest list in `examples/`.
2. Name the folder after the model code: `adb shell getprop ro.product.model` (e.g. `KFTRWI` → `examples/kftrwi/`).
3. Start `debloat.txt` with a header like this:

   ```
   # Amazon Fire HD 10 (11th gen, 2021), KFTRWI, Fire OS 8.3.2.4 (PS8324/4417), Android 11, SDK 30.
   # Tested 2026-11-05: 4 batches, screenshot after each, rebooted. Home, Settings, Wi-Fi, Play Store,
   # Kindle and Netflix open.
   # Kept on purpose: Kindle, Appstore, OTA updates.
   # Protected on this build (pm refused): com.amazon.device.metrics, com.fireos.usagestats.proxy
   ```

4. One package per line, a `#` comment saying what it is. Packages you kept stay in the file, commented out.
5. Run `tests/test_tools.sh`, add a row to the README's "Tested tablets" table, open a pull request,
   and fill in the "Tested my tablet" issue form (or paste the same details in the PR).

5a. Add a dated `# Status:` line. List only packages you disabled and lived with for a few days.
    Findings about the firmware (protected packages, what did not work) go in `docs/devices/<model-code>.md`.
6. No personal details in anything you commit: serial numbers, Wi-Fi names, IP addresses, profile or
   family names, home paths. `tests/test_tools.sh` checks for the obvious ones.

What makes a list mergeable: every package was seen on that tablet, it was applied on the real device,
and it survived a reboot. Untested additions go in commented out, with a note.

## Something broke

Open an issue with the model, the Fire OS version, the list you used and the last batch before it broke.
Run `tools/restore.sh` first: it undoes everything this repo changed.

## Code

Read `AGENTS.md`. In short: bash 3.2 compatible, shellcheck clean, `tests/test_tools.sh` passes, and
nothing reaches `adb shell` without being validated.
