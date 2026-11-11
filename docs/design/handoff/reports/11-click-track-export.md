# 11 · Click track export (WAV, MIDI, MP3) — report

## What changed
- **Two ways in, as specced:**
  - Songs list › Share has a new middle item, "Export click track…" · "Pick one: WAV, MIDI or MP3, for recording software". It uses the same pick mode as the song export, with the bar text "Tap the song for a click track" and Cancel. Tapping a song opens its export sheet.
  - Parts page › "Share this song" now opens the share menu: "Send to a Stikka user" (the export as before) or "Export click track".
  - As before, neither is in unsaved Free play.
- **The sheet** (`lib/src/ui/click_export_sheet.dart`) follows the reference:
  - The song name and a summary line, then what will be in the file.
  - Three format rows, each with its file size. WAV is selected the first time, then the last format used (saved in settings).
  - The file name, then Save to phone and Share.
  - At 115% the rows wrap. Only the middle scrolls; the title and buttons stay.
- **Length:** every song with parts plays each part once, whatever At the end says. Only a one-part song that loops (a plain song) gets Count by and Length: the same controls as Stop after, starting at its Stop after if that's on, else 4:00. Time rounds up to whole bars ("98 bars, rounded to whole bars. No count-in.").
- **Timing comes from the real metronome scheduler.** It runs the song offline against a recorder instead of the speaker, so the file places every click exactly where live playback would:
  - accents, silent beats, subdivisions, polyrhythm, Gradual;
  - and the raised first beat of a part when "Sound on part changes" is on;
  - with your current click sound and volumes;
  - never the count-in, Speed up, Practice speed or Stop after.
- **WAV:** 48 kHz, 16-bit mono, written directly. The first click is at sample 0 and the file ends exactly at the last bar line. Overlapping clicks go through the same kind of limiter as live playback (ceiling −0.1 dB), without its 1 ms delay.
- **MP3:**
  - Format: 48 kHz mono, 160 kbps CBR, with the LAME/Info tag (encoder delay and padding).
  - Encoder: LAME 4.0, unmodified, built by the app as its own small library (not ffmpeg) and called from Dart.
  - Licenses page: new "LAME" entry (LGPL, with where its source is).
- **MIDI:**
  - Type 1, 960 ticks per quarter note.
  - A tempo track: the time signature at each change, each part's name as a marker, a tempo at each part, and a tempo on every beat of a Gradual part.
  - One note track on channel 10: accent 76 (Hi Wood Block), beat 77 (Low Wood Block), subdivision 42 (Closed Hi-Hat), polyrhythm 56 (Cowbell). Velocity comes from the volume; silent steps have no note.
  - In x/8 the tempo is written per quarter note (two eighths), so it lines up with the audio.
- **Save / Share:**
  - Save opens Android's own "Save to" screen, then shows "Saved Glass Harbor.wav".
  - Share opens the Android share menu through a FileProvider.
  - No new permission.
- **Preparing:** made in a background isolate, so the click and the screen never stutter.
  - After 0.4 s the pressed button shows "Preparing · 62%" and the other one becomes Cancel; the rest dims.
  - Cancel, Back or leaving the app stops it and deletes the half-made file.
  - A failure shows "Couldn't make the file. Try again." in the danger color.
- **Data:** settings format 12 adds `exportFormat` (an upgrade starts at WAV). Snapshot `test/fixtures/library_v12/`.
- Build 112.

## Decisions (also in PLAN.md)
- **The sheet comes from the bottom, as in the reference.** The spec says "like the When I press Start sheet", but that panel now drops from the top, so I followed the reference.
- **Share is white with black text,** as in the reference, not the accent color. "Save to phone" has 12px side padding so it fits on one line at 115% on a normal phone.
- **A Gradual one-part looping song** also gets Length; the ramp restarts each pass, as it does when playing.
- **Gradual in text:** the one-part line says "120 to 140 bpm" because arrow glyphs are banned in screen text.
- **The summary's duration** is rounded to the second. It shows the real length of the song ("0:39" for the test's Glass Harbor, not the reference's illustrative "0:42").
- **File sizes:** WAV exact, MP3 by frames, MIDI by writing it. Shown as "4.9 MB", "23 MB", "8 KB".
- **File names** drop `\ / : * ? " < > |` and control characters. "Click track" is used if nothing is left.

