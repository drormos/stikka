# 10 · Tuner: bass range and weak low/high notes (tester report)

Spec: ui-spec.md › Tuner › "Range (Nov 2026 …)". Re-read it first.

Tester report (closed test, Android):
- Bass: only the G string (98 Hz) is detected. E, A and D show the level but no note.
- Electric guitar through an amp/monitor after an amp simulator: steady and good, but the high B and E strings take a long time to lock on.
- Another tuner app on the same phone tunes the bass easily, so the phone's mic can hear it.

What we already know from the code:
- `PitchDetector.minHz = 60` (chosen for "from E2"), so E1 (41.2) and A1 (55) can't be found at all.
- D2 (73.4 Hz) is inside the range and still failed. Find out why. Suspects: `MicBridge.kt` falling back from UNPROCESSED to a source with a low-cut filter on phones that don't offer UNPROCESSED (prefer VOICE_RECOGNITION as the fallback, not MIC/DEFAULT); `clarity = 0.85` too strict for a real bass (weak fundamental, strong harmonics); the first-peak rule picking a harmonic.

Changes:
1. Range from B0 (30.9 Hz) to ~1500 Hz. If 4096 samples (~85 ms) is too short for B0/E1 to be reliable, use a longer window, but keep the time until a note first appears at ≤ ~0.25 s and the reading steady.
2. Fix whatever makes D2 fail (above). Say in the report what it was.
3. High B3/E4 strings must lock on about as fast as the others: check the clarity threshold and the median/hold logic on fast-decaying, harmonic-rich (distorted) tones.
4. No change to the page layout or wording.

Tests:
- Synthetic tones, each detected to the right note and within ±2 cents: B0 30.9, E1 41.2, A1 55, D2 73.4, G2 98, E2 82.4, B3 246.9, E4 329.6. For each, also a version with a weak fundamental (strong 2nd/3rd harmonics) and a decaying envelope, and a soft-clipped "amp sim" version for B3/E4.
- No octave errors on those.

Phone checks (if connected): play bass notes E1, A1, D2, G2 from a tone generator through a speaker and report what the tuner shows and how fast. Report which audio source the phone ended up using.
