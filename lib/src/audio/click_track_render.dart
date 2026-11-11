import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import '../model/click_sound.dart';
import '../model/click_track.dart';
import '../model/click_volumes.dart';
import '../model/metronome_pattern.dart';
import 'click_output.dart';
import 'click_scheduler.dart';
import 'mp3_encoder.dart';
import 'soloud_click_output.dart';

/// One sound of a click track: [at] seconds from beat 1, the accent or
/// normal sample, at [gain], played at [speed] (a raised accent, a
/// polyrhythm pulse), as `SoloudClickOutput` plays it.
typedef TrackClick = ({double at, bool accent, double gain, double speed});

/// Every click of [track] and where it ends (its last bar line), in
/// seconds from beat 1: the real [ClickScheduler] plays the track's plan
/// against a recording output, so the file has live playback's timing.
Future<({List<TrackClick> clicks, double end})> clickTrackEvents(
  ClickTrack track, {
  required ClickVolumes volumes,
  bool raisePartChanges = false,
}) async {
  final out = _Recorder(volumes);
  final plan = track.plan..raisesPartChanges = raisePartChanges;
  final first = track.parts[track.locate(0).part];
  // Everything up to the end in one refill.
  final scheduler = ClickScheduler(out, lookahead: const Duration(days: 1));
  await scheduler.start(
    bpm: first.tempoAtBeat(0),
    pattern: first.pattern,
    run: plan,
  );
  final end = scheduler.endAt, start = scheduler.runStart;
  scheduler.stop();
  if (end == null || start == null) {
    throw StateError('The click track has no end');
  }
  double seconds(Duration d) => (d - start).inMicroseconds / 1e6;
  final clicks = [
    for (final c in out.clicks)
      (at: seconds(c.at), accent: c.accent, gain: c.gain, speed: c.speed),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return (clicks: clicks, end: seconds(end));
}

class _Recorder implements ClickOutput {
  _Recorder(this._volumes);

  final ClickVolumes _volumes;
  final clicks = <({Duration at, bool accent, double gain, double speed})>[];

  @override
  Duration now() => Duration.zero;

  @override
  Future<void> prepare() async {}

  @override
  void release() {}

  @override
  ClickHandle schedule(StepLevel level, Duration at, {bool raised = false}) {
    final click = raised
        ? (
            at: at,
            accent: true,
            gain: _volumes.accent,
            speed: SoloudClickOutput.partChangeSpeed,
          )
        : (
            at: at,
            accent: level == StepLevel.accent,
            gain: _volumes.forLevel(level),
            speed: 1.0,
          );
    clicks.add(click);
    return click;
  }

  @override
  ClickHandle schedulePulse(StepLevel level, Duration at) {
    final accent = level == StepLevel.accent;
    final click = (
      at: at,
      accent: accent,
      gain: _volumes.polyrhythm * (accent ? 1 : 0.75),
      speed: SoloudClickOutput.pulseSpeed,
    );
    clicks.add(click);
    return click;
  }

  // Nothing is cancelled in one pass to the end.
  @override
  void cancel(ClickHandle handle) {}

  @override
  set sound(ClickSound value) {}

  @override
  set volumes(ClickVolumes value) {}

  @override
  void preview() {}

  @override
  Stream<void> get deviceFailures => const Stream.empty();

  @override
  Future<void> recover() async {}
}

/// A click sound's two samples (−1…1) at [rate].
typedef ClickSamples = ({Float32List accent, Float32List normal, int rate});

/// The samples in a 16-bit mono PCM WAV (the `assets/clicks/` files).
({Float32List samples, int rate}) readWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var rate = 0;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, at, at + 4);
    final size = data.getUint32(at + 4, Endian.little);
    if (id == 'fmt ') rate = data.getUint32(at + 12, Endian.little);
    if (id == 'data') {
      final n = min(size, bytes.length - at - 8) ~/ 2;
      return (
        samples: Float32List.fromList([
          for (var i = 0; i < n; i++)
            data.getInt16(at + 8 + 2 * i, Endian.little) / 32768,
        ]),
        rate: rate,
      );
    }
    at += 8 + size + (size & 1);
  }
  throw const FormatException('No data in the WAV');
}

/// Mixes clicks into PCM a block at a time (from sample 0, at
/// [exportSampleRate]), through a look-ahead limiter like the live one
/// (ceiling −0.1 dB, 1 ms look-ahead, 50 ms release) but without its
/// delay, so the first click stays at sample 0.
class ClickMixer {
  ClickMixer(this.clicks, this.samples, {required this.length})
    : _maxLength = [
        for (final c in clicks)
          (_sample(samples, c.accent).length *
                  exportSampleRate /
                  samples.rate /
                  c.speed)
              .ceil(),
      ].fold(0, max);

  final List<TrackClick> clicks;
  final ClickSamples samples;

  /// Samples in all.
  final int length;

  final int _maxLength;
  int _first = 0;
  int _at = 0;
  double _gain = 1;

  static const _lookahead = exportSampleRate ~/ 1000;
  static final _ceiling = pow(10, -0.1 / 20).toDouble();
  static final _release = exp(-1 / (0.05 * exportSampleRate));

  static Float32List _sample(ClickSamples s, bool accent) =>
      accent ? s.accent : s.normal;

  bool get done => _at >= length;

