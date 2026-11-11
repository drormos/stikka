import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikka/src/controller/library_controller.dart';
import 'package:stikka/src/controller/metronome_controller.dart';
import 'package:stikka/src/model/click_track.dart';
import 'package:stikka/src/model/metronome_pattern.dart';
import 'package:stikka/src/model/on_start.dart';
import 'package:stikka/src/model/song_part.dart';
import 'package:stikka/src/platform/android_bridge.dart';
import 'package:stikka/src/storage/library_store.dart';
import 'package:stikka/src/ui/click_export_sheet.dart';
import 'package:stikka/src/ui/theme.dart';

import '../audio/fake_click_output.dart';

SongPart part(String name, int bars, int bpm, {int? to, int beats = 4}) =>
    SongPart(
      id: name,
      name: name,
      bars: bars,
      tempoStart: bpm,
      tempoEnd: to ?? bpm,
      pattern: MetronomePattern.simple(beatsPerBar: beats, stepsPerBeat: 1),
    );

/// Glass Harbor (ui-spec.md's example): 4 parts, 21 bars, the Chorus
/// looping.
final glassHarbor = [
  part('Intro', 4, 120),
  part('Verse', 8, 120),
  part('Break', 1, 128, beats: 2),
  part('Chorus', 8, 128, to: 140),
];

void main() {
  late Directory dir;
  late LibraryController library;
  late MetronomeController metronome;
  late List<MethodCall> calls;
  Object? Function(MethodCall)? answer;

  setUp(() => dir = Directory.systemTemp.createTempSync('click_export'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Still writing.
    }
  });

  Future<void> open(
    WidgetTester tester, {
    List<SongPart>? parts,
    SongEnd end = SongEnd.loopLastPart,
    OnStart onStart = OnStart.off,
    double textScale = 1,
    Size size = const Size(412, 915),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    calls = [];
    answer = null;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AndroidBridge.android, (call) async {
      calls.add(call);
      return answer?.call(call);
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(AndroidBridge.android, null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });
    metronome = MetronomeController(FakeClickOutput());
    addTearDown(metronome.dispose);
    library = (await tester.runAsync(
      () => LibraryController.load(
        LibraryStore(File('${dir.path}/library.json')),
      ),
    ))!;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: stikkaTheme(StikkaColors.stageBlack, Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showClickExportSheet(
                  context,
                  name: 'Glass Harbor',
                  parts: parts ?? glassHarbor,
                  end: end,
                  onStart: onStart,
                  library: library,
                  metronome: metronome,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a song with parts: summary, what is in it, three formats '
      'with sizes, WAV first, the file name follows the format', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(ClickExportSheet.title), findsOneWidget);
    expect(find.text('4 parts · 21 bars · 0:39'), findsOneWidget);
    expect(
      find.text(
        'The song once, as written. Chorus plays once instead of looping. '
        'No count-in or practice speed.',
      ),
      findsOneWidget,
    );
    for (final f in ExportFormat.values) {
      expect(find.byKey(ClickExportSheet.formatKey(f)), findsOneWidget);
      expect(find.text(ClickExportSheet.formatLines[f]!), findsOneWidget);
    }
    expect(find.text('3.8 MB'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d KB$')), findsOneWidget);
    expect(find.text('Glass Harbor.wav'), findsOneWidget);
    expect(find.byKey(OnStartKeys.stopBy), findsNothing);
    await tester.tap(find.byKey(ClickExportSheet.formatKey(ExportFormat.mp3)));
    await tester.pump();
    expect(find.text('Glass Harbor.mp3'), findsOneWidget);
  });

  testWidgets('a plain looping song asks for a length: 4:00 is 98 bars at '
      '98, rounded to whole bars', (tester) async {
    await open(
      tester,
      parts: [part('Part 1', 1, 98)],
      end: SongEnd.loopLastPart,
    );
    expect(find.text('98 bpm · 4/4 · loops until you stop'), findsOneWidget);
    expect(find.byKey(OnStartKeys.stopBy), findsOneWidget);
    expect(find.text('4:00'), findsOneWidget);
    expect(
      find.text('98 bars, rounded to whole bars. No count-in.'),
      findsOneWidget,
    );
    expect(find.text('23 MB'), findsOneWidget);
  });

  testWidgets('Share makes the file and hands it over; the format is '
      'remembered', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(ClickExportSheet.formatKey(ExportFormat.midi)));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ClickExportSheet.shareKey));
      for (var i = 0; i < 50 && calls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    final share = calls.single;
    expect(share.method, 'shareFile');
    final args = share.arguments as Map;
    expect(args['mime'], 'audio/midi');
    expect(args['path'] as String, endsWith('/exports/Glass Harbor.mid'));
    expect(File(args['path'] as String).readAsBytesSync().sublist(0, 4), [
      0x4D,
      0x54,
      0x68,
      0x64,
    ]);
    expect(find.text(ClickExportSheet.title), findsNothing, reason: 'closed');
    expect(library.exportFormat, ExportFormat.midi);
  });

  testWidgets('Save: Android saves it, the sheet closes, "Saved …"', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(ClickExportSheet.formatKey(ExportFormat.midi)));
    await tester.pump();
    answer = (call) => true;
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ClickExportSheet.saveKey));
      for (var i = 0; i < 50 && calls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(calls.single.method, 'saveFile');
    expect((calls.single.arguments as Map)['name'], 'Glass Harbor.mid');
    expect(find.text('Saved Glass Harbor.mid'), findsOneWidget);
    expect(find.text(ClickExportSheet.title), findsNothing);
  });

  testWidgets('a refused save: the danger line, the sheet stays', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(ClickExportSheet.formatKey(ExportFormat.midi)));
    await tester.pump();
    answer = (call) => throw PlatformException(code: 'save');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ClickExportSheet.saveKey));
      for (var i = 0; i < 50 && calls.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text(ClickExportSheet.failed), findsOneWidget);
    final line = tester.widget<Text>(find.text(ClickExportSheet.failed));
    expect(line.style!.color, StikkaColors.stageBlack.danger);
    expect(find.byKey(ClickExportSheet.saveKey), findsOneWidget);
  });

  for (final (name, size) in [
    ('360dp', const Size(360, 640)),
    ('a normal phone', const Size(412, 915)),
  ]) {
    testWidgets('115% on $name: wraps, never cuts; the title and the '
        'buttons stay on screen', (tester) async {
      await open(tester, textScale: 1.15, size: size);
      expect(tester.takeException(), isNull);
      for (final key in [ClickExportSheet.saveKey, ClickExportSheet.shareKey]) {
        final r = tester.getRect(find.byKey(key));
        expect(r.bottom, lessThanOrEqualTo(size.height));
        expect(r.height, greaterThanOrEqualTo(52));
      }
      expect(
        tester.getRect(find.text(ClickExportSheet.title)).top,
        greaterThanOrEqualTo(0),
      );
      final mp3 = tester.getRect(
        find.byKey(ClickExportSheet.formatKey(ExportFormat.mp3)),
      );
      expect(mp3.width, size.width - 32);
    });
  }
}

/// Keys from the When I press Start panel the sheet reuses.
abstract final class OnStartKeys {
  static const stopBy = Key('stop-by');
}
