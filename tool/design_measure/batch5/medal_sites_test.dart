// Batch 5 Batch 0, §1: the composed medals where the app draws a medal
// today. For 320 / 375 / 430 pt, light and dark, Small / Medium / Large
// (only through buildAppTheme(textSize:)), one image per combination with:
//   1. Profile today: the real MonthlyMedalCollection, at Profile's width;
//   2. Profile, N10 proposal (ProtoCollection);
//   3. the month card's summary content with the new medal (48 pt disc);
//   4. the Day-0 Welcome card with the Welcome image (112 pt disc);
//   5. N8's tier celebration in the same card (Silver, Ember Peak).
// And medal_sites.txt: today's medal sizes, the month card's content
// height today (the real MonthCardSheet) and with each medal option, and
// the celebration card's height today and with the image.
//
// Needs the WebP candidates first:
//   build/scene_art_venv/bin/python tool/medals/build_medals.py docs/design/medals/source build/medals/png
//   build/scene_art_venv/bin/python tool/medals/medal_assets.py
//   DESIGN_MEASURE_OUT=build/design_measure/batch5_sites \
//     flutter test tool/design_measure/batch5/medal_sites_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py sites
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/services/month_transition.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir, writePng;
import 'medal_prototype.dart';

const _widths = [320.0, 375.0, 430.0];

/// The proposal's sizes (report §1).
const _currentDisc = 72.0;
const _historyDisc = 48.0;
const _welcomeRowDisc = 64.0;
const _cardMedalDisc = 48.0;
const _celebrationDisc = 112.0;

MonthlyMedalResult _result(int month, int score) => MonthlyMedalResult(
    year: 2026,
    month: month,
    score: score,
    maxScore: MonthlyMedalRules.maxScore(2026, month),
    activeDays: 20,
    correct: 0,
    wrong: 0,
    skipped: 0,
    tier: MonthlyMedalRules.tierFor(year: 2026, month: month, score: score),
    ruleVersion: 1,
    finalizedAt: DateTime(2026, month + 1, 1));

const _summaryData = MonthCardData(
    year: 2026,
    month: 11,
    theme: ClimbThemes.emberPeak,
    variant: MonthCardVariant.summary,
    previousYear: 2026,
    previousMonth: 10,
    tier: MedalTier.silver,
    steps: 24,
    days: 31,
    score: 228,
    nearMiss: (MedalTier.gold, 5));

Widget _caption(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800)),
    );

