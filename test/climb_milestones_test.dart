import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/climb_milestones.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';

/// Batch 5 (N8, N12, N15, N24): what one completion reaches in its month.
void main() {
  group('between (pure)', () {
    for (final (year, month) in [
      (2027, 2),
      (2026, 9),
      (2026, 11),
      (2026, 10)
    ]) {
      final days = DateTime(year, month + 1, 0).day;
      test('$days-day month: a tier exactly when tierFor rises, never two', () {
        final max = MonthlyMedalRules.maxScore(year, month);
        for (var after = 0; after <= max; after++) {
          for (var points = 0; points <= 10 && points <= after; points++) {
            final m = ClimbMilestones.between(
                year: year,
                month: month,
                theme: ClimbThemes.greenSlope,
                stepsBefore: 0,
                stepsAfter: 0,
                scoreBefore: after - points,
                scoreAfter: after);
            final b = MonthlyMedalRules.tierFor(
                year: year, month: month, score: after - points);
            final a = MonthlyMedalRules.tierFor(
                year: year, month: month, score: after);
            expect(m.tier, a == b ? null : a, reason: '$after − $points');
            if (a != null && b != null) {
              expect(a.index - b.index, lessThanOrEqualTo(1));
            }
          }
        }
      });

      test('$days-day month: each save point and the flag on its own step', () {
        final reached = <String, int>{};
        for (var step = 1; step <= days; step++) {
          final m = ClimbMilestones.between(
              year: year,
              month: month,
              theme: ClimbThemes.greenSlope,
              stepsBefore: step - 1,
              stepsAfter: step,
              scoreBefore: 0,
              scoreAfter: 0);
          for (final p in m.savePoints) {
            expect(reached.containsKey(p.clearing), isFalse);
            reached[p.clearing] = step;
          }
        }
        expect(reached, {
          for (final p in ClimbSavePoints.all) p.clearing: p.reachedOn(days),
          'C6': days,
        });
        // An all-skipped day (no step) reaches nothing.
        expect(
            ClimbMilestones.between(
                    year: year,
                    month: month,
                    theme: ClimbThemes.greenSlope,
                    stepsBefore: 7,
                    stepsAfter: 7,
                    scoreBefore: 0,
                    scoreAfter: 0)
                .isEmpty,
            isTrue);
      });
    }

    test('the Day-0 test (the first step, at most 10 points) never crosses',
        () {
      final m = ClimbMilestones.between(
          year: 2026,
          month: 10,
          theme: ClimbThemes.greenSlope,
          stepsBefore: 0,
          stepsAfter: 1,
          scoreBefore: 0,
          scoreAfter: 10);
      expect(m.isEmpty, isTrue);
    });
  });

  group('afterCompletion (real SQLite)', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    const dbName = 'test_climb_milestones.db';
    late StorageService storage;
    late Database db;

    Future<void> entry(String day, {int correct = 5}) =>
        db.insert('climb_daily_entries', {
          'day': day,
          'completed_at': '${day}T12:00:00.000',
          'step': 1,
          'correct_count': correct,
          'wrong_count': 0,
          'skipped_count': 5 - correct,
          'rule_version': 1,
        });

    setUp(() async {
      final path = join(await getDatabasesPath(), dbName);
      await databaseFactory.deleteDatabase(path);
      StorageService.clockForTesting = () => DateTime(2026, 11, 7, 9);
      storage = StorageService(dbName: dbName);
      await storage.resolveClimbMonthTheme(2026, 11);
      db = await databaseFactory.openDatabase(path);
    });

    tearDown(() async {
      await db.close();
      StorageService.clockForTesting = DateTime.now;
    });

    test(
        'the 7th full day reaches C1 (70 points, no tier yet); the 8th '
        'crosses Bronze (75 of 300)', () async {
      for (var d = 1; d <= 7; d++) {
        await entry('2026-11-0$d');
      }
      var m = await ClimbMilestones.afterCompletion(
          storage: storage, day: '2026-11-07', step: 1, points: 10);
      expect(m!.tier, isNull);
      expect(m.theme, ClimbThemes.emberPeak);
      expect([for (final p in m.savePoints) p.clearing], ['C1']);
      expect((m.steps, m.score), (7, 70));

      await entry('2026-11-08');
      m = await ClimbMilestones.afterCompletion(
          storage: storage, day: '2026-11-08', step: 1, points: 10);
      expect(m!.tier, MedalTier.bronze);
      expect(m.savePoints, isEmpty);
    });

    test('N24: a month already finalized gives nothing', () async {
      for (var d = 1; d <= 9; d++) {
        await entry('2026-10-0$d');
      }
      StorageService.clockForTesting = () => DateTime(2026, 11, 7, 9);
      await storage.finalizePastMedalMonths();
      // A late October completion after October was frozen.
      await entry('2026-10-31');
      expect(
          await ClimbMilestones.afterCompletion(
              storage: storage, day: '2026-10-31', step: 1, points: 10),
          isNull);
    });
  });
}
