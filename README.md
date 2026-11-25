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
`.armeabi-v7a.apk` – the same build number); a branch's push is a TEST build (a pre-release); a Release (latest) is made by Run
workflow on `main` (below – Shorebird) – only when signed with FALCON's permanent key. Settings: GitHub → Settings → Secrets and variables → Actions →
**Variables** `FALCON_SUPABASE_URL`, `FALCON_SUPABASE_KEY` (publishable), `FALCON_SERVER`; **Secret** `FALCON_SUPABASE_SECRET` (a
secret key of FALCON's Supabase – used only by the build to keep the signing key in the private bucket `app-keys`, made once).

## Shorebird – a fix without a new app file (25-11-2026, his word: "falcon pn same updet system banwychi aahe" – as the ERP app)
* **A merge into `main` sends nothing by itself any more** – it is checked and built only.
* **A new app file:** Actions → **build** → Run workflow on `main` ("Publish" ticked; unticked = build and check only). Shorebird builds the
  one file (`shorebird release`, FALCON's Shorebird id in `shorebird.yaml`), the files per processor are made from it (`tool/abi_apks.sh`,
  each entry byte for byte Shorebird's), and it is the latest Release – the app's own update offers it as before.
* **A fix of the Dart code only:** merge it, then Actions → **patch** → Run workflow (empty release = the latest one). Phones on that
  release take it at an opening and use it from the next one – no update. A change of a plugin, native code, a permission or a picture /
  font is refused there: that needs a new app file. Gone wrong: Shorebird console → FALCON → the release → the patch → Roll back.
* The patch-signing key: made once by the first Shorebird release, kept only in the private bucket `app-keys` of FALCON's Supabase
  (`shorebird-patch-private.pem` / `-public.pem`, `tool/shorebird_keys.sh`) – download a copy and keep it offline; lost = no patch for
  the releases made with it. `SHOREBIRD_TOKEN` (a key of the Shorebird service account) is a GitHub secret, never in a file or chat.
* `shorebird.yaml` goes into the app's assets only in these builds (`tool/shorebird_asset.sh`), never in `pubspec.yaml` – RCL's ERP / HR
  app has this code inside as a package, and one more asset there would stop the ERP's own patches.
* Phones get patches only from a Shorebird release – the first one is one more update (the last one needed for a Dart fix).

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

## The place exact and at once · Parcel only outside the mess · Google's map · opened from the ERP / HR app at once (25-11-2026)

His words: "falcon madhe pn location fetch 1 second madhe hoyla hawey"; "jar mi outside asel mess pasun at the mess option band asel tyala
parcel gheyla lagel"; "kal pahile mess pasun 20 km lamb hoto but app sangat hote 5 km … ekdm perfect"; "signed in through RCL HR … comes
from HR by itself he nko"; "final back erp hr madhe jail app band nahi"; "falcon madhe sagle thikani google map … other map nahi"; "hr aso
erp aso app open zalel zale tyache maghe auto falcon pn on hoil … falcon opening chi screen ti yenar nahi".
* **The place** (`lib/core/geo.dart`): one reading of its own at once beside the stream (inside the ERP the phone's stream may be the HR
  tracking's, a point in minutes); only an **exact** reading (± 100 m or better) gives the distance, "at the mess", his section or the van's
  point – a rough one (the towers, no GPS yet: kilometres off – the wrong 5 km) says "Finding your exact place… (± …)"; a rough reading
  does not push out an exact one of the last 30 s.
* **Outside the mess area** (an exact reading): "At the mess" is dim and cannot be chosen – Parcel only (the home and the Parcel page).
* The two cards of HR on the home are gone. "‹ HR" on the home goes back to the ERP / HR page inside that app (it closed the whole app).
* **Google's map everywhere**: with no point of its own (sections without a place), the map shows the phone's place – the drawn road
  only in an app built without the key.
* **Inside the ERP / HR app** (`lib/embed.dart` `falconWarm`): made ready behind it as it opens – signed in with HR's pass, his home read –
  so Mess opens straight on the home; the home read a moment ago is shown at once and read again quietly (`Load.first`).

## The WhatsApp code – copied in WhatsApp, back in FALCON (25-11-2026)

His word: "otp whats app la yeto mi whats app war jaun copy krun alo ki ekde falcon madhe otp taku det nahi screen la touch kel tr otp
box madhe kahi jat nahi". The six boxes (`lib/ui/kit.dart` `CodeBoxes`) work as the ERP app's sign-in: the one real box lies over the six,
so a touch opens the keyboard again (before, the touch only asked for a focus the box still had – the keyboard did not come back); back
from WhatsApp the code copied there ("Copy code") fills the boxes by itself and is checked (Android; never the same code twice), else the
keyboard comes again; **Paste code** takes the six digits of anything copied. The code a guest says to the employee: no paste.

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