## Tests
- `test/audio/click_track_render_test.dart`:
  - A song of 4/4 → 2/4 → 7/8 (with 16ths) → a Gradual part. Every click in the rendered WAV is within 1 sample of the expected time, the first is at sample 0, and the length is exact.
  - The limiter keeps overlaps under the ceiling.
  - MIDI is read back: tempo map, time signatures, markers, the Gradual tempo points, and every note's time through the tempo map within 1 sample of the audio's clicks (x/8 included). Polyrhythm pulses and silent beats are covered.
  - MP3 has the right frame header and the Info and LAME tags. This test runs on the Mac with Homebrew's LAME and is skipped in CI.
  - Cancel deletes the half-made file.
- `test/model/click_track_test.dart`: the length rules for Stop, Loop song and Loop last part, a plain song by Time and by Bars, a Gradual one-part song, the starting length, file names and sizes.
- `test/ui/click_export_sheet_test.dart`:
  - the sheet's content;
  - the plain-song length;
  - Share and Save (the format is remembered, "Saved …");
  - the failure line;
  - 115% on 360dp and on a normal phone: nothing cut, buttons on screen.
- `test/ui/share_flow_test.dart`: both ways in.
- Storage: the v11 → v12 migration and the new snapshot.
- `flutter test` (1776) and `flutter analyze` pass.
- Also checked with ffmpeg: a 4:00 MP3 decodes to exactly 11,520,000 samples (240.000 s) with the first click at sample 0, so players that read the tag line it up exactly.

## APK size
- Release APK: 68.7 → 69.6 MB, +0.85 MB. That compares against the 1.11.0 release APK from 9 Nov, so it also includes handoff 10's small Dart changes.
- LAME is 234 KB for arm64, 176 KB for armv7 and 258 KB for x86_64. A phone installing from Play (per-device split) gets only one, about +0.25 MB.

## Phone check (OnePlus, debug build 112, font size 115%)
- Done:
  - Imported a "Glass Harbor test" song through the share target: Intro 4/4, Verse 4/4 in 8ths, Break 2/4, Bridge 7/8, and a Gradual Chorus 128 → 140 with a polyrhythm. It's now in the debug app's library; delete it when you like.
  - The parts page menu and the Songs list menu, pick mode and the sheet all match the reference. Both sheets fit; the pick bar text wraps to two lines at 115%.
  - Glass Harbor test: 5 parts · 25 bars · 0:51, WAV 4.9 MB.
  - Copper Sky (plain, 98 bpm in 8ths): Count by / Length at 4:00, "98 bars, rounded to whole bars. No count-in.", WAV 23 MB, MP3 4.8 MB, MIDI 8 KB.
  - Save to phone, WAV: the 4-minute file was ready in under 0.7 s, then Android's "Save to" screen opened with "Copper Sky.wav".
  - I pulled the WAV the phone made: 48 kHz mono, exactly 240.000 s. All 784 clicks are within 0.98 samples of the grid, the first at sample 0, peak −0.5 dBFS.
- Finished with Dror tapping SAVE in Android's "Save to" screen (I don't touch other apps):
  - **Saved:** Copper Sky.wav (23,040,044 bytes), .mp3 (9,600,960) and .mid (14,200) are all in Download.
  - **"Saved Copper Sky.mid"** shows at the bottom, clear and not dimmed, also with the Songs panel still open.
  - **Preparing:** an 8:00 MP3 takes ~2.5 s on the phone. "Preparing · 36%" with Cancel next to it, the rest dimmed.
  - **Cancel at 63%** deleted the half-made file and the sheet went back to Save / Share.
  - **MP3 remembered** as the last format.
  - **The phone's MP3** decodes (ffmpeg, which reads the LAME tag) to exactly 480.000 s, and every click peaks at the same sample offset as in the WAV.
  - **The phone's MIDI:** type 1, 960 PPQ, 4/4, a "Part 1" marker, 612,245 µs per quarter (98 bpm), 1568 notes, ending exactly at bar 196.
- Not checked: the Android share menu with a file. I opened it once by mistake (with a song's Stikka text, which was cancelled and nothing sent), but I don't drive it.
- Screenshots in `docs/design/screens/` (115% font, the phone's side dots cropped off):
  - `click-export-songs-menu-115.png`, `click-export-pick-115.png`, `click-export-parts-menu-115.png`
  - `click-export-sheet-115.png` (Glass Harbor test), `click-export-sheet-plain-115.png`, `click-export-sheet-mp3-115.png`
  - `click-export-preparing-115.png`, `click-export-saved-115.png`
- No DAW on this Mac. Instead of the bar 1 / last bar check in a DAW, the tests check that MIDI and WAV agree, and ffmpeg confirmed the MP3.

## Dror should check
- Share a file to WhatsApp or Drive once (I don't drive the Android share menu).
- If you have Reaper, Logic or GarageBand, drop the WAV and MIDI in at bar 1: the clicks should sit on the grid through the 7/8 Bridge and the Chorus ramp.
