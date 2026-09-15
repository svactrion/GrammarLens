import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/screens/avatar_picker_screen.dart';

void main() {
  testWidgets(
      'settling debounces before calling onAvatarChanged — a fast settle '
      "doesn't write immediately", (tester) async {
    final changes = <Avatar>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AvatarPickerScreen(
          currentAvatar: Avatar.values[3],
          onAvatarChanged: changes.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Settled, but the 500ms debounce window hasn't elapsed yet.
    expect(changes, isEmpty);

    await tester.pump(const Duration(milliseconds: 600));
    expect(changes, hasLength(1));
  });

  testWidgets(
      'leaving before the debounce fires still flushes the pending change '
      "instead of losing it", (tester) async {
    final changes = <Avatar>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AvatarPickerScreen(
                    currentAvatar: Avatar.values[3],
                    onAvatarChanged: changes.add,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(changes, isEmpty); // still inside the debounce window

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(changes, hasLength(1));
  });

  testWidgets('the centered avatar carries a Hero for the flight back to '
      "Settings' preview row", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AvatarPickerScreen(
          currentAvatar: Avatar.values[3],
          onAvatarChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heroes = tester.widgetList<Hero>(find.byType(Hero));
    expect(heroes.any((h) => h.tag == avatarHeroTag), isTrue);
  });

  Future<void> pumpPushed(
    WidgetTester tester, {
    required ValueChanged<Avatar> onAvatarChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AvatarPickerScreen(
                    currentAvatar: Avatar.values[3],
                    onAvatarChanged: onAvatarChanged,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'tapping Done closes the screen and keeps the swiped avatar saved, '
      'even mid-debounce — Done never adds a second write, it flushes the '
      'same pending one dispose() already would', (tester) async {
    final changes = <Avatar>[];
    await pumpPushed(tester, onAvatarChanged: changes.add);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(changes, isEmpty); // still inside the debounce window

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarPickerScreen), findsNothing);
    expect(changes, hasLength(1));
    expect(changes.single, isNot(Avatar.values[3]));
  });

  testWidgets(
      'tapping Done after the autosave already fired does not write a '
      'second time', (tester) async {
    final changes = <Avatar>[];
    await pumpPushed(tester, onAvatarChanged: changes.add);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600)); // past the debounce
    expect(changes, hasLength(1));

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarPickerScreen), findsNothing);
    expect(changes, hasLength(1)); // still just the one write, not two
  });

  testWidgets(
      'Done and the back button are equivalent exit paths — both leave '
      'the same swiped avatar saved', (tester) async {
    final doneChanges = <Avatar>[];
    await pumpPushed(tester, onAvatarChanged: doneChanges.add);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    final backChanges = <Avatar>[];
    await pumpPushed(tester, onAvatarChanged: backChanges.add);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(doneChanges, hasLength(1));
    expect(backChanges, hasLength(1));
    expect(doneChanges.single, backChanges.single);
  });

  group('neighbor peek stays at least half-visible at both target widths', () {
    // Regression coverage for the batch that enlarged the center avatar
    // (docs/build-log.md, same date): measuring the real widget tree (not
    // hand-derived arithmetic) found the neighbor's visible fraction
    // depends only on viewportFraction, not on centerRadius at all — so
    // this stays true regardless of whatever centerRadius is currently
    // set to, as long as viewportFraction itself doesn't move above 0.5.
    Future<void> expectHalfVisibleAt(
      WidgetTester tester,
      double screenWidth,
    ) async {
      tester.view.physicalSize = Size(screenWidth, 800) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AvatarPickerScreen(
            currentAvatar: Avatar.values[3],
            onAvatarChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final neighborLabel = Avatar.values[4].semanticLabel;
      final neighborImage = find.descendant(
        of: find.bySemanticsLabel(neighborLabel),
        matching: find.byWidgetPredicate((w) => w is Image),
      );
      expect(neighborImage, findsOneWidget,
          reason: 'the neighbor should already be built and peeking in');

      final rect = tester.getRect(neighborImage);
      final visibleWidth = (screenWidth - rect.left).clamp(0.0, rect.width);
      final fraction = visibleWidth / rect.width;

      expect(fraction, greaterThanOrEqualTo(0.5),
          reason: 'at $screenWidth pt, only ${(fraction * 100).round()}% of '
              'the neighbor is visible — swiping is the only way to pick, '
              'so this signal must never drop below half');
    }

    testWidgets('375pt (iPhone SE)', (tester) async {
      await expectHalfVisibleAt(tester, 375);
    });

    testWidgets('320pt (1st-gen iPhone SE width)', (tester) async {
      await expectHalfVisibleAt(tester, 320);
    });
  });
}
