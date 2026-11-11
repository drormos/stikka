import 'package:flutter_test/flutter_test.dart';
import 'package:stikka/src/model/click_track.dart';
import 'package:stikka/src/model/metronome_pattern.dart';
import 'package:stikka/src/model/on_start.dart';
import 'package:stikka/src/model/song_part.dart';

SongPart part(String name, int bars, int bpm, {int? to, int beats = 4}) =>
    SongPart(
      id: name,
      name: name,
      bars: bars,
      tempoStart: bpm,
      tempoEnd: to ?? bpm,
      pattern: MetronomePattern.simple(beatsPerBar: beats, stepsPerBeat: 1),
    );

void main() {
  final song = [part('Intro', 4, 120), part('Verse', 8, 128)];

  group('length rules', () {
    for (final end in SongEnd.values) {
      test('$end: every part once', () {
        final track = ClickTrack.of('S', song, end);
        expect(ClickTrack.asksLength(song, end), isFalse);
        expect(track.bars, 12);
        expect(track.end, SongEnd.stop);
        expect(track.seconds, closeTo(4 * 2 + 8 * 4 * 60 / 128, 1e-9));
      });
    }

    test('a one-part song that stops plays its part once', () {
      final one = [part('Verse', 8, 120)];
      expect(ClickTrack.asksLength(one, SongEnd.stop), isFalse);
      expect(ClickTrack.of('S', one, SongEnd.stop).bars, 8);
    });

    test('a plain looping song: Time rounds up to whole bars', () {
      final plain = [part('Part 1', 1, 98)];
      expect(ClickTrack.asksLength(plain, SongEnd.loopLastPart), isTrue);
      // 4:00 at 98 in 4/4: 240 / 2.449 = 98 bars exactly.
      final four = ClickTrack.of('S', plain, SongEnd.loopLastPart);
      expect(four.bars, 98);
      expect(four.seconds, closeTo(240, 1e-6));
      // 0:15 is 6.1 bars: 7.
      final short = ClickTrack.of(
        'S',
        plain,
        SongEnd.loopLastPart,
        length: const OnStart(stopTime: Duration(seconds: 15)),
      );
      expect(short.bars, 7);
    });

    test('a plain looping song by Bars', () {
      final track = ClickTrack.of(
        'S',
        [part('Part 1', 1, 120)],
        SongEnd.loopSong,
        length: const OnStart(stopBy: StopBy.bars, stopBars: 32),
      );
      expect(track.bars, 32);
      expect(track.seconds, closeTo(64, 1e-9));
    });

    test('a one-part Gradual song loops its ramp', () {
      final ramp = part('Build', 2, 100, to: 140);
      final track = ClickTrack.of(
        'S',
        [ramp],
        SongEnd.loopLastPart,
        length: const OnStart(stopBy: StopBy.bars, stopBars: 5),
      );
      expect(
        [for (var b = 0; b < 5; b++) track.locate(b).bar],
        [0, 1, 0, 1, 0],
      );
    });

    test('starts at Stop after if on, else 4:00', () {
      const on = OnStart(stopOn: true, stopBy: StopBy.bars, stopBars: 16);
      expect(ClickTrack.startLength(on), on);
      final off = ClickTrack.startLength(OnStart.off);
      expect(off.stopBy, StopBy.time);
      expect(off.stopTime, const Duration(minutes: 4));
    });
  });

  test('file names drop what file systems refuse', () {
    expect(
      ClickTrack.fileName('Glass Harbor', ExportFormat.wav),
      'Glass Harbor.wav',
    );
    expect(
      ClickTrack.fileName('AC/DC: "Hi"?', ExportFormat.midi),
      'ACDC Hi.mid',
    );
    expect(ClickTrack.fileName(' ../ ', ExportFormat.mp3), 'Click track.mp3');
  });

  test('sizes', () {
    expect(sizeLabel(4032044), '4 MB');
    expect(sizeLabel(23040044), '23 MB');
    expect(sizeLabel(700000), '0.7 MB');
    expect(sizeLabel(1234), '2 KB');
    expect(sizeLabel(200), '1 KB');
    expect(estimatedSize(ExportFormat.wav, 1), 44 + 96000);
    // 160 kbps: ~20 KB a second.
    expect(estimatedSize(ExportFormat.mp3, 60), closeTo(1200000, 3000));
  });
}
