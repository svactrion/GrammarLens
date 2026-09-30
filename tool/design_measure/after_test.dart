// Batch 3b "after" images: the real product (HomeScreen, MonthlyMountain),
// not the study copy in scene.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'home_fakes.dart';
import 'layouts.dart';

/// Screens with their status bar / home indicator insets.
const _screens = [
  (Size(320, 568), 20.0, 0.0),
  (Size(375, 667), 20.0, 0.0),
  (Size(430, 932), 59.0, 34.0),
];

Future<void> _precacheAvatar(WidgetTester tester, GlobalKey key) =>
    tester.runAsync(() => precacheImage(
        AssetImage(Avatar.values.first.assetPath), key.currentContext!));

/// The real mountain window at a card [width], the pawn on [day].
Widget _window(double width, int days, int day, Brightness b, String caption) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Caption(caption, width: width, brightness: b),
        SizedBox(
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: MonthlyMountain(
                days: days,
                completedDays: day,
                avatar: Avatar.values.first,
                allowUserScroll: false),
          ),
        ),
      ],
    );

Future<void> _shootWindows(WidgetTester tester, Widget child, Size size,
    String file, Brightness b) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(b),
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: b == Brightness.light
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF101416),
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    ),
  ));
  await _precacheAvatar(tester, key);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await writePng(tester, key, file);
}

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });

  // Home: 12 of 31 steps in October 2026, 40 correct and 12 wrong answers
  // (92 points: Bronze reached, 78).
  for (final (size, top, bottom) in _screens) {
    for (final (textSize, brightness) in [
      (AppTextSize.medium, Brightness.light),
      (AppTextSize.large, Brightness.light),
      if (size.width == 375) (AppTextSize.medium, Brightness.dark),
    ]) {
      final name = 'after_home_${size.width.toInt()}_${textSize.name}_'
          '${brightness.name}.png';
      testWidgets(name, (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: designHome(
              clock: DateTime(2026, 10, 12, 9),
              storage: DesignStorage(steps: 12, correct: 40, wrong: 12),
              textSize: textSize,
              brightness: brightness),
        ));
        await _precacheAvatar(tester, key);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        await writePng(tester, key, '$out/$name');
      });
    }
  }

  // The window at the three card widths, pawn on days 4, 12 and 24.
  for (final screen in [320.0, 375.0, 430.0]) {
    final name = 'after_window_${screen.toInt()}_light_31d.png';
    testWidgets(name, (tester) async {
      final w = cardWidth(screen);
      await _shootWindows(
          tester,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final day in [4, 12, 24]) ...[
              _window(w, 31, day, Brightness.light,
                  '${screen.toInt()} pt screen · day $day of 31'),
              const SizedBox(width: 12),
            ]
          ]),
          Size(3 * (w + 12) + 24, 350 + 24 + 22),
          '$out/$name',
          Brightness.light);
    });
  }

  // Near the summit for each month length: D2 in the product.
  testWidgets('after_markers', (tester) async {
    final w = cardWidth(375);
    await _shootWindows(
        tester,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final days in [28, 29, 30, 31]) ...[
            _window(
                w,
                days,
                days - 2,
                Brightness.light,
                days == 31
                    ? '31 days · day-28 marker shown'
                    : days == 28
                        ? '28 days · day 28 is the summit'
                        : '$days days · day-28 marker hidden'),
            const SizedBox(width: 12),
          ]
        ]),
        Size(4 * (w + 12) + 24, 350 + 24 + 22),
        '$out/after_markers_28-31d_375_light.png',
        Brightness.light);
  });
}
