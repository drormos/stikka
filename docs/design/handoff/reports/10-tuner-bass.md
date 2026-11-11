# 10 · Tuner: bass range and weak low/high notes — report

## What changed
- **Range B0 (30.9 Hz) to 1500 Hz.** The floor went from 60 Hz to 29 Hz (B0 less half a semitone). The listen window stays 4096 samples (~85 ms): it holds 2.6 periods of B0, which already reads within 1 cent, so a longer window wasn't needed. A plucked bass note shows in ~0.09–0.13 s, well under 0.25 s.
- **Why bass D (73 Hz) failed although it was in range:** when you tune string by string, the string you just tuned keeps ringing. A new string sounding over one a fourth below (D over A, A over E) scores only 0.7–0.8 on "how periodic is this", and the old cut-off was 0.85, so the tuner showed the level but no note. Reproduced in a test: the old detector read D2 once, then nothing, over a ringing E1 or A1. The same thing hit guitar A over a ringing low E, and B over a ringing G. The cut-off is now 0.65; noise still scores far below that.
- **High B/E slow to lock:** the same cause. B3 over a ringing G3 also latched onto the pair's shared lower period (49 Hz, "G1"). The rule that picks the period now favours the louder string's own period (key threshold 0.9 → 0.7). In the tests B3 and E4 lock on in 0.09–0.13 s, the same as the other strings, also with the previous string ringing and through soft clipping ("amp sim").
- **New microphone filter** (`lib/src/audio/mic_filter.dart`), run on the sound before detection:
  - Lowering the floor brought mains hum (50/60 Hz) into range. Alone it read as G1, and mixed with a fading string it gave low wrong notes. Two narrow notches at 50 and 60 Hz remove it. No bass string is near either; A1 at 55 Hz loses ~1 dB.
  - A 25 Hz high-pass removes rumble and handling noise.
  - A 3 kHz low-pass removes hiss above the harmonics that carry the pitch. This matters with the lower cut-off: a fading E4 at 1 s now holds within ±0.5 cent (it was ±5 cents without the filter).
  - The notches need ~0.1 s to settle, so the first 0.1 s after the microphone starts is ignored.
- **Audio source:** `MicBridge.kt` already fell back to `VOICE_RECOGNITION` (not MIC/DEFAULT) when the phone has no `UNPROCESSED`, so that wasn't the cause. It now logs which one it used: `adb logcat -s Stikka` prints `tuner mic: UNPROCESSED at 48000 Hz` (or `VOICE_RECOGNITION`).
- No change to the page layout or wording.

## Tests
- `test/audio/pitch_detector_test.dart`, at 48 and 44.1 kHz:
  - B0, E1, A1, D2, E2, G2, B3, E4, each read to the right note (no octave errors) within 2 cents.
  - The same notes with a weak fundamental (strong 2nd/3rd partials), a decaying envelope and noise.
  - B3/E4 soft clipped at two drive levels.
- `test/controller/tuner_bass_test.dart` (new), through the real controller in 1024-sample chunks:
  - Each bass string B0–G2, plucked with hum and noise, shows within 0.25 s and reads within 2 cents.
  - A1, D2, G2, A2, G3, B3 and E4, each played over the string below still ringing, lock on within 0.25 s and hold for over a second. The old code fails all of these.
  - 50 Hz and 60 Hz hum alone shows no note.
- `tuner_guitar_test.dart`: at 2 s, when the string has faded almost into the noise, the allowed error went from 3 to 4 cents. E4 now reads ~3.1 cents off there instead of blank, a side effect of the lower cut-off.
- `flutter test` (1744) and `flutter analyze` pass; the debug APK builds.

## Known limit
Late in a note, once the new string has died down to the level of the one still ringing, the pair can read as their shared lower period, e.g. G3 over D3 shows G1 after ~1.5 s. I tried blanking such frames, but a single plucked G3 scores almost the same as these mixes, so that rule would have blanked real notes. A guitarist mutes the other strings or plucks again, which fixes it at once.

## Not done / Dror should check
- **No phone was connected**, so the bass-through-a-speaker check didn't run, and I can't say which audio source the tester's phone uses. On the phone:
  - Play E1, A1, D2, G2 from a tone generator through a speaker that can reproduce them (phone and laptop speakers can't play 41 Hz; a bass amp or a sub can).
  - Check that each shows within ~¼ s.
  - Run `adb logcat -s Stikka` while the tuner opens to see the source.
- Best real-world check: a bass played unplugged and through an amp, string by string, letting each ring. Also the tester's electric through the amp sim, high B and E.
- No screenshots: nothing on screen changed.
- No build-number bump: this isn't installed anywhere yet. It goes into the next release.
