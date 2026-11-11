# 12 · Pick mode must look like a different list — report

## What changed
- **Header.** After Share › "Export a song…" or "Export click track…", the search's place shows a header: a round badge with the action's icon (share / waveform), the title ("Export a song" / "Click track"), the muted line under it, and an outlined Cancel (2px, 40px). Background #1A1A1A with a 2px #2E2E2E line under it, all from theme tokens.
- **Rows.** Every ▷ becomes the action's icon (white, 20px). The loaded song loses its red ▶ and highlight. Name, tempo and time signature stay where they were.
- **Bottom row** (+ New song, Share) is hidden but keeps its space, so the panel doesn't change size.
- **One widget for both modes:** `PickHeader` with a `PickAction` (title, line, icon) in `lib/src/ui/pick_header.dart`.
- **Motion** (animations on): the tapped menu row moves and widens into the header over 260ms (the demo's ease), its text crossfading into the header's; the rest of the menu fades over 120ms; the row icons swap in place from ~80ms on and brighten. Cancel, Back or a pick reverses it: the header shrinks back into Share over 220ms and the ▷ icons return. With Remove animations on it is all instant.
- Back still leaves pick mode first; a second Back closes the panel.

## Decisions
- **Header height.** The spec says "in the same 106px space as title + search", but the app's Songs list has no title line, only the search (when there are more than 8 songs). So the header covers the search's space. At normal text size it fits that space exactly, so the rows don't move (tested frame by frame). At 115% the title and line wrap and the header is taller than the search, so the rows move down by that much (as in the reference's 115% column). With 8 songs or fewer there is no search, so the header's height opens smoothly with the motion and the rows below move down.
- Cancel keeps a 48px touch area (accessibility), drawn 40px tall.
- The waveform icon is drawn from the reference's SVG (no matching Material icon).

## Tests
`test/ui/share_flow_test.dart`, group "pick mode looks like a different list" (real Saira font loaded): header and rows per mode, hidden bottom row, no "playing"; rows keep their positions every frame entering and leaving; the flight starts on the menu row, ends on the header, and shrinks into Share; the icons swap 48–112ms in; Remove animations = instant; 115% text on 360dp: title and line wrap, Cancel stays one line and ≥40px, no overflow. The older Songs-list share tests now check the new header. `flutter analyze` and `flutter test` (1780) pass.

## Screenshots (phone, 115% text, Remove animations on; build 113 debug)
- `docs/design/screens/pick-mode-export-115.png`
- `docs/design/screens/pick-mode-click-115.png`

The still screens make the mode clear: the header with its badge and Cancel, and the share / waveform icon on every row, no red ▶. Back from pick mode returned to the normal list (▷, red ▶ on the loaded song, search, New song · Share).

## For Dror to check
- **The motion, with animations on.** Your phone has Remove animations on, so I only checked it in widget tests (frame checks). Please judge it yourself with animations on: the menu row flying into the header, and back into Share.
- The hidden bottom row leaves an empty strip under the list in pick mode (it keeps its space so nothing jumps). Say if the designer wants something else there.
- No phone settings were changed. The debug app is now in Songs mode (I tapped the Songs tab to open the list).

## Follow-up: tapping outside in pick mode (asked by Dror, spec "Leaving it")
- In both pick modes, a tap outside the panel now does what Cancel does: the header shrinks back into Share and the normal Songs list returns. A second tap outside closes the panel as usual. Dragging the panel down still closes it completely. The sets view and the song picker still close on a tap outside.
- How: the list's outside area (`CloseOnTouch`) now asks the panel first (`stepBack`); only the Songs list in pick mode takes the touch.
- Test: "a tap outside steps back to the list like Cancel (both modes); a second one closes; dragging down closes from pick mode" in `test/ui/share_flow_test.dart`. `flutter analyze` and `flutter test` (1781) pass.
- Phone: build 114 debug is installed but **not checked**. The notification shade came up while I was tapping, so I stopped. Some taps landed in the app in Free play (it opened "When I press Start"); I can't rule out that one landed in the shade. Please check: Songs ⌄ › Share › Export a song…, then tap the dim area above the list. It should go back to the Songs list, and a second tap should close it.
