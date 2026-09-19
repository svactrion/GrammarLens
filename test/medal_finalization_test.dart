import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/medal_finalization.dart';
import 'package:grammar_lens/services/storage_service.dart';

import 'support/recording_analytics_sink.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const dbName = 'test_medal_finalization.db';
  late StorageService storage;
  late Database db;
  late RecordingAnalyticsSink sink;
  late AnalyticsService analytics;

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    StorageService.clockForTesting = () => DateTime(2026, 12, 2, 9);
    storage = StorageService(dbName: dbName);
    await storage.getCurrentMonthlyMedalProgress();
    db = await databaseFactory.openDatabase(path);
    sink = RecordingAnalyticsSink();
    analytics = AnalyticsService(sink: sink);
  });

  tearDown(() async {
    await db.close();
    StorageService.clockForTesting = DateTime.now;
  });

  test('reports one medal_month_finalized per newly frozen month', () async {
    // October: 3 correct-only days => 30 of 310 (9.7 % rounds to 10), below Bronze.
    for (final day in ['01', '02', '03']) {
      await _entry(db, '2026-10-$day', correct: 5);
    }
    // November: 23 days of 5 correct => 230 of 300 => Gold, 77 %.
    for (var d = 1; d <= 23; d++) {
      await _entry(db, '2026-11-${d.toString().padLeft(2, '0')}', correct: 5);
    }

    await finalizePastMedalMonthsAndReport(
      storageService: storage,
      analyticsService: analytics,
    );

    final events = sink.named('medal_month_finalized');
    expect(events.map((e) => e.parameters), [
      {
        'tier': 'none',
        'score_pct': 10,
        'active_days': 3,
        'days_in_month': 31,
        'rule_version': 1,
        'months_ago': 2,
      },
      {
        'tier': 'gold',
        'score_pct': 77,
        'active_days': 23,
        'days_in_month': 30,
        'rule_version': 1,
        'months_ago': 1,
      },
    ]);
  });

  test('launch + resume + Profile triggers never double-report a month',
      () async {
    await _entry(db, '2026-11-04', correct: 5);

    // Three triggers racing/repeating: app launch, resume, Profile open.
    await Future.wait([
      finalizePastMedalMonthsAndReport(
          storageService: storage, analyticsService: analytics),
      finalizePastMedalMonthsAndReport(
          storageService: storage, analyticsService: analytics),
    ]);
    await finalizePastMedalMonthsAndReport(
        storageService: storage, analyticsService: analytics);

    expect(sink.named('medal_month_finalized'), hasLength(1));
    expect(await storage.getMonthlyMedalResults(), hasLength(1));
  });

  test('a user with no history reports nothing', () async {
    await finalizePastMedalMonthsAndReport(
        storageService: storage, analyticsService: analytics);
    expect(sink.events, isEmpty);
  });
}

Future<void> _entry(Database db, String day, {int correct = 0}) =>
    db.insert('climb_daily_entries', {
      'day': day,
      'completed_at': '${day}T12:00:00.000',
      'step': correct > 0 ? 1 : 0,
      'correct_count': correct,
      'wrong_count': 0,
      'skipped_count': 5 - correct,
      'rule_version': 1,
    });
