import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stikka/src/audio/click_track_render.dart';
import 'package:stikka/src/audio/mp3_encoder.dart';
import 'package:stikka/src/model/click_track.dart';
import 'package:stikka/src/model/click_volumes.dart';
import 'package:stikka/src/model/metronome_pattern.dart';
import 'package:stikka/src/model/midi_file.dart';
import 'package:stikka/src/model/song_part.dart';

SongPart part(
  String name,
  int bars,
  int bpm, {
  int? to,
  int beats = 4,
  int unit = 4,
  int sub = 1,
  int poly = 0,
}) {
  var pattern = MetronomePattern.simple(
    beatsPerBar: beats,
    stepsPerBeat: sub,
    beatUnit: unit,
  );
  if (poly > 0) pattern = pattern.withPolyrhythm(poly);
  return SongPart(
    id: name,
    name: name,
    bars: bars,
    tempoStart: bpm,
    tempoEnd: to ?? bpm,
    pattern: pattern,
  );
}

/// 4/4 → 2/4 → 7/8 (in eighths, with 16ths) → a Gradual 4/4 ramp.
final song = [
  part('Intro', 2, 120),
  part('Verse', 2, 128, beats: 2),
  part('Bridge', 2, 140, beats: 7, unit: 8, sub: 2),
  part('Chorus', 3, 128, to: 140),
];

/// Every sounding step's time, worked out beat by beat; and the end.
({List<double> times, double end}) expected(List<SongPart> parts) {
  final times = <double>[];
  var t = 0.0;
  for (final p in parts) {
    final pattern = p.pattern;
    for (var bar = 0; bar < p.bars; bar++) {
      for (var beat = 0; beat < pattern.beatsPerBar; beat++) {
        final d = 60 / p.tempoAtBeat(bar * pattern.beatsPerBar + beat);
        for (var s = 0; s < pattern.stepsPerBeat; s++) {
          final level = pattern.steps[beat * pattern.stepsPerBeat + s];
          if (level != StepLevel.silent) {
            times.add(t + s * d / pattern.stepsPerBeat);
          }
        }
        t += d;
      }
    }
  }
  return (times: times, end: t);
}

ClickSamples woodblock() {
  final accent = readWav(
    File('assets/clicks/woodblock_accent.wav').readAsBytesSync(),
  );
  final normal = readWav(
    File('assets/clicks/woodblock_normal.wav').readAsBytesSync(),
  );
  return (accent: accent.samples, normal: normal.samples, rate: accent.rate);
}

/// Where each click starts: the first sample above silence after a gap.
List<int> onsets(Int16List pcm) {
  final found = <int>[];
  var quiet = 1 << 30;
  for (var i = 0; i < pcm.length; i++) {
    if (pcm[i].abs() > 2) {
      if (quiet > 200) found.add(i);
      quiet = 0;
    } else {
      quiet++;
    }
  }
  return found;
}

