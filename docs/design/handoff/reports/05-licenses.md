# 05 · Open-source licenses row: report

Not released (ships with the next release). `flutter analyze` is clean and `flutter test` passes (1702 tests). I checked it on the Android emulator at 115% text; the phone wasn't used.

## What changed
1. **The row:** Settings › About has a 56px "Open-source licenses" row with ›, under "Privacy policy". It has no muted line.
2. **The page:** the row opens Flutter's own licenses page.
   - Application name "Metra" and the version as on the About line ("1.9.0 (109)").
   - No icon and no legalese; "Powered by Flutter" stays, as part of Flutter's page.
3. **Metra's look, through the theme only:**
   - Settings' background, text colors and Saira fonts, in Stage Black and Daylight.
   - The top bar matches Settings' bar: the same ‹, the same 22px semibold title, the divider under it, 64dp tall.
   - The title is "Open-source licenses".
   - Each package's license page uses the same style: the package name, "1 license." under it, then the text.
4. **Every bundled library is listed.** Flutter collects the licenses of Metra's Dart packages (flutter_soloud, audio_service and the rest) and of the Flutter engine by itself. I added what it misses: the native code flutter_soloud compiles into the app.
   - SoLoud: the audio engine.
   - pffft and Signalsmith Stretch / Linear: maths and filters.
   - libogg, libvorbis, Opus and libFLAC: the Xiph audio codecs.
   - The two Saira fonts.
   - The tuner's microphone code is Metra's own (Android's AudioRecord), so it has nothing to add.

## Decisions
- **Theme override instead of a custom page**, as the prompt asks. The title comes from a one-string localization override. Every other piece of text is Flutter's.
- **64dp top bar:** Flutter's default 56dp was too tight for the package pages' two-line title at 115% text ("1 license." touched the divider). 64dp is also exactly Settings' bar height.
- **Source of the Xiph license texts:** their official COPYING files, fetched from the Xiph GitHub repos. The flutter_soloud package doesn't include them, but the APK does ship those libraries.
- **miniaudio isn't listed:** it's public domain / MIT-0, which needs no notice.

## Screenshots (emulator, 115% text)
In `docs/design/screens/`:
- `licenses-row-daylight.png` and `licenses-row-dark.png`: the About section with the new row.
- `licenses-page-daylight.png` and `licenses-page-dark.png`: the licenses page (title, Metra, 1.9.0 (109), the list).
- `licenses-detail-daylight.png` and `licenses-detail-dark.png`: SoLoud's license.

## For the designer
- **Title position:** the title sits about 4dp further right than Settings' title. That's Flutter's bar layout and can't be closed through the theme alone. Fine as is?
- **Package names:** they appear as the packages name themselves, including lowercase technical names ("abseil-cpp", "audio_service"). The list has about 100 entries.

## Phone checks
None needed. The page is Flutter's own, and the emulator showed both themes at 115%. Optional: open it once on the phone after the next release.
