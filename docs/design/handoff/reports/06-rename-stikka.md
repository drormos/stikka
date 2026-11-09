# 06 · Rename Metra → Stikka: report

Done, not released (07 does that). Three commits: A (what users see, plus the import change and the guard), C (internal names), docs/store/social; plus this report. `flutter analyze` is clean and `flutter test` passes (1708 tests), including the release checks (no INTERNET, microphone optional) and the new name guard.

Feedback address: **stikka.app@gmail.com** (Dror confirmed it).

## 1. Every mention, sorted

`grep -rni metra` found 859 lines in 160 files (skipping build/, .dart_tool/, .git/, docs/history.md, past CHANGELOG entries, handoff done/ and reports/). docs/design/ is the designer's: not touched, except the new screenshots and this report.

**A: users see it → Stikka**
- Launcher label: `appLabel` in android/app/build.gradle.kts, "Stikka" (release) and "Stikka dev" (debug).
- Share-target label and Quick Settings tile label in AndroidManifest.xml. The tile and the share menu both read "Stikka" (checked in the built APKs with aapt2).
- MaterialApp `title` (main.dart). The notification channel name was already "Metronome playback", so nothing to change. The notification and lock-screen card take the app label.
- lib/ strings: About Stikka (title, row), the version line "Stikka 1.9.0 (109)", the feedback subject "Stikka feedback (…)", the feedback address, the licenses page `applicationName`, the tuner's microphone line, "While Stikka is open", the error messages in main.dart and metronome_screen.dart, "a newer Stikka" (share_menu.dart, twice), the share-menu lines and "Copy the whole Stikka message", "Shared from Stikka", the import help line.
- assets/whats_new.md: the heading "What's new in Stikka" and the old line "The screen stays on while Stikka is open" (users read the old entries too).
- ios/Runner/Info.plist: CFBundleDisplayName Stikka, CFBundleName stikka. macOS: PRODUCT_NAME Stikka, so the app is Stikka.app (scheme and test host updated).
- store/listing.md and the feature graphic.
- Doc comments that name the app (lib/, Kotlin) were renamed along with the strings.