void main() {
  const sr = exportSampleRate;
  final track = ClickTrack.of('Glass Harbor', song, SongEnd.loopLastPart);
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('click-export'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the scheduler plays each step where the parts put it', () async {
    final events = await clickTrackEvents(
      track,
      volumes: ClickVolumes.defaults,
    );
    final want = expected(song);
    expect(events.end, closeTo(want.end, 1 / sr));
    expect(events.clicks.length, want.times.length);
    for (var i = 0; i < want.times.length; i++) {
      expect(events.clicks[i].at, closeTo(want.times[i], 1 / sr), reason: '$i');
    }
    expect(events.clicks.first.at, 0);
  });

  test('WAV: clicks within a sample, first at 0, ends at the last bar '
      'line', () async {
    final events = await clickTrackEvents(
      track,
      volumes: ClickVolumes.defaults,
    );
    final path = '${dir.path}/t.wav';
    final render = await AudioRender.start(
      path: path,
      format: ExportFormat.wav,
      clicks: events.clicks,
      end: events.end,
      samples: woodblock(),
    );
    await render.done;
    final bytes = File(path).readAsBytesSync();
    final want = expected(song);
    final length = (want.end * sr).round();
    expect(bytes.length, 44 + 2 * length);
    expect(bytes.length, estimatedSize(ExportFormat.wav, track.seconds));
    final h = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes, 0, 4), 'RIFF');
    expect(h.getUint32(24, Endian.little), sr);
    expect(h.getUint16(22, Endian.little), 1);
    expect(h.getUint16(34, Endian.little), 16);
    final pcm = Int16List.sublistView(Uint8List.fromList(bytes.sublist(44)));
    expect(pcm[0], isNot(0));
    final found = onsets(pcm);
    expect(found.length, want.times.length);
    for (var i = 0; i < found.length; i++) {
      expect(
        (found[i] - want.times[i] * sr).abs(),
        lessThanOrEqualTo(1),
        reason: 'click $i',
      );
    }
    // A single click peaks at −0.5 dBFS, never clipped.
    expect(
      pcm.reduce((a, b) => a.abs() > b.abs() ? a : b).abs(),
      lessThan(32767),
    );
  });

  test('overlaps go through the limiter: under the ceiling', () {
    final clicks = <TrackClick>[
      (at: 0, accent: true, gain: 1, speed: 1),
      (at: 0, accent: true, gain: 1, speed: 1.5),
      (at: 0, accent: false, gain: 1, speed: 1),
    ];
    final mixer = ClickMixer(clicks, woodblock(), length: sr ~/ 10);
    final out = mixer.next(sr);
    final peak = out.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
    expect(peak, lessThanOrEqualTo(0.9886));
    expect(peak, greaterThan(0.9));
  });

  test('MIDI: tempo map, time signatures, markers and notes line up with '
      'the audio', () async {
    final midi = readMidi(clickTrackMidi(track, ClickVolumes.defaults));
    expect(midi.format, 1);
    expect(midi.ppq, 960);
    expect(midi.signatures, [
      (0, '4/4'),
      (960 * 8, '2/4'),
      (960 * 12, '7/8'),
      (960 * 12 + 480 * 14, '4/4'),
    ]);
    expect(midi.markers.map((m) => m.$2), [
      'Intro',
      'Verse',
      'Bridge',
      'Chorus',
    ]);
    final chorusTick = 960 * 12 + 480 * 14;
    expect(midi.markers.last.$1, chorusTick);
    // 7/8 at 140 counts eighths: a quarter is two of them.
    expect(midi.tempoAt(960 * 12), (60e6 / 140 * 2).round());
    // Gradual: a tempo point on every beat of the Chorus (12 beats).
    expect(midi.tempos.where((t) => t.$1 >= chorusTick).length, 12);

    final events = await clickTrackEvents(
      track,
      volumes: ClickVolumes.defaults,
    );
    final times = [for (final n in midi.notes) midi.seconds(n.tick)];
    expect(times.length, events.clicks.length);
    for (var i = 0; i < times.length; i++) {
      expect(times[i], closeTo(events.clicks[i].at, 1 / sr), reason: '$i');
    }
    expect(midi.seconds(midi.end), closeTo(events.end, 1 / sr));
    expect(midi.notes.first.key, ClickNotes.accent);
    expect(midi.notes.first.velocity, 127);
    expect(midi.notes[1].key, ClickNotes.beat);
    expect(midi.notes[1].velocity, (0.8 * 127).round());
    // The Bridge's 16ths: subdivision notes.
    expect(midi.notes.where((n) => n.key == ClickNotes.subdivision).length, 14);
  });

  test('MIDI: polyrhythm pulses and no notes for silent steps', () {
    // Beat 2: normal → accent → silent.
    final p = part('Groove', 1, 120, poly: 3).pattern.cycleBeat(1).cycleBeat(1);
    final t = ClickTrack.of('P', [
      SongPart.steady(id: 'a', name: 'A', bars: 1, bpm: 120, pattern: p),
    ], SongEnd.stop);
    final midi = readMidi(clickTrackMidi(t, ClickVolumes.defaults));
    // Beats 1, 3, 4 (beat 2 silent) and 3 pulses.
    expect(midi.notes.where((n) => n.key != ClickNotes.polyrhythm).length, 3);
    expect(
      [
        for (final n in midi.notes.where((n) => n.key == ClickNotes.polyrhythm))
          n.tick,
      ],
      [0, 1280, 2560],
    );
  });

  test('MP3: 48 kHz mono CBR with the LAME tag', () async {
    final events = await clickTrackEvents(
      track,
      volumes: ClickVolumes.defaults,
    );
    final path = '${dir.path}/t.mp3';
    final render = await AudioRender.start(
      path: path,
      format: ExportFormat.mp3,
      clicks: events.clicks,
      end: events.end,
      samples: woodblock(),
    );
    await render.done;
    final bytes = File(path).readAsBytesSync();
    // Frame sync, MPEG-1 layer III, 160 kbps, 48 kHz, mono.
    expect(bytes[0], 0xFF);
    expect(bytes[1] & 0xFE, 0xFA);
    expect(bytes[2] >> 4, 0xA); // 160 kbps
    expect(bytes[2] >> 2 & 3, 1); // 48 kHz
    expect(bytes[3] >> 6, 3); // mono
    final head = String.fromCharCodes(bytes.sublist(0, 480));
    expect(head, contains('Info'));
    expect(head, contains('LAME'));
    expect(
      bytes.length,
      closeTo(estimatedSize(ExportFormat.mp3, track.seconds), 960),
    );
  }, skip: _lame() ? false : 'no desktop LAME (brew install lame)');

  test('cancel deletes the half-made file', () async {
    final long = ClickTrack.of('L', [part('Part 1', 1, 120)], SongEnd.loopSong);
    final events = await clickTrackEvents(long, volumes: ClickVolumes.defaults);
    final path = '${dir.path}/c.wav';
    final render = await AudioRender.start(
      path: path,
      format: ExportFormat.wav,
      clicks: events.clicks,
      end: events.end,
      samples: woodblock(),
    );
    await render.cancel();
    expect(File(path).existsSync(), isFalse);
  });
}

