import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/month_transition.dart';
import 'package:grammar_lens/services/storage_service.dart';

import 'support/recording_analytics_sink.dart';

/// Batch 6 (M1–M3, M20): which month card a Home open gets. Real SQLite,
/// with both clocks (Home's `now` and the storage's) set to the same
/// instant.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const dbName = 'test_month_transition.db';
  late StorageService storage;
  late Database db;
  late RecordingAnalyticsSink sink;
  late AnalyticsService analytics;

  Future<void> at(DateTime now) async {
    StorageService.clockForTesting = () => now;
  }

  Future<MonthCardData?> load(DateTime now) async {
    await at(now);
    return MonthTransition.load(
        storage: storage, analytics: analytics, now: now);
  }

  Future<void> entry(String day, {int correct = 0, int wrong = 0}) =>
      db.insert('climb_daily_entries', {
        'day': day,
        'completed_at': '${day}T12:00:00.000',
        'step': correct + wrong > 0 ? 1 : 0,
        'correct_count': correct,
        'wrong_count': wrong,
        'skipped_count': correct + wrong > 0 ? 0 : 5,
        'rule_version': 1,
      });

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    await at(DateTime(2026, 10, 3, 9));
    storage = StorageService(dbName: dbName);
    // Opening the database; October's first view records its theme.
    await storage.resolveClimbMonthTheme(2026, 10);
    db = await databaseFactory.openDatabase(path);
    sink = RecordingAnalyticsSink();
    analytics = AnalyticsService(sink: sink);
  });

  tearDown(() async {
    await db.close();
    StorageService.clockForTesting = DateTime.now;
  });

  group('decide (pure)', () {
    test('none once seen, none for a user new this month', () {
      expect(
          MonthTransition.decide(
              cardSeen: true, usedBefore: true, previousSteps: 9),
          isNull);
      expect(
          MonthTransition.decide(
              cardSeen: false, usedBefore: false, previousSteps: 9),
          isNull);
    });
    test('summary with a step last month, fresh without', () {
      expect(
          MonthTransition.decide(
              cardSeen: false, usedBefore: true, previousSteps: 1),
          MonthCardVariant.summary);
      expect(
          MonthTransition.decide(
              cardSeen: false, usedBefore: true, previousSteps: 0),
          MonthCardVariant.fresh);
    });
    test('the previous month across a year', () {
      expect(MonthTransition.previousMonth(2027, 1), (2026, 12));
      expect(MonthTransition.previousMonth(2026, 11), (2026, 10));
    });
  });

  test(
      'the month\'s first open shows the summary card, from the frozen '
      'medal, with the new month\'s theme', () async {
    for (var d = 1; d <= 24; d++) {
      await entry('2026-10-${d.toString().padLeft(2, '0')}',
          correct: d <= 12 ? 5 : 4, wrong: d <= 12 ? 0 : 1);
    }
    // 12 × 10 + 12 × 9 = 228: Silver, 5 short of Gold (233).
    final card = await load(DateTime(2026, 11, 1, 8));
    expect(card, isNotNull);
    expect(card!.variant, MonthCardVariant.summary);
    expect((card.year, card.month), (2026, 11));
    expect(card.theme, ClimbThemes.emberPeak);
    expect((card.previousYear, card.previousMonth), (2026, 10));
    expect(card.tier, MedalTier.silver);
    expect((card.steps, card.days, card.score), (24, 31, 228));
    expect(card.nearMiss, (MedalTier.gold, 5));
    // The card froze October itself and reported it once.
    expect(sink.events.where((e) => e.name == 'medal_month_finalized'),
        hasLength(1));
    expect((await storage.getMonthlyMedalResults()).single.month, 10);
  });

  test('the same month\'s second open shows nothing once dismissed', () async {
    await entry('2026-10-02', correct: 5);
    expect(await load(DateTime(2026, 11, 1, 8)), isNotNull);
    await MonthTransition.markSeen(storage, 2026, 11);
    expect(await load(DateTime(2026, 11, 1, 9)), isNull);
    expect(await load(DateTime(2026, 11, 20, 9)), isNull);
    // December is a new month.
    expect(await load(DateTime(2026, 12, 1, 9)), isNotNull);
  });

  test('a card open when the app is closed (not dismissed) shows again',
      () async {
    await entry('2026-10-02', correct: 5);
    expect(await load(DateTime(2026, 11, 1, 8)), isNotNull);
    // No markSeen: the app was closed with the card open. A restart:
    storage = StorageService(dbName: dbName);
    expect(await load(DateTime(2026, 11, 1, 10)), isNotNull);
  });

  test(
      'months skipped: one card, for the month the user is in, fresh '
      'because the previous month has no step', () async {
    await entry('2026-10-02', correct: 5);
    final card = await load(DateTime(2027, 2, 14, 8));
    expect(card!.variant, MonthCardVariant.fresh);
    expect((card.year, card.month), (2027, 2));
    expect((card.previousYear, card.previousMonth), (2027, 1));
    expect(card.theme, ClimbThemeRotation.shownFor(2027, 2));
    await MonthTransition.markSeen(storage, 2027, 2);
    expect(await load(DateTime(2027, 2, 15, 8)), isNull);
  });

  test('a previous month with only all-skipped days is a fresh start',
      () async {
    await entry('2026-10-02');
    final card = await load(DateTime(2026, 11, 2, 8));
    expect(card!.variant, MonthCardVariant.fresh);
  });

  test('no card in the month a user starts in', () async {
    // A fresh database whose first Home view is in November.
    final path = join(await getDatabasesPath(), 'test_month_transition_new.db');
    await databaseFactory.deleteDatabase(path);
    await at(DateTime(2026, 11, 5, 8));
    final fresh = StorageService(dbName: 'test_month_transition_new.db');
    await fresh.resolveClimbMonthTheme(2026, 11);
    expect(
        await MonthTransition.load(
            storage: fresh,
            analytics: analytics,
            now: DateTime(2026, 11, 5, 8)),
        isNull);
    // Its next month gets one.
    await at(DateTime(2026, 12, 1, 8));
    expect(
        await MonthTransition.load(
            storage: fresh,
            analytics: analytics,
            now: DateTime(2026, 12, 1, 8)),
        isNotNull);
  });

  test('1.0 history without theme rows still counts as a returning user',
      () async {
    await db.delete('climb_month_themes');
    await entry('2026-09-20', correct: 5);
    expect(await storage.hasClimbHistoryBefore(2026, 11), isTrue);
    expect((await load(DateTime(2026, 11, 1, 8)))!.variant,
        MonthCardVariant.fresh);
  });

  test('without a medal, the near-miss gap is to Bronze', () async {
    // 74 points in October: 4 short of Bronze (78).
    for (var d = 1; d <= 7; d++) {
      await entry('2026-10-0$d', correct: 5);
    }
    await entry('2026-10-08', correct: 2);
    final card = await load(DateTime(2026, 11, 1, 8));
    expect(card!.tier, isNull);
    expect(card.score, 74);
    expect(card.nearMiss, (MedalTier.bronze, 4));
  });

  test('a storage error is no card', () async {
    final broken = _BrokenStorage();
    expect(
        await MonthTransition.load(
            storage: broken,
            analytics: analytics,
            now: DateTime(2026, 11, 1, 8)),
        isNull);
  });

  test('hasOneTimeFlag reads without claiming', () async {
    const key = 'month_card:2026-11';
    expect(StorageService.monthCardSeenFlag(2026, 11), key);
    expect(StorageService.monthZoomFlag(2026, 11), 'month_zoom:2026-11');
    expect(await storage.hasOneTimeFlag(key), isFalse);
    expect(await storage.hasOneTimeFlag(key), isFalse);
    expect(await storage.claimOneTimeFlag(key), isTrue);
    expect(await storage.hasOneTimeFlag(key), isTrue);
  });
}

class _BrokenStorage extends StorageService {
  @override
  Future<bool> hasOneTimeFlag(String key) => throw StateError('no db');
}
