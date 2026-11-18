import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/widgets/profile_stage.dart';

import 'support/fix3_render.dart';

/// Fix round 3, C5 (SPEC V23, v11): the ribbon looked thick on the device.
/// Its width follows the screen, tails included: the screen's width − 60
/// (330 at 390, 368 at 428). The name and the "Climbing with" line each
/// stay on one line, shrinking to 85 % at most and then ending with "…";
/// 62 pt tall at the default text size. Checked at the five sizes and the
/// largest text size; `FIX3_CAPTURE=1` renders them.
void main() {
  final ribbon = find.byKey(ProfileStage.ribbonKey);
  final start = find.byKey(ProfileStage.tailStartKey);
  final end = find.byKey(ProfileStage.tailEndKey);

  Future<void> pumpStage(WidgetTester tester, Size size,
      {String name = 'Ada',
      AppTextSize text = AppTextSize.medium,
      Brightness brightness = Brightness.light}) async {
    await pumpFix3(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: ProfileStage(
            hero: Avatar.fox,
            name: name,
            since: DateTime(2026, 11, 2),
            onChange: () {},
            onEditName: () {},
          ),
        ),
      ),
      size: size,
      textSize: text,
      brightness: brightness,
    );
  }

  /// A line's own text: one line, drawn at [scale] of its [size] or more.
  void expectOneLine(WidgetTester tester, Key key, double size) {
    final text = tester.widget<Text>(find.byKey(key));
    expect(text.maxLines, 1);
    expect(text.style!.fontSize! / size,
        greaterThanOrEqualTo(ProfileStage.ribbonMinTextScale - 1e-9));
    final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.byKey(key), matching: find.byType(RichText)));
    // One line high (no wrap).
    expect(
        paragraph.size.height, lessThan(paragraph.text.style!.fontSize! * 2));
  }

  for (final size in const [
    Size(375, 667),
    Size(390, 844),
    Size(402, 874),
    Size(428, 926),
    Size(440, 956),
  ]) {
    for (final text in [AppTextSize.medium, AppTextSize.large]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('$name, ${text.name} text: screen − 60 wide, one line each',
          (tester) async {
        await pumpStage(tester, size, text: text);
        expect(tester.takeException(), isNull);
        final whole = Rect.fromLTRB(
            tester.getRect(start).left,
            tester.getRect(ribbon).top,
            tester.getRect(end).right,
            tester.getRect(ribbon).bottom);
        expect(whole.width, closeTo(size.width - 60, .5),
            reason: 'tails included');
        expect(whole.center.dx, closeTo(size.width / 2, .5));
        if (text == AppTextSize.medium) {
          expect(tester.getSize(ribbon).height, 62);
        }
        expectOneLine(tester, ProfileStage.nameKey, 23);
        expectOneLine(tester, ProfileStage.climbingKey, 12);
        await fix3Capture(tester, 'V23-ribbon-$name-${text.name}');
      });
    }
  }

  testWidgets(
      'a long name and a long line: shrink to 85 %, then "…" (never wrap)',
      (tester) async {
    await pumpStage(tester, const Size(375, 667),
        name: 'Maximiliana Alexandrina Johanson', text: AppTextSize.large);
    final name = tester.widget<Text>(find.byKey(ProfileStage.nameKey));
    expect(name.style!.fontSize, closeTo(23 * .85, .01));
    expect(name.overflow, TextOverflow.ellipsis);
    expectOneLine(tester, ProfileStage.nameKey, 23);
    expectOneLine(tester, ProfileStage.climbingKey, 12);
  });

  testWidgets('dark: the same ribbon', (tester) async {
    await pumpStage(tester, const Size(428, 926), brightness: Brightness.dark);
    await fix3Capture(tester, 'V23-ribbon-428x926', dark: true);
  });
}
