# 06 · Rename the app: Metra → Stikka

Spec: ui-spec.md › "Name" (new, at the top). Re-read it first. The band "Met Ra" claimed the old name, so the rename has to cover everything. **Before you start, ask Dror for the new feedback email address** (the plan is stikka.app@gmail.com; he's creating it). Don't release; 07 does that.

## 1. Find every mention first
`grep -rni metra` over the whole repo, skipping only build/, .dart_tool/, .git/, docs/history.md, past CHANGELOG entries, and docs/design/handoff/done/ and reports/. That includes .claude/, .agents/, .github/, tool/, test/, integration_test/, ios/, macos/, android/ (gradle files too), store/ and every *.md. Also search for "METRA" and "Metra" inside images: run OCR on store/screenshots, docs/design/screens/store and every image store/instagram/gen.py makes. Sort every hit into A, B or C below, and list all of them in the report.

## 2. A: what users see → "Stikka"
- **Launcher and app names:** the label for release builds ("Stikka") and debug builds ("Stikka dev"), wherever `appLabel` is set. The share-target label (AndroidManifest line ~66, "Metra" in the share menu). The Quick Settings tile's label. MaterialApp `title`. The notification and lock-screen media session, and the notification channel's **name** (not its ID).
- **Every string in lib/:**
  - About Stikka, the version line "Stikka 1.10.0 (…)", and the feedback subject.
  - The licenses page `applicationName`.
  - The tuner's microphone line.
  - "Keep screen on: While Stikka is open".
  - The error messages in main.dart and metronome_screen.dart, and "a newer Stikka".
  - The share menu lines and the "Copy the whole Stikka message" line.
  - The What's new heading.
- **Feedback email:** the new address, in about.dart.
- **ios/ and macos/:** the display names (CFBundleDisplayName / CFBundleName), even though we don't ship there.

## 3. Exports must keep working, old and new
- **New exports:** the data line becomes `stikka1:`, the ending reads "Shared from Stikka", and the help line reads "To import into Stikka: copy this whole message, then in Stikka tap Share › Import."
- **Import finds the data by its content, not by the app's name.**
  - It accepts any line made of letters, then a version number, a colon and the encoded block (`metra1:`, `stikka1:`, or whatever a future name brings).
  - It accepts the block even with no prefix at all, if it decodes to a valid export.
  - The version number still decides how the block is read.
  - It strips any "Shared from …" ending.
  - That way a rename never breaks sharing again.
- **Tests:**
  - Fixtures exported by the real 1.9.0 code (a set with parts, plus one song) import in the new build.
  - A `stikka1:` export round-trips.
  - A bare block and an unknown prefix (`foo1:`) both import.
  - Garbage gets "nothing to import" and never crashes.
- **For the report:** old Metra builds (1.9.0 and earlier) only look for `metra1:`, so they can't read a `stikka1:` export. That code is already on phones and can't be changed from here. Every tester updates through Play, so it's accepted. Say so in the report.

## 4. B: keep on purpose (never shown to users; changing them would break installs or data)
- The applicationId `com.dror.metra` / `.debug` and the Kotlin package com.dror.metra.
- The notification channel ID `com.dror.metra.playback`, and the method channels `metra/android`, `metra/tile`, `metra/share`.
- The saved file names, the signing key alias and keystore, the repo folder name, and the Google Group URL (`metra-testers`; Google can't rename it).
- Add a short comment next to each of these: "Old name, kept on purpose: see ui-spec.md › Name."

## 5. C: internal names → Stikka (users never see these, but future work shouldn't trip on them)
- The Dart package name (pubspec `name: stikka`, every `package:metra/` import) and the pubspec description.
- MetraApp, MetraColors, MetraFonts, MetraMotion, metraTheme, and METRA_ROOT in gen.py.
- metra.iml → stikka.iml.
- Do this as its own commit, after A, with analyze and tests green.

## 6. Docs, store and social
- **README, SECURITY, CONTRIBUTING, ARCHITECTURE, TESTING, RELEASING, PLAN.md, CLAUDE.md, and the project skills in .claude/ and .agents/:**
  - The name becomes Stikka.
  - Keep CLAUDE.md's rules exactly as they are, renamed only.
  - Add one line to README: "Formerly Metra."
- **PRIVACY.md:**
  - The name, the email, and "the developer of Stikka on Google Play".
  - Add: "Stikka was called Metra until version 1.10.0."
  - Change nothing else.
- **CHANGELOG:** don't touch past entries. 07 adds the new one.
- **store/listing.md:**
  - App name **Stikka**.
  - Short and full descriptions renamed. Recount the characters, and check the 30 / 80 / 4000 limits.
  - Fix the adb paths in the screenshot steps (the package ID stays, so mostly unchanged).
  - Regenerate feature-graphic.png from feature-graphic.html.
- **store/instagram/:**
  - INSTAGRAM.md: the profile name becomes `Stikka · Metronome for drummers`, plus every caption, comment and the schedule.
  - Rename posts/01-meet-metra → 01-meet-stikka.
  - Regenerate every image with gen.py, then OCR them all for "Metra".
  - Regenerate the r2 reel with reels.py if it shows the name.
  - Add a short "Rename" section to INSTAGRAM.md: what Dror changes in Instagram, the Facebook Page and Business Suite (see 8).
- **docs/design/** is mine. Don't edit it, except your report.

## 7. Guard and checks
- **New test:** no user-visible "Metra" anywhere. It scans the string literals in lib/, the AndroidManifest and gradle labels, assets/whats_new.md (except the rename line) and store/listing.md. The allowlist is only the old-import code in section 3. It fails the build on any other hit, and tool/release.sh runs it.
- `flutter analyze` and `flutter test` pass, plus the release checks (no INTERNET, microphone optional).
- **Emulator upgrade check (no phone):**
  - Install 1.9.0 (109) from its release commit.
  - Add songs, a set with parts, a Practice speed song, Free play settings, a changed Reference A4, and a Quick Settings tile.
  - Install the new build over it.
  - Everything should survive. The launcher, tile, notification and share menu should say Stikka. Importing an old `metra1:` message should work.
- **Screenshots at 115%:** launcher label, Settings › About, About Stikka, the licenses page header, the share menu with Export, the Quick Settings tile, and the media notification. Save them as docs/design/screens/rename-*.png.

## 8. In the report: Dror's list outside the repo, in this order
1. GitHub: rename the repo drormos/metra → drormos/stikka (Settings › Rename; GitHub redirects the old links). Then: `git remote set-url origin https://github.com/drormos/stikka.git`, and switch the privacy URL in about.dart, RELEASING.md and SECURITY.md to the new address. **Ask Dror first and do it in this session if he agrees**, and say which you did.
2. Play Console › Store listing: the app name, the short and full descriptions, the feature graphic. Then App content › Privacy policy URL: the new link.
3. Instagram: the name field, then the handle, if Dror got @stikka (or the one he chose). Change the profile picture only if gen.py changed it.
4. Facebook Page: the name (Meta reviews name changes, usually within days) and the cover.
5. Business Suite: delete the scheduled Metra posts (from Nov 10 onward) and schedule the regenerated ones. Decide about the Nov 8 "Meet Metra" post (my advice: archive it and post "Meet Stikka").
6. Google Group metra-testers: change the group's display name and description. The URL stays.
7. Gmail: forward metra.application@gmail.com to the new address.
8. The Claude Desktop project name and the canvas title: Dror's call.

Write the report, move this file to done/, commit.
