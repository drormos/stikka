import 'package:flutter/material.dart';

import 'theme.dart';

/// What a pick mode does (ui-spec.md "Sharing sets and songs" › In the
/// Songs list): its header's title, the muted line under it, and the icon
/// on the header and on every row.
enum PickAction {
  exportSong('Export a song', 'Tap one to send it to another Stikka user'),
  clickTrack('Click track', 'Tap one to export it as WAV, MIDI or MP3');

  const PickAction(this.title, this.line);

  final String title;
  final String line;

  Widget icon({required double size, required Color color}) => switch (this) {
    exportSong => Icon(Icons.share_outlined, size: size, color: color),
    clickTrack => WaveformIcon(size: size, color: color),
  };
}

/// Pick mode's header, in place of the list's search: a round badge with
/// the action's icon, the action as the title with a muted line under it,
/// and an outlined Cancel (pick-mode.reference.html, option A). Title and
/// line wrap at large text; Cancel keeps its size.
class PickHeader extends StatelessWidget {
  const PickHeader({
    super.key,
    required this.action,
    this.onCancel,
    this.cancelKey,
  });

  final PickAction action;
  final VoidCallback? onCancel;
  final Key? cancelKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border, width: 2)),
      ),
      child: Padding(
        // Cancel's 48px touch area sets the height: no taller than the
        // search it covers, so the rows don't move.
        padding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceOnSheet,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: action.icon(size: 18, color: colors.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    action.line,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              key: cancelKey,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.text,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                side: BorderSide(color: colors.controlOutline, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: onCancel,
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five bars of different heights (the click track's icon), drawn like
/// the reference's 24px stroke icon.
class WaveformIcon extends StatelessWidget {
  const WaveformIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _Waveform(color));
}

class _Waveform extends CustomPainter {
  _Waveform(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // M3 12h2 M7 8v8 M11 4v16 M15 8v8 M19 10v4
    canvas
      ..drawLine(const Offset(3, 12), const Offset(5, 12), paint)
      ..drawLine(const Offset(7, 8), const Offset(7, 16), paint)
      ..drawLine(const Offset(11, 4), const Offset(11, 20), paint)
      ..drawLine(const Offset(15, 8), const Offset(15, 16), paint)
      ..drawLine(const Offset(19, 10), const Offset(19, 14), paint);
  }

  @override
  bool shouldRepaint(_Waveform old) => old.color != color;
}
