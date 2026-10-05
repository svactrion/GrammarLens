import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/screens/debug_panel_screen.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/debug_sample_collection.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_month_card.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

import 'support/recording_analytics_sink.dart';

/// Any medal read or write fails the test, except the running month's
/// progress, the one record the sample collection reads.
class _UntouchedStorage extends StorageService {
  static final running = MonthlyMedalProgress(
      year: 2026,
      month: 11,
      score: 131,
      maxScore: MonthlyMedalRules.maxScore(2026, 11),
      activeDays: 14,
      correct: 0,
      wrong: 0,
      skipped: 0);
  final calls = <String>[];
  bool sampleMode = false;
  Never _no(String name) {
    calls.add(name);
    throw StateError('storage touched: $name');
  }

  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async =>
      _no('finalizePastMedalMonths');
  @override
  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() async {
    if (sampleMode) {
      calls.add('getCurrentMonthlyMedalProgress');
      return running;
    }
    return _no('getCurrentMonthlyMedalProgress');
  }

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async =>
      _no('getMonthlyMedalResults');
  @override
  Future<WelcomeBadge?> getWelcomeBadge() async => _no('getWelcomeBadge');
  @override
  Future<Map<(int, int), String>> getClimbMonthThemes() async =>
      _no('getClimbMonthThemes');
}

/// P6: the debug panel's sample collection on Profile's shelf.
void main() {
  final now = DateTime(2026, 11, 14, 10);
  setUp(() => DebugSampleCollection.clockForTesting = () => now);
  tearDown(() {
    DebugSampleCollection.runtime = false;
    DebugSampleCollection.clockForTesting = DateTime.now;
    DebugTools.enabledForTesting = true;
  });

  test(
      'the sample: the Welcome badge, eight finished months in all four '
      'themes and every tier, and the running month (ten slots: no medal '
      'alone on a row of five or eight)', () {
    final s = DebugSampleCollection.sample(now);
    expect(s.results, hasLength(8));
    final slots = 1 + s.results.length + 1;
    expect(slots % 5, isNot(1));
    expect(slots % 8, isNot(1));
    expect(s.progress.year, 2026);
    expect(s.progress.month, 11);
    expect(s.results.first.month, 10);
    expect(s.results.last.month, 3);
    expect({for (final r in s.results) r.tier},
        {MedalTier.bronze, MedalTier.silver, MedalTier.gold});
    expect(s.themeIds.values.toSet(), {for (final t in ClimbThemes.all) t.id});
    expect(s.themeIds[(2026, 11)], ClimbThemeRotation.shownFor(2026, 11).id);
    expect(s.welcomeBadge.earnedAt.isBefore(DateTime(2026, 3, 31)), isTrue);
    expect(s.progress.score < s.progress.maxScore, isTrue);
  });

  test('last month is the month card\'s Gold summary', () {
    final card =
        ClimbDebugMonthCard.sample(ClimbDebugMonthCardValue.summaryGold, now)!;
    final last = DebugSampleCollection.sample(now).results.first;
    final s = DebugSampleCollection.sample(now);
    expect((last.year, last.month), (card.previousYear, card.previousMonth));
    expect(last.tier, card.tier);
    expect(last.tier, MedalTier.gold);
    expect(last.score, card.score);
    expect(last.activeDays, card.steps);
    expect(s.themeIds[(last.year, last.month)], card.previousTheme.id);
    expect(s.themeIds[(2026, 11)], card.theme.id);
  });

  test('the running month is the stored progress when given', () {
    final s =
        DebugSampleCollection.sample(now, progress: _UntouchedStorage.running);
    expect(s.progress, same(_UntouchedStorage.running));
  });

  test('off by default, and never on where the debug tools are off', () {
    expect(DebugSampleCollection.enabled, isFalse);
    DebugSampleCollection.runtime = true;
    expect(DebugSampleCollection.enabled, isTrue);
    DebugTools.enabledForTesting = false;
    expect(DebugSampleCollection.enabled, isFalse);
  });

  Future<(_UntouchedStorage, RecordingAnalyticsSink)> pumpProfile(
      WidgetTester tester,
      {bool sampleMode = false}) async {
    tester.view.physicalSize = const Size(430, 2400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = _UntouchedStorage()..sampleMode = sampleMode;
    final sink = RecordingAnalyticsSink();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: SettingsScreen(
        active: true,
        themeMode: AppThemeMode.system,
        onSelectThemeMode: (_) {},
        textSize: AppTextSize.medium,
        onSelectTextSize: (_) {},
        profile:
            const UserProfile(name: 'Ada', learningGoal: LearningGoal.general),
        storageService: storage,
        onProfileUpdated: (_) {},
        onResetOnboarding: () {},
        analyticsService: AnalyticsService(sink: sink),
      ),
    ));
    await tester.pumpAndSettle();
    return (storage, sink);
  }

  testWidgets(
      'on: Profile shows the sample on the shelf with the stored running '
      'month, reads no other medal record, writes none and sends no event',
      (tester) async {
    DebugSampleCollection.runtime = true;
    final (storage, sink) = await pumpProfile(tester, sampleMode: true);
    expect(storage.calls, ['getCurrentMonthlyMedalProgress']);
    expect(sink.events, isEmpty);
    // The running month's points, now on the progress card (1.2.0 Batch 7;
    // it was the bar's "N points" label).
    expect(
        find.textContaining(
            'Monthly total: ${_UntouchedStorage.running.score} / '),
        findsOneWidget);
    expect(find.byType(MonthlyMedalCollection), findsOneWidget);
    expect(find.byKey(MonthlyMedalCollection.welcomeSlotKey), findsOneWidget);
    for (final r in DebugSampleCollection.sample(now).results) {
      expect(find.byKey(MonthlyMedalCollection.slotKey(r.year, r.month)),
          findsOneWidget);
    }
    expect(
        find.byKey(MonthlyMedalCollection.slotKey(2026, 11)), findsOneWidget);
  });

  testWidgets('off: Profile reads storage as before', (tester) async {
    final (storage, _) = await pumpProfile(tester);
    expect(storage.calls, contains('finalizePastMedalMonths'));
  });

  testWidgets('the debug panel switches it, in memory only', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: DebugPanelScreen(onResetLocalData: () async {}),
    ));
    final toggle = find.byKey(DebugPanelScreen.sampleCollectionKey);
    await tester.scrollUntilVisible(toggle, 200);
    await tester.tap(toggle);
    await tester.pump();
    expect(DebugSampleCollection.runtime, isTrue);
    await tester.tap(toggle);
    await tester.pump();
    expect(DebugSampleCollection.runtime, isFalse);
  });
}
