import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/click_track_render.dart';
import '../controller/library_controller.dart';
import '../controller/metronome_controller.dart';
import '../model/click_track.dart';
import '../model/metronome_pattern.dart';
import '../model/midi_file.dart';
import '../model/on_start.dart';
import '../model/song_part.dart';
import '../platform/android_bridge.dart';
import 'choices.dart';
import 'haptics.dart';
import 'on_start_sheet.dart';
import 'theme.dart';

/// The click track export sheet (ui-spec.md "Click track export",
/// `click-export.reference.html`), from the bottom: [name]'s [parts]
/// ending as [end] as a WAV, MIDI or MP3 file, saved or shared. [onStart]
/// is the song's own, for a looping one-part song's starting length.
Future<void> showClickExportSheet(
  BuildContext context, {
  required String name,
  required List<SongPart> parts,
  required SongEnd end,
  required OnStart onStart,
  required LibraryController library,
  required MetronomeController metronome,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
  ),
  builder: (_) => ClickExportSheet(
    name: name,
    parts: parts,
    end: end,
    onStart: onStart,
    library: library,
    metronome: metronome,
  ),
);

enum _Action { save, share }

class ClickExportSheet extends StatefulWidget {
  const ClickExportSheet({
    super.key,
    required this.name,
    required this.parts,
    required this.end,
    required this.onStart,
    required this.library,
    required this.metronome,
  });

  final String name;
  final List<SongPart> parts;
  final SongEnd end;
  final OnStart onStart;
  final LibraryController library;
  final MetronomeController metronome;

  static const saveKey = Key('click-export-save');
  static const shareKey = Key('click-export-share');
  static const cancelKey = Key('click-export-cancel');
  static Key formatKey(ExportFormat f) => Key('click-export-${f.name}');

  static const title = 'Export click track';
  static const failed = "Couldn't make the file. Try again.";
  static const formatLines = {
    ExportFormat.wav: 'For recording software. Exact timing.',
    ExportFormat.midi:
        'For recording software. Tempo, time signatures and part names; '
        'no sound.',
    ExportFormat.mp3:
        'For listening and sending. Not exact enough for '
        'recording.',
  };

  /// How long the sheet waits before the pressed button shows progress.
  static const progressDelay = Duration(milliseconds: 400);

  /// What will be in the file, under the summary.
  static String contentLine(List<SongPart> parts, SongEnd end) {
    final once = switch (end) {
      SongEnd.stop => 'The song once, as written.',
      SongEnd.loopSong => 'The song once, as written, instead of looping.',
      SongEnd.loopLastPart =>
        'The song once, as written. ${parts.last.name} plays once instead '
            'of looping.',
    };
    return '$once No count-in or practice speed.';
  }

  /// A looping one-part song's line: "98 bpm · 4/4 · loops until you stop".
  static String loopingLine(SongPart part) {
    final tempo = part.gradual
        ? '${part.tempoStart} to ${part.tempoEnd}'
        : '${part.tempoStart}';
    return '$tempo bpm · ${part.pattern.timeSignature} · loops until you stop';
  }

  /// Under the Length: "98 bars, rounded to whole bars. No count-in."
  static String lengthLine(ClickTrack track, OnStart length) =>
      length.stopBy == StopBy.time
      ? '${OnStart.barsLabel(track.bars)}, rounded to whole bars. '
            'No count-in.'
      : 'No count-in.';

  @override
  State<ClickExportSheet> createState() => _ClickExportSheetState();
}

class _ClickExportSheetState extends State<ClickExportSheet> {
  late ExportFormat _format = widget.library.exportFormat;
  late OnStart _length = ClickTrack.startLength(widget.onStart);
  late ClickTrack _track;
  late Map<ExportFormat, int> _sizes;

  _Action? _busy;
  bool _showProgress = false;
  double _progress = 0;
  bool _failed = false;
  Timer? _progressTimer;
  AudioRender? _render;
  bool _cancelled = false;
  late final _lifecycle = AppLifecycleListener(onHide: _cancel);

