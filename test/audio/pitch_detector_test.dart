import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stikka/src/audio/pitch_detector.dart';

/// [hz] with [harmonics] (amplitude per partial, the fundamental first),
/// plus a little noise: a stand-in for a plucked string.
Float32List tone(
  double hz,
  int rate,
  int length, {
  List<double> harmonics = const [1],
  double amplitude = 0.3,
  double noise = 0.0,
  int seed = 1,
  int start = 0,
  double decay = 0,
  double drive = 0,
}) {
  final random = math.Random(seed);
  final sum = harmonics.reduce((a, b) => a + b);
  return Float32List.fromList([
    for (var i = 0; i < length; i++)
      () {
        final t = (start + i) / rate;
        var x = 0.0;
        for (var h = 0; h < harmonics.length; h++) {
          // Higher partials die away faster, as on a string.
          x +=
              harmonics[h] *
              math.exp(-decay * (1 + 0.5 * h) * t) *
              math.sin(2 * math.pi * hz * (h + 1) * t);
        }
        x *= amplitude / sum;
        // An amp simulator's soft clipping (tanh), back to the same peak.
        if (drive > 0) x = _tanh(drive * x) / _tanh(drive * amplitude);
        return x + noise * (random.nextDouble() * 2 - 1);
      }(),
  ]);
}

double _tanh(double x) {
  final e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

double cents(double measured, double hz) =>
    1200 * math.log(measured / hz) / math.ln2;

/// The note name of [hz] at A4 = 440, to catch octave errors.
int semitone(double hz) => (12 * math.log(hz / 440) / math.ln2).round();

void main() {
  // Bass strings (5-string B0, E1 A1 D2 G2) and guitar strings.
  const strings = {
    'B0': 30.87,
    'E1': 41.20,
    'A1': 55.0,
    'D2': 73.42,
    'E2': 82.41,
    'G2': 98.0,
    'B3': 246.94,
    'E4': 329.63,
  };

  // Guitar strings E2 A2 D3 G3 B3 E4, the bass's low E (41 Hz is below
  // range; its 2nd harmonic is not what we read), and up to E6.
  const notes = [82.41, 110.0, 146.83, 196.0, 246.94, 329.63, 659.26, 1318.5];

  for (final rate in [48000, 44100]) {
    final detector = PitchDetector(rate);
    group('at $rate Hz', () {
      test('pure tones within 1 cent, E2 to E6', () {
        for (final hz in notes) {
          final got = detector.detect(tone(hz, rate, detector.frameSize));
          expect(got, isNotNull, reason: '$hz');
          expect(cents(got!, hz).abs(), lessThan(1), reason: '$hz → $got');
        }
      });

      test('string-like tones with strong overtones, and noise, stay on '
          'the fundamental within 1 cent', () {
        for (final hz in notes.take(6)) {
          // The 2nd and 3rd partials louder than the fundamental, as on a
          // low string, which tempts an octave error.
          final got = detector.detect(
            tone(
              hz,
              rate,
              detector.frameSize,
              harmonics: [0.5, 1, 0.8, 0.4, 0.3, 0.2],
              noise: 0.01,
            ),
          );
          expect(got, isNotNull, reason: '$hz');
          expect(cents(got!, hz).abs(), lessThan(1), reason: '$hz → $got');
        }
      });

      void expectNote(Float32List frame, String name, double hz) {
        final got = detector.detect(frame);
        expect(got, isNotNull, reason: name);
        expect(semitone(got!), semitone(hz), reason: '$name → $got');
        expect(cents(got, hz).abs(), lessThan(2), reason: '$name → $got');
      }

      test('bass and guitar strings, B0 to E4, within 2 cents', () {
        for (final MapEntry(key: name, value: hz) in strings.entries) {
          expectNote(tone(hz, rate, detector.frameSize), name, hz);
        }
      });

      test('a weak fundamental (strong 2nd and 3rd partials), dying away, '
          'stays on the fundamental', () {
        // A phone's microphone barely hears a bass's fundamental.
        for (final MapEntry(key: name, value: hz) in strings.entries) {
          expectNote(
            tone(
              hz,
              rate,
              detector.frameSize,
              harmonics: [0.15, 1, 0.8, 0.4, 0.3, 0.2],
              decay: hz > 200 ? 3 : 1,
              noise: 0.005,
            ),
            name,
            hz,
          );
        }
      });

      test('the high strings through an amp simulator (soft clipped)', () {
        for (final name in ['B3', 'E4']) {
          final hz = strings[name]!;
          for (final drive in [4.0, 10.0]) {
            expectNote(
              tone(
                hz,
                rate,
                detector.frameSize,
                harmonics: [1, 0.5, 0.3, 0.2],
                decay: 3,
                drive: drive,
                noise: 0.005,
              ),
              '$name drive $drive',
              hz,
            );
          }
        }
      });

      test('a detuned low E reads its offset', () {
        final hz = 82.41 * math.pow(2, 12 / 1200);
        final got = detector.detect(tone(hz, rate, detector.frameSize))!;
        expect(cents(got, 82.41), closeTo(12, 1));
      });

      test('silence and noise read as no pitch', () {
        expect(detector.detect(Float32List(detector.frameSize)), isNull);
        expect(
          detector.detect(
            tone(110, rate, detector.frameSize, amplitude: 0.001),
          ),
          isNull,
          reason: 'below the silence level',
        );
        expect(
          detector.detect(
            tone(110, rate, detector.frameSize, amplitude: 0, noise: 0.2),
          ),
          isNull,
          reason: 'white noise has no clear period',
        );
      });
    });
  }

  test('the frame is ~85 ms, a power of two', () {
    expect(PitchDetector(48000).frameSize, 4096);
    expect(PitchDetector(44100).frameSize, 4096);
  });
}
