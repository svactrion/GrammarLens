// Batch 3c-A images and shell measurements. Output: DESIGN_MEASURE_OUT or
// build/design_measure.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_score_bar.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'common.dart';
import 'geometry.dart';
import 'painter.dart';
import 'shell.dart';

final out = outDir();

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// Today's card, built from the product: the two header rows (copied from
/// HomeScreen._buildClimb), the real MonthlyMountain and ClimbScoreBar.
Widget currentCard(double cardW, int day, BuildContext? _) =>
    Builder(builder: (context) {
      final theme = Theme.of(context);
      return SizedBox(
        width: cardW,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Mountain of Learning', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text('October 2026 · $day / 31 steps',
              style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MonthlyMountain(
                    days: 31,
                    completedDays: day,
                    avatar: snail,
                  ),
                  ClimbScoreBar(
                    score: day * 7,
                    maxScore: MonthlyMedalRules.maxScore(2026, 10),
                    thresholds: {
                      for (final t in MedalTier.values)
                        t: MonthlyMedalRules.threshold(2026, 10, t)
                    },
                  ),
                ]),
          ),
        ]),
      );
    });

Widget card(Candidate c, int days, int day, double w, Framing f) =>
    MountainCard(
        c: c,
        days: days,
        day: day,
        cardW: w,
        framing: f,
        month: days == 28 ? 'February' : 'October',
        year: days == 28 ? 2027 : 2026,
        monthNumber: days == 28 ? 2 : 10);

/// A caption above [child], wrapped to the card's width [w].
Widget captioned(String text, Brightness b, Widget child, double w) => SizedBox(
    width: w,
    child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
              height: 36,
              child: Caption(
                  text,
                  b == Brightness.light
                      ? const Color(0xFF263D39)
                      : const Color(0xFFE4E2D8))),
          child
        ]));