void main() {
  final out = outDir();
  final rows = <String>[];
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() => File('$out/medal_sites.txt').writeAsStringSync([
        'Batch 5 Batch 0 §1: medals where the app draws them today, and the '
            'composed medals in the same places (tool/design_measure/batch5/'
            'medal_sites_test.dart). Points. Light and dark lay out the same; '
            'light only below.',
        '',
        'Profile today (MonthlyMedalCollection at Profile\'s width): column = '
            'the list\'s content width; specimen = each Bronze/Silver/Gold '
            'circle; height = the whole collection with the sample data.',
        'Profile proposal (ProtoCollection): discs $_currentDisc (this month), '
            '$_historyDisc (history), $_welcomeRowDisc (Welcome row).',
        'Month card: content height of the real MonthCardSheet (Silver, the '
            'fullest summary) and of the copy with each medal option. Batch 6 '
            'measured the real sheet at content + 16 pt, scrolling above 9/16 '
            'of the screen (docs/design/batch6/card/).',
        'Celebration card: the Day-0 Welcome card today (80 pt trophy circle) '
            'and with the Welcome image at $_celebrationDisc pt.',
        '',
        'width text    column  specimen  profile today  proposal | month card: real  fit 40  disc 40  disc 48  disc 56 | card today  image 96  image 112',
        ...rows,
      ].join('\n')));

  for (final w in _widths) {
    for (final b in Brightness.values) {
      for (final size in AppTextSize.values) {
        final name = 'sites_${w.toInt()}_${b.name}_${size.name}';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = Size(w, 3200) * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          // Decode the medals first (see precacheMedals).
          final warm = GlobalKey();
          await tester.pumpWidget(SizedBox(key: warm));
          await tester.runAsync(() => precacheMedals(warm.currentContext!));
          final hPad = (w * 0.045).clamp(16.0, 28.0);
          final keys = {
            for (final k in [
              'today',
              'proposal',
              'real',
              'fit40',
              'disc40',
              'disc48',
              'disc56',
              'card80',
              'card96',
              'card112',
            ])
              k: GlobalKey(debugLabel: k)
          };
          Widget measured(String k, Widget child) =>
              KeyedSubtree(key: keys[k], child: child);
          Widget offstage(String k, Widget child) =>
              Offstage(child: SizedBox(width: w, child: measured(k, child)));
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(b, textSize: size),
            home: Builder(builder: (context) {
              final scheme = Theme.of(context).colorScheme;
              return Material(
                color: scheme.surfaceContainerLow,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SingleChildScrollView(
                    child: Stack(children: [
                      // Measured only, not drawn.
                      offstage(
                          'real',
                          Material(
                              child: MonthCardSheet(
                                  data: _summaryData,
                                  avatar: Avatar.values.first,
                                  onClose: () {}))),
                      for (final (k, medal) in [
                        (
                          'fit40',
                          const ProtoMedalFit(
                              name: 'medal_ember_peak_silver', box: 40)
                        ),
                        (
                          'disc40',
                          const ProtoMedal(
                              name: 'medal_ember_peak_silver', disc: 40)
                        ),
                        (
                          'disc48',
                          const ProtoMedal(
                              name: 'medal_ember_peak_silver',
                              disc: _cardMedalDisc)
                        ),
                        (
                          'disc56',
                          const ProtoMedal(
                              name: 'medal_ember_peak_silver', disc: 56)
                        ),
                      ])
                        offstage(
                            k,
                            Material(
                                child: ProtoMonthCardSummary(medal: medal))),
                      for (final (k, d) in [('card80', null), ('card96', 96.0)])
                        offstage(
                            k,
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: hPad),
                              child: ProtoCelebrationCard(
                                  image: d == null
                                      ? null
                                      : ProtoMedal(
                                          name: 'medal_welcome', disc: d),
                                  title: 'Welcome to the climb',
                                  body:
                                      "Answer at least one question a day to keep "
                                      "moving up this month's mountain."),
                            )),
                      RepaintBoundary(
                        key: key,
                        child: ColoredBox(
                          color: scheme.surfaceContainerLow,
                          child: SizedBox(
                            width: w,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _caption(context,
                                      '1 · PROFILE TODAY (${w.toInt()} pt, ${size.name})'),
                                  measured(
                                      'today',
                                      MonthlyMedalCollection(
                                        welcomeBadge: WelcomeBadge(
                                            earnedAt: DateTime(2026, 8, 3),
                                            ruleVersion: 1,
                                            backfilled: false),
                                        currentProgress:
                                            const MonthlyMedalProgress(
                                                year: 2026,
                                                month: 11,
                                                score: 160,
                                                maxScore: 300,
                                                activeDays: 18,
                                                correct: 0,
                                                wrong: 0,
                                                skipped: 0),
                                        results: [
                                          _result(10, 251),
                                          _result(9, 96),
                                          _result(8, 41),
                                        ],
                                      )),
                                  _caption(context,
                                      '2 · PROFILE, N10 PROPOSAL (each month its theme; unearned faded)'),
                                  measured(
                                      'proposal',
                                      const ProtoCollection(
                                          currentDisc: _currentDisc,
                                          historyDisc: _historyDisc,
                                          welcomeDisc: _welcomeRowDisc)),
                                  _caption(context,
                                      '3 · MONTH CARD, MEDAL DISC ${_cardMedalDisc.toInt()} PT'),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                        color: scheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                            color: scheme.outlineVariant)),
                                    child: const Material(
                                      type: MaterialType.transparency,
                                      child: ProtoMonthCardSummary(
                                          medal: ProtoMedal(
                                              name: 'medal_ember_peak_silver',
                                              disc: _cardMedalDisc)),
                                    ),
                                  ),
                                  _caption(context,
                                      '4 · DAY-0 WELCOME CARD, IMAGE ${_celebrationDisc.toInt()} PT'),
                                  measured(
                                      'card112',
                                      const ProtoCelebrationCard(
                                          image: ProtoMedal(
                                              name: 'medal_welcome',
                                              disc: _celebrationDisc),
                                          title: 'Welcome to the climb',
                                          body:
                                              "Answer at least one question a day to keep "
                                              "moving up this month's mountain.")),
                                  _caption(context,
                                      '5 · N8 TIER CELEBRATION, SAME CARD (placeholder copy)'),
                                  const ProtoCelebrationCard(
                                      image: ProtoMedal(
                                          name: 'medal_ember_peak_silver',
                                          disc: _celebrationDisc),
                                      title: 'Silver on Ember Peak',
                                      body:
                                          'You reached 150 points this month. '
                                          'Gold is at 233.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          double h(String k) =>
              tester.getSize(find.byKey(keys[k]!, skipOffstage: false)).height;
          final specimen = tester
              .getSize(find
                  .descendant(
                      of: find.byKey(keys['today']!),
                      matching: find.byType(MedalBadge))
                  .first)
              .width;
          final column = tester.getSize(find.byKey(keys['today']!)).width;
          String f(double v) => v.toStringAsFixed(1).padLeft(6);
          if (b == Brightness.light) {
            rows.add(
                '${w.toInt().toString().padRight(5)} ${size.name.padRight(7)} '
                '${f(column)}  ${f(specimen)}    ${f(h('today'))}       ${f(h('proposal'))} |'
                '                  ${f(h('real'))}  ${f(h('fit40'))}  ${f(h('disc40'))}  ${f(h('disc48'))}  ${f(h('disc56'))} |'
                '    ${f(h('card80'))}    ${f(h('card96'))}    ${f(h('card112'))}');
          }
          await writePng(tester, key, '$out/$name.png');
        });
      }
    }
  }
}
