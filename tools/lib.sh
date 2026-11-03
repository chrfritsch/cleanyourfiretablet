# Shared by tools/*.sh. Source it after cd-ing to the repo root.
# shellcheck disable=SC2034  # the regexes are used by the sourcing scripts
PKG_RE='^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$'
NEVER_RE='^(android|com\.android\.(systemui|settings|shell|phone|packageinstaller|permissioncontroller|providers\..*)|com\.google\.android\.(gms|gsf|permissioncontroller|packageinstaller)|com\.android\.vending|com\.amazon\.firelauncher|com\.android\.webview|com\.amazon\.webview\.chromium)$'

die() { echo "$*" >&2; exit 1; }
# </dev/null: adb would otherwise eat the stdin of a surrounding while-read loop
sh_() { adb shell "$@" </dev/null | tr -d '\r'; }
has() { grep -xF -- "$1" >/dev/null <<<"$2"; }

# One package per line, # comments, duplicates dropped, tolerant of the BOM and CRLF that Notepad adds.
parse_list() { LC_ALL=C awk 'NR==1{sub(/^\357\273\277/,"")} {sub(/\r$/,""); sub(/#.*/,"")} NF && !seen[$1]++ {print $1}' "$1"; }

need_device() {
  command -v adb >/dev/null || die "adb not found: brew install android-platform-tools (macOS) or apt install adb (Linux)"
  [ "$(adb get-state 2>/dev/null)" = device ] || die "no tablet: plug it in, turn on USB debugging and accept the prompt (several devices? set ANDROID_SERIAL)"
  # ro.serialno, not get-serialno: over Wi-Fi ADB that is ip:port, and the restore record would split
  SERIAL=$(sh_ getprop ro.serialno); [ -n "$SERIAL" ] || SERIAL=$(adb get-serialno | tr -d '\r')
  [[ "$SERIAL" =~ ^[A-Za-z0-9._-]+$ ]] || die "odd serial, refusing to use it as a folder name: $SERIAL"
  STATE="backup/$SERIAL"
  mkdir -p "$STATE"
}

# Change a setting; its first-seen value goes to backup/<serial>/settings-before.txt for restore.sh.
record() { grep -q "^$1 $2 " "$STATE/settings-before.txt" 2>/dev/null || echo "$1 $2 $(sh_ settings get "$1" "$2")" >> "$STATE/settings-before.txt"; }
put() { record "$1" "$2"; sh_ settings put "$1" "$2" "$3"; echo "$1 $2 = $3"; }

# Google's signing certs (SHA-256): the original, and the one Play services was rotated to.
GOOGLE_CERTS='f0fd6c5b410f25cb25c3b53346c8972fae30f8ee7411df910480ad6b2d60db83 7ce83c1b71f3d572fed04c8d40c5cb10ff75e6d87d9df6fbd53f0468c2905053'

sha256_of() { if command -v shasum >/dev/null; then shasum -a 256 "$1"; else sha256sum "$1"; fi | cut -d' ' -f1; }

find_apksigner() {  # APKSIGNER overrides; else PATH, else the newest Android SDK build-tools
  if [ -n "${APKSIGNER:-}" ]; then [ -x "$APKSIGNER" ] && echo "$APKSIGNER"; return; fi
  command -v apksigner && return
  local d a found=""; for d in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do
    [ -n "$d" ] || continue
    for a in "$d"/build-tools/*/apksigner; do [ -x "$a" ] && found=$a; done
    [ -n "${found:-}" ] && { echo "$found"; return; }
  done
  return 1
}

# 0 = hash listed in gapps.sha256 or every APK inside is signed by Google; 1 = refuse (reason on stderr).
verify_gapp() {
  local f=$1 pins=${GAPPS_SHA256:-gapps.sha256} h as t a c d ok=1
  h=$(sha256_of "$f")
  if [ -r "$pins" ] && grep -q "^$h " "$pins"; then echo "  sha256 listed in gapps.sha256"; return 0; fi
  as=$(find_apksigner) || { echo "  not listed in gapps.sha256 and no apksigner to check the signature (install Android build-tools)" >&2; return 1; }
  t=$(mktemp -d)
  case "$f" in *.apk) cp "$f" "$t/a.apk";; *) unzip -qo "$f" '*.apk' -d "$t" || { rm -rf "$t"; echo "  cannot unpack $f" >&2; return 1; };; esac
  compgen -G "$t/*.apk" >/dev/null || { rm -rf "$t"; echo "  no APKs at the top level of ${f##*/}" >&2; return 1; }
  for a in "$t"/*.apk; do
    c=$("$as" verify --print-certs "$a" 2>/dev/null) || { echo "  signature does not verify: ${a##*/}" >&2; ok=0; break; }
    # every signer must be Google; the "Source Stamp" line is APKMirror's, not a signer
    c=$(sed -n 's/^Signer #[0-9]* certificate SHA-256 digest: //p' <<<"$c")
    [ -n "$c" ] || { echo "  not signed by Google (no certificate)" >&2; ok=0; break; }
    for d in $c; do has "$d" "$(tr ' ' '\n' <<<"$GOOGLE_CERTS")" || { echo "  not signed by Google (certificate $d)" >&2; ok=0; break 2; }; done
  done
  rm -rf "$t"
  [ $ok = 1 ] || return 1
  echo "  signed by Google"
}
