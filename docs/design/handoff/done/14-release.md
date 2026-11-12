# 14 · Release: tuner bass, click track export, clearer pick mode

Depends on 10–13 being done (they are). Use the release skill. Don't upload, tag or push unless Dror asks.

1. **Version:** the next minor version after the last release (check CHANGELOG and pubspec; 1.11.0 was the last one I know of), next build number.
2. **What's new** (in the app, max 4 lines) and **Play release notes** (≤500 characters, same lines):
   - Export a song as a click track: WAV or MIDI for recording software, MP3 to send.
   - The tuner now tunes bass, down to a 5-string's low B, and locks on faster.
   - Choosing a song to export now looks clearly different from the song list.
   - Also update CHANGELOG, assets/whats_new.md and store/listing.md (add one line about click track export to the full description if it lists features).
3. **No phone this time:** Dror's phone isn't connected. Don't wait for it or ask for it. Checks (don't skip them; the audio code and the saved settings changed):
   - The release gates (analyze, tests, permissions: still no INTERNET, microphone optional, no new permission for export).
   - A drift run, if it can run without the phone (emulator or the offline test harness). If it needs the phone, skip it and say so in the report.
   - Upgrade check from the last release: the library/settings migration tests with the v11 and v12 snapshots must pass (settings format 11 → 12, `exportFormat` starts at WAV). If the emulator works, also install the last release then this signed build on it and check songs and settings are kept; if it crashes like in 06, rely on the tests and say so.
   - The licenses page lists LAME (widget test is enough).
4. **Privacy:** nothing new is collected or sent; exported files go only where the user chooses. If PRIVACY.md or the Play Data safety form needs a line for "files the user exports", say so in the report; don't change the form yourself.
5. **Screenshots:** skip (no phone). List in the report what Dror should look at on the phone after installing: the pick mode list reaching the panel bottom (13) and sharing an exported file once to WhatsApp or Drive (11).
6. Build the signed AAB. Report its path, the version, the exact release notes to paste, any Play Console steps, and the push/tag commands for Dror's go-ahead.
