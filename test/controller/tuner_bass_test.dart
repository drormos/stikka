import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stikka/src/audio/mic_input.dart';
import 'package:stikka/src/controller/tuner_controller.dart';

import '../audio/fake_mic_input.dart';
import 'tuner_guitar_test.dart' show pluck;

/// The tester's report (handoff 10): a bass's E, A and D showed no note,
/// and a guitar's high strings were slow to lock on. Through the real
/// controller, at 48 kHz, in 1024-sample chunks like `MicBridge.kt`.
void main() {
  late FakeMicInput mic;
  late TunerController tuner;

  setUp(() async {
    mic = FakeMicInput(state: MicPermission.granted);
    tuner = TunerController(mic, referenceA4: () => 440);
    await tuner.open();
  });

  tearDown(() => tuner.dispose());

  String? shown() {
    final note = tuner.note;
    return note == null
        ? null
        : '${note.name}${note.sharp ? '#' : ''}${note.octave}';
  }

  /// Plays [samples] and returns how long until [name] showed and stayed
  /// to the end, or null if it never settled.
  Duration? lockTime(Float32List samples, String name) {
    int? since;
    for (var i = 0; i < samples.length; i += 1024) {
      final end = math.min(i + 1024, samples.length);
      mic.push(Float32List.sublistView(samples, i, end));
      if (shown() == name) {
        since ??= end;
      } else {
        since = null;
      }
    }
    return since == null ? null : Duration(microseconds: since * 1000 ~/ 48);
  }

  const bass = {'B0': 30.87, 'E1': 41.20, 'A1': 55.0, 'D2': 73.42, 'G2': 98.0};
  const quarterSecond = Duration(milliseconds: 250);

  for (final MapEntry(key: name, value: hz) in bass.entries) {
    test('bass $name plucked, with hum and noise, shows within 0.25 s '
        'and within 2 cents', () {
      final samples = pluck(hz, 1, seed: name.hashCode);
      expect(
        lockTime(Float32List.sublistView(samples, 0, 12000), name),
        lessThanOrEqualTo(quarterSecond),
      );
      mic.push(Float32List.sublistView(samples, 12000));
      expect(shown(), name);
      expect(tuner.note!.cents, closeTo(0, 2));
    });
  }

  // Tuning string by string leaves the last one ringing, a fourth (or a
  // third) below. Before this fix bass D over a ringing A showed nothing,
  // and B3 over a ringing G3 settled on their common period, G1.
  for (final (from, to, name) in [
    (41.20, 55.0, 'A1'),
    (55.0, 73.42, 'D2'),
    (73.42, 98.0, 'G2'),
    (82.41, 110.0, 'A2'),
    (146.83, 196.0, 'G3'),
    (196.0, 246.94, 'B3'),
    (246.94, 329.63, 'E4'),
  ]) {
    test('$name over the string below it, still ringing, locks on within '
        '0.25 s and holds', () {
      // Longer than the 1 s hold, so an early reading can't hide a blank.
      // Later, once the new string has died down to the old one's level,
      // the two can repeat at a common lower period (G3 with D3 at G1):
      // a known limit, not checked (blanking those blanked real notes).
      final last = pluck(from, 3, seed: 5);
      final next = pluck(to, 2, seed: 9, hum: 0, noise: 0);
      // A second of the last string first, as when tuning.
      mic.push(Float32List.sublistView(last, 0, 48000));
      for (var i = 0; i < 60000; i += 1024) {
        final end = math.min(i + 1024, 60000);
        mic.push(
          Float32List.fromList([
            for (var j = i; j < end; j++) last[48000 + j] + next[j],
          ]),
        );
        if (end >= 12000) {
          expect(shown(), name, reason: '${end * 1000 ~/ 48000} ms');
        }
      }
    });
  }

  // From the moment the tuner opens. A hum that starts later leaks through
  // for ~0.1 s while the notch settles.
  test('mains hum alone (50 or 60 Hz) is not a note', () async {
    final random = math.Random(1);
    for (final mains in [50.0, 60.0]) {
      tuner.dispose();
      mic = FakeMicInput(state: MicPermission.granted);
      tuner = TunerController(mic, referenceA4: () => 440);
      await tuner.open();
      final hum = Float32List.fromList([
        for (var i = 0; i < 48000; i++)
          0.02 * math.sin(2 * math.pi * mains * i / 48000) +
              0.004 * (random.nextDouble() * 2 - 1),
      ]);
      for (var i = 0; i < hum.length; i += 1024) {
        mic.push(Float32List.sublistView(hum, i, math.min(i + 1024, 48000)));
        expect(shown(), isNull, reason: '$mains Hz at $i');
      }
    }
  });
}
