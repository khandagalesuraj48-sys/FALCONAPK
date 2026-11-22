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
GitHub → Actions → "build": every push builds `FALCON-<version>-<build>.apk` (the run's "Artifacts"); a push to `main` also puts it
up as the latest Release. Settings: GitHub → Settings → Secrets and variables → Actions → **Variables** `FALCON_SUPABASE_URL`,
`FALCON_SUPABASE_KEY` (publishable), `FALCON_SERVER`; optional **Secrets** for Sketchline's signing key
(`FALCON_KEYSTORE_B64`, `FALCON_KEYSTORE_PASSWORD`, `FALCON_KEY_ALIAS`, `FALCON_KEY_PASSWORD`).

## Checks (each with a time limit)
```
timeout 300 flutter analyze --no-fatal-infos
timeout 300 flutter test
```
