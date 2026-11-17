import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/services/month_transition.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';
import 'package:grammar_lens/widgets/monthly_climb/mountain_scene.dart';
import 'package:grammar_lens/utils/haptics.dart';

import 'support/month_card_support.dart';
import 'support/recording_analytics_sink.dart';

final _sheet = sheetFinder;
final _mountain = mountainFinder;

String _sheetText(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: _sheet, matching: find.byType(Text)))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

/// Home's mountain under the full-screen card (offstage while it is open).
final _homeMountain = find.byType(MonthlyMountain, skipOffstage: false);

/// UI polish (R04, R04b): "See my new mountain" on the recap (when shown),
/// then "Start climbing" closes the card.
Future<void> _closeByButton(WidgetTester tester) async {
  final next = find.byKey(MonthCardSheet.seeNewMountainKey);
  if (next.evaluate().isNotEmpty) {
    await tester.tap(next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.tap(find.byKey(MonthCardSheet.startClimbingKey));
}

/// The system back on the full-screen card: closed without its button.
Future<void> _closeByBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}

/// Runs the recap's points bar to its end.
Future<void> _runBar(WidgetTester tester) async {
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}

void main() {
  setUp(() => HapticMap.log = []);

  group('variants, end to end (M3, M5, M13, M15; UI polish R04, R04b)', () {
    testWidgets(
        'summary (R04): last month, its medal title, steps, points, the gap, '
        'the near-miss and next month; Home\'s new mountain held behind',
        (tester) async {
      await pumpHome(tester, CardStorage());
      expect(_sheet, findsOneWidget);
      final text = _sheetText(tester);
      expect(text, contains('YOUR OCTOBER CLIMB'));
      expect(text, contains('Silver on Green Slope!'));
      expect(text, contains('24 / 31 days'));
      expect(text, contains('228 | points'));
      expect(text, contains('5 | to Gold'));
      expect(text, contains('Just 5 points from Gold'));
      expect(text, contains('Next: November · Ember Peak'));
      expect(find.byKey(MonthCardSheet.seeNewMountainKey), findsOneWidget);
      expect(find.byKey(MonthCardSheet.startClimbingKey), findsNothing);
      // The recap's own mountain is last month's, edge to edge.
      final scene = tester.widget<MountainScene>(
          find.descendant(of: _sheet, matching: find.byType(MountainScene)));
      expect(scene.theme, ClimbThemes.greenSlope);
      expect(scene.avatarDay, 24);
      final mountain = tester.widget<MonthlyMountain>(_homeMountain);
      expect(mountain.zoom!.value, 0);
      expect(mountain.theme, ClimbThemes.emberPeak);
    });

    testWidgets(
        'N16: once the bar has run, the header medal is last month\'s theme '
        'and tier', (tester) async {
      await pumpHome(tester, CardStorage());
      await _runBar(tester);
      final badge = tester.widget<MedalBadge>(find.descendant(
          of: find.byKey(MonthCardSheet.medalKey),
          matching: find.byType(MedalBadge)));
      // October 2026 is Green Slope; the card is November's (Ember Peak).
      expect(badge.asset, MedalArt.monthly('green_slope', MedalTier.silver));
      expect(badge.disc, MonthCardSheet.headerMedal);
      expect(badge.earned, isTrue);
    });

    test(
        'N37: the disc by screen height: 112 from 740 pt, 70 at 667, 48 at '
        '568', () {
      expect(MonthCardSheet.medalDiscFor(932), 112);
      expect(MonthCardSheet.medalDiscFor(812), 112);
      expect(MonthCardSheet.medalDiscFor(740), 112);
      expect(MonthCardSheet.medalDiscFor(739), 70);
      expect(MonthCardSheet.medalDiscCompact, lessThanOrEqualTo(88));
      expect(MonthCardSheet.medalDiscFor(667), 70);
      expect(MonthCardSheet.medalDiscFor(568), 48);
    });

    test('the bar stops at each medal line passed, then at the score', () {
      // October 2026: Bronze 78, Silver 155, Gold 233.
      expect(MonthCardSheet.barStops(2026, 10, 228), [78, 155, 228]);
      expect(MonthCardSheet.barStops(2026, 10, 74), [74]);
      expect(MonthCardSheet.barStops(2026, 10, 155), [78, 155]);
      expect(MonthCardSheet.barStops(2026, 10, 300), [78, 155, 233, 300]);
    });

    testWidgets(
        'the bar fills to Bronze, Silver and the score: a light tap at each '
        'stop and success on reaching the month\'s medal', (tester) async {
      await pumpHome(tester, CardStorage());
      HapticMap.log = [];
      await _runBar(tester);
      expect(HapticMap.log, ['light', 'success', 'light']);
      // The bar's marker ends at the score.
      expect(
          find.descendant(
              of: find.byKey(MonthCardSheet.pointsBarKey),
              matching: find.text('228')),
          findsOneWidget);
    });

    testWidgets('summary without a medal: no medal; the gap to Bronze',
        (tester) async {
      await pumpHome(tester, CardStorage(score: 74, steps: 8));
      await _runBar(tester);
      expect(
          find.descendant(
              of: find.byKey(MonthCardSheet.medalKey),
              matching: find.byType(MedalBadge)),
          findsNothing);
      final text = _sheetText(tester);
      expect(text, contains('You climbed Green Slope'));
      expect(text, contains('Just 4 points from Bronze'));
    });

    testWidgets('Gold: no near-miss line', (tester) async {
      await pumpHome(tester, CardStorage(score: 300, steps: 30));
      expect(_sheetText(tester), contains('Gold on Green Slope!'));
      expect(find.byKey(MonthCardSheet.nearMissKey), findsNothing);
    });

    testWidgets('a gap of 6: no near-miss line', (tester) async {
      await pumpHome(tester, CardStorage(score: 227, steps: 24));
      expect(find.byKey(MonthCardSheet.nearMissKey), findsNothing);
    });

    testWidgets(
        '"See my new mountain" opens the new mountain (R04b): the month, its '
        'mountain, its steps and medal lines', (tester) async {
      await pumpHome(tester, CardStorage());
      await tester.tap(find.byKey(MonthCardSheet.seeNewMountainKey));
      await tester.pumpAndSettle();
      expect(find.byKey(MonthCardSheet.newMountainKey), findsOneWidget);
      final text = _sheetText(tester);
      expect(text, contains('NOVEMBER · EMBER PEAK'));
      expect(text, contains('A new mountain!'));
      // November 2026: 30 days; Bronze 75, Silver 150, Gold 225.
      expect(
          text,
          contains('30 steps to the summit. Bronze at 75 points, Silver 150, '
              'Gold 225.'));
    });

    testWidgets('fresh start: the new mountain only, no recap', (tester) async {
      await pumpHome(tester, CardStorage(steps: 0)..frozen = null);
      expect(find.byKey(MonthCardSheet.newMountainKey), findsOneWidget);
      expect(find.byKey(MonthCardSheet.seeNewMountainKey), findsNothing);
      expect(_sheetText(tester), contains('A new mountain!'));
      expect(_sheetText(tester), isNot(contains('CLIMB')));
    });

    testWidgets('a user new this month gets no card', (tester) async {
      await pumpHome(tester, CardStorage()..usedBefore = false);
      expect(_sheet, findsNothing);
      expect(tester.widget<MonthlyMountain>(_mountain).zoom, isNull);
    });
  });

  group('closing (M6, M12)', () {
    Future<void> closeAndCheck(
        WidgetTester tester, Future<void> Function() close) async {
      final storage = CardStorage();
      await pumpHome(tester, storage);
      expect(_sheet, findsOneWidget);
      await close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_sheet, findsNothing);
      // Seen, and the month-change zoom started (claimed as it starts).
      expect(storage.flags, contains('month_card:2026-11'));
      expect(storage.flags, contains('month_zoom:2026-11'));
      expect(tester.widget<MonthlyMountain>(_mountain).zoom, isNotNull);
      await settleZoom(tester);
      expect(tester.widget<MonthlyMountain>(_mountain).zoom, isNull);
    }

    testWidgets('the button', (tester) async {
      await closeAndCheck(tester, () => _closeByButton(tester));
    });

    testWidgets('the system back', (tester) async {
      await closeAndCheck(tester, () => _closeByBack(tester));
    });
  });

  group('showMonthCard reports how it was closed', () {
    Future<MonthCardDismissal?> run(
        WidgetTester tester, Future<void> Function() close) async {
      MonthCardDismissal? how;
      await pumpHome(tester, CardStorage()..usedBefore = false);
      final context = tester.element(find.byType(HomeScreen));
      showMonthCard(context,
              data: const MonthCardData(
                  year: 2026,
                  month: 11,
                  theme: ClimbThemes.emberPeak,
                  variant: MonthCardVariant.fresh,
                  previousYear: 2026,
                  previousMonth: 10),
              avatar: Avatar.values.first)
          .then((h) => how = h);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await close();
      await tester.pumpAndSettle();
      return how;
    }

    testWidgets('button', (tester) async {
      expect(await run(tester, () => _closeByButton(tester)),
          MonthCardDismissal.button);
    });
    testWidgets('the system back: barrier', (tester) async {
      expect(await run(tester, () => _closeByBack(tester)),
          MonthCardDismissal.barrier);
    });
  });

  testWidgets(
      'a card open when the app is closed shows again; once closed, '
      'not again', (tester) async {
    final storage = CardStorage();
    await pumpHome(tester, storage, key: const ValueKey(1));
    expect(_sheet, findsOneWidget);
    // The app is closed with the card open: a new app, same storage.
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester, storage, key: const ValueKey(2));
    expect(_sheet, findsOneWidget);
    await _closeByButton(tester);
    await settleZoom(tester);
    await pumpHome(tester, storage, key: const ValueKey(3));
    expect(_sheet, findsNothing);
  });

  for (final screen in const [Size(320, 568), Size(375, 812), Size(430, 932)]) {
    testWidgets(
        'after the card closes the Daily Test entry is on screen and opens the '
        'test during the zoom (M21), ${screen.width.toInt()} pt',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      await pumpHome(tester, CardStorage(), screen: screen, sink: sink);
      await _closeByButton(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_sheet, findsNothing);
      expect(tester.widget<MonthlyMountain>(_mountain).zoom, isNotNull);
      final today = tester.getRect(find.byKey(HomeScreen.dailyTestCardKey));
      final list = tester.getRect(find.byType(Scrollable).first);
      final shown = today.bottom - list.top;
      expect(shown, greaterThanOrEqualTo(HomeScreen.monthCardTodayPeek - .5));
      // 1.2.0: the entry is the card's button, and it is in the part that
      // shows.
      final button = tester.getRect(find.text('Start today’s test'));
      expect(button.top, greaterThanOrEqualTo(list.top));
      await tester.tapAt(button.center);
      // The tap reached the Today card: the Daily Test opens (its route is
      // pushed; its own layout is not this test's subject) and the zoom
      // jumps to its end (M16).
      expect(
          sink.events
              .where((e) => e.name == 'mode_selected')
              .map((e) => e.parameters?['mode']),
          ['daily_test']);
      await tester.pump();
      expect(find.byType(DailyTestScreen, skipOffstage: false), findsOneWidget);
      expect(tester.widget<MonthlyMountain>(_mountain).zoom, isNull);
    });
  }

  group('events (M19)', () {
    List<RecordedEvent> named(RecordingAnalyticsSink sink, String name) =>
        sink.events.where((e) => e.name == name).toList();

    Future<void> closeBy(WidgetTester tester, String method) async {
      switch (method) {
        case 'button':
          await _closeByButton(tester);
        case 'barrier':
          await _closeByBack(tester);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('shown once, with theme, variant, tier and the line',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      await pumpHome(tester, CardStorage(), sink: sink);
      expect(named(sink, 'month_card_shown').single.parameters, {
        'theme_id': 'ember_peak',
        'variant': 'summary',
        'medal_tier': 'silver',
        'near_miss_shown': 1,
      });
    });

    testWidgets('fresh start: tier none, no line', (tester) async {
      final sink = RecordingAnalyticsSink();
      await pumpHome(tester, CardStorage(steps: 0)..frozen = null, sink: sink);
      expect(named(sink, 'month_card_shown').single.parameters, {
        'theme_id': 'ember_peak',
        'variant': 'fresh',
        'medal_tier': 'none',
        'near_miss_shown': 0,
      });
    });

    for (final method in ['button', 'barrier']) {
      testWidgets('dismissed once by $method, with how long it was open',
          (tester) async {
        var now = DateTime(2026, 11, 1, 9);
        HomeScreen.monthCardClockForTesting = () => now;
        addTearDown(() => HomeScreen.monthCardClockForTesting = DateTime.now);
        final sink = RecordingAnalyticsSink();
        await pumpHome(tester, CardStorage(), sink: sink);
        now = now.add(const Duration(milliseconds: 4200));
        // Ten minutes in the background do not count.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 10));
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        now = now.add(const Duration(milliseconds: 800));
        await closeBy(tester, method);
        final dismissed = named(sink, 'month_card_dismissed');
        expect(dismissed, hasLength(1));
        final p = dismissed.single.parameters!;
        expect({...p}..remove('open_ms'), {
          'theme_id': 'ember_peak',
          'variant': 'summary',
          'method': method,
        });
        expect(p['open_ms'], 5000);
        await settleZoom(tester);
        expect(named(sink, 'month_card_shown'), hasLength(1));
      });
    }

    Future<RecordingAnalyticsSink> zoomUntilEnd(WidgetTester tester,
        {bool reduceMotion = false, Future<void> Function()? during}) async {
      if (reduceMotion) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      final sink = RecordingAnalyticsSink();
      await pumpHome(tester, CardStorage(), sink: sink);
      await closeBy(tester, 'barrier');
      // The zoom has started (its pause, then 1.8 s; Reduce Motion's
      // 250 ms cross-fade may already have ended).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      if (!reduceMotion) expect(named(sink, 'month_zoom_ended'), isEmpty);
      await during?.call();
      await settleZoom(tester);
      return sink;
    }

    Map<String, Object>? ended(RecordingAnalyticsSink sink) {
      final events = named(sink, 'month_zoom_ended');
      expect(events, hasLength(1));
      return events.single.parameters;
    }

    testWidgets('zoom ended: completed', (tester) async {
      final sink = await zoomUntilEnd(tester);
      expect(ended(sink), {
        'theme_id': 'ember_peak',
        'outcome': 'completed',
        'trigger': 'month_change',
      });
    });

    testWidgets('zoom ended: skipped by a tap on the mountain', (tester) async {
      final sink = await zoomUntilEnd(tester, during: () async {
        final window = tester.getRect(_mountain);
        await tester.tapAt(window.topCenter + const Offset(0, 80));
        await tester.pump();
      });
      expect(ended(sink)!['outcome'], 'skipped');
    });

    testWidgets('zoom ended: Reduce Motion', (tester) async {
      final sink = await zoomUntilEnd(tester, reduceMotion: true);
      expect(ended(sink)!['outcome'], 'reduce_motion');
    });

    testWidgets(
        'zoom ended: the Daily Test opened; mode_selected carries '
        'the month\'s theme', (tester) async {
      final sink = await zoomUntilEnd(tester, during: () async {
        // 1.2.0: the entry is the Daily Test card's button.
        await tester.tapAt(tester.getCenter(find.text('Start today’s test')));
      });
      expect(ended(sink)!['outcome'], 'daily_test_opened');
      expect(named(sink, 'mode_selected').single.parameters,
          {'mode': 'daily_test', 'theme_id': 'ember_peak'});
    });
  });
}
