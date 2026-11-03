# Fire HD 10 (13th gen, 2023), KFTUWI, Fire OS 8.3.3.8

Android 11 (SDK 30), arm64-v8a, build RS8338.3344N. Tested on one tablet; list: [`examples/kftuwi`](../../examples/kftuwi/debloat.txt).

## Result
- 19 of 28 listed packages disabled, still disabled after a reboot. Home, Settings, Wi-Fi, Kindle, Prime Video,
  Music and Audible worked after every batch.
- Protected, refuse `pm disable-user`: `com.amazon.kindle.kso`, `com.amazon.client.metrics`, `com.amazon.device.metrics`,
  `com.amazon.platform`, `com.fireos.usagestats.proxy`, `com.fireos.arcus.proxy`, `com.amazon.csapp`,
  `com.amazon.whisperlink.core.android`, `com.amazon.diode`.
- Batch 4 (`alta.h2clientservice`, `dp.contacts`) was still disabled after a reboot; Home and Wi-Fi fine.

## Not solved
- **Lockscreen ads.** Special Offers (`kindle.kso`) is protected, and `LOCKSCREEN_AD_ENABLED=0` was back at 1 after a reboot. Also tried: `am force-stop` (protected), RUN_IN_BACKGROUND/standby bucket (accepted, process keeps running, ~240 MB), `pm suspend` (accepted, ad still shows) and `pm hide` (shell lacks MANAGE_USERS).
  Decompiled `kso` to see why: `LOCKSCREEN_AD_ENABLED` is only ever written in lockstep with a second flag,
  `Settings.Global IS_DTCP_ENABLED` (`DeviceSettingsUtil.setDtcpEnabled`), which gates the whole ad event
  pipeline (`SystemEventListener`). Both are meant to be turned off together by `EnrollmentManager.setEnrollmentState(false)`,
  the same code path the Settings app's "remove Special Offers" flow uses. But `DtcpSettingsController` also reads an
  Arcus (Amazon remote config) key, `lsSuppressionAvailableIn`, whose *default* value is `["JP"]` — lockscreen-ad
  suppression is only a sanctioned feature outside Japan if the server-side config says so for your country/account.
  That's consistent with ads coming back on reboot/resync even if both flags are flipped locally: the account-side
  config, not the local settings, is authoritative. Confirms the README's "tied to the Amazon account" note with code,
  doesn't give a new bypass.
- **A different Home.** Fire Launcher is protected and `set-home-activity` is accepted but ignored, and so is `cmd role add-role-holder android.app.role.HOME` (the role shows the new holder, Home still opens Fire Launcher; `pm disable-user -k` is refused as protected).
- **Home-screen "For You" sponsored tile.** Decompiled `firelauncher`: `AdsRefreshManager` drives it, fed by
  `RemoteSettingsAccess`/`ArcusUtils.getArcusCache(...).getArcusAccess(LauncherArcusConfigs.ADS)` — the same
  server-side-config pattern as `kso`'s lockscreen ads, not a local `SharedPreferences` or `Settings` key. No ADB
  override exists.
- **Silk browser's sponsored/recommended content.** `cmd package resolve-activity -a android.intent.action.VIEW`
  confirms `com.amazon.cloud9` (Silk) is the default browser on this tablet. Its new-tab "Home" page and a
  "Product Recommendations" settings screen (`ProductRecommendationsPreferences.java`, `HomeTabPreferences.java`)
  expose real on/off switches, default **on**: `sponsored_products_switch`, `buy_it_again_switch`,
  `purchase_based_products_switch`, `recently_viewed_products_switch`, `viewed_based_products_switch`,
  `video_recommendations_switch`, plus Just-For-You/News sections. These are ordinary `SharedPreferences`, but
  `com.amazon.cloud9` isn't debuggable (`adb shell run-as com.amazon.cloud9` → "package not debuggable"), so they
  can't be flipped over ADB — only by hand in Silk's own Settings menu. Not scriptable; note it for anyone using
  Silk as their browser.
