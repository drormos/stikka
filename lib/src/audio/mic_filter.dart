import 'dart:math' as math;
import 'dart:typed_data';

/// Cleans the microphone stream before pitch detection: a high-pass at
/// 25 Hz (rumble and handling noise, below B0), notches at the mains
/// frequencies (50 and 60 Hz: since the tuner reaches down to B0, hum is in
/// range, and alone or mixed with a fading string it reads as a low wrong
/// note; no bass string is near either, A1 at 55 Hz loses ~1 dB), and a
/// low-pass at 3 kHz (hiss above the harmonics that carry the pitch, so a
/// fading string stays readable longer). Butterworth stages from the RBJ
/// cookbook. The state carries across chunks: feed it the stream in order.
class MicFilter {
  MicFilter(int rate)
    : _stages = [
        _Biquad.highPass(25, rate),
        _Biquad.notch(50, rate),
        _Biquad.notch(60, rate),
        _Biquad.lowPass(3000, rate),
      ];

  final List<_Biquad> _stages;

  /// [chunk] filtered, in a new list.
  Float32List process(Float32List chunk) {
    final out = Float32List.fromList(chunk);
    for (final stage in _stages) {
      stage.run(out);
    }
    return out;
  }
}

class _Biquad {
  _Biquad._(double b0, double b1, double b2, double a0, double a1, double a2)
    : _b0 = b0 / a0,
      _b1 = b1 / a0,
      _b2 = b2 / a0,
      _a1 = a1 / a0,
      _a2 = a2 / a0;

  factory _Biquad.highPass(double hz, int rate) {
    final (c, alpha) = _shape(hz, rate, math.sqrt1_2);
    return _Biquad._(
      (1 + c) / 2,
      -(1 + c),
      (1 + c) / 2,
      1 + alpha,
      -2 * c,
      1 - alpha,
    );
  }

  factory _Biquad.lowPass(double hz, int rate) {
    final (c, alpha) = _shape(hz, rate, math.sqrt1_2);
    return _Biquad._(
      (1 - c) / 2,
      1 - c,
      (1 - c) / 2,
      1 + alpha,
      -2 * c,
      1 - alpha,
    );
  }

  /// Q 10: 5 Hz wide at 50 Hz.
  factory _Biquad.notch(double hz, int rate) {
    final (c, alpha) = _shape(hz, rate, 10);
    return _Biquad._(1, -2 * c, 1, 1 + alpha, -2 * c, 1 - alpha);
  }

  static (double, double) _shape(double hz, int rate, double q) {
    final w = 2 * math.pi * hz / rate;
    return (math.cos(w), math.sin(w) / (2 * q));
  }

  final double _b0, _b1, _b2, _a1, _a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  void run(Float32List samples) {
    for (var i = 0; i < samples.length; i++) {
      final x = samples[i];
      final y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;
      _x2 = _x1;
      _x1 = x;
      _y2 = _y1;
      _y1 = y;
      samples[i] = y;
    }
  }
}
