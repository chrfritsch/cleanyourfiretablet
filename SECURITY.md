# Security

This project runs commands on your tablet over ADB and on your computer. Please report a problem privately, not in
a public issue: use GitHub's private vulnerability reporting (the repo's Security tab → Report a vulnerability).

## What counts

- A script running commands on a device or computer it was not pointed at, or mishandling a package name, path or argument.
- A list or the prompt leading to a tablet that `tools/restore.sh` cannot restore.
- `gplay.sh` installing a file that is neither in `gapps.sha256` nor signed by Google.
- Anything in a pull request that runs code on a contributor's or maintainer's machine.

ADB is powerful by design. Turn USB debugging off when you are done.
