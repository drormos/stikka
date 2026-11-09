import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikka/src/model/library.dart';
import 'package:stikka/src/ui/media_cover.dart';
import 'package:stikka/src/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('SairaExtraCondensed')
      ..addFont(rootBundle.load('assets/fonts/SairaExtraCondensed-Bold.ttf'));
    await loader.load();
  });

  test('renders a square PNG', () async {
    final png = await renderMediaCover(120);
    expect(png.sublist(1, 4), 'PNG'.codeUnits);
    // Width and height from the IHDR chunk: 512 × 512.
    final header = ByteData.sublistView(png, 16, 24);
    expect(header.getUint32(0), 512);
    expect(header.getUint32(4), 512);
    final out = Platform.environment['STIKKA_COVER_OUT'];
    if (out != null) File(out).writeAsBytesSync(png);
  });

  test('the needle is in the chosen color (its Stage Black value)', () async {
    Future<Set<int>> centreColumn(AccentColor color) async {
      final png = await renderMediaCover(120, color: color);
      final out = Platform.environment['STIKKA_COVER_OUT_${color.name}'];
      if (out != null) File(out).writeAsBytesSync(png);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      final rgba = (await image.toByteData())!;
      return {
        for (var y = 0; y < 512; y++)
          // ARGB from RGBA at x = 256.
          (0xFF << 24) | (rgba.getUint32((y * 512 + 256) * 4) >> 8),
      };
    }

    final blue = StikkaColors.of(ui.Brightness.dark, AccentColor.blue).accent;
    final red = StikkaColors.stageBlack.accent;
    final blueColumn = await centreColumn(AccentColor.blue);
    expect(blueColumn, contains(blue.toARGB32()));
    expect(blueColumn, isNot(contains(red.toARGB32())));
    expect(await centreColumn(AccentColor.red), contains(red.toARGB32()));
  });

  test('one file per tempo and color, written once', () async {
    final dir = Directory.systemTemp.createTempSync('stikka_cover');
    addTearDown(() => dir.deleteSync(recursive: true));
    final uri = await mediaCoverFile(dir, 96);
    expect(uri.pathSegments.last, 'media_cover_96_red.png');
    final written = File.fromUri(uri).lastModifiedSync();
    await mediaCoverFile(dir, 96);
    expect(File.fromUri(uri).lastModifiedSync(), written);
    final blue = await mediaCoverFile(dir, 96, color: AccentColor.blue);
    expect(blue.pathSegments.last, 'media_cover_96_blue.png');
  });
}