void main() {
  setUpAll(loadFonts);
  final numbers = StringBuffer();
  tearDownAll(() =>
      File('$out/shell_numbers.txt').writeAsStringSync(numbers.toString()));

  // Per candidate: 375 and 320, light and dark, 31 days, days 3 and 25.
  for (final c in candidates) {
    for (final screen in [375.0, 320.0]) {
      for (final b in Brightness.values) {
        final name = '${c.id}_${screen.toInt()}_${b.name}_31d.png';
        testWidgets(name, (tester) async {
          final w = cardWidth(screen);
          await shoot(
              tester,
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final day in [3, 25]) ...[
                  captioned(
                      '${c.title} · ${screen.toInt()} pt · ${b.name} · day $day of 31',
                      b,
                      card(c, 31, day, w, f1),
                      w),
                  const SizedBox(width: 16),
                ]
              ]),
              Size(2 * (w + 16) + 28, 560),
              '$out/$name',
              b);
        });
      }
      final name28 = '${c.id}_${screen.toInt()}_light_28d.png';
      testWidgets(name28, (tester) async {
        final w = cardWidth(screen);
        await shoot(
            tester,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final day in [3, 25]) ...[
                captioned('${c.title} · ${screen.toInt()} pt · day $day of 28',
                    Brightness.light, card(c, 28, day, w, f1), w),
                const SizedBox(width: 16),
              ]
            ]),
            Size(2 * (w + 16) + 28, 560),
            '$out/$name28',
            Brightness.light);
      });
    }
    final framingName = '${c.id}_framing_375_light_31d.png';
    testWidgets(framingName, (tester) async {
      final w = cardWidth(375);
      await shoot(
          tester,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final day in [3, 25]) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final f in [f1, whole]) ...[
                  captioned('${c.id.toUpperCase()} · ${f.id} · day $day of 31',
                      Brightness.light, card(c, 31, day, w, f), w),
                  const SizedBox(width: 16),
                ]
              ]),
              const SizedBox(height: 14),
            ]
          ]),
          Size(2 * (w + 16) + 28, 2 * 560),
          '$out/$framingName',
          Brightness.light);
    });
  }

  testWidgets('current_375_light_31d.png', (tester) async {
    final w = cardWidth(375);
    await shoot(
        tester,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final day in [3, 25]) ...[
            captioned('Today (Batch 3b) · 375 pt · light · day $day of 31',
                Brightness.light, currentCard(w, day, null), w),
            const SizedBox(width: 16),
          ]
        ]),
        Size(2 * (w + 16) + 28, 560),
        '$out/current_375_light_31d.png',
        Brightness.light);
    await tester.pump();
  });

  testWidgets('overview_375_light_31d.png', (tester) async {
    final w = cardWidth(375);
    await shoot(
        tester,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final day in [3, 25]) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              captioned('Today (Batch 3b) · day $day', Brightness.light,
                  currentCard(w, day, null), w),
              const SizedBox(width: 16),
              for (final c in candidates) ...[
                captioned('${c.title} · day $day', Brightness.light,
                    card(c, 31, day, w, f1), w),
                const SizedBox(width: 16),
              ]
            ]),
            const SizedBox(height: 16),
          ]
        ]),
        Size(3 * (w + 16) + 28, 2 * 560),
        '$out/overview_375_light_31d.png',
        Brightness.light);
  });

  // Shell measurements: plaque vs the month/counter row at 320 pt, and
  // text contrast.
  for (final ts in AppTextSize.values) {
    for (final screen in [320.0, 375.0]) {
      testWidgets('shell ${screen.toInt()} ${ts.name}', (tester) async {
        final w = cardWidth(screen);
        tester.view.physicalSize = Size(w + 40, 520) * 3;
        tester.view.devicePixelRatio = 3;
        await tester.pumpWidget(MaterialApp(
            theme: buildAppTheme(Brightness.light, textSize: ts),
            home: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: card(c1, 30, 30, w, f1)))));
        final plaque = tester.getRect(find.byKey(MountainCard.plaqueKey));
        final month = tester.getRect(find.byKey(MountainCard.monthKey));
        final counter = tester.getRect(find.byKey(MountainCard.counterKey));
        final horizontalRoom =
            math.min(plaque.left - month.right, counter.left - plaque.right);
        numbers.writeln(
            '${screen.toInt()} pt ${ts.name.padRight(6)} card ${w.toStringAsFixed(1)} '
            'plaque ${plaque.width.toStringAsFixed(1)}×${plaque.height.toStringAsFixed(1)} '
            'bottom ${(plaque.bottom - 20).toStringAsFixed(1)} | month/counter row top ${(month.top - 20).toStringAsFixed(1)} '
            '| vertical gap ${(month.top - plaque.bottom).toStringAsFixed(1)} '
            '| overlap ${plaque.overlaps(month) || plaque.overlaps(counter)} '
            '| side room beside plaque ${horizontalRoom.toStringAsFixed(1)} '
            '| "September · 30 / 30" row fits: ${month.right < counter.left}');
      });
    }
  }
  test('contrast', () {
    for (final b in Brightness.values) {
      final scheme = buildAppTheme(b).colorScheme;
      final p = ClimbThemes.greenSlope.paletteFor(b);
      final t = tones(p);
      numbers.writeln(
          '${b.name}: plaque text onSurface on surfaceContainerHigh '
          '${contrast(scheme.onSurface, scheme.surfaceContainerHigh).toStringAsFixed(2)}:1; '
          'plaque border outline vs card ${contrast(scheme.outline, scheme.surfaceContainerHigh).toStringAsFixed(2)}:1, vs body ${contrast(scheme.outline, scheme.surfaceContainerLow).toStringAsFixed(2)}:1; '
          'month/counter ink on sky ${contrast(p.ink, t['sky']!).toStringAsFixed(2)}, '
          'far ${contrast(p.ink, t['far']!).toStringAsFixed(2)}, mid ${contrast(p.ink, t['mid']!).toStringAsFixed(2)}, '
          'body ${contrast(p.ink, t['body']!).toStringAsFixed(2)}, shadow ${contrast(p.ink, t['shadow']!).toStringAsFixed(2)}');
      numbers.writeln(
          '${b.name} tones: ${t.entries.map((e) => '${e.key} #${e.value.toARGB32().toRadixString(16).substring(2).toUpperCase()}').join(', ')}');
    }
  });
}
