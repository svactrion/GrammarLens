import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/utils/suggested_focus.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';

import '../tool/screenshots/seed.dart';

/// The App Store screenshots' seeded learner (`tool/screenshots/seed.dart`,
/// 1.2.0): what each frame relies on, on a real SQLite file.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const dbName = 'test_screenshot_seed.db';
  late StorageService storage;

  Future<void> seedAt(DateTime now, {bool premium = false}) async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    StorageService.clockForTesting = () => now;
    storage = StorageService(dbName: dbName);
    await seedScreenshotData(storage, now: now, premium: premium);
  }

  tearDown(() {
    StorageService.clockForTesting = DateTime.now;
    StorageService.themeForNewMonthForTesting = ClimbThemeRotation.shownFor;
  });

  final now = DateTime(2026, 10, 6, 9, 41);

  test('the learner is made up: Sam, the Fox, exam prep', () async {
    await seedAt(now);
    final profile = (await storage.getUserProfile())!;
    expect(profile.name, 'Sam');
    expect(profile.avatar!.semanticLabel, 'Fox');
    expect(profile.learningGoal, LearningGoal.examPrep);
  });

  test('each month is recorded with its own theme, Glacier Peak only now',
      () async {
    await seedAt(now);
    final themes = await storage.getClimbMonthThemes();
    expect(themes, {
      (2026, 7): ClimbThemes.greenSlope.id,
      (2026, 8): ClimbThemes.emberPeak.id,
      (2026, 9): ClimbThemes.redCanyon.id,
      (2026, 10): ClimbThemes.glacierPeak.id,
    });
    expect(themes.values.toSet(), hasLength(4));
    // What Home reads for this month.
    expect(await storage.resolveClimbMonthTheme(2026, 10),
        ClimbThemes.glacierPeak.id);
  });

  test('the seed puts the storage clock back as it found it', () async {
    await seedAt(now);
    expect(StorageService.clockForTesting(), now);
  });

  test('July, August and September end on Bronze, Silver and Gold', () async {
    await seedAt(now);
    final results = await storage.getMonthlyMedalResults();
    expect([
      for (final r in results) (r.year, r.month, r.tier)
    ], [
      (2026, 9, MedalTier.gold),
      (2026, 8, MedalTier.silver),
      (2026, 7, MedalTier.bronze),
    ]);
    // The app's own launch finalization finds nothing left to freeze.
    expect(await storage.finalizePastMedalMonths(), isEmpty);
  });

  test('the months before wrap into the previous year in January', () async {
    await seedAt(DateTime(2027, 1, 20, 9, 41));
    final results = await storage.getMonthlyMedalResults();
    expect([
      for (final r in results) (r.year, r.month, r.tier)
    ], [
      (2026, 12, MedalTier.gold),
      (2026, 11, MedalTier.silver),
      (2026, 10, MedalTier.bronze),
    ]);
  });

  test('this month stops one step short of Halfway Hut, today not taken',
      () async {
    await seedAt(now);
    final progress = await storage.getCurrentMonthlyMedalProgress();
    final hut = ClimbSavePoints.all.firstWhere((p) => p.object == 'cabin');
    expect(progress.activeDays, hut.reachedOn(31) - 1);

    final today = (await storage.getDailyTestSetForToday())!;
    expect(today.completedAt, isNull);

    // Today's live result (four right, one wrong) crosses no medal
    // threshold, so the result frame shows explanations, not a celebration.
    final todayPoints = MonthlyMedalRules.score(correct: 4, wrong: 1);
    for (final tier in MedalTier.values) {
      final t = MonthlyMedalRules.threshold(2026, 10, tier);
      expect(progress.score < t && progress.score + todayPoints >= t, isFalse,
          reason: tier.name);
    }
    expect(screenshotTodayAnswers.first, 'to eat');
  });

  test("Suggested Focus has a clear first choice: Modal Verbs, three times",
      () async {
    await seedAt(now);
    final spots =
        await storage.getWeakSpots(limit: StorageService.allWeakSpots);
    final focus = suggestedFocus(spots)!;
    expect(focus.topicId, 'modalVerbs');
    expect(focus.frequency, 3);
    expect(spots.where((s) => s.frequency == 3), hasLength(1));
  });

  test('nothing opens over Home: day-0 paywall, zooms, month card', () async {
    await seedAt(now);
    for (final flag in [
      StorageService.day0PaywallFlag,
      StorageService.firstRunZoomFlag,
      StorageService.monthZoomFlag(2026, 10),
      StorageService.monthCardSeenFlag(2026, 10),
    ]) {
      expect(await storage.hasOneTimeFlag(flag), isTrue, reason: flag);
    }
  });

  test('free stores no entitlement override, premium stores one', () async {
    await seedAt(now);
    expect(await storage.getDebugAccessOverride(), isNull);
    await seedAt(now, premium: true);
    expect(await storage.getDebugAccessOverride(), isTrue);
  });

  test('an install that already has a profile is left as it is', () async {
    await seedAt(now);
    final before = await storage.getMonthlyMedalResults();
    await seedScreenshotData(storage, now: now, premium: true);
    expect(await storage.getMonthlyMedalResults(), hasLength(before.length));
    expect(await storage.getDebugAccessOverride(), isNull);
  });
}
