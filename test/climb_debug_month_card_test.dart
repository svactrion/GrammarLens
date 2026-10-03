import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/month_transition.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_day.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_month_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'support/month_card_support.dart';
import 'support/recording_analytics_sink.dart';

/// Storage that records every "seen" record access: the replay must never
/// read or write them. (Recorded, not thrown: `MonthTransition.load`
/// swallows errors, which would hide a throw.)
class _NoFlagsStorage extends CardStorage {
  _NoFlagsStorage() : super();
  final List<String> flagCalls = [];
  @override
  Future<bool> hasOneTimeFlag(String key) async {
    flagCalls.add('read $key');
    return false;
  }

  @override
  Future<bool> claimOneTimeFlag(String key) async {
    flagCalls.add('write $key');
    return true;
  }
}

/// `CLIMB_DEBUG_MONTH_CARD` (Batch 6, M9, M17, M18).
void main() {
  tearDown(() {
    ClimbDebugMonthCard.valueForTesting = null;
    ClimbDebugMonthCard.eventsForTesting = null;
    ClimbDebugTheme.valueForTesting = null;
    ClimbDebugDay.valueForTesting = null;
  });

  test('release ignores it; debug and profile apply it; unknown is nothing',
      () {
    for (final v in ClimbDebugMonthCardValue.values) {
      expect(ClimbDebugMonthCard.resolve(enabled: false, defined: v.wireName),
          isNull);
      expect(
          ClimbDebugMonthCard.resolve(enabled: true, defined: v.wireName), v);
    }
    expect(ClimbDebugMonthCard.resolve(enabled: true, defined: ''), isNull);
    expect(ClimbDebugMonthCard.resolve(enabled: true, defined: 'gold'), isNull);
    expect(ClimbDebugMonthCardValue.values.map((v) => v.wireName),
        ['summary_gold', 'summary_none', 'summary_near', 'fresh', 'first_run']);
  });

  test('the test suite runs without the define; events are off by default', () {
    expect(ClimbDebugMonthCard.value, isNull);
    expect(ClimbDebugMonthCard.sendsEvents, isFalse);
    ClimbDebugMonthCard.valueForTesting = 'fresh';
    expect(ClimbDebugMonthCard.sendsEvents, isFalse);
    ClimbDebugMonthCard.eventsForTesting = true;
    expect(ClimbDebugMonthCard.sendsEvents, isTrue);
  });

  group('samples, from the medal rules', () {
    final now = DateTime(2026, 11, 1);
    MonthCardData sample(ClimbDebugMonthCardValue v) =>
        ClimbDebugMonthCard.sample(v, now)!;
    int t(MedalTier tier) => MonthlyMedalRules.threshold(2026, 10, tier);

    test('summary_gold: Gold, no near-miss line', () {
      final c = sample(ClimbDebugMonthCardValue.summaryGold);
      expect((c.variant, c.tier, c.nearMiss),
          (MonthCardVariant.summary, MedalTier.gold, null));
      expect((c.steps, c.days, c.score), (27, 31, t(MedalTier.gold) + 12));
    });
    test('summary_none: no medal, no near-miss line', () {
      final c = sample(ClimbDebugMonthCardValue.summaryNone);
      expect((c.tier, c.nearMiss), (null, null));
      expect(c.score, t(MedalTier.bronze) - 33);
    });
    test('summary_near: Silver, the line to Gold', () {
      final c = sample(ClimbDebugMonthCardValue.summaryNear);
      expect(c.tier, MedalTier.silver);
      expect(c.nearMiss, (MedalTier.gold, MonthlyMedalRules.nearMissPoints));
    });
    test('fresh: the month\'s theme; first_run: no card', () {
      final c = sample(ClimbDebugMonthCardValue.fresh);
      expect((c.variant, c.theme),
          (MonthCardVariant.fresh, ClimbThemes.emberPeak));
      expect(ClimbDebugMonthCard.sample(ClimbDebugMonthCardValue.firstRun, now),
          isNull);
    });
    test('with CLIMB_DEBUG_THEME the card names that theme', () {
      ClimbDebugTheme.valueForTesting = 'glacier_peak';
      expect(sample(ClimbDebugMonthCardValue.fresh).theme,
          ClimbThemes.glacierPeak);
    });
    test(
        'Batch 5: last month\'s medal is its calendar theme, or '
        'CLIMB_DEBUG_THEME\'s', () {
      expect(sample(ClimbDebugMonthCardValue.summaryGold).previousTheme,
          ClimbThemes.greenSlope);
      ClimbDebugTheme.valueForTesting = 'red_canyon';
      expect(sample(ClimbDebugMonthCardValue.summaryGold).previousTheme,
          ClimbThemes.redCanyon);
    });
  });

  group('the replay on Home', () {
    for (final v in [
      ClimbDebugMonthCardValue.summaryGold,
      ClimbDebugMonthCardValue.summaryNone,
      ClimbDebugMonthCardValue.summaryNear,
      ClimbDebugMonthCardValue.fresh,
    ]) {
      testWidgets(
          '${v.wireName}: the card, then the zoom; no flag read or '
          'written, no event', (tester) async {
        ClimbDebugMonthCard.valueForTesting = v.wireName;
        final sink = RecordingAnalyticsSink();
        final storage = _NoFlagsStorage()..usedBefore = false;
        await pumpHome(tester, storage, sink: sink);
        expect(sheetFinder, findsOneWidget);
        await tester.fling(sheetFinder, const Offset(0, 500), 1500);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.widget<MonthlyMountain>(mountainFinder).zoom, isNotNull);
        await settleZoom(tester);
        expect(tester.widget<MonthlyMountain>(mountainFinder).zoom, isNull);
        expect(sink.events.where((e) => e.name.startsWith('month_')), isEmpty);
        expect(storage.flagCalls, isEmpty);
      });
    }

    testWidgets('replays on every launch (a new Home), not on resume',
        (tester) async {
      ClimbDebugMonthCard.valueForTesting = 'summary_near';
      final storage = _NoFlagsStorage();
      await pumpHome(tester, storage, key: const ValueKey(1));
      expect(sheetFinder, findsOneWidget);
      await tester.tapAt(const Offset(20, 120));
      await settleZoom(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));
      expect(sheetFinder, findsNothing);
      // Hot restart / a new launch: a new Home.
      await tester.pumpWidget(const SizedBox());
      await pumpHome(tester, storage, key: const ValueKey(2));
      expect(sheetFinder, findsOneWidget);
      expect(find.text('Just 5 points from Gold'), findsOneWidget);
      expect(storage.flagCalls, isEmpty);
    });

    testWidgets('first_run: no card; the zoom from K-c; no flag, no event',
        (tester) async {
      ClimbDebugMonthCard.valueForTesting = 'first_run';
      final sink = RecordingAnalyticsSink();
      final storage = _NoFlagsStorage();
      await pumpHome(tester, storage, sink: sink);
      expect(sheetFinder, findsNothing);
      expect(tester.widget<MonthlyMountain>(mountainFinder).zoom, isNotNull);
      await settleZoom(tester);
      expect(tester.widget<MonthlyMountain>(mountainFinder).zoom, isNull);
      expect(sink.events.where((e) => e.name.startsWith('month_')), isEmpty);
      expect(storage.flagCalls, isEmpty);
    });

    testWidgets(
        'with CLIMB_DEBUG_DAY and CLIMB_DEBUG_THEME: the scene and the '
        'card follow them', (tester) async {
      ClimbDebugMonthCard.valueForTesting = 'fresh';
      ClimbDebugTheme.valueForTesting = 'red_canyon';
      ClimbDebugDay.valueForTesting = 12;
      await pumpHome(tester, _NoFlagsStorage());
      expect(find.textContaining('Red Canyon'), findsWidgets);
      expect(find.text(ClimbThemes.redCanyon.tagline), findsOneWidget);
      await tester.tapAt(const Offset(20, 120));
      await settleZoom(tester);
      expect(tester.widget<MonthlyMountain>(mountainFinder).zoom, isNull);
    });

    testWidgets('CLIMB_DEBUG_MONTH_CARD_EVENTS on: the replay sends its events',
        (tester) async {
      ClimbDebugMonthCard.valueForTesting = 'summary_gold';
      ClimbDebugMonthCard.eventsForTesting = true;
      final sink = RecordingAnalyticsSink();
      await pumpHome(tester, _NoFlagsStorage(), sink: sink);
      await tester.tapAt(const Offset(20, 120));
      await settleZoom(tester);
      expect(
          sink.events.map((e) => e.name).where((n) => n.startsWith('month_')),
          ['month_card_shown', 'month_card_dismissed', 'month_zoom_ended']);
    });
  });
}
