# 13 · Pick mode polish — report

## What changed
- **The list runs down into the bottom row's space.** In pick mode the list now reaches the panel's bottom edge, so more songs show (one or two more, depending on text size) and it scrolls as usual. The panel keeps its size, and the rows don't move when entering or leaving: only the list's bottom edge changes. While pick mode comes and goes, the "+ New song · Share" row fades over the list's bottom; once it's gone, the rows under it take taps.
- **Shorter header lines:** "Export a song" · "Tap a song to send it"; "Click track" · "Tap a song for WAV, MIDI or MP3".
- **Timings** unchanged from build 115 (180ms in, 150ms out, menu fade 90ms), as the spec now says.

## Decisions
- The panel's height is measured when pick mode starts and kept until it has fully left. That's how the list can grow without the panel growing or shrinking. With few songs (the panel shorter than the screen), the panel keeps its size and the extra space under the last row stays empty.
- The bottom row stays in the same place in the layout and is drawn over the list's bottom edge with no height of its own. Moving it into a separate layer broke the accessibility tree (a Flutter assert), so the layout's structure is the same in both modes.
- After you leave pick mode, the list's bottom edge snaps back once the bottom row has faded in. If you scrolled to the very end in pick mode, the last row can end up under the bottom row again (the list stays scrolled to the end).

## Tests
In `test/ui/share_flow_test.dart` (group "pick mode looks like a different list"):
- New: "pick mode: the list runs down into the hidden bottom row's space; the panel and rows stay put". Both modes, 21 songs: the panel's rect doesn't change, the list grows by exactly the bottom row's height, the rows stay put, more rows show, and Cancel puts the list back.
- Changed: "115% text on 360dp": the title and line of both modes take at most two lines each (it used to check that the line wraps), and Cancel still keeps its size.

`flutter analyze` is clean and `flutter test` passes (1782).

## Screenshots
**Not replaced.** Build 116 debug is installed, but a picture-in-picture video from another app was over the bottom right of the phone's screen, where the list's new bottom edge shows. I didn't touch it or the phone. `pick-mode-export-115.png` and `pick-mode-click-115.png` are still the build 115 shots. I can take new ones once the video window is closed.

## For Dror to check
- On build 116, open Songs ⌄ › Share › Export a song…. The list should run to the panel's bottom with no empty block, and the header's line should fit on two lines. Do the same for Export click track….
- With animations on: the bottom row should fade over the list's last rows coming and going, and nothing should jump. Debug builds animate slower than release.
