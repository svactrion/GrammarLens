import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/services/month_transition.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'support/month_card_support.dart';
import 'support/recording_analytics_sink.dart';

final _sheet = sheetFinder;
final _mountain = mountainFinder;

String _sheetText(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: _sheet, matching: find.byType(Text)))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

void main() {
  group('variants, end to end (M3, M5, M13, M15)', () {
    testWidgets(
        'summary: last month, medal, steps, points, near-miss, next '
        'month and theme, one button; K-c behind the sheet', (tester) async {
      await pumpHome(tester, CardStorage());
      expect(_sheet, findsOneWidget);
      final text = _sheetText(tester);
      expect(text, contains('Your October climb'));
      expect(text, contains('Silver medal'));
      expect(text, contains('24 / 31 steps'));
      expect(text, contains('228 points'));
      expect(text, contains('Just 5 points from Gold'));
      expect(text, contains('Next: November · Ember Peak'));
      expect(find.widgetWithText(FilledButton, 'See the mountain'),
          findsOneWidget);
      final mountain = tester.widget<MonthlyMountain>(_mountain);
      expect(mountain.zoom!.value, 0);
      expect(mountain.theme, ClimbThemes.emberPeak);
    });

    testWidgets('summary without a medal: no medal row; the gap to Bronze',
        (tester) async {
      await pumpHome(tester, CardStorage(score: 74, steps: 8));
      expect(find.byKey(MonthCardSheet.medalKey), findsNothing);
      expect(_sheetText(tester), contains('Just 4 points from Bronze'));
    });

    testWidgets('Gold: no near-miss line', (tester) async {
      await pumpHome(tester, CardStorage(score: 300, steps: 30));
      expect(_sheetText(tester), contains('Gold medal'));
      expect(find.byKey(MonthCardSheet.nearMissKey), findsNothing);
    });

    testWidgets('a gap of 6: no near-miss line', (tester) async {
      await pumpHome(tester, CardStorage(score: 227, steps: 24));
      expect(find.byKey(MonthCardSheet.nearMissKey), findsNothing);
    });

    testWidgets('fresh start: avatar, title, theme and tagline, no numbers',
        (tester) async {
      await pumpHome(tester, CardStorage(steps: 0)..frozen = null);
      final text = _sheetText(tester);
      expect(text, contains('A new mountain awaits'));
      expect(text, contains('Ember Peak'));
      expect(text, contains(ClimbThemes.emberPeak.tagline));
      expect(text, contains('Your avatar is ready at the start.'));
      expect(RegExp(r'\d').hasMatch(text), isFalse, reason: text);
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
      await closeAndCheck(
          tester,
          () => tester
              .tap(find.widgetWithText(FilledButton, 'See the mountain')));
    });

    testWidgets('a swipe down', (tester) async {
      await closeAndCheck(
          tester, () => tester.fling(_sheet, const Offset(0, 500), 1500));
    });

    testWidgets('a tap outside', (tester) async {
      await closeAndCheck(tester, () => tester.tapAt(const Offset(20, 120)));
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
      expect(
          await run(
              tester, () => tester.tap(find.text(MonthCardSheet.buttonLabel))),
          MonthCardDismissal.button);
    });
    testWidgets('drag', (tester) async {
      expect(
          await run(
              tester, () => tester.fling(_sheet, const Offset(0, 500), 1500)),
          MonthCardDismissal.drag);
    });
    testWidgets('barrier', (tester) async {
      expect(await run(tester, () => tester.tapAt(const Offset(20, 120))),
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
    await tester.tap(find.text(MonthCardSheet.buttonLabel));
    await settleZoom(tester);
    await pumpHome(tester, storage, key: const ValueKey(3));
    expect(_sheet, findsNothing);
  });

  for (final screen in const [Size(320, 568), Size(375, 812), Size(430, 932)]) {
    testWidgets(
        'after the sheet closes the Daily Test entry is on screen and opens the '
        'test during the zoom (M21), ${screen.width.toInt()} pt',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      await pumpHome(tester, CardStorage(), screen: screen, sink: sink);
      // The button may be below the sheet's fold (it scrolls when needed).
      await tester.ensureVisible(find.text(MonthCardSheet.buttonLabel));
      await tester.pump();
      await tester.tap(find.text(MonthCardSheet.buttonLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_sheet, findsNothing);
      expect(tester.widget<MonthlyMountain>(_mountain).zoom, isNotNull);
      final today = tester.getRect(find
          .ancestor(of: find.text('Daily Test'), matching: find.byType(Card))
          .first);
      final list = tester.getRect(find.byType(Scrollable).first);
      final shown = today.bottom - list.top;
      expect(shown, greaterThanOrEqualTo(HomeScreen.monthCardTodayPeek - .5));
      // Tap the part that shows.
      await tester.tapAt(Offset(today.center.dx, today.bottom - shown / 2));
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
          await tester.ensureVisible(find.text(MonthCardSheet.buttonLabel));
          await tester.pump();
          await tester.tap(find.text(MonthCardSheet.buttonLabel));
        case 'drag':
          await tester.fling(_sheet, const Offset(0, 500), 1500);
        case 'barrier':
          await tester.tapAt(const Offset(20, 120));
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

    for (final method in ['button', 'drag', 'barrier']) {
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
      await closeBy(tester, 'drag');
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
        final today = tester.getRect(find
            .ancestor(of: find.text('Daily Test'), matching: find.byType(Card))
            .first);
        await tester.tapAt(Offset(today.center.dx, today.bottom - 20));
      });
      expect(ended(sink)!['outcome'], 'daily_test_opened');
      expect(named(sink, 'mode_selected').single.parameters,
          {'mode': 'daily_test', 'theme_id': 'ember_peak'});
    });
  });
}