  bool get _asksLength => ClickTrack.asksLength(widget.parts, widget.end);

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _update();
  }

  void _update() {
    _track = ClickTrack.of(
      widget.name,
      widget.parts,
      widget.end,
      length: _length,
    );
    final seconds = _track.seconds;
    _sizes = {
      for (final f in ExportFormat.values)
        f: estimatedSize(
          f,
          seconds,
          midiBytes: f == ExportFormat.midi
              ? clickTrackMidi(_track, widget.metronome.volumes).length
              : 0,
        ),
    };
  }

  @override
  void dispose() {
    _cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Stops a file being made and deletes it (Cancel, Back, leaving).
  void _cancel() {
    final render = _render;
    if (_busy == null) return;
    _cancelled = true;
    _render = null;
    _progressTimer?.cancel();
    if (render != null) unawaited(render.cancel());
    if (mounted) {
      setState(() {
        _busy = null;
        _showProgress = false;
      });
    }
  }

  Future<void> _run(_Action action) async {
    if (_busy != null) return;
    Haptics.tick();
    widget.library.setExportFormat(_format);
    setState(() {
      _busy = action;
      _failed = false;
      _progress = 0;
      _cancelled = false;
    });
    _progressTimer = Timer(ClickExportSheet.progressDelay, () {
      if (mounted && _busy != null) setState(() => _showProgress = true);
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = ClickTrack.fileName(widget.name, _format);
    try {
      final path = await _make(name);
      if (_cancelled || path == null) return;
      _progressTimer?.cancel();
      if (action == _Action.save) {
        if (!await AndroidBridge.saveFile(path, name, _format.mimeType)) {
          if (mounted) setState(() => _busy = null);
          return;
        }
        if (!mounted) return;
        Navigator.pop(context);
        messenger?.showSnackBar(SnackBar(content: Text('Saved $name')));
      } else {
        await AndroidBridge.shareFile(path, _format.mimeType);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('click export: $e');
      if (_cancelled || !mounted) return;
      setState(() {
        _busy = null;
        _showProgress = false;
        _failed = true;
      });
    }
  }

  /// Writes the file into the cache's `exports/` (older exports there go):
  /// its path, or null when cancelled.
  Future<String?> _make(String name) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/exports');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final path = '${dir.path}/$name';
    if (_format == ExportFormat.midi) {
      await File(path)
          .writeAsBytes(clickTrackMidi(_track, widget.metronome.volumes));
      return path;
    }
    final events = await clickTrackEvents(
      _track,
      volumes: widget.metronome.volumes,
      raisePartChanges: widget.metronome.partChangeSound,
    );
    final samples = await _samples();
    if (_cancelled) return null;
    final render = _render = await AudioRender.start(
      path: path,
      format: _format,
      clicks: events.clicks,
      end: events.end,
      samples: samples,
      onProgress: (p) {
        if (mounted && !_cancelled) setState(() => _progress = p);
      },
    );
    if (_cancelled) {
      await render.cancel();
      return null;
    }
    await render.done;
    _render = null;
    return _cancelled ? null : path;
  }

  Future<ClickSamples> _samples() async {
    final sound = widget.metronome.clickSound;
    Future<({Float32List samples, int rate})> read(StepLevel level) async {
      final data = await rootBundle.load(sound.assetFor(level));
      return readWav(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }

    final accent = await read(StepLevel.accent);
    final normal = await read(StepLevel.normal);
    return (accent: accent.samples, normal: normal.samples, rate: accent.rate);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = TextStyle(fontSize: 13, color: colors.muted, height: 1.45);
    final busy = _busy != null;
    return PopScope(
      onPopInvokedWithResult: (_, _) => _cancel(),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.beatResting,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Semantics(
                header: true,
                child: const Text(
                  ClickExportSheet.title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              // Only the middle scrolls; the title and buttons stay.
              Flexible(
                child: IgnorePointer(
                  ignoring: busy,
                  child: Opacity(
                    opacity: busy && _showProgress ? 0.4 : 1,
                    child: SingleChildScrollView(child: _middle(colors, muted)),
                  ),
                ),
              ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      ClickExportSheet.failed,
                      style: TextStyle(fontSize: 14, color: colors.danger),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _buttons(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _middle(StikkaColors colors, TextStyle muted) {
    final first = widget.parts.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        Text(
          _asksLength
              ? ClickExportSheet.loopingLine(first)
              : '${widget.parts.length == 1 ? '1 part' : '${widget.parts.length} parts'}'
                    ' · ${OnStart.barsLabel(_track.bars)}'
                    ' · ${OnStart.timeLabel(Duration(seconds: _track.seconds.round()))}',
          style: muted.copyWith(height: 1.35),
        ),
        const SizedBox(height: 12),
        if (_asksLength) ...[
          Choices<StopBy>(
            key: OnStartSheet.stopByKey,
            label: OnStartSheet.countByLabel,
            options: const {StopBy.bars: 'Bars', StopBy.time: 'Time'},
            selected: _length.stopBy,
            onSelected: (v) => _setLength(_length.copyWith(stopBy: v)),
          ),
          const SizedBox(height: 4),
          OnStartSheet.lengthStepper(_length, _setLength),
          const SizedBox(height: 4),
          Text(ClickExportSheet.lengthLine(_track, _length), style: muted),
        ] else
          Text(
            ClickExportSheet.contentLine(widget.parts, widget.end),
            style: muted,
          ),
        const SizedBox(height: 14),
        Text(
          'FORMAT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 12 * 0.08,
            color: colors.muted,
          ),
        ),
        const SizedBox(height: 12),
        for (final f in ExportFormat.values) ...[
          _formatRow(colors, f),
          if (f != ExportFormat.values.last) const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        Text(
          ClickTrack.fileName(widget.name, _format),
          style: muted.copyWith(height: 1.35),
        ),
      ],
    );
  }

  void _setLength(OnStart length) => setState(() {
    _length = length;
    _update();
  });

  Widget _formatRow(StikkaColors colors, ExportFormat f) {
    final selected = f == _format;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? colors.surfaceOnSheet : colors.sheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? colors.text : colors.border,
            width: 2,
          ),
        ),
        child: InkWell(
          key: ClickExportSheet.formatKey(f),
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (selected) return;
            Haptics.tick();
            setState(() => _format = f);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          f.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ClickExportSheet.formatLines[f]!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    sizeLabel(_sizes[f]!),
                    style: TextStyle(fontSize: 13, color: colors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttons(StikkaColors colors) {
    const label = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    Widget progress() => Semantics(
      liveRegion: true,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: colors.text, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _progress.clamp(0.0, 1.0),
              child: ColoredBox(color: colors.surfaceOnSheet),
            ),
            Center(
              child: Text(
                'Preparing · ${(_progress * 100).floor()}%',
                style: label,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
    Widget outlined(Key key, String text, VoidCallback? onPressed) =>
        OutlinedButton(
          key: key,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: shape,
            side: BorderSide(color: colors.border, width: 2),
          ),
          onPressed: onPressed,
          child: Text(text, style: label, textAlign: TextAlign.center),
        );
    final shown = _showProgress ? _busy : null;
    final save = shown == _Action.save
        ? progress()
        : shown == _Action.share
        ? outlined(ClickExportSheet.cancelKey, 'Cancel', _cancel)
        : outlined(
            ClickExportSheet.saveKey,
            'Save to phone',
            () => _run(_Action.save),
          );
    final share = shown == _Action.share
        ? progress()
        : shown == _Action.save
        ? outlined(ClickExportSheet.cancelKey, 'Cancel', _cancel)
        : FilledButton.icon(
            key: ClickExportSheet.shareKey,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: shape,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              // White on Stage Black (the reference), not the accent.
              backgroundColor: colors.text,
              foregroundColor: colors.background,
            ),
            onPressed: () => _run(_Action.share),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share', style: label),
          );
    return Row(
      children: [
        Expanded(child: save),
        const SizedBox(width: 8),
        Expanded(child: share),
      ],
    );
  }
}
