import 'on_start.dart';
import 'song_part.dart';
import 'song_plan.dart';

/// The click track export's formats (ui-spec.md "Click track export").
enum ExportFormat {
  wav('WAV', 'wav', 'audio/wav'),
  midi('MIDI', 'mid', 'audio/midi'),
  mp3('MP3', 'mp3', 'audio/mpeg');

  const ExportFormat(this.label, this.extension, this.mimeType);

  final String label;
  final String extension;
  final String mimeType;
}

/// What a click track export holds: a song's parts as written, once (or a
/// one-part looping song for a chosen length), without the count-in,
/// Speed up, Practice speed or Stop after. Pure: the renderers
/// (`audio/click_track_render.dart`, `model/midi_file.dart`) play its
/// [plan] for [bars] bars.
class ClickTrack {
  ClickTrack._(this.name, this.parts, this.end, this.bars);

  /// [name]'s song of [parts] ending as [end]. A one-part song that loops
  /// ([asksLength]) plays for [length]: its Count by and Length (Stop
  /// after's), Time rounded up to whole bars; every other song plays each
  /// part once.
  factory ClickTrack.of(
    String name,
    List<SongPart> parts,
    SongEnd end, {
    OnStart? length,
  }) {
    if (!asksLength(parts, end)) {
      final total = parts.fold(0, (sum, p) => sum + p.bars);
      return ClickTrack._(name, parts, SongEnd.stop, total);
    }
    final on = length ?? startLength(OnStart.off);
    final bars = on.stopBy == StopBy.bars
        ? on.stopBars
        : barsFor(parts.single, on.stopTime);
    return ClickTrack._(name, parts, SongEnd.loopLastPart, bars);
  }

  /// A one-part song that loops would be one pass of its part: the sheet
  /// asks how long instead.
  static bool asksLength(List<SongPart> parts, SongEnd end) =>
      parts.length == 1 && end != SongEnd.stop;

  /// The length the sheet starts at: the song's Stop after if it's on,
  /// else 4:00 by Time.
  static OnStart startLength(OnStart song) => song.stopOn
      ? song
      : song.copyWith(
          stopBy: StopBy.time,
          stopTime: const Duration(minutes: 4),
        );

  /// Whole bars of [part] (looping, a Gradual one restarting its ramp)
  /// that reach [time]: rounded up, like Stop after.
  static int barsFor(SongPart part, Duration time) {
    final target = time.inMicroseconds / 1e6 - 1e-6;
    var seconds = 0.0;
    var bars = 0;
    while (seconds < target) {
      seconds += _barSeconds(part, bars % part.bars);
      bars++;
    }
    return bars < 1 ? 1 : bars;
  }

  static double _barSeconds(SongPart part, int bar) {
    final beats = part.pattern.beatsPerBar;
    var s = 0.0;
    for (var b = 0; b < beats; b++) {
      s += 60 / part.tempoAtBeat(bar * beats + b);
    }
    return s;
  }

  final String name;
  final List<SongPart> parts;

  /// [SongEnd.stop], or [SongEnd.loopLastPart] for a one-part song looped
  /// to [bars].
  final SongEnd end;
  final int bars;

  /// A fresh plan for the scheduler (it keeps where it jumped): ends at
  /// the line after [bars] bars, nothing personal in it.
  SongPlan get plan => SongPlan(
    parts: parts,
    end: end,
    onStart: OnStart(stopOn: true, stopBy: StopBy.bars, stopBars: bars),
  );

  /// Where song bar [bar] (from 0) is: the part and the bar within it.
  ({int part, int bar}) locate(int bar) =>
      _where.locate(bar) ?? (part: parts.length - 1, bar: 0);
  late final _where = plan;

  /// The length in seconds, beat by beat (the same tempos the scheduler
  /// plays).
  double get seconds {
    var s = 0.0;
    for (var bar = 0; bar < bars; bar++) {
      final at = locate(bar);
      s += _barSeconds(parts[at.part], at.bar);
    }
    return s;
  }

  /// The file's name: the song's, without characters file systems refuse.
  static String fileName(String song, ExportFormat format) {
    final clean = song
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]'), '')
        .trim()
        .replaceAll(RegExp(r'^\.+'), '');
    return '${clean.isEmpty ? 'Click track' : clean}.${format.extension}';
  }
}

/// WAV and MP3 sample rate.
const exportSampleRate = 48000;

/// The MP3 bit rate, bits per second (CBR).
const mp3BitRate = 160000;

/// Expected file size: WAV exactly, MP3 to the frame, MIDI as written.
int estimatedSize(ExportFormat format, double seconds, {int midiBytes = 0}) {
  final samples = (seconds * exportSampleRate).round();
  return switch (format) {
    ExportFormat.wav => 44 + 2 * samples,
    ExportFormat.midi => midiBytes,
    // 1152 samples a frame, 480 bytes at 160 kbps and 48 kHz; LAME's
    // delay and padding, plus the Info (LAME tag) frame.
    ExportFormat.mp3 => ((samples + 1105) / 1152).ceil() * 480 + 480 + 480,
  };
}

/// "4 MB", "0.7 MB", "23 MB", "2 KB".
String sizeLabel(int bytes) {
  const mb = 1000 * 1000;
  if (bytes < mb ~/ 10) {
    final kb = (bytes / 1000).ceil();
    return '${kb < 1 ? 1 : kb} KB';
  }
  final m = bytes / mb;
  if (m >= 10) return '${m.round()} MB';
  final one = m.toStringAsFixed(1);
  return '${one.endsWith('.0') ? one.substring(0, one.length - 2) : one} MB';
}
