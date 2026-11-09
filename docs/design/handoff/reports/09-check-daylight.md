# 09 · Color swatches: white check in Daylight: report

Not released (the release build comes right after this, as Dror asked). `flutter analyze` is clean and `flutter test` passes (1725 tests). I checked it on Dror's phone in Stikka dev, at the phone's 115% text, and set it back to System and Red afterwards.

## What changed
1. The check inside the chosen circle is white (#FFFFFF) in Daylight for all six colors. It stays black in Stage Black.
2. Test: for each theme, I tap all six circles in turn and check the check's color (black in Stage Black, white in Daylight).

`dangerResting` was already built in 08 with the values the spec now lists (#8E2620 / #E9B0AA), so nothing changed there.

## Decisions
- The check color is one theme-file function of the theme (`SwatchColors.check`), not a new color token: only this check uses it.

## Screenshots (phone, 115% text)
- `docs/design/screens/color-settings-blue-light-115.png` (replaced): Settings in Daylight with Blue chosen and the white check. The phone's side dots are cropped off.

## For Dror to check
None needed.
