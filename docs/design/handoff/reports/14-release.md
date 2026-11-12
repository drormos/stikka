# 14 · Release 1.12.0: report

Built, not uploaded, tagged or pushed. **Stikka 1.12.0 (build 117).** One release commit (`release: 1.12.0 (build 117)`), plus PLAN.md status and this report.

AAB: `build/app/outputs/bundle/release/app-release.aab` (64.1 MB, signed with the release key)
APK (sideload copy): `build/app/outputs/flutter-apk/app-release.apk`

## 1. Version
pubspec was `1.11.0+116` (debug builds after the 1.11.0 release used 112–116). Now `1.12.0+117`.

## 2. Notes
**Play release notes (paste as is, 229 / 500 characters):**

```
- Export a song as a click track: WAV or MIDI for recording software, MP3 to send.
- The tuner now tunes bass, down to a 5-string's low B, and locks on faster.
- Choosing a song to export now looks clearly different from the song list.
```

- `assets/whats_new.md`: the same three lines under `## 1.12.0 · Nov 2026` (what the app shows).
- `CHANGELOG.md`: the Unreleased items moved under `## [1.12.0] - 2026-11-12`.
- `store/listing.md`: full description gets one line under SETLISTS AND STAGE MODE, "• Export a song as a click track: WAV or MIDI for your recording software, or MP3 to send." (3126 / 4000). Its release-notes section now holds the lines above.

**Play Console steps:** create the release on the track you use, upload the AAB, paste the notes. Paste the new full description from `store/listing.md` into Main store listing (one new line; nothing else changed).

## 3. Checks (no phone)
- **Gates:** `flutter analyze` clean; `flutter test` 1782 passed (includes the release-consistency, schema guard and name guard tests).
- **Permissions:** the release manifest requests exactly what 1.11.0 does (compared line for line): RECORD_AUDIO, FOREGROUND_SERVICE(_MEDIA_PLAYBACK), WAKE_LOCK, BIND_QUICK_SETTINGS_TILE. No INTERNET, no POST_NOTIFICATIONS, microphone `required="false"`. Export adds no permission. (`android.permission.DUMP` in the merged manifest is the profile installer's receiver guard, the same as before, not a permission Stikka asks for.)
- **Long fuzz runs:** 5000 scheduler sessions and 4000 damaged library files, all passed.
- **Drift: NOT RUN.** The audio engine couldn't start on the Mac (`SoLoudBackendNotInitedException` in every copy, and again in a single test run alone). The Mac's default output was the HyperX Cloud III Wireless headset, probably switched off at that hour. I didn't change the Mac's sound output. Dror chose to skip it for this release (the scheduler change since 1.11.0 is 3 lines).
- **Upgrade check:** the migration tests with the v11 and v12 snapshots pass (format 11 → 12, `exportFormat` starts at WAV, songs and settings kept). The emulator failed as in 06: after installing 1.11.0 (release build from c921520) and sharing a set to it, Android showed "Process system isn't responding" before any upgrade, so the emulator gave no result. I relied on the tests.
- **Licenses page:** the widget test now also checks that LAME is listed (it checked SoLoud, libogg, Opus and Saira before).

Note: while I worked, a phone showed up in `adb devices` over wireless debugging. I didn't touch it (you said no phone this time); every adb command targeted the emulator only.

## 4. Privacy
Nothing new is collected or sent; exported files go only to the place or app the user picks in Android's own save or share sheet. Play's Data safety form doesn't count user-started transfers like this, so **no change to the form**. PRIVACY.md stays correct as written. Optional, if you'd like it spelled out: under "What stays on your phone", add "Songs or click tracks you export go only where you send or save them." Not done.

## 5. On the phone, after installing
Install over the debug app with `adb install -r` (a Play install can't be sideloaded over).
- Songs list › Share › Export click track…: the pick list runs to the bottom of the panel (13), header on two lines.
- Export a song once as WAV and share it to WhatsApp or Drive (11); it should arrive and play.
- Export one as MP3 and play it; MIDI opens in a DAW if you have one handy.
- Tuner on a bass's low E (or a 5-string's low B).
- Songs and settings survived the update (format 11 → 12).

## 6. To publish (after your go-ahead)
```
git push
git tag v1.12.0 && git push origin v1.12.0
gh release create v1.12.0 --title "Stikka 1.12.0" --notes-file <notes.md>
```
