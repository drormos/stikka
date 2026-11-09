# 08 · Accent color in Settings: report

Not released (ships with the next release). `flutter analyze` is clean and `flutter test` passes (1723 tests). The emulator hung (its System UI stopped responding), so I took the screenshots on Dror's phone in the debug app (Stikka dev), with the phone's own text size, which is already 115%. I only touched Stikka dev and set it back to System and Red at the end.

## What changed
1. **Tokens.**
   - New `danger` token: #FF3B30 Stage Black, #D7261E Daylight.
   - The chosen color sets accent, accent sounding, accent resting and pulse accent resting in both themes, plus primary in Stage Black, with the spec table's values.
   - Daylight's primary button stays #111111 in every color. Every other token is unchanged.
2. **Every use of red, sorted.**
   - **Danger (red in every color):**
     - the "Delete …?" / "Discard changes …?" dialog's filled button
     - the swipe-to-remove / delete background behind a row
     - Free play's leave dialog "Discard"
     - error text: the main screen's notices ("Audio problem", library problem, save failed), the Save as new / song editor name field's error text and outline, and the theme's `error` color
     - the old multi-select bar's red action (not shown anywhere today)
   - **Follows the color:**
     - tempo needle (ruler and song map)
     - beat blocks (accent resting / sounding), polyrhythm accent cells, accent beats on the parts page
     - Start / Stop and Save (the primary button) in Stage Black
     - current-song marker and checkmarks
     - the selected mode tab's line
     - lit top-row buttons
     - the What's new dot on the gear
     - the tuner's needle
     - Save as new's checkboxes
     - selected text / handles
     - the lock-screen cover's needle
   - Colors still come only from the theme file. The existing guard test (fails on any color written in a widget) now also catches `Color.fromARGB` / `Color.fromRGBO`.
3. **Settings › Color** sits right under Theme.
   - The heading is "Color · Red" (muted "Color", the name in the text color).
   - Six 40px circles, Red to Purple, sit in 48dp touch targets, spread across the width. The chosen one has a 2px ring in the text color with a 3px gap, and a black check.
   - A tap switches the whole app with a 200 ms color crossfade, and nothing moves. With "Remove animations" on, it switches at once. A tap on the chosen one does nothing.
   - The choice is saved at once. A missing or unknown value loads as Red, and an upgrade keeps Red.
   - TalkBack reads "Color, Blue, selected, 5 of 6", and "Color, Red, 1 of 6" for the others.
4. **Outside the main screens.**
   - The lock-screen / notification media cover (`media_cover.dart`) draws its tempo needle in the chosen color. It uses the Stage Black value, since the cover is always black.
   - The cover is refreshed at the next media-item update. A color change itself triggers one, so the card shows the new needle right away. Cover files are named per tempo and color, so the system never shows a cached red one.
   - This matches the later spec addition (Theme › Color › "Outside the app"): it was already built when that came in.
   - The status-bar icon and the Quick Settings tile are white system icons with no accent, so they're unchanged.
   - The launcher icon stays red; no icon switching.
5. **Tests:**
   - All six colors in both themes match the table, and every other token stays the same.
   - Red equals today's palette.
   - Danger is red in every color.
   - A delete dialog in Green has a red Delete.
   - Colors crossfade, and a theme switch still snaps.
   - The setting saves and reloads, an unknown value loads as Red, and an old file (version 10) loads as Red.
   - The Settings row: placement, one row, 48dp targets, TalkBack labels.
   - The cover: a rendered Blue cover has a Blue needle and no red one; Red still has red. A color change asks for a new cover and shows it (`metronome_audio_handler_test`). File names include the color.

## Decisions
- **`dangerResting` token** (#8E2620 / #E9B0AA, today's red accent resting). The swipe-to-delete background is a softer red before it's armed. Without this token it would have followed the color, so I kept it red with today's exact values. It isn't in the spec table.
- **Swatch colors:** each circle shows that color's accent in the current theme (Stage Black values in dark, Daylight values in light), so you see what you'll get.
- **320dp phones:** six 48dp targets don't fit in 272dp. There, each target narrows to about 45dp, so the circles stay one row as the spec asks. From about 336dp of row width up, they're full 48dp.
- **Saved format 11:** settings gain `accentColor` (`red`).
- **The crossfade** is Flutter's own theme animation (200 ms). Only the accent tokens fade, and switching between dark and light still snaps as before.

## Screenshots (phone, 115% text)
In `docs/design/screens/` (the phone's side dots are cropped off):
- `color-settings-blue-dark-115.png`, `color-settings-blue-light-115.png`: Settings with Blue chosen.
- `color-main-blue-*-115.png`, `color-main-yellow-*-115.png`, `color-main-purple-*-115.png` (dark and light): the main screen playing.
- `color-delete-green-dark-115.png`, `color-delete-green-light-115.png`: "Delete Copper Sky?" in Green, Delete still red, and the red swipe background behind it.
- `color-cover-blue.png`: the media cover at 120 bpm in Blue, rendered by the cover test (`STIKKA_COVER_OUT_blue=<path> flutter test test/ui/media_cover_test.dart`). It's the image itself, not a lock-screen screenshot: the lock screen is the phone's own UI, which I don't drive.

## For Dror / the designer to check
- **Black check on Daylight swatches.** The spec asks for a black check. On Daylight's darker Blue (#0A62C4) and Purple (#8A3CB8), black is only about 3.5:1. That passes the 3:1 minimum for icons but looks dim on the phone (see `color-settings-blue-light-115.png`). Should Daylight use a light check?
- **Daylight Start / Stop stays black**, as the spec says. Dror asked about this; it's by design.
- Device check: none needed beyond this. The phone screenshots cover both themes, and the upgrade from version 10 kept Red on the phone.
