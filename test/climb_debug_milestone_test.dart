import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_day.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_milestone.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_month_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'support/month_card_support.dart';
import 'support/recording_analytics_sink.dart';

/// Records every stored-record access the replay might make: it must make
/// none beyond Home's own climb load.
class _RecordingStorage extends CardStorage {
  _RecordingStorage() : super();
  final List<String> calls = [];
  @override
  Future<bool> hasOneTimeFlag(String key) async {
    calls.add('read $key');
    return false;
  }

  @override
  Future<bool> claimOneTimeFlag(String key) async {
    calls.add('write $key');
    return true;
  }
}

/// `CLIMB_DEBUG_MILESTONE` (Batch 5, N13, N22).
void main() {
  tearDown(() {
    ClimbDebugMilestone.valueForTesting = null;
    ClimbDebugMonthCard.valueForTesting = null;
    ClimbDebugTheme.valueForTesting = null;
    ClimbDebugDay.valueForTesting = null;
  });

  test(
      'debug and profile only (N27); the eight values; unknown or unset is nothing',
      () {
    for (final v in ClimbDebugMilestoneValue.values) {
      expect(
          ClimbDebugMilestone.resolve(enabled: true, defined: v.wireName), v);
      expect(ClimbDebugMilestone.resolve(enabled: false, defined: v.wireName),
          isNull);
    }
    expect(ClimbDebugMilestoneValue.values.map((v) => v.wireName), [
      'bronze',
      'silver',
      'gold',
      'first_camp',
      'halfway_hut',
      'mountain_spring',
      'high_camp',
      'summit',
    ]);
    expect(ClimbDebugMilestone.resolve(enabled: true, defined: ''), isNull);
    expect(ClimbDebugMilestone.resolve(enabled: true, defined: 'platinum'),
        isNull);
  });

  test('the test suite runs without the define', () {
    expect(ClimbDebugMilestone.value, isNull);
  });

  test('tiers map to tiers, the rest to save points (summit: the flag)', () {
    expect(ClimbDebugMilestoneValue.gold.tier, MedalTier.gold);
    expect(ClimbDebugMilestoneValue.gold.savePoint, isNull);
    expect(ClimbDebugMilestoneValue.highCamp.savePoint!.name, 'High Camp');
    expect(ClimbDebugMilestoneValue.summit.savePoint, ClimbSavePoints.flag);
  });

  final celebration = find.byType(MedalCelebration);

  group('a tier: the celebration over Home', () {
    testWidgets(
        'the current month and its theme; one tap closes it; no record read '
        'or written, no event', (tester) async {
      // Home's own reads, without the define.
      final plain = _RecordingStorage()..usedBefore = false;
      await pumpHome(tester, plain, key: const ValueKey('plain'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());

      ClimbDebugMilestone.valueForTesting = 'silver';
      final sink = RecordingAnalyticsSink();
      final storage = _RecordingStorage()..usedBefore = false;
      await pumpHome(tester, storage, sink: sink);
      await tester.pump(const Duration(milliseconds: 300));
      expect(celebration, findsOneWidget);
      expect(find.text('Silver medal earned'), findsOneWidget);
      expect(find.text('November · Ember Peak'), findsOneWidget);
      expect(
          tester
              .widget<MedalBadge>(find.descendant(
                  of: celebration, matching: find.byType(MedalBadge)))
              .asset,
          MedalArt.monthly('ember_peak', MedalTier.silver));
      await tester.tap(celebration);
      await tester.pumpAndSettle();
      expect(celebration, findsNothing);
      // Nothing beyond what Home reads anyway; nothing written.
      expect(storage.calls, plain.calls);
      expect(storage.calls.where((c) => c.startsWith('write')), isEmpty);
      expect(sink.events, isEmpty);
    });

    testWidgets('with CLIMB_DEBUG_THEME: that theme\'s medal and name',
        (tester) async {
      ClimbDebugMilestone.valueForTesting = 'gold';
      ClimbDebugTheme.valueForTesting = 'red_canyon';
      await pumpHome(tester, _RecordingStorage()..usedBefore = false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('November · Red Canyon'), findsOneWidget);
      await tester.tap(celebration);
      await tester.pumpAndSettle();
    });

    testWidgets('replays on every launch (a new Home), not on resume',
        (tester) async {
      ClimbDebugMilestone.valueForTesting = 'bronze';
      final storage = _RecordingStorage()..usedBefore = false;
      await pumpHome(tester, storage, key: const ValueKey(1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(celebration);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));
      expect(celebration, findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pumpHome(tester, storage, key: const ValueKey(2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(celebration, findsOneWidget);
      await tester.tap(celebration);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'with CLIMB_DEBUG_MONTH_CARD: the card and its zoom first, then the '
        'celebration', (tester) async {
      ClimbDebugMilestone.valueForTesting = 'gold';
      ClimbDebugMonthCard.valueForTesting = 'summary_gold';
      await pumpHome(tester, _RecordingStorage());
      expect(sheetFinder, findsOneWidget);
      expect(celebration, findsNothing);
      await tester.tapAt(const Offset(20, 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(celebration, findsNothing, reason: 'not during the zoom');
      await settleZoom(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(celebration, findsOneWidget);
      await tester.tap(celebration);
      await tester.pumpAndSettle();
    });
  });

  group('a save point: the hop and the label in the scene', () {
    Widget mountain(
            {int days = 31, int completed = 4, Animation<double>? zoom}) =>
        MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: Scaffold(
                body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                        width: 341.25,
                        child: MonthlyMountain(
                            days: days,
                            completedDays: completed,
                            avatar: Avatar.values.first,
                            zoom: zoom)))));
    final label = find.byKey(MonthlyMountain.labelKey);

    for (final v
        in ClimbDebugMilestoneValue.values.where((v) => v.tier == null)) {
      testWidgets('${v.wireName}: one step before, then onto it, and its label',
          (tester) async {
        ClimbDebugMilestone.valueForTesting = v.wireName;
        final step = v.savePoint!.reachedOn(31);
        await tester.pumpWidget(mountain());
        await tester.pump();
        expect(find.bySemanticsLabel(RegExp('${step - 1} of 31 steps')),
            findsOneWidget);
        expect(label, findsNothing);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 900));
        expect(
            find.bySemanticsLabel(RegExp('$step of 31 steps')), findsOneWidget);
        expect(label, findsOneWidget);
        expect(
            tester
                .widget<Text>(
                    find.descendant(of: label, matching: find.byType(Text)))
                .data,
            v.savePoint!.name);
        await tester.pumpAndSettle();
      });
    }

    testWidgets('it takes the place of CLIMB_DEBUG_DAY in the scene',
        (tester) async {
      ClimbDebugMilestone.valueForTesting = 'high_camp';
      ClimbDebugDay.valueForTesting = 3;
      final step = ClimbSavePoints.all[3].reachedOn(31);
      await tester.pumpWidget(mountain());
      expect(find.bySemanticsLabel(RegExp('${step - 1} of 31 steps')),
          findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('during a zoom it waits; the hop and the label come after',
        (tester) async {
      ClimbDebugMilestone.valueForTesting = 'first_camp';
      final zoom = AnimationController(vsync: const TestVSync(), value: .5);
      addTearDown(zoom.dispose);
      await tester.pumpWidget(mountain(zoom: zoom));
      await tester.pump(const Duration(seconds: 2));
      expect(find.bySemanticsLabel(RegExp('6 of 31 steps')), findsOneWidget);
      await tester.pumpWidget(mountain());
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 900));
      expect(label, findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
