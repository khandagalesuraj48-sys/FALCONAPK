# CLAUDE.md – FALCON phone app (Flutter, Android)

Read this first, then `README.md`. The same owner and rules as FALCON's web and server (`khandagalesuraj48-sys/Wolf`); the short version:

## The owner and how to talk to him
* Sujit Mule, MD of Rachana Construction Limited (RCL).
* **Reply in Marathi (Devanagari).** Answer first. Simple. One step at a time.
* "adhi charcha kar" = discuss first, no code. "fkt check kr" = only check, change nothing.

## Rules
1. **Exactly what he asks, nothing extra.** He decides each step.
2. **The approved designs are the source of truth** (Wolf `docs/DESIGN_INVENTORY.md` – the phone boards): the app's own screens,
   never the web shown inside the app.
3. **Live and business-critical:** the app uses FALCON's LIVE database and server. No test entry is ever saved live. No push to
   `main` without his yes; a server or database change belongs to the Wolf repository and its own rules.
4. **Evidence, not claims:** `flutter analyze` and `flutter test` (here and in the build); say plainly what was not run or not
   verified (a real phone, the live server).
5. **Every command has a timeout.**
6. **Fix a thing everywhere it is used** – the web (Wolf) and this app together.
7. **The repository is PUBLIC:** no secret, key, password, keystore or personal data in any file. The signing key lives only in
   GitHub secrets; the Supabase publishable key (public by design) in GitHub variables.
8. Work arrives as a branch + pull request; he merges.

## Name
* The application is **FALCON** – "Food & Site Operations", by Sketchline Industries; package `si.sketchline.falcon`. It is not
  "LION Mess" and not a LION module.

## How it is built
* No server of its own: FALCON's Supabase (sign-in by a WhatsApp code, the database's own rules) and FALCON's server steps
  (`/api/start`, `/api/register`, `/api/welcome`, `/api/device`, `/api/guest-pass`, `/api/lookup` on FALCON's web address).
* `.github/workflows/build.yml` checks and builds the APK on every push; on `main` it is put up as a GitHub Release.