**B: kept on purpose** (each has the comment "Old name, kept on purpose: see ui-spec.md › Name.")
- applicationId and namespace `com.dror.metra` / `.debug` (build.gradle.kts), and the Kotlin package (`package com.dror.metra` in all five .kt files).
- Notification channel ID `com.dror.metra.playback` (main.dart).
- Method channels `metra/android`, `metra/tile`, `metra/share` (android_bridge.dart) and `metra/mic`, `metra/mic/pcm` (mic_input.dart).
- Keystore `~/keys/metra-release.jks` and its alias `metra` (comment in PLAN.md "Release builds"; key.properties is outside git).
- The Google Group URL `metra-testers`: it stays in INSTAGRAM.md, the CTA slides and reels.py.
- The repo folder `/Users/dror/Developer/metra` (CLAUDE.md still says to work there).
- The saved file names never had the name in them (`library.json`, `settings.json`), so there was nothing to keep.
- iOS/macOS bundle IDs `com.dror.metra` (they follow the app ID, as before).
- The golden `test/fixtures/export_v1/set.txt` (build 101's text, must always read) and the new 1.9.0 fixtures: they must stay as the old builds wrote them.

**C: internal → Stikka** (own commit, analyze and tests green)
- pubspec `name: stikka`, description "Stikka, a stage metronome.", and every `package:stikka/` import (lib, test, integration_test, tool).
- StikkaApp, StikkaColors (and StikkaColorsContext), StikkaFonts, StikkaMotion, stikkaTheme; STIKKA_ROOT in gen.py.
- metra.iml → stikka.iml. It is gitignored, so this was a local rename (plus .idea/modules.xml), with no commit.
- Also: the Kotlin log tag, the test temp-dir names, the env var STIKKA_COVER_OUT, and `$TMPDIR/stikka-drift` (tool/drift_parallel.sh, release.sh, release skill).

**In images (OCR with macOS Vision over store/screenshots, docs/design/screens/store, the feature graphic and every image gen.py makes):**
- store/screenshots and docs/design/screens/store: no "Metra". They show the app's screens, which never show the name.
- After regenerating, the only hits left are intended ones:
  - "Join the Google Group metra-testers" on the CTA slides (B).
  - The rename announcement `posts/10-rename/1.png` and `stories/story-0-rename.png`. They were already in store/instagram and aren't made by gen.py; I left them as they are.
- Post 05 slide 2 showed the old share menu ("…another Metra user…", "From a Metra export"). It came from `docs/design/screens/share-menu-set-115.png`. I captured the menu again on the phone at 115% as `docs/design/screens/rename-share-menu.png`, with the sidebar dots painted out. gen.py now uses that file for slide 2. Your old file is untouched.

## 2. Exports, old and new

- **New exports:** the data line is `stikka1:`, the help line is "To import into Stikka: copy this whole message, then in Stikka tap Share › Import.", and the song list ends with "Shared from Stikka".
- **Import no longer cares about the name** (`parseShared`, model/share_export.dart):
  - It tries, in order, every block in the text with an optional `<letters><version>:` prefix and 16 or more base64url characters, and takes the first one that decodes to an export.
  - A block with no prefix reads as version 1. A prefix with any other version is skipped (the version decides how the block is read).
  - Text around the block, such as the readable list or any "Shared from …" ending, is ignored.
- **Tests (test/model/share_export_test.dart):**
  - **1.9.0 fixtures:** I checked out the 1.9.0 release commit (dcdb11a) and exported a set with parts plus one song with its own code (`test/fixtures/export_v1/metra-1.9.0-set.txt` and `-song.txt`). Both import in the new build.
  - **Round trip:** a `stikka1:` export round-trips.
  - **Other forms:** a bare block, `foo1:`, and texts ending in "Shared from Metra" or "Shared from Stikka" all import.
  - **Unknown version:** `stikka2:` is skipped.
  - **Garbage:** 10 kinds of junk all give "nothing to import" and never throw.
- **Old builds can't read new exports.** Metra 1.9.0 and older only look for `metra1:`, so they can't read a `stikka1:` export. That code is already on phones and can't be changed from here. It's accepted because every tester updates through Play. Until someone updates, they can still send to updated bandmates, but they can't read exports from them.

## 3. Guard

`test/platform/name_guard_test.dart` fails on "Metra" or "METRA" as a word in these places:
- every non-comment line in lib/
- AndroidManifest.xml and build.gradle.kts
- assets/whats_new.md (the line that contains "now called" is allowed, for 07's rename line)
- store/listing.md

The lowercase IDs kept on purpose never match. The import code no longer names any app, so the allowlist ended up empty. `tool/release.sh` runs it as part of `flutter test` (a comment there says so).

## 4. Docs, store, social

- **Docs:**
  - README ("Formerly Metra."), SECURITY, CONTRIBUTING, ARCHITECTURE, TESTING, RELEASING, PLAN, CLAUDE.md (rules unchanged, name only), and the project skills: renamed.
  - .github issue forms: renamed.
  - PRIVACY.md: the name, stikka.app@gmail.com, "the developer of Stikka on Google Play", and the new line "Stikka was called Metra until version 1.10.0." Nothing else changed. The effective date stays 2 November.
  - CHANGELOG: not touched. 07 adds the entry.
- **store/listing.md:**
  - App name Stikka (6 / 30).
  - Short description 74 / 80 (it doesn't name the app). Full description 3035 / 4000 (recounted).
  - The adb paths keep the package ID, so they didn't change.
  - feature-graphic.png: rendered again from the HTML with headless Chrome at 1024×500. The layout is the same as before; only the word changed.
- **store/instagram:**
  - The whole folder was untracked until now; it's committed with the regenerated images.
  - INSTAGRAM.md: the profile name `Stikka · Metronome for drummers`, every caption and the schedule. `01-meet-metra` is now `01-meet-stikka`.
  - INSTAGRAM.md has a new "Rename" section (Instagram, Facebook Page, Business Suite).
  - Every image regenerated with gen.py. Only the name and Pillow's anti-aliasing differ. The profile picture and the Facebook page picture came out pixel-identical, so they stay.
  - Reel R2 was **not** rebuilt (you said no reels). reels.py now draws "Stikka", but the existing `reels/r2-tonights-gig.mp4` still shows "Metra" in its corner. It isn't scheduled. Run `reels.py r2 <recording>` before posting it.
- `__pycache__/` added to .gitignore.

## 5. Upgrade check

- **The emulator didn't work.** On the API 37 emulator, I installed 1.9.0 (release build from dcdb11a) and seeded it:
  - imported the set (3 songs, 1 with parts) through the share target
  - Practice speed on Glass Harbor
  - Free play at 106
  - A4 442
  - the Quick Settings tile added

  Installing the new build over it with `adb install -r` succeeded. Then Android's own "Updating…" screen hung, and the system server kept crashing ("System UI / Process system isn't responding", then "Activity class does not exist") until I stopped. That's the emulator, not Stikka: the same happened to the launcher. So the emulator result is incomplete.
- **On your phone (debug app, as you said):**
  - Stikka dev was 1.9.0 (109) with your data: 16 songs, 3 sets, 2 songs with parts.
  - I copied library.json and settings.json off first. They are outside the repo, in my session's scratch folder.
  - Then I installed the new debug build with `adb install -r`. **library.json is byte-identical** after the update.
  - settings.json differs only as a fresh launch should (Principle 10 / Behavior): back to Free play (no set or song loaded) and Count-in off. Everything else is the same, including tempo 150, sound, volumes, Reference A4 and the tips seen.
  - Importing the old `metra1:` message (the 1.9.0 fixture) through the share target showed "Add "Fri"? 3 songs, 1 with parts". I tapped **Cancel**, so your library is unchanged.
  - Your phone's data had no Practice speed song and A4 was 440. Those cases were only covered on the emulator (before it failed) and by the tests (Practice speed and A4 are plain fields, read the same as before).
- **Labels (aapt2 on the built APKs):** application label "Stikka" (release) / "Stikka dev" (debug), share target "Stikka", tile "Stikka".
- **Notification:** while playing on the phone it was posted on channel `com.dror.metra.playback`, title "Midnight Engine", from the debug app. I stopped the click afterwards.

## 6. Screenshots (phone, 115% text, sidebar dots cropped)

- `docs/design/screens/rename-settings-about.png`: Settings › About ("About Stikka", "Stikka 1.9.0 (109)")
- `docs/design/screens/rename-about-stikka.png`: About Stikka
- `docs/design/screens/rename-licenses.png`: licenses page header "Stikka / 1.9.0 (109)"
- `docs/design/screens/rename-share-menu.png`: the set's share menu with Export ("another Stikka user", "From a Stikka export"). Not cropped; the dots are painted out, because gen.py uses it.
- `docs/design/screens/rename-import-metra1.png`: an old `metra1:` set read by the new build

**Not taken:** the launcher label, the Quick Settings tile and the media notification. Those are your phone's own screens (home screen, notification shade), which I don't touch. The labels are verified in the APKs (section 5).

## 7. Dror: please check on the phone (Stikka dev is installed)
1. **Launcher:** the icon reads "Stikka dev".
2. **Notification:** start the click. The notification and lock-screen card say Stikka dev.
3. **Tile:** if you have the tile, its label reads Stikka.
4. **Share menu:** share any text from another app. The share menu lists "Stikka" for the debug app.

The release build says "Stikka" in all four places; 07 ships it.

## 8. Your list outside the repo, in order

1. **GitHub: done in this session** (you agreed). The repo is now drormos/stikka; GitHub redirects the old links.
   - `origin` now points at `https://github.com/drormos/stikka.git`.
   - The privacy URL is `https://github.com/drormos/stikka/blob/main/PRIVACY.md` in about.dart and RELEASING.md. The security-advisory links in SECURITY.md and the issue-form config point at the new repo too.
   - Nothing is pushed yet: main is 5 commits ahead of origin. Push when you're ready (07 or now).
2. **Play Console › Store listing:** the app name **Stikka**, then the short and full descriptions from store/listing.md, then the feature graphic `store/feature-graphic.png`. Then App content › Privacy policy: `https://github.com/drormos/stikka/blob/main/PRIVACY.md`. The new link works only after the push; the old link redirects.
3. **Instagram:** Edit profile › Name `Stikka · Metronome for drummers`, then the handle if @stikka (or your choice) is free. The profile picture didn't change.
4. **Facebook Page:** the name Stikka (Meta reviews it, usually within days), and the new cover `store/instagram/facebook/page-cover.png`.
5. **Business Suite:** delete the scheduled Metra posts from Nov 10 on, and schedule the regenerated ones (same folders, dates and times). For the Nov 8 "Meet Metra" post, I agree with the designer: archive it and post `posts/01-meet-stikka/` (or announce with `posts/10-rename/` first).
6. **Google Group metra-testers:** change the display name and description to Stikka. The URL stays.
7. **Gmail:** forward metra.application@gmail.com to stikka.app@gmail.com.
8. **The Claude Desktop project name and the canvas title:** your call.
