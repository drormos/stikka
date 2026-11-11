# 12 · Pick mode must look like a different list

Spec: ui-spec.md › Sharing sets and songs › In the Songs list (the pick mode paragraph, rewritten), and Click track export › Way in. Re-read them first.
Reference: docs/design/pick-mode.reference.html (column 2 and 3 = what to build; column 4 was rejected). Motion demo: docs/design/pick-mode-demo.html (open in a browser; it has a "Remove animations" switch).

Problem: after Share › "Export a song…" (or "Export click track…"), the list looks exactly like the normal Songs list (▷ icons, the loaded song highlighted, one plain line on top), so a tester thought the menu had just closed.

1. Header: replace the "Tap the song…" line with the new header in the same 106px space as title + search (so rows don't move): icon badge, title, muted line, outlined Cancel button. Texts and icons per mode as in the spec.
2. Rows: ▷ → the action's icon; no red ▶ / highlight on the loaded song; bottom row hidden.
3. Motion: the tapped menu row becomes the header (move + widen, ~260ms, text crossfade); rest of the menu fades; row icons swap in place with the snap-in / soft brighten after a short delay. Cancel / Back / picking a song reverses it into the Share button. All instant with Remove animations on.
4. Both pick modes use the same widget (title, line, icon as parameters).

Tests: header and rows per mode; rows keep their positions entering and leaving; Back leaves pick mode; reduced motion = instant; layout at 115% on 360dp (title and line wrap, Cancel keeps its size).

Phone: Dror's phone has Remove animations on. Don't change any phone setting. Screenshots (both modes, 115%) into docs/design/screens/ named pick-mode-*-115.png; check the still screens make the mode obvious. Verify the motion in widget tests (frame checks), and say in the report that Dror should judge the motion himself with animations on.
