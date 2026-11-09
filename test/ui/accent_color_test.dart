import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stikka/src/model/library.dart';
import 'package:stikka/src/ui/editor_scaffold.dart';
import 'package:stikka/src/ui/theme.dart';

/// ui-spec.md "Color (the user's accent color)": the token table.
void main() {
  // SB accent (= primary), SB sounding, SB resting, SB pulse resting,
  // Daylight accent (= sounding), Daylight resting, Daylight pulse resting.
  const table = {
    AccentColor.red: [
      0xFFFF3B30, 0xFFFF4A3D, 0xFF8E2620, 0xFF5A1A16, //
      0xFFD7261E, 0xFFE9B0AA, 0xFFF0CCC8,
    ],
    AccentColor.orange: [
      0xFFFF9500, 0xFFFF9D14, 0xFF8C5200, 0xFF593400, //
      0xFFA85200, 0xFFD6B592, 0xFFE1CBB3,
    ],
    AccentColor.yellow: [
      0xFFFFD60A, 0xFFFFD91E, 0xFF8C7606, 0xFF594B04, //
      0xFF8A6A00, 0xFFCBBE92, 0xFFDAD1B3,
    ],
    AccentColor.green: [
      0xFF30D158, 0xFF41D565, 0xFF1A7330, 0xFF11491F, //
      0xFF1B7F37, 0xFFA1C6A7, 0xFFBFD6C1,
    ],
    AccentColor.blue: [
      0xFF0A84FF, 0xFF1E8EFF, 0xFF06498C, 0xFF042E59, //
      0xFF0A62C4, 0xFF9ABBDD, 0xFFBBCFE2,
    ],
    AccentColor.purple: [
      0xFFBF5AF2, 0xFFC467F3, 0xFF693285, 0xFF431F55, //
      0xFF8A3CB8, 0xFFCBACD8, 0xFFDAC6E0,
    ],
  };

  List<int> accents(StikkaColors c) => [
    c.accent,
    c.accentSounding,
    c.accentResting,
    c.pulseAccentResting,
    c.primary,
  ].map((c) => c.toARGB32()).toList();

  /// Every token but the accent ones.
  List<int> rest(StikkaColors c) => [
    c.background,
    c.sheet,
    c.dim,
    c.lifted,
    c.slot,
    c.shadow,
    c.surface,
    c.surfaceOnSheet,
    c.divider,
    c.selectedRow,
    c.border,
    c.text,
    c.muted,
    c.beatResting,
    c.beatSounding,
    c.mutedFill,
    c.mutedLine,
    c.tickResting,
    c.tickSounding,
    c.pulseResting,
    c.pulseMutedLine,
    c.disabledText,
    c.controlOutline,
    c.onPrimary,
    c.danger,
    c.dangerResting,
  ].map((c) => c.toARGB32()).toList();

  for (final MapEntry(key: color, value: v) in table.entries) {
    test('${color.label}: tokens match the table in both themes', () {
      final dark = StikkaColors.of(Brightness.dark, color);
      expect(accents(dark), [v[0], v[1], v[2], v[3], v[0]]);
      expect(rest(dark), rest(StikkaColors.stageBlack));
      final light = StikkaColors.of(Brightness.light, color);
      expect(accents(light), [
        v[4],
        v[4],
        v[5],
        v[6],
        0xFF111111,
      ], reason: "Daylight's primary button stays black");
      expect(rest(light), rest(StikkaColors.daylight));
      expect(CoverColors.needle(color), dark.accent);
    });
  }

  test('Red is today\'s palette; danger is red in every color', () {
    expect(
      accents(StikkaColors.of(Brightness.dark, AccentColor.red)),
      accents(StikkaColors.stageBlack),
    );
    expect(
      accents(StikkaColors.of(Brightness.light, AccentColor.red)),
      accents(StikkaColors.daylight),
    );
    for (final color in AccentColor.values) {
      expect(
        StikkaColors.of(Brightness.dark, color).danger.toARGB32(),
        0xFFFF3B30,
      );
      expect(
        StikkaColors.of(Brightness.light, color).danger.toARGB32(),
        0xFFD7261E,
      );
    }
  });

  test('a new color crossfades; a theme switch snaps', () {
    final red = StikkaColors.of(Brightness.dark, AccentColor.red);
    final blue = StikkaColors.of(Brightness.dark, AccentColor.blue);
    final mid = red.lerp(blue, 0.5);
    expect(mid.accent, Color.lerp(red.accent, blue.accent, 0.5));
    expect(mid.danger, red.danger);
    expect(red.lerp(StikkaColors.daylight, 0.4), same(red));
    expect(red.lerp(StikkaColors.daylight, 0.6), same(StikkaColors.daylight));
  });

  testWidgets('a delete dialog in Green: Delete stays red', (tester) async {
    final green = StikkaColors.of(Brightness.dark, AccentColor.green);
    await tester.pumpWidget(
      MaterialApp(
        theme: stikkaTheme(green, Brightness.dark),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmDelete(context, title: 'Delete Song?'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byKey(deleteConfirmKey));
    expect(
      button.style!.backgroundColor!.resolve({}),
      StikkaColors.stageBlack.danger,
    );
  });
}