bool _lame() {
  const path = '/opt/homebrew/lib/libmp3lame.dylib';
  if (!File(path).existsSync()) return false;
  Mp3Encoder.libraryPath = path;
  return Mp3Encoder.available;
}

typedef MidiNote = ({int tick, int key, int velocity});

/// A small type 1 reader: enough to check what [clickTrackMidi] writes.
class Midi {
  int format = 0, ppq = 0, end = 0;
  final tempos = <(int, int)>[];
  final signatures = <(int, String)>[];
  final markers = <(int, String)>[];
  final notes = <MidiNote>[];

  int tempoAt(int tick) => tempos.lastWhere((t) => t.$1 <= tick).$2;

  double seconds(int tick) {
    var s = 0.0;
    for (var i = 0; i < tempos.length; i++) {
      final from = tempos[i].$1;
      if (from >= tick) break;
      final to = i + 1 < tempos.length && tempos[i + 1].$1 < tick
          ? tempos[i + 1].$1
          : tick;
      s += (to - from) * tempos[i].$2 / ppq / 1e6;
    }
    return s;
  }
}

Midi readMidi(Uint8List b) {
  final m = Midi();
  int u16(int at) => b[at] << 8 | b[at + 1];
  int u32(int at) => u16(at) << 16 | u16(at + 2);
  expect(String.fromCharCodes(b, 0, 4), 'MThd');
  m
    ..format = u16(8)
    ..ppq = u16(12);
  var at = 14;
  for (var t = 0; t < u16(10); t++) {
    expect(String.fromCharCodes(b, at, at + 4), 'MTrk');
    final stop = at + 8 + u32(at + 4);
    var i = at + 8, tick = 0;
    int vlq() {
      var v = 0;
      while (true) {
        final c = b[i++];
        v = v << 7 | c & 0x7F;
        if (c < 0x80) return v;
      }
    }

    while (i < stop) {
      tick += vlq();
      final status = b[i++];
      if (status == 0xFF) {
        final type = b[i++];
        final len = vlq();
        final data = b.sublist(i, i + len);
        i += len;
        switch (type) {
          case 0x51:
            m.tempos.add((tick, data[0] << 16 | data[1] << 8 | data[2]));
          case 0x58:
            m.signatures.add((tick, '${data[0]}/${1 << data[1]}'));
          case 0x06:
            m.markers.add((tick, String.fromCharCodes(data)));
          case 0x2F:
            m.end = tick;
        }
      } else {
        final key = b[i++], velocity = b[i++];
        expect(status & 0x0F, 9, reason: 'channel 10');
        if (status & 0xF0 == 0x90 && velocity > 0) {
          m.notes.add((tick: tick, key: key, velocity: velocity));
        }
      }
    }
    at = stop;
  }
  return m;
}