- **Appstore (`venezia`) notification spam.** Decompiled it: all its notifications (app updates, pre-order
  availability, recommendations) go through one lumped channel, `NotificationChannel("appstore_notification", ...)`
  — no per-topic granularity. Unlike `pm disable`, Android's **appops** mechanism isn't blocked by Amazon's
  protected-package check (it's a different, orthogonal control) and needs no root:
  `adb shell cmd appops set <pkg> POST_NOTIFICATION deny` silences a package's notifications outright, which
  is the same effect `Settings > Apps > <app> > Notifications > off` has. `dumpsys notification` on this tablet
  shows `com.amazon.appverification`, `com.amazon.redstone`, `com.amazon.venezia` and `com.amazon.watson` already
  fully muted (`muted=N/N`, presumably from the on-device Settings UI at some point), but `com.amazon.kindle.starsight`
  (an Alexa-namespaced package, `com/amazon/alexa`/`com/amazon/fluid` in its decompile — looks like an Alexa
  suggestion/"Hunches"-style feature) is still posting unmuted notifications. Not muted here: per AGENTS.md,
  anything Alexa-adjacent needs asking first, and this wasn't on the list the person confirmed.

## Reverse-engineered: why `kso` resists ADB
Pulled and decompiled `services.jar`/`fosservices.jar` from the device. The "protected package" check is Amazon's
own code (`ControlProtectedPackagesCallback`), not a general Android flag:
```java
shouldProtectPackage(uid, pkg, ctx) =
    isSystemApp(pkg) && pkg in denyList && uid == 2000   // 2000 = SHELL_UID, i.e. adb
```
It only blocks the calling UID `2000` (adb/shell). The deny list itself is unreadable without root
(`/data/system/PackageManagerDenyList`, owned by `system`). `pm suspend` isn't covered by this check at all
(accepted, but the lockscreen ad is rendered by a separate path and doesn't care about suspended state).

Tried the one non-root bypass the code suggests: a caller that isn't UID 2000. Built and sideloaded a minimal
`DeviceAdminReceiver` test app and ran `dpm set-device-owner`, expecting an accounts-related block. Instead:
`IllegalStateException: Trying to set the device owner, but the user already has a profile owner.` Every user on
this tablet (0, 10, 11) already has a Profile Owner: `com.amazon.parentalcontrols` on 0 and 10, `com.amazon.tahoe`
(Kids/Free Time) on 11. That slot is exclusive per user and pre-claimed by Amazon, independent of any Google/Amazon
account. `dpm remove-active-admin` needs the admin's own manifest to declare `android:testOnly`, which a shipped
system app won't. Conclusion: not a single lock, two independent ones, both Amazon's. Accounts were never the
real blocker. Tried the next idea anyway: provisioning Device Owner on a brand-new,
clean secondary user instead (`pm create-user`), since Device Owner's authority is device-wide even though it's
anchored to one user. Hit a third, harder blocker: `IllegalStateException: Not allowed to set the device owner
because there are already several users on the device`. This is a hard AOSP rule, not an Amazon one: Device Owner
can only be provisioned while the device has exactly one user. This tablet already has 3 (other household
profiles), independent of accounts or the parentalcontrols profile-owner slot, and not something to work around
without deleting other people's profiles. Closing this line of investigation here.
 Lawnchair 15 beta 3,
  Kvaesitso 1.41.0 and Home on Fire 1.5.2 (accessibility service) were tried and removed.
- **Home screen recommendations.** Settings → Apps & Notifications → Amazon App Settings → Home Screens. App
  preferences, not Android settings (a settings diff around the toggles showed no change).

## Google Play
`tools/gplay.sh` installed Services Framework 10-6494331, Play services 26.43.30 (arm64-v8a, Android 11+) and Play Store
53.7.24-24 (hashes in `gapps.sha256`). The store opens at its sign-in screen; sign-in was not checked.

## Profiles
Two other profiles (an adult and a kids profile) exist; only the main profile was cleaned.

## Keyboard and animations
`tools/keyboard.sh` switched to Gboard (installed from Play); it stayed the keyboard after a reboot. Fire OS sends
`market://` links to the Amazon Appstore unless they name the Play Store package. `tools/speed.sh` (0.5) also
survived the reboot.
