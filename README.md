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

## Where he is, Google Map, opened from HR (23-11-2026 – pictures N1–N8, approved "ho banaw")

* **The mess home** reads the phone's place while it is open (`lib/core/geo.dart` – nothing is saved or sent): inside the mess's
  area → "At the mess" and the counter QR; away → how far (a straight line), **Directions** (Google Maps), "Parcel". He can switch.
  The meal follows the **server's clock** (`lib/core/clock.dart`: GET `/api/start`, then every 10 minutes).
  (25-11-2026, his word: "location fetching la time ghetey … khup fast hoyla haw") the place comes fast: the phone's own reading of the
  last 15 s is shown at once, then the place is asked every second on Android (it was once in 5 s); on Android 13+ the phone may give
  its reading of the last 15 s at once. The same in RCL's ERP / HR app, which has this code inside (its `pubspec.yaml` pin).
* **Google Map** (`lib/ui/gmap.dart`) on the home, tracking, the driver's route, the owner's route and live vans, choosing a section.
  The key is the ERP's own, given at the build: GitHub → FALCONAPK → Settings → Secrets → Actions → **`MAPS_API_KEY`** (the same
  value as the ERP app's secret – never in a file or in chat). Without it, or without places: the drawn road of before.
* **Opened from HR:** the ERP / HR app opens `falcon://app/hr?p=<HR's pass>` (only this package); `/hr` (`lib/screens/from_hr.dart`)
  sends the pass to FALCON's `/api/hr` and he is in – no company code, no WhatsApp code; "‹ HR" goes back.


## Only Sections (23-11-2026 – Wolf part 0017)
His word: "ekach thew only section … section che baheun koni kel asel tr … location direction he sagle hot jail". No circle anywhere.
A van order goes where the person is: the section whose metres hold his location (found by itself – `core/geo.dart` `sectionAt`, the
server's own rule), or, outside every section, his location goes with that order only. The owner sees it with how far it is from the
mess and Google's directions (Orders, Parcels for the van, the route); the driver gets it as a stop of its own, with the directions and
"I'm here". Needs FALCON's SQL update `2026-11-23f_sections_only.sql` first.

## FALCON inside RCL's ERP / HR app (23-11-2026 – "falcon seprate pn chalayla pahije ani erp hr madeh pn chalayla pahije")

This app works on its own exactly as before. The same code is ALSO used by RCL's ERP / HR app (rcl-mobile 3.171.0, package `falcon`
pinned by commit there): when the FALCON app is not on the phone, the Mess card opens FALCON's screens inside that app.
* `lib/embed.dart` – `falconStart()` and `FalconInApp(pass, onLeave)`: FALCON's own router from `/hr?p=<HR's pass>` (no second
  sign-in), its theme; the phone's back goes a page back, then FALCON's home, then out; "Back to RCL app" on FALCON's homes.
* Inside the other app: pictures from this package (`assetPackage`), FALCON's own sign-up pages are not offered (`HrAgain`), the
  update from inside the app is not used (it is this app's own).
* The font has one name for both: `packages/falcon/Schibsted` (pubspec.yaml declares it under that name too).
* A change here reaches the ERP / HR app when rcl-mobile moves its pinned commit (`pubspec.yaml` → `falcon` → `ref`).
