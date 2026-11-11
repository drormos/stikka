# 13 · Pick mode polish (after build 115 review)

Spec: ui-spec.md › Sharing sets and songs › In the Songs list (pick mode paragraph). Re-read it first. Follows 12.

From the 115% screenshots (pick-mode-export-115.png, pick-mode-click-115.png):

1. The list stops after 5 songs and leaves an empty dark block where the hidden bottom row was. In pick mode the list must run down into that space (more rows visible, scrolls as usual). Rows still must not move when entering or leaving pick mode; only the bottom edge of the list changes.
2. Shorter header lines (they wrapped to three lines at 115%):
   - Export a song: "Tap a song to send it"
   - Click track: "Tap a song for WAV, MIDI or MP3"
3. Keep the timings from build 115 (180ms in, 150ms out, menu fade 90ms); the spec now says so.

Tests: list height in pick mode fills to the panel bottom; header lines at 115% on 360dp take at most two lines. Screenshots: replace pick-mode-export-115.png and pick-mode-click-115.png.