  /// The next [count] samples (fewer at the end).
  Float32List next(int count) {
    final n = min(count, length - _at);
    final mix = Float32List(n + _lookahead);
    final from = _at, to = _at + mix.length;
    while (_first < clicks.length &&
        clicks[_first].at * exportSampleRate + _maxLength < from) {
      _first++;
    }
    for (var i = _first; i < clicks.length; i++) {
      final c = clicks[i];
      final onset = c.at * exportSampleRate;
      if (onset >= to) break;
      final src = _sample(samples, c.accent);
      final step = samples.rate / exportSampleRate * c.speed;
      final last = src.length - 1;
      for (var t = max(from, onset.ceil()); t < to; t++) {
        final p = (t - onset) * step;
        if (p >= last) break;
        final k = p.floor();
        mix[t - from] += (src[k] + (src[k + 1] - src[k]) * (p - k)) * c.gain;
      }
    }
    // Overs in reach: gain ramps down over the look-ahead to meet each.
    final overs = <(int, double)>[
      for (var i = 0; i < mix.length; i++)
        if (mix[i].abs() > _ceiling) (i, _ceiling / mix[i].abs()),
    ];
    final out = Float32List(n);
    var o = 0;
    for (var i = 0; i < n; i++) {
      _gain = 1 - (1 - _gain) * _release;
      while (o < overs.length && overs[o].$1 < i) {
        o++;
      }
      for (var j = o; j < overs.length && overs[j].$1 <= i + _lookahead; j++) {
        final (at, need) = overs[j];
        final g = need + (1 - need) * (at - i) / _lookahead;
        if (g < _gain) _gain = g;
      }
      out[i] = mix[i] * _gain;
    }
    _at += n;
    return out;
  }
}

/// A 16-bit mono WAV header for [samples] samples.
Uint8List wavHeader(int samples, {int rate = exportSampleRate}) {
  final h = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      h.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  h.setUint32(4, 36 + samples * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  h
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  tag(36, 'data');
  h.setUint32(40, samples * 2, Endian.little);
  return h.buffer.asUint8List();
}

Uint8List _pcm16(Float32List block) {
  final out = ByteData(block.length * 2);
  for (var i = 0; i < block.length; i++) {
    out.setInt16(
      i * 2,
      (block[i] * 32767).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  return out.buffer.asUint8List();
}

/// What the render isolate gets.
typedef _Job = ({
  SendPort port,
  String path,
  bool mp3,
  List<TrackClick> clicks,
  ClickSamples samples,
  int length,
  String? lamePath,
});

/// Writes [clicks] as a WAV or MP3 at [path] in a background isolate,
/// reporting progress (0–1). Cancelling kills it and deletes the file.
class AudioRender {
  AudioRender._(this._isolate, this.done);

  static Future<AudioRender> start({
    required String path,
    required ExportFormat format,
    required List<TrackClick> clicks,
    required double end,
    required ClickSamples samples,
    void Function(double progress)? onProgress,
  }) async {
    final port = ReceivePort();
    final done = Completer<void>();
    final isolate = await Isolate.spawn<_Job>(_render, (
      port: port.sendPort,
      path: path,
      mp3: format == ExportFormat.mp3,
      clicks: clicks,
      samples: samples,
      length: (end * exportSampleRate).round(),
      lamePath: Mp3Encoder.libraryPath,
    ));
    port.listen((message) {
      if (message is double) {
        onProgress?.call(message);
      } else {
        port.close();
        if (done.isCompleted) return;
        message == null
            ? done.complete()
            : done.completeError(StateError('$message'));
      }
    });
    isolate.addOnExitListener(port.sendPort, response: 'exited');
    return AudioRender._(isolate, done.future).._path = path;
  }

  final Isolate _isolate;

  /// Completes when the file is written; errors if it couldn't be.
  final Future<void> done;
  late final String _path;

  /// Stops and deletes the half-made file.
  Future<void> cancel() async {
    done.ignore(); // ends with "exited"
    _isolate.kill(priority: Isolate.immediate);
    try {
      await File(_path).delete();
    } on FileSystemException {
      // Never created.
    }
  }

  static void _render(_Job job) {
    Mp3Encoder? mp3;
    RandomAccessFile? file;
    try {
      Mp3Encoder.libraryPath = job.lamePath;
      file = File(job.path).openSync(mode: FileMode.write);
      if (job.mp3) {
        mp3 = Mp3Encoder.open(
          sampleRate: exportSampleRate,
          bitRate: mp3BitRate,
        );
        if (mp3 == null) throw StateError('No MP3 encoder');
      } else {
        file.writeFromSync(wavHeader(job.length));
      }
      final mixer = ClickMixer(job.clicks, job.samples, length: job.length);
      var reported = -1.0;
      while (!mixer.done) {
        final block = mixer.next(exportSampleRate ~/ 4);
        file.writeFromSync(mp3 == null ? _pcm16(block) : mp3.encode(block));
        final progress = mixer._at / job.length;
        if (progress - reported >= 0.01) {
          job.port.send(reported = progress);
        }
      }
      if (mp3 != null) {
        file.writeFromSync(mp3.flush());
        final tag = mp3.tag();
        if (tag.isNotEmpty) {
          file
            ..setPositionSync(0)
            ..writeFromSync(tag);
        }
      }
      file.closeSync();
      file = null;
      job.port.send(null);
    } catch (e) {
      try {
        file?.closeSync();
        File(job.path).deleteSync();
      } on Object {
        // Best effort.
      }
      job.port.send('$e');
    } finally {
      mp3?.close();
    }
  }
}
