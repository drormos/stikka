# 07 · Release 1.10.0 (Stikka): report

Built and committed (`release: 1.10.0 (build 110)`). Not uploaded, tagged or pushed. Dror asked for this to go fast, so two checks were left out (see "Expedited").

## Build
- Version **1.10.0 (build 110)**.
- AAB: `build/app/outputs/bundle/release/app-release.aab`, 63 MB. Signed with the upload key (`META-INF/METRA.SF/.RSA`, alias `metra`, kept on purpose).
- The manifest inside it has versionName 1.10.0 and label "Stikka".
- Sideload APK: `build/app/outputs/flutter-apk/app-release.apk`.
- `tool/release.sh` ran its gates first: `flutter analyze` and `flutter test`, including the release-consistency test, the schema guard, the permissions checks (no INTERNET, microphone optional) and the no-"Metra" guard.

## Release notes (paste into Play; 123 / 500 characters)
```
- Metra is now called Stikka. Same app, and all your songs are here.
- Settings › About now lists the open-source licenses.
```
The same lines are in assets/whats_new.md (`## 1.10.0 · Nov 2026`) and store/listing.md. CHANGELOG has `[1.10.0] - 2026-11-09`:
- the rename;
- that old `metra1:` exports still import, and that Metra 1.9.0 and older can't read the new ones;
- the new feedback address;
- the licenses page.

## Privacy
- https://github.com/drormos/stikka/blob/main/PRIVACY.md serves the renamed policy; main was pushed in 06.
- The old URL returns a 301 redirect to it.
- The app opens the new URL.

## Guard
The rename line ("Metra is now called Stikka…") is the Play notes too, so the guard now allows the "now called" line in store/listing.md, as it already did in What's new. Any other "Metra" still fails the build. The first run caught that line before the build, which shows the guard works.

## Expedited (Dror asked to speed this up)
- **No drift run.** Since 1.9.0, lib/src/audio and lib/src/storage changed only by one comment. The scheduler, the click output and the store are untouched.
- **No second emulator upgrade check on the signed build.** The API 37 emulator's system server kept crashing in 06. What covers the upgrade instead:
  - 06's check on the phone: the debug app went from 1.9.0 (109) to the new code with library.json byte-identical, and an old `metra1:` set imported.
  - The app ID and the saved-file format are unchanged (the schema guard passed).

## Play Console, with this upload (from 06 §8)
1. **Store listing:**
   - App name **Stikka**.
   - Short description and full description from store/listing.md (only the name changed).
   - Feature graphic `store/feature-graphic.png`.
2. **App content › Privacy policy:** https://github.com/drormos/stikka/blob/main/PRIVACY.md
3. **Upload** the AAB to the closed test with the notes above.

## Left for Dror's go-ahead
`git push && git tag v1.10.0 && git push origin v1.10.0`, and the GitHub release (`gh release create v1.10.0 --title "Stikka 1.10.0"`).
