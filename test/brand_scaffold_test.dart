import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/widgets/brand_scaffold.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';

/// D1's rollout (docs/design-audit.md §5, docs/build-log.md 2026-09-09)
/// gave BrandScaffold two constructor asserts and an isTabRoot-driven
/// bottom-padding source, none of which had a test — closed here
/// (docs/design-audit.md, Batch 0/4).
void main() {
  group('constructor asserts', () {
    test('throws when both children and body are provided', () {
      expect(
        () => BrandScaffold(
          title: const Text('Title'),
          body: const SizedBox(),
          children: const [SizedBox()],
        ),
        throwsAssertionError,
      );
    });

    test('throws when neither children nor body is provided', () {
      expect(
        () => BrandScaffold(title: const Text('Title')),
        throwsAssertionError,
      );
    });

    test('throws when both title and appBar are provided', () {
      expect(
        () => BrandScaffold(
          title: const Text('Title'),
          appBar: AppBar(),
          children: const [SizedBox()],
        ),
        throwsAssertionError,
      );
    });

    test('throws when neither title nor appBar is provided', () {
      expect(
        () => BrandScaffold(children: const [SizedBox()]),
        throwsAssertionError,
      );
    });
  });

  group('isTabRoot bottom padding', () {
    testWidgets(
        'true reads the real bar height from NavBarClearance, not a guess',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NavBarClearance(
            value: 123,
            child: BrandScaffold(
              title: Text('Title'),
              isTabRoot: true,
              children: [SizedBox()],
            ),
          ),
        ),
      );

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect((listView.padding as EdgeInsets).bottom, 123);
    });

    testWidgets(
        'false (default, a pushed screen with no nav bar to clear) uses '
        'the safe-area bottom inset plus 16, not NavBarClearance',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NavBarClearance(
            // Present in the tree but must be ignored, since this
            // BrandScaffold is a pushed screen (isTabRoot: false) with no
            // floating nav bar of its own to clear.
            value: 999,
            child: MediaQuery(
              data: MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
              child: BrandScaffold(
                title: Text('Title'),
                children: [SizedBox()],
              ),
            ),
          ),
        ),
      );

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect((listView.padding as EdgeInsets).bottom, 34 + 16);
    });
  });
}
