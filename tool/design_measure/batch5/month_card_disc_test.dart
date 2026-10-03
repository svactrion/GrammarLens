// Batch 5 step 5 (N30): the largest medal disc with which the fullest
// summary month card does not scroll, per screen and text size. The real
// MonthCardSheet (Silver, the near-miss line, the next month) laid out at
// the screen's width with the app's theme (text size only through
// buildAppTheme(textSize:)); its natural height is the sheet's height
// (Batch 6: the sheet sizes to it), and a modal sheet holds at most 9/16
// of the screen. Discs 88 down to 40 in 2 pt steps
// (MonthCardSheet.debugMedalDiscOverride). Writes month_card_disc.txt.
//
//   DESIGN_MEASURE_OUT=docs/design/batch5/card \
//     flutter test tool/design_measure/batch5/month_card_disc_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/month_transition.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';

import '../layouts.dart' show loadFont, outDir;

const _screens = {
  '320x568': Size(320, 568),
  '375x667': Size(375, 667),
  '375x812': Size(375, 812),
  '430x932': Size(430, 932),
};

const _card = MonthCardData(
    year: 2026,
    month: 11,
    theme: ClimbThemes.emberPeak,
    variant: MonthCardVariant.summary,
    previousTheme: ClimbThemes.greenSlope,
    previousYear: 2026,
    previousMonth: 10,
    tier: MedalTier.silver,
    steps: 24,
    days: 31,
    score: 228,
    nearMiss: (MedalTier.gold, 5));

void main() {
  final rows = <String>[];
  setUpAll(loadFont);
  tearDown(() => MonthCardSheet.debugMedalDiscOverride = null);
  tearDownAll(() => File('${outDir()}/month_card_disc.txt').writeAsStringSync([
        'Batch 5 step 5 (N30): the fullest summary card\'s height (= the '
            'sheet\'s) by medal disc, against the sheet\'s limit (9/16 of the '
            'screen). Points. Largest fitting: the largest disc whose card '
            'is not taller than the limit.',
        '',
        'screen   text    limit   at 88   at 64   at 48   largest fitting',
        ...rows,
      ].join('\n')));

  for (final MapEntry(key: name, value: screen) in _screens.entries) {
    for (final size in AppTextSize.values) {
      testWidgets('$name $size', (tester) async {
        tester.view.physicalSize = screen * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        Future<double> heightAt(double disc) async {
          MonthCardSheet.debugMedalDiscOverride = disc;
          await tester.pumpWidget(MaterialApp(
            theme: buildAppTheme(Brightness.light, textSize: size),
            home: Material(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: screen.width,
                  child: KeyedSubtree(
                    key: key,
                    child: MonthCardSheet(
                        data: _card,
                        avatar: Avatar.values.first,
                        onClose: () {}),
                  ),
                ),
              ),
            ),
          ));
          return tester.getSize(find.byKey(key)).height;
        }

        final limit = screen.height * 9 / 16;
        final h88 = await heightAt(88), h64 = await heightAt(64);
        final h48 = await heightAt(48);
        double? best;
        for (var d = 88.0; d >= 40; d -= 2) {
          if (await heightAt(d) <= limit) {
            best = d;
            break;
          }
        }
        String f(double v) => v.toStringAsFixed(1).padLeft(6);
        rows.add('${name.padRight(8)} ${size.name.padRight(6)}  ${f(limit)}  '
            '${f(h88)}  ${f(h64)}  ${f(h48)}   ${best == null ? 'none' : best.toStringAsFixed(0)}');
      });
    }
  }
}
