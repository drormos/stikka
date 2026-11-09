# 08 · Accent color in Settings

Spec: ui-spec.md › Theme › "Color (the user's accent color)" (the token table) and › Settings › "Color". Re-read both first. Canvas: "Detail · Accent color in Settings (decided: A, swatches)" and "Detail · Accent colors in both themes". Do this after 07 (the Stikka release) has shipped; it goes into the release after that.

1. **Tokens:** add a `danger` token (#FF3B30 Stage Black, #D7261E Daylight). Then make accent, accentSounding, accentResting, pulseAccentResting and primary (Stage Black only) come from the chosen color, with the exact values in the spec table, in both themes. Every other token stays the same.
2. **Sort every use of red:** go through every place that uses accent, primary or a literal red today.
   - Destructive actions use `danger`: Delete, Remove, destructive dialog buttons and error text.
   - Everything else follows the color.
   - List both groups in the report.
   - Add a test that fails if any widget uses a literal color instead of a token.
3. **Settings:** add a "Color" row right under Theme, as the spec says: six 40px circles in a 48dp touch target, ring and check on the chosen one, and the heading "Color · <name>".
   - Tapping a circle switches the whole app at once with a ~200ms crossfade, and nothing moves.
   - The choice is saved right away. A missing or unknown saved value loads as Red, and an upgrade keeps Red.
4. **Outside the app:** the lock-screen / notification media cover (media_cover.dart, the tempo ruler with its needle) draws the needle in the chosen color (Stage Black value); after a color change, refresh the cover the next time the media item updates (no need to repost a stopped notification). The status-bar icon stays white (Android draws it one color). The Quick Settings tile is drawn by Android in the system colors: leave it. **The launcher icon stays red**: no icon switching.
5. **Tests:**
   - For each of the six colors, in both themes, the tokens match the spec table.
   - The setting persists, and an unknown value loads as Red.
   - Danger stays red in every color.
   - TalkBack labels ("Color, Blue, selected, 5 of 6").
6. **Emulator screenshots at 115% text, both themes:** Settings with Blue chosen; the main screen playing in Blue, Yellow and Purple; a delete dialog in Green (Delete still red). Save them as docs/design/screens/color-*.png. No phone needed.

Don't release. Write the report, move this file to done/, commit.
