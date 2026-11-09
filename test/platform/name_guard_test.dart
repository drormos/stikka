import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No user-visible "Metra" (ui-spec.md › Name: the app is Stikka). The
/// lowercase IDs kept on purpose (`com.dror.metra`, `metra/…` channels)
/// never show, so only the capitalized name counts. The import code needs
/// no exception: it finds exports by content, not by "metra1:".
final _old = RegExp(r'\b(Metra|METRA)\b');

/// The lines of [path] that name the old app, as "path:line: text".
List<String> _hits(String path, {bool Function(String line)? skip}) => [
  for (final (i, line) in File(path).readAsLinesSync().indexed)
    if (_old.hasMatch(line) && !(skip?.call(line) ?? false))
      '$path:${i + 1}: ${line.trim()}',
];

void main() {
  test('no "Metra" in lib/ strings', () {
    final hits = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          // Comments aren't shown; every other line may hold a string.
          ..._hits(file.path, skip: (l) => l.trimLeft().startsWith('//')),
    ];
    expect(hits, isEmpty);
  });

  test(
    'no "Metra" in the Android labels, What\'s new or the store listing',
    () {
      final hits = [
        ..._hits('android/app/src/main/AndroidManifest.xml'),
        ..._hits('android/app/build.gradle.kts'),
        // The rename line says what the app used to be called.
        ..._hits('assets/whats_new.md', skip: (l) => l.contains('now called')),
        ..._hits('store/listing.md'),
      ];
      expect(hits, isEmpty);
    },
  );
}
