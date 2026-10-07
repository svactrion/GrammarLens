// Batch 5 Batch 0, §2: where the Day-0 Welcome celebration appears today.
// The real DailyTestResultScreen with the bundled Day-0 questions, a save
// that reports "Welcome badge just earned", at 320 × 568, 375 × 667,
// 375 × 812 and 430 × 932, Small / Medium / Large (buildAppTheme(textSize:)
// only), answers all correct (the shortest cards) and two wrong (longer).
// Writes welcome_result.txt: how much of the Welcome card is on screen at
// the list's scroll top, and how far the list must scroll to show it all;
// and one PNG per screen at Medium, all correct.
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch5_welcome \
//     flutter test tool/design_measure/batch5/welcome_result_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir, writePng;

/// A save that succeeds and reports the Welcome badge as just earned.
class _WelcomeStorage extends StorageService {
  @override
  Future<bool> completeDailyTest(
          Map<String, String> answers, List<ErrorEntry> errorEntries,
          {String? day, DateTime? completedAt}) async =>
      true;
}

class _NoPrefetch extends DailyTestService {
  _NoPrefetch(StorageService storage)
      : super(claudeService: ClaudeService(), storageService: storage);
  @override
  Future<void> prefetchSet(String day) async {}
}

const _screens = {
  '320x568': (320.0, 568.0, 20.0, 0.0),
  '375x667': (375.0, 667.0, 20.0, 0.0),
  '375x812': (375.0, 812.0, 47.0, 34.0),
  '430x932': (430.0, 932.0, 59.0, 34.0),
};

void main() {
  final out = outDir();
  final rows = <String>[];
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() => File('$out/welcome_result.txt').writeAsStringSync([
        'Batch 5 Batch 0 §2: the Day-0 result screen with the Welcome card '
            '(real DailyTestResultScreen, bundled Day-0 questions). Points.',
        'list: the scrolling area between the band and the fixed footer; card '
            'top: the Welcome card\'s top in that area at scroll top; shown: '
            'its height on screen at scroll top; scroll: how far the list '
            'must scroll to show the whole card. The footer button reads '
            '"Start my climb" in every row.',
        '',
        'screen   answers  text     list h  card h  card top  shown         scroll',
        ...rows,
      ].join('\n')));

  for (final MapEntry(key: screen, value: (w, h, top, bottom))
      in _screens.entries) {
    for (final wrong in [0, 2]) {
      for (final size in AppTextSize.values) {
        final name = 'welcome_${screen}_${wrong}wrong_${size.name}';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = Size(w, h) * 2;
          tester.view.devicePixelRatio = 2;
          tester.view.padding =
              FakeViewPadding(top: top * 2, bottom: bottom * 2);
          addTearDown(tester.view.reset);
          final set = DailyTestSet(
              day: '2026-10-14',
              questions: kDayZeroQuestions,
              source: DailyTestSource.bundled);
          final answers = {
            for (final (i, q) in kDayZeroQuestions.indexed)
              q.item.id: i < wrong ? 'wrong answer' : q.correctAnswer,
          };
          final storage = _WelcomeStorage();
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(Brightness.light, textSize: size),
              home: DailyTestResultScreen(
                dailyTestSet: set,
                answers: answers,
                dailyTestService: _NoPrefetch(storage),
                analyticsService: AnalyticsService(),
                isDay0: true,
                onDone: () {},
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(find.text('Start my climb'), findsOneWidget);
          final list = tester.getRect(find.byType(Scrollable).first);
          final cardFinder = find.ancestor(
              of: find.text('Welcome to the climb', skipOffstage: false),
              matching: find.byType(Card, skipOffstage: false));
          // The list builds lazily: scroll until the card is built.
          await tester.scrollUntilVisible(
              find.text('Welcome to the climb'), 300,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          final scrolled = position.pixels;
          final card = tester.getRect(cardFinder.first);
          final cardTop = card.top + scrolled - list.top;
          final shown = (list.height - cardTop).clamp(0.0, card.height);
          final scroll =
              (cardTop + card.height - list.height).clamp(0.0, double.infinity);
          String f(double v) => v.toStringAsFixed(1).padLeft(6);
          rows.add('${screen.padRight(8)} ${'$wrong wrong'.padRight(8)} '
              '${size.name.padRight(7)} ${f(list.height)}  ${f(card.height)}  '
              '${f(cardTop)}  ${f(shown)} (${(shown * 100 / card.height).round().toString().padLeft(3)} %)  ${f(scroll)}');
          if (wrong == 0 && size == AppTextSize.medium) {
            position.jumpTo(0);
            await tester.pumpAndSettle();
            await writePng(tester, key, '$out/$name.png');
          }
        });
      }
    }
  }
}
