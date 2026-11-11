import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikka/src/controller/library_controller.dart';
import 'package:stikka/src/controller/metronome_controller.dart';
import 'package:stikka/src/model/library.dart';
import 'package:stikka/src/model/metronome_pattern.dart';
import 'package:stikka/src/model/share_export.dart';
import 'package:stikka/src/platform/android_bridge.dart';
import 'package:stikka/src/storage/library_store.dart';
import 'package:stikka/src/ui/click_export_sheet.dart';
import 'package:stikka/src/ui/editor_scaffold.dart';
import 'package:stikka/src/ui/metronome_screen.dart';
import 'package:stikka/src/ui/parts_page.dart';
import 'package:stikka/src/ui/pick_header.dart';
import 'package:stikka/src/ui/play_marker.dart';
import 'package:stikka/src/ui/quick_pick.dart';
import 'package:stikka/src/ui/setlist_group.dart';
import 'package:stikka/src/ui/share_menu.dart';
import 'package:stikka/src/ui/theme.dart';

import '../audio/fake_click_output.dart';
import 'test_theme.dart';

/// Sharing sets and songs on screen (ui-spec.md "Sharing sets and songs").
void main() {
  late Directory dir;
  late MetronomeController metronome;
  late LibraryController library;
  late List<String> shared;
  String clipboard = '';

  setUp(() => dir = Directory.systemTemp.createTempSync('stikka_share'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // A save on the fake clock may still be writing.
    }
  });

  /// "Fri" (One 100, Two 110) loaded at One; shares and the clipboard are
  /// caught.
  Future<void> pump(
    WidgetTester tester, {
    int more = 0,
    Size size = const Size(400, 900),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    shared = [];
    final before = QuickPick.share;
    QuickPick.share = (text) async => shared.add(text);
    addTearDown(() => QuickPick.share = before);
    clipboard = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': clipboard}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    metronome = MetronomeController(FakeClickOutput());
    addTearDown(metronome.dispose);
    library = (await tester.runAsync(
      () => LibraryController.load(
        LibraryStore(File('${dir.path}/library.json')),
      ),
    ))!;
    final ids = [
      for (final (name, bpm) in [('One', 100), ('Two', 110)])
        library
            .addSong(
              name: name,
              bpm: bpm,
              pattern: const MetronomePattern.standard(),
            )
            .id,
    ];
    for (var i = 1; i <= more; i++) {
      library.addSong(
        name: 'S$i',
        bpm: 80 + i,
        pattern: const MetronomePattern.standard(),
      );
    }
    final set = library.saveSetlist(name: 'Fri', songIds: ids);
    library.loadSetlist(set.id, metronome);
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        home: MetronomeScreen(controller: metronome, library: library),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openSetPanel(WidgetTester tester) =>
      tap(tester, find.byKey(SetlistGroup.headerKey));

  /// The Songs list, in Single song on "One".
  Future<void> openSongs(WidgetTester tester) async {
    library.playSingleSong(library.songsAZ.first, metronome);
    await tester.pump();
    await tap(tester, find.byKey(SetlistGroup.songsKey));
  }

  String setExport(String name, List<Song> songs) =>
      exportSetText(Setlist(id: 'x', name: name, songIds: const []), songs);

  Song song(String name, int bpm) => Song(
    id: name,
    name: name,
    bpm: bpm,
    pattern: const MetronomePattern.standard(),
  );

  testWidgets('both share menus open upward from Share, centred on it '
      '(within 16px of the screen edges), 8px above it', (tester) async {
    await pump(tester);
    void check(Key button) {
      final at = tester.getRect(find.byKey(button));
      final menu = tester.getRect(find.byKey(shareMenuKey));
      expect(menu.bottom, moreOrLessEquals(at.top - 8), reason: '8px above');
      expect(menu.left, greaterThanOrEqualTo(16));
      expect(menu.right, lessThanOrEqualTo(400 - 16));
      final clamped = menu.left == 16 || menu.right == 400 - 16;
      if (!clamped) {
        expect(menu.center.dx, moreOrLessEquals(at.center.dx));
      }
    }

    await openSetPanel(tester);
    await tap(tester, find.byKey(QuickPick.shareKey));
    check(QuickPick.shareKey);
    await tester.tapAt(const Offset(200, 60)); // outside: closes
    await tester.pumpAndSettle();
    expect(find.byKey(shareMenuKey), findsNothing);
    expect(find.byType(QuickPick), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await openSongs(tester);
    await tap(tester, find.byKey(QuickPick.songsShareKey));
    check(QuickPick.songsShareKey);
  });

  testWidgets('Set ⌄ › Share › Export set: the whole set as a Stikka export', (
    tester,
  ) async {
    await pump(tester);
    await openSetPanel(tester);
    await tap(tester, find.byKey(QuickPick.shareKey));
    expect(find.text(ShareMenus.forImport), findsOneWidget);
    await tap(tester, find.text('Export set'));
    final read = parseShared(shared.single)!;
    expect(read.setName, 'Fri');
    expect([for (final s in read.songs) s.name], ['One', 'Two']);
  });

  testWidgets('Songs list: "New song" · "Share" in the bottom row; Export a '
      'song… picks one (header + Cancel, no search or Share meanwhile), a tap '
      'exports it and leaves; Cancel and Back leave too', (tester) async {
    await pump(tester);
    await openSongs(tester);
    final newSong = tester.getRect(find.byKey(QuickPick.newSongKey));
    final share = tester.getRect(find.byKey(QuickPick.songsShareKey));
    expect(newSong.size, share.size);
    expect(newSong.right, lessThan(share.left));

    Future<void> pick() async {
      await tap(tester, find.byKey(QuickPick.songsShareKey));
      await tap(tester, find.text('Export a song…'));
      expect(find.text(PickAction.exportSong.title), findsOneWidget);
      expect(find.byKey(QuickPick.songsShareKey).hitTestable(), findsNothing);
    }

    await pick();
    await tap(tester, find.byKey(QuickPick.exportPickCancelKey));
    expect(find.text(PickAction.exportSong.title), findsNothing);
    expect(shared, isEmpty);

    await pick();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(PickAction.exportSong.title), findsNothing);
    expect(find.byType(QuickPick), findsOneWidget, reason: 'Back leaves it');

    await pick();
    await tap(
      tester,
      find.descendant(of: find.byType(QuickPick), matching: find.text('Two')),
    );
    expect(parseShared(shared.single)!.songs.single.name, 'Two');
    expect(find.text(PickAction.exportSong.title), findsNothing);
    expect(library.currentSong!.name, 'One', reason: 'nothing loaded');
  });

  testWidgets('Songs list: Export click track… picks a song (the "Click '
      'track" header), and its export sheet opens', (tester) async {
    await pump(tester);
    await openSongs(tester);
    await tap(tester, find.byKey(QuickPick.songsShareKey));
    expect(
      find.text('Pick one: WAV, MIDI or MP3, for recording software'),
      findsOneWidget,
    );
    await tap(tester, find.text('Export click track…'));
    expect(find.text(PickAction.clickTrack.title), findsOneWidget);
    expect(find.byKey(QuickPick.songsShareKey).hitTestable(), findsNothing);
    await tap(
      tester,
      find.descendant(of: find.byType(QuickPick), matching: find.text('Two')),
    );
    expect(find.text(PickAction.clickTrack.title), findsNothing);
    expect(find.text(ClickExportSheet.title), findsOneWidget);
    expect(find.text('110 bpm · 4/4 · loops until you stop'), findsOneWidget);
    expect(shared, isEmpty);
    expect(library.currentSong!.name, 'One', reason: 'nothing loaded');
  });

  group('pick mode looks like a different list', () {
    // Real Saira, so the header wraps (or not) as on the phone.
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final loader = FontLoader(StikkaFonts.body)
        ..addFont(rootBundle.load('assets/fonts/Saira-Medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Saira-SemiBold.ttf'));
      await loader.load();
    });

    Finder inList(Finder f) =>
        find.descendant(of: find.byType(QuickPick), matching: f);
    final rows = ['One', 'S1', 'S2', 'S3'];
    Map<String, Rect> rowRects(WidgetTester tester) => {
      for (final name in rows) name: tester.getRect(inList(find.text(name))),
    };
    Future<void> openMenu(WidgetTester tester) =>
        tap(tester, find.byKey(QuickPick.songsShareKey));

    testWidgets('header, rows and the hidden bottom row, per mode', (
      tester,
    ) async {
      await pump(tester, more: 9); // over 8 songs: the search shows
      await openSongs(tester);
      expect(find.byType(SearchField), findsOneWidget);
      expect(inList(find.byType(PlayMarker)), findsWidgets);

      for (final (item, action, icon) in [
        ('Export a song…', PickAction.exportSong, Icons.share_outlined),
        ('Export click track…', PickAction.clickTrack, null),
      ]) {
        await openMenu(tester);
        await tap(tester, find.text(item));
        final header = find.byKey(QuickPick.exportPickCancelKey);
        expect(header.hitTestable(), findsOneWidget);
        expect(find.text(action.title).hitTestable(), findsOneWidget);
        expect(find.text(action.line).hitTestable(), findsOneWidget);
        expect(find.byType(SearchField).hitTestable(), findsNothing);
        expect(
          inList(find.byType(PlayMarker)),
          findsNothing,
          reason: 'no ▷, no red ▶ on the loaded song',
        );
        final rowIcons = icon != null
            ? inList(find.byIcon(icon))
            : inList(find.byType(WaveformIcon));
        // Every visible row, plus the header's badge.
        expect(rowIcons.evaluate().length, greaterThan(rows.length));
        expect(find.byKey(QuickPick.songsShareKey).hitTestable(), findsNothing);
        expect(find.byKey(QuickPick.newSongKey).hitTestable(), findsNothing);
        expect(
          find.bySemanticsLabel('playing'),
          findsNothing,
          reason: 'now playing does not matter here',
        );
        await tap(tester, header);
        expect(find.text(action.title), findsNothing);
        expect(inList(find.byType(PlayMarker)), findsWidgets);
        expect(find.byKey(QuickPick.songsShareKey).hitTestable(), findsOne);
      }
    });

    testWidgets('the menu row flies into the header and back into Share; '
        'the rows keep their places all the way', (tester) async {
      await pump(tester, more: 9);
      await openSongs(tester);
      final before = rowRects(tester);
      final share = tester.getRect(find.byKey(QuickPick.songsShareKey));
      await openMenu(tester);
      final menuRow = tester.getRect(
        find.byKey(const ValueKey('share-export')),
      );
      await tester.tap(find.text('Export a song…'));
      await tester.pump();
      final flight = find.byKey(QuickPick.pickFlightKey);
      expect(flight, findsOneWidget);
      expect(
        tester.getRect(flight).top,
        moreOrLessEquals(menuRow.top, epsilon: 1),
      );
      expect(
        tester.getRect(flight).width,
        moreOrLessEquals(menuRow.width, epsilon: 1),
      );

      var lastTop = tester.getRect(flight).top;
      var swappedAt = Duration.zero;
      for (var ms = 16; ms <= 256; ms += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(rowRects(tester), before, reason: 'rows still at $ms ms');
        if (flight.evaluate().isNotEmpty) {
          final top = tester.getRect(flight).top;
          expect(top, lessThanOrEqualTo(lastTop), reason: 'moving up');
          lastTop = top;
        }
        if (swappedAt == Duration.zero &&
            inList(find.byType(PlayMarker)).evaluate().isEmpty) {
          swappedAt = Duration(milliseconds: ms);
        }
      }
      expect(
        swappedAt.inMilliseconds,
        inInclusiveRange(48, 112),
        reason: 'the icons swap a moment after the header starts',
      );
      await tester.pumpAndSettle();
      expect(flight, findsNothing);
      final header = tester.getRect(find.byType(PickHeader).hitTestable());
      expect(lastTop, moreOrLessEquals(header.top, epsilon: 2));
      expect(rowRects(tester), before);

      // Cancel: back into Share.
      await tester.tap(find.byKey(QuickPick.exportPickCancelKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(flight, findsOneWidget);
      for (var ms = 32; ms <= 208; ms += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(rowRects(tester), before, reason: 'rows still at $ms ms');
      }
      final end = tester.getRect(flight);
      expect(
        (end.center - share.center).distance,
        lessThan((header.center - share.center).distance / 4),
        reason: 'it shrinks into Share',
      );
      await tester.pumpAndSettle();
      expect(flight, findsNothing);
      expect(rowRects(tester), before);
      expect(find.byKey(QuickPick.songsShareKey).hitTestable(), findsOne);
    });

    testWidgets('Remove animations: all of it at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester, more: 9);
      await openSongs(tester);
      final before = rowRects(tester);
      await tester.tap(find.byKey(QuickPick.songsShareKey));
      await tester.pump();
      await tester.tap(find.text('Export click track…'));
      await tester.pump();
      expect(find.byKey(QuickPick.pickFlightKey), findsNothing);
      expect(find.text(PickAction.clickTrack.title).hitTestable(), findsOne);
      expect(inList(find.byType(PlayMarker)), findsNothing);
      expect(inList(find.byType(WaveformIcon)), findsWidgets);
      expect(rowRects(tester), before);
      await tester.tap(find.byKey(QuickPick.exportPickCancelKey));
      await tester.pump();
      expect(find.byKey(QuickPick.pickFlightKey), findsNothing);
      expect(find.text(PickAction.clickTrack.title), findsNothing);
      expect(inList(find.byType(PlayMarker)), findsWidgets);
      expect(rowRects(tester), before);
    });

    testWidgets('115% text on 360dp: title and line wrap, Cancel keeps its '
        'size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.15;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, more: 9, size: const Size(360, 800));
      await openSongs(tester);
      await openMenu(tester);
      await tap(tester, find.text('Export a song…'));
      expect(tester.takeException(), isNull);
      final cancel = tester.getSize(find.byKey(QuickPick.exportPickCancelKey));
      final label = tester.getSize(
        find.descendant(
          of: find.byKey(QuickPick.exportPickCancelKey),
          matching: find.text('Cancel'),
        ),
      );
      expect(cancel.height, greaterThanOrEqualTo(40));
      expect(label.height, lessThan(15 * 1.15 * 2), reason: 'one line');
      final line = tester.getSize(
        find.text(PickAction.exportSong.line).hitTestable(),
      );
      expect(line.height, greaterThan(13 * 1.15 * 1.35 * 1.5), reason: 'wraps');
      final header = tester.getRect(find.byType(PickHeader).hitTestable());
      final title = tester.getRect(
        find.text(PickAction.exportSong.title).hitTestable(),
      );
      expect(header.contains(title.topLeft), isTrue);
      expect(title.bottom, lessThanOrEqualTo(header.bottom));
    });
  });

  testWidgets('Paste shared: the check ("1 song you already have, 1 new"), '
      'then Add set loads it at song 1 and closes the panel', (tester) async {
    await pump(tester);
    clipboard =
        'From the band:\n${setExport('Sat', [song('One', 100), song('Three', 120)])}';
    await openSetPanel(tester);
    await tap(tester, find.byKey(QuickPick.changeSetKey));
    await tap(tester, find.byKey(QuickPick.pasteSharedKey));
    expect(find.text('Add "Sat"?'), findsOneWidget);
    expect(find.text('2 songs.'), findsOneWidget);
    expect(find.text('1 song you already have, 1 new.'), findsOneWidget);
    await tap(tester, find.byKey(ShareDialogKeys.add));
    expect(library.activeSetlist!.name, 'Sat');
    expect(library.currentIndex, 0);
    expect(library.songs.map((s) => s.name), ['One', 'Two', 'Three']);
    expect(find.byType(QuickPick), findsNothing);
  });

  testWidgets('nothing Stikka-shaped: "Nothing to add"; the same set again: '
      '"You already have this set", and it opens', (tester) async {
    await pump(tester);
    clipboard = 'see you at 8';
    await openSetPanel(tester);
    await tap(tester, find.byKey(QuickPick.shareKey));
    await tap(tester, find.text('Import a set'));
    expect(find.text(ShareMenus.nothing), findsOneWidget);
    expect(find.text(ShareMenus.nothingLine), findsOneWidget);
    await tap(tester, find.byKey(ShareDialogKeys.ok));
    expect(library.setlists, hasLength(1));
    expect(find.byType(QuickPick), findsOneWidget, reason: 'stays open');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    clipboard = setExport('Fri', library.visibleSongs);
    library.playSingleSong(library.songsAZ.last, metronome);
    await tester.pump();
    await tap(tester, find.byKey(SetlistGroup.songsKey));
    await tap(tester, find.byKey(QuickPick.songsShareKey));
    await tap(tester, find.text('Import a song'));
    expect(find.text('You already have this set'), findsOneWidget);
    await tap(tester, find.byKey(ShareDialogKeys.ok));
    expect(library.activeSetlist!.name, 'Fri');
    expect(library.setlists, hasLength(1));
    expect(library.songs, hasLength(2));
  });

  testWidgets('a song with the same name and different music arrives as '
      '"(shared)" and loads in Single song', (tester) async {
    await pump(tester);
    clipboard = exportSongText(song('One', 150));
    await openSongs(tester);
    await tap(tester, find.byKey(QuickPick.songsShareKey));
    await tap(tester, find.text('Import a song'));
    expect(
      find.text('"One" is different from yours: added as "One (shared)".'),
      findsOneWidget,
    );
    await tap(tester, find.byKey(ShareDialogKeys.add));
    expect(library.currentSong!.name, 'One (shared)');
    expect(library.singleSong, isTrue);
    expect(metronome.bpm, 150);
    expect(library.songById(library.songsAZ.first.id)!.bpm, 100);
  });

  testWidgets('shared to Stikka from another app: the check opens on the '
      'main screen', (tester) async {
    await pump(tester);
    AndroidBridge.sharedText.value = setExport('Sun', [song('Four', 90)]);
    await tester.pumpAndSettle();
    expect(find.text('Add "Sun"?'), findsOneWidget);
    expect(AndroidBridge.sharedText.value, isNull, reason: 'taken once');
    await tap(tester, find.byKey(ShareDialogKeys.cancel));
    expect(library.setlists, hasLength(1), reason: 'Cancel adds nothing');
  });

  testWidgets('parts page: "Share this song" exports the song as it is '
      'there; not in unsaved Free play', (tester) async {
    await pump(tester);
    final context = tester.element(find.byType(SetlistGroup));
    openPartsPage(context, library, metronome);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(PartsPage.shareSongKey),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    // A small menu: the Stikka export, or the click track.
    await tap(tester, find.byKey(PartsPage.shareSongKey));
    expect(find.text('Export click track'), findsOneWidget);
    await tap(tester, find.text('Send to a Stikka user'));
    expect(parseShared(shared.single)!.songs.single.name, 'One');
    await tap(tester, find.byKey(PartsPage.shareSongKey));
    await tap(tester, find.text('Export click track'));
    expect(find.text(ClickExportSheet.title), findsOneWidget);
    expect(find.text('One.wav'), findsOneWidget);
    await tester.tapAt(const Offset(200, 20)); // outside: closes
    await tester.pumpAndSettle();
    expect(find.text(ClickExportSheet.title), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    library.detachSong();
    await tester.pump();
    openPartsPage(context, library, metronome);
    await tester.pumpAndSettle();
    expect(find.byKey(PartsPage.shareSongKey), findsNothing);
  });
}
