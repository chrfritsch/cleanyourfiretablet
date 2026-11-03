#!/usr/bin/env bash
# Turn off Amazon ad tracking, usage uploads and lockscreen ads; optionally set a Private DNS ad blocker.
# Usage: tools/privacy.sh [dns.adguard-dns.com]
# The first value seen for each setting goes to backup/<serial>/settings-before.txt for restore.sh.
set -euo pipefail
cd "$(dirname "$0")/.."; . tools/lib.sh; need_device
tools/backup.sh
put secure limit_ad_tracking 1
put secure amz_limit_ad_tracking 1
put secure non_amz_limit_ad_tracking 1
put secure "advertisingIdApp:interestBasedAds:value" 0
put secure PromotedNewTiles 0
put secure usage_metrics_marketing_enabled 0
put secure USAGE_METRICS_UPLOAD_ENABLED 0
put global LOCKSCREEN_AD_ENABLED 0
put secure search_on_lockscreen_settings 0
echo "note: Fire OS resets LOCKSCREEN_AD_ENABLED on reboot, so lockscreen ads usually return (README)."
if [ -n "${1:-}" ]; then
  [[ "$1" =~ ^[A-Za-z0-9.-]+$ ]] || die "not a hostname: $1"
  put global private_dns_mode hostname
  put global private_dns_specifier "$1"
fi
