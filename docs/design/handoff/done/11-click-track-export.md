# 11 · Click track export (WAV, MIDI, MP3)

Spec: ui-spec.md › "Click track export" (new section), plus the two changed lines in "Sharing sets and songs" (Songs list menu item, parts page "Share this song" menu). Re-read them first.
Reference: docs/design/click-export.reference.html (all states: entry points, sheet for a song with parts, plain looping song, preparing, saved, failed, 115%).

Independent of 10 (tuner). Do it after 10 is done.

1. Entry points: "Export click track…" in the Songs list share menu (pick mode with "Tap the song for a click track"); "Share this song" on the parts page opens a two-item menu (Send to a Stikka user / Export click track).
2. The export sheet exactly as the reference: format rows (WAV / MIDI / MP3) with the file size, file name line, Save to phone + Share. Remember the last format.
3. Length rules: Stop → all parts once; Loop song → once; Loop last part → last part once. One-part looping songs show Count by + Length (start from Stop after if on, else 4:00; round up to whole bars).
4. Render offline, using the same timing and sounds as live playback (current click sound and volumes; accents, silent beats, subdivisions, polyrhythm, Gradual). Never count-in, Speed up, Practice speed or Stop after. First click at sample 0; file ends exactly at the last bar line.
   - WAV: 48 kHz, 16-bit, mono, written directly (no library).
   - MP3: 48 kHz mono 160 kbps CBR, with the LAME/Xing encoder-delay tag. Android has no MP3 encoder, so add a small LAME-based encoder (not ffmpeg). Add it to the Licenses page. Report the APK size change.
   - MIDI: type 1, 960 PPQ. Tempo track with tempo per part (a point every beat in Gradual parts), time signature events, part names as markers. Note track on channel 10: different notes for accent, beat, subdivision and polyrhythm, velocity from volume, no notes for silent steps.
   - x/8 time signatures: the MIDI tempo and the WAV must line up with what the app plays. Test it.
5. Save to phone via Android's create-document screen; Share via the Android share sheet (FileProvider). Snackbar "Saved <name>" after saving.
6. Preparing state (only after ~0.4 s): the pressed button becomes the progress bar, the other becomes Cancel, the rest dims; Cancel / Back / leaving the app stops and deletes the partial file. Failure line in the danger color.

Tests:
- Rendered WAV: click onsets land within 1 sample of the expected times for a song with 4/4 → 2/4 → 7/8 parts and a Gradual part; length equals the song length exactly.
- MIDI: parse it back and check the tempo map, time signatures, markers and note times against the song.
- Length rules for each "At the end" option and a plain looping song (Time and Bars).
- Sheet layout at 115% on 360dp and on a normal phone.

Check on the phone: export Glass Harbor-style test song as all three formats, Save and Share. Screenshots (sheet, preparing, saved, 115%) into docs/design/screens/ named click-export-*.png. If you can, import the WAV and MIDI into any DAW you can run and confirm they line up at bar 1 and at the last bar.
