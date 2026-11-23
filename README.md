# FALCON – the phone app

Food & Site Operations – Sketchline Industries. The Android app (Flutter) for RCL's sites: the employee's and the guest's meals,
the mess owner's and operator's kitchen and deliveries, and the driver's trips – the app's own screens of the approved designs,
on FALCON's own database and server (the same rules as the web: `khandagalesuraj48-sys/Wolf`).

| Part | Where |
|---|---|
| Settings given to the build (URL, publishable key, server) | `lib/config.dart` |
| The look (colours, type, icons – Lucide, ISC; font Schibsted Grotesk, SIL OFL) | `lib/ui/look.dart`, `lib/ui/kit.dart`, `assets/` |
| The logo (B – the falcon on the plate, a fork and a knife crossed behind; his pick of 23-11-2026; drawn for FALCON) | the app icon `android/app/src/main/res/mipmap-*` (adaptive on Android 8+), the opening screen `drawable-*/launch_logo.png`, inside the app `assets/brand/falcon-logo.png` (`Logo` in `lib/ui/kit.dart`) |
| Data, session, formats | `lib/core/` |
| Screens (sign-in and registration, employee, guest, mess owner, driver) | `lib/screens/` |
| Addresses and who may open what | `lib/routes.dart` |

## The APK
GitHub → Actions → "build": every push builds `FALCON-<version>-<build>.apk` and one file per processor (`.arm64-v8a.apk`,
`.armeabi-v7a.apk` – the same build number); a branch's push is a TEST build (a pre-release); a merge into `main` is the latest
Release – only when signed with FALCON's permanent key. Settings: GitHub → Settings → Secrets and variables → Actions →
**Variables** `FALCON_SUPABASE_URL`, `FALCON_SUPABASE_KEY` (publishable), `FALCON_SERVER`; **Secret** `FALCON_SUPABASE_SECRET` (a
secret key of FALCON's Supabase – used only by the build to keep the signing key in the private bucket `app-keys`, made once).

## The update from inside the app (23-11-2026 – like the ERP app)
At every opening the app looks at the latest Release (`lib/core/update.dart`): "Update to …?" (Update / Close, what is new shown);
Update – Android's Download Manager downloads this phone's own file in the background (`android/…/UpdateKit.kt`), the fingerprint
is checked, "Install?" comes over any screen (or the notification "Update ready"). Me → version and "Check for update". A phone
with a test build of before (the debug key) uninstalls it once and installs the first release signed with the permanent key.

## Checks (each with a time limit)
```
timeout 300 flutter analyze --no-fatal-infos
timeout 300 flutter test
```
