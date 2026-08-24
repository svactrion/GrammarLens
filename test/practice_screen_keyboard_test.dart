import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

// Verifies the fix for docs/prd.md Theme 2 / roadmap "What's next #1": the
// on-screen keyboard must not cover the primary Next/Skip/Submit button on
// free-text question screens. `FakeViewPadding` is how Flutter reports a
// real keyboard's height to the app, so setting `tester.view.viewInsets`
// reproduces the exact signal a live device sends when its keyboard opens —
// without needing a live simulator keyboard or simulated taps.
void main() {
  const topic = Topic(
    id: TopicId.articles,
    title: 'Articles',
    description: 'a/an/the',
    icon: Icons.school,
  );

  const practiceSet = PracticeSet(
    topicId: 'articles',
    items: [
      PracticeItem(
        id: 'q1',
        type: PracticeItemType.fillInBlank,
        instruction: 'I saw ___ elephant at the zoo.',
      ),
      PracticeItem(
        id: 'q2',
        type: PracticeItemType.sentenceWriting,
        instruction: 'Write a sentence describing yesterday using the past '
            'perfect tense, with enough detail that this line wraps across '
            'more than one row on a small phone screen.',
      ),
    ],
  );

  // Logical size × devicePixelRatio, matching real device profiles.
  const devices = {
    'iPhone SE (small)': (size: Size(375, 667), dpr: 2.0),
    'iPhone 15 Pro Max (large)': (size: Size(430, 932), dpr: 3.0),
  };

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Size logicalSize,
    required double devicePixelRatio,
  }) async {
    tester.view.physicalSize = logicalSize * devicePixelRatio;
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeScreen(
          topic: topic,
          practiceSet: practiceSet,
          claudeService: ClaudeService(),
          storageService: StorageService(),
          analyticsService: AnalyticsService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expectButtonAboveKeyboard(
    WidgetTester tester, {
    required double keyboardHeight,
  }) async {
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // FakeViewPadding takes physical pixels; MediaQuery.viewInsets (and
    // therefore the widget under test) works in logical pixels, so convert
    // using the same devicePixelRatio the test view reports.
    tester.view.viewInsets =
        FakeViewPadding(bottom: keyboardHeight * tester.view.devicePixelRatio);
    await tester.pumpAndSettle();

    // Exactly one FilledButton is on screen at a time — the primary action
    // (Skip/Next/Submit, whichever label applies). Finding by type avoids
    // coupling this check to whichever label the current state happens to
    // show.
    final buttonRect = tester.getRect(find.byType(FilledButton));
    final fieldRect = tester.getRect(find.byType(TextField));

    expect(
      buttonRect.bottom,
      lessThanOrEqualTo(screenHeight - keyboardHeight),
      reason: 'Primary button must stay above the keyboard, not hidden '
          'behind it.',
    );
    expect(
      fieldRect.bottom,
      lessThanOrEqualTo(screenHeight - keyboardHeight),
      reason: 'Answer field must stay above the keyboard, not hidden '
          'behind it.',
    );
  }

  for (final MapEntry(key: deviceName, value: device) in devices.entries) {
    group(deviceName, () {
      testWidgets('short fill-in-blank: button stays visible above keyboard',
          (tester) async {
        await pumpScreen(
          tester,
          logicalSize: device.size,
          devicePixelRatio: device.dpr,
        );
        await tester.enterText(find.byType(TextField), 'an');
        await expectButtonAboveKeyboard(tester, keyboardHeight: 300);
      });

      testWidgets('long sentence-writing: button stays visible above keyboard',
          (tester) async {
        await pumpScreen(
          tester,
          logicalSize: device.size,
          devicePixelRatio: device.dpr,
        );
        // Advance to the second (long-form) question.
        await tester.tap(find.widgetWithText(FilledButton, 'Skip'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'By the time I arrived, she had already left for the airport.',
        );
        await expectButtonAboveKeyboard(tester, keyboardHeight: 320);
      });

      testWidgets('button returns to the bottom once the keyboard closes',
          (tester) async {
        await pumpScreen(
          tester,
          logicalSize: device.size,
          devicePixelRatio: device.dpr,
        );
        final screenHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;

        tester.view.viewInsets =
            FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
        await tester.pumpAndSettle();

        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();

        final buttonRect =
            tester.getRect(find.widgetWithText(FilledButton, 'Skip'));
        expect(buttonRect.bottom, greaterThan(screenHeight - 60));
      });

      testWidgets(
          'answer field has no scrollable ancestor, so the keyboard can '
          'never force-scroll the question header to keep it in view',
          (tester) async {
        await pumpScreen(
          tester,
          logicalSize: device.size,
          devicePixelRatio: device.dpr,
        );

        // The header (context/instruction/hint) lives in its own scroll
        // region, separate from the input. If the TextField ever regained a
        // Scrollable ancestor spanning the header again, Flutter's built-in
        // "scroll the focused field into view" behaviour could drag the
        // header off screen the way it did before this fix.
        expect(
          find.ancestor(
            of: find.byType(TextField),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
      });

      testWidgets(
          'question header position is unaffected by the keyboard opening',
          (tester) async {
        await pumpScreen(
          tester,
          logicalSize: device.size,
          devicePixelRatio: device.dpr,
        );
        final instructionFinder =
            find.text(practiceSet.items[0].instruction);
        final rectBefore = tester.getRect(instructionFinder);

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'an');
        tester.view.viewInsets =
            FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();

        expect(tester.getRect(instructionFinder), rectBefore);
      });

      testWidgets('tapping outside the text field dismisses the keyboard',
          (tester) async {
        await pumpScreen(
          tester,
          logicalSize: device.size,
          devicePixelRatio: device.dpr,
        );

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'an');
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);

        // Tap the question card's background — nowhere near the field or
        // the buttons — the way a user reaching to dismiss the keyboard
        // would.
        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
      });
    });
  }
}
