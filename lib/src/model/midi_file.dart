import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'click_track.dart';
import 'click_volumes.dart';
import 'metronome_pattern.dart';

/// Ticks per quarter note.
const midiPpq = 960;

/// The note track's notes (General MIDI drums, channel 10): wood blocks
/// like the default click, a hi-hat for subdivisions, a cowbell for the
/// polyrhythm, so each can get its own sound.
abstract final class ClickNotes {
  static const accent = 76; // Hi Wood Block
  static const beat = 77; // Low Wood Block
  static const subdivision = 42; // Closed Hi-Hat
  static const polyrhythm = 56; // Cowbell
}

/// [track] as a type 1 MIDI file (ui-spec.md "Click track export"): a
/// tempo track (the tempo at every part, every beat in a Gradual one; time
/// signatures; part names as markers) and one note track on channel 10,
/// one note per click, velocity from [volumes]; silent steps have none.
/// In x/8 every eighth is a beat, so a quarter is two beats.
Uint8List clickTrackMidi(ClickTrack track, ClickVolumes volumes) {
  final tempo = <_Event>[], notes = <_Event>[];
  tempo.add(_Event(0, 0, _meta(0x03, utf8.encode(track.name))));
  notes.add(_Event(0, 0, _meta(0x03, utf8.encode('Click'))));
  var tick = 0;
  String? signature;
  int? usPerQuarter;
  int? lastPart;
  for (var bar = 0; bar < track.bars; bar++) {
    final at = track.locate(bar);
    final part = track.parts[at.part];
    final p = part.pattern;
    final ticksPerBeat = midiPpq * 4 / p.beatUnit;
    if (p.timeSignature != signature) {
      signature = p.timeSignature;
      tempo.add(
        _Event(tick, 1, [
          0xFF, 0x58, 4, p.beatsPerBar, //
          log2(p.beatUnit), 96 ~/ p.beatUnit, 8,
        ]),
      );
    }
    if (at.part != lastPart) {
      lastPart = at.part;
      tempo.add(_Event(tick, 2, _meta(0x06, utf8.encode(part.name))));
    }
    for (var beat = 0; beat < p.beatsPerBar; beat++) {
      final bpm = part.tempoAtBeat(at.bar * p.beatsPerBar + beat);
      final us = (60e6 / bpm * p.beatUnit / 4).round();
      if (us != usPerQuarter) {
        usPerQuarter = us;
        tempo.add(
          _Event(tick + (beat * ticksPerBeat).round(), 3, [
            0xFF, 0x51, 3, us >> 16 & 0xFF, us >> 8 & 0xFF, us & 0xFF, //
          ]),
        );
      }
    }
    final ticksPerStep = ticksPerBeat / p.stepsPerBeat;
    void note(double step, int key, double gain) {
      final at = tick + (step * ticksPerStep).round();
      final velocity = (gain * 127).round().clamp(1, 127);
      notes
        ..add(_Event(at, 5, [0x99, key, velocity]))
        ..add(_Event(at + midiPpq ~/ 16, 4, [0x89, key, 0]));
    }

    for (var s = 0; s < p.stepsPerBar; s++) {
      switch (p.steps[s]) {
        case StepLevel.accent:
          note(s.toDouble(), ClickNotes.accent, volumes.accent);
        case StepLevel.normal:
          note(s.toDouble(), ClickNotes.beat, volumes.beat);
        case StepLevel.soft:
          note(s.toDouble(), ClickNotes.subdivision, volumes.subdivision);
        case StepLevel.silent:
      }
    }
    for (var k = 0; k < p.polyrhythm; k++) {
      final level = p.polyStates[k];
      if (level == StepLevel.silent) continue;
      note(
        p.pulseOffset(k),
        ClickNotes.polyrhythm,
        volumes.polyrhythm * (level == StepLevel.accent ? 1 : 0.75),
      );
    }
    tick += (p.beatsPerBar * ticksPerBeat).round();
  }
  final end = tick;
  return Uint8List.fromList([
    ..._chunk('MThd', [0, 1, 0, 2, midiPpq >> 8, midiPpq & 0xFF]),
    ..._track(tempo, end),
    ..._track(notes, end),
  ]);
}

int log2(int n) => (log(n) / ln2).round();

class _Event {
  _Event(this.tick, this.order, this.bytes);
  final int tick;

  /// At one tick: names, time signature, marker, tempo, note offs, ons.
  final int order;
  final List<int> bytes;
}

List<int> _meta(int type, List<int> data) => [
  0xFF,
  type,
  ..._vlq(data.length),
  ...data,
];

List<int> _track(List<_Event> events, int end) {
  // Note-offs past the end close at the end.
  final sorted = [
    for (final e in events) e.tick > end ? _Event(end, e.order, e.bytes) : e,
  ]..sort((a, b) => a.tick != b.tick ? a.tick - b.tick : a.order - b.order);
  final out = <int>[];
  var last = 0;
  for (final e in sorted) {
    out
      ..addAll(_vlq(e.tick - last))
      ..addAll(e.bytes);
    last = e.tick;
  }
  out.addAll([..._vlq(end - last), 0xFF, 0x2F, 0]);
  return _chunk('MTrk', out);
}

List<int> _chunk(String id, List<int> data) => [
  ...ascii.encode(id),
  data.length >> 24 & 0xFF,
  data.length >> 16 & 0xFF,
  data.length >> 8 & 0xFF,
  data.length & 0xFF,
  ...data,
];

List<int> _vlq(int value) {
  final bytes = [value & 0x7F];
  for (var v = value >> 7; v > 0; v >>= 7) {
    bytes.insert(0, 0x80 | v & 0x7F);
  }
  return bytes;
}
