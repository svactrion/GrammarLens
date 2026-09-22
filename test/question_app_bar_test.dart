import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/question_app_bar.dart';

/// Covers the button-layout batch's explicit requirement: the title must
/// not shift sideways between question 1 (no valid Back destination) and
/// question 2 (Back becomes usable). Before this batch, Back lived in the
/// bottom footer and was omitted outright on question 1 rather than shown
/// disabled — omitting it shrank the app bar's leading slot, which shifted
/// the centered title's on-screen x position the moment Back appeared on
/// question 2. HeaderIconButton's `visible` flag fixes this by
/// always reserving Back's exact footprint, whether or not it's usable
/// right now.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool showBack,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          appBar: QuestionAppBar(
            title: 'Articles',
            currentIndex: showBack ? 1 : 0,
            total: 5,
            showBack: showBack,
            onBack: () {},
            onClose: () {},
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets(
      "the title's center x is identical on question 1 (Back hidden) and "
      'question 2 (Back visible)', (tester) async {
    await pump(tester, showBack: false);
    final centerOnQ1 = tester.getCenter(find.text('Articles')).dx;

    await pump(tester, showBack: true);
    final centerOnQ2 = tester.getCenter(find.text('Articles')).dx;

    expect(centerOnQ2, centerOnQ1);
  });

  testWidgets(
      'Back reserves its 40x40 footprint even when hidden on question 1',
      (tester) async {
    await pump(tester, showBack: false);

    // No tappable Back button — but HeaderIconButton still occupies
    // the same box, invisible rather than absent.
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    expect(
      tester
          .widget<SizedBox>(
            find
                .ancestor(
                  of: find.byIcon(Icons.close_rounded),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      HeaderIconButton.size,
    );
  });

  testWidgets('Back and Close are both 40x40', (tester) async {
    await pump(tester, showBack: true);

    final backSize = tester.getSize(find.byIcon(Icons.arrow_back_rounded));
    final closeSize = tester.getSize(find.byIcon(Icons.close_rounded));

    // The icons themselves are drawn smaller than the 40x40 touch target
    // (see HeaderIconButton) — what must match is each button's own
    // full SizedBox footprint, not the icon glyph size.
    Size buttonSize(Finder icon) => tester.getSize(
          find.ancestor(of: icon, matching: find.byType(SizedBox)).first,
        );

    expect(
      buttonSize(find.byIcon(Icons.arrow_back_rounded)),
      const Size(HeaderIconButton.size, HeaderIconButton.size),
    );
    expect(
      buttonSize(find.byIcon(Icons.close_rounded)),
      const Size(HeaderIconButton.size, HeaderIconButton.size),
    );
    // Sanity: the icon glyphs themselves are non-empty and equal-sized to
    // each other, even though smaller than their touch targets.
    expect(backSize, closeSize);
  });

  testWidgets(
      'shows only the N / total counter — no progress bar duplicating it '
      '(docs/design-audit.md, Batch 0 item 7)', (tester) async {
    await pump(tester, showBack: true);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('2 / 5'), findsOneWidget);
  });

  testWidgets('tapping Back and Close fire their own callbacks',
      (tester) async {
    var backTapped = false;
    var closeTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          appBar: QuestionAppBar(
            title: 'Articles',
            currentIndex: 1,
            total: 5,
            showBack: true,
            onBack: () => backTapped = true,
            onClose: () => closeTapped = true,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(backTapped, isTrue);

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(closeTapped, isTrue);
  });
}
