import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';

/// Monthly themes as data, the global-calendar rotation, and the rule that
/// what is recorded for a month is what the month is shown with.
void main() {
  group('registry', () {
    test('four themes in rotation order, with their names and taglines', () {
      expect(ClimbThemes.all.map((t) => (t.id, t.name, t.tagline)), [
        (
          'green_slope',
          'Green Slope',
          'Green slopes and an easy trail to find your rhythm.'
        ),
        (
          'ember_peak',
          'Ember Peak',
          'Smoke on the ridge, warm rock underfoot.'
        ),
        (
          'glacier_peak',
          'Glacier Peak',
          'Thin air, bright ice, and a view worth the climb.'
        ),
        (
          'red_canyon',
          'Red Canyon',
          'Sun-baked rock and a mesa waiting at the top.'
        ),
      ]);
    });

    test('all four are ready, each with its light and dark images (Batch 4)',
        () {
      expect(ClimbThemes.all.every((t) => t.ready), isTrue);
      for (final theme in ClimbThemes.all) {
        expect(theme.backgroundFor(Brightness.light),
            'assets/climb/${theme.id}/background_light.webp');
        expect(theme.backgroundFor(Brightness.dark),
            'assets/climb/${theme.id}/background_dark.webp');
        // The palettes only colour the dots and the loading fill now; every
        // theme shares Green Slope's.
        expect(theme.lightPalette, same(ClimbThemes.greenSlope.lightPalette));
        expect(theme.darkPalette, same(ClimbThemes.greenSlope.darkPalette));
        // G4 (Batch 4): the flag stands on C6, whatever the summit's shape,
        // so every theme draws it.
        expect(theme.hasSummitFlag, isTrue, reason: theme.id);
      }
    });

    test('an unknown id falls back to Green Slope', () {
      expect(ClimbThemes.byId('ember_peak'), ClimbThemes.emberPeak);
      expect(ClimbThemes.byId('from_a_newer_build'), ClimbThemes.greenSlope);
    });

    // The values ClimbPalette.of(brightness) returned in theme.dart before
    // the palette moved here, copied literally.
    test('Green Slope light palette is unchanged by the move', () {
      final p = ClimbThemes.greenSlope.paletteFor(Brightness.light);
      expect([
        p.sky,
        p.mountain,
        p.ridge,
        p.trail,
        p.stone,
        p.ink,
        p.accent
      ], const [
        Color(0xFFEAF0EC),
        Color(0xFFACC4AC),
        Color(0xFF789B86),
        Color(0xFFD9CCAC),
        Color(0xFFF5F0DF),
        Color(0xFF263D39),
        Color(0xFFFF7A1A),
      ]);
      expect(p.accent, buildAppTheme(Brightness.light).colorScheme.primary);
    });

    test('Green Slope dark palette is unchanged by the move', () {
      final p = ClimbThemes.greenSlope.paletteFor(Brightness.dark);
      expect([
        p.sky,
        p.mountain,
        p.ridge,
        p.trail,
        p.stone,
        p.ink,
        p.accent
      ], const [
        Color(0xFF182327),
        Color(0xFF405C53),
        Color(0xFF2E463F),
        Color(0xFF8E8874),
        Color(0xFFC8C8B9),
        Color(0xFFE4E2D8),
        Color(0xFFFF8A3D),
      ]);
      expect(p.accent, buildAppTheme(Brightness.dark).colorScheme.primary);
    });
  });

  group('rotation', () {
    String scheduled(int year, int month) =>
        ClimbThemeRotation.scheduledFor(year, month).id;

    test('October 2026 is the anchor, then one theme a month, repeating', () {
      expect(scheduled(2026, 10), 'green_slope');
      expect(scheduled(2026, 11), 'ember_peak');
      expect(scheduled(2026, 12), 'glacier_peak');
      expect(scheduled(2027, 1), 'red_canyon');
      expect(scheduled(2027, 2), 'green_slope');
      expect(scheduled(2027, 3), 'ember_peak');
      expect(scheduled(2028, 10), 'green_slope');
    });

    test('months before October 2026 are Green Slope', () {
      expect(scheduled(2026, 9), 'green_slope');
      expect(scheduled(2026, 7), 'green_slope');
      expect(scheduled(2025, 12), 'green_slope');
    });

    test('every theme is ready, so a month is shown with its scheduled theme',
        () {
      expect(ClimbThemeRotation.shownFor(2026, 10), ClimbThemes.greenSlope);
      expect(ClimbThemeRotation.shownFor(2026, 11), ClimbThemes.emberPeak);
      expect(ClimbThemeRotation.shownFor(2026, 12), ClimbThemes.glacierPeak);
      expect(ClimbThemeRotation.shownFor(2027, 1), ClimbThemes.redCanyon);
      for (var i = 0; i < 24; i++) {
        final m = DateTime(2026, 10 + i);
        expect(ClimbThemeRotation.shownFor(m.year, m.month),
            ClimbThemeRotation.scheduledFor(m.year, m.month));
      }
    });
  });

  group('recorded theme', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Directory dir;
    late StorageService storage;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('climb-theme-test-');
      storage = StorageService(dbName: join(dir.path, 'app.db'));
    });

    tearDown(() async {
      await dir.delete(recursive: true);
      StorageService.clockForTesting = DateTime.now;
      StorageService.themeForNewMonthForTesting = ClimbThemeRotation.shownFor;
    });

    test('November 2026 is recorded as Ember Peak', () async {
      StorageService.clockForTesting = () => DateTime(2026, 11, 3);
      expect(await storage.resolveClimbMonthTheme(2026, 11), 'ember_peak');
    });

    test('a month keeps its recorded theme when the rotation changes later',
        () async {
      StorageService.clockForTesting = () => DateTime(2026, 11, 3);
      expect(await storage.resolveClimbMonthTheme(2026, 11), 'ember_peak');

      // A later build changes the rotation while November is running.
      StorageService.themeForNewMonthForTesting =
          (year, month) => ClimbThemes.greenSlope;
      expect(await storage.resolveClimbMonthTheme(2026, 11), 'ember_peak');

      // The next month gets its theme from the new rotation.
      StorageService.clockForTesting = () => DateTime(2026, 12, 1);
      expect(await storage.resolveClimbMonthTheme(2026, 12), 'green_slope');
      expect(await storage.resolveClimbMonthTheme(2026, 11), 'ember_peak');
    });
  });
}
