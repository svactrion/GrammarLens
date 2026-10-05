import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_carousel.dart';

/// Onboarding in two steps (the 1.2.0 additional screens package): the
/// companion and the required name, then the optional goal.
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<UserProfile>? onComplete,
    Size size = const Size(390, 844),
    double keyboard = 0,
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      home: OnboardingScreen(onComplete: onComplete ?? (_) {}),
    ));
    await tester.pumpAndSettle();
  }

  Finder continueButton() => find.byKey(OnboardingScreen.continueKey);
  Finder startButton() => find.byKey(OnboardingScreen.startKey);
  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<FilledButton>(button).onPressed != null;

  Future<void> enterName(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), name);
    await tester.pump();
  }

  Future<void> toGoalStep(WidgetTester tester, {String name = 'Ada'}) async {
    await enterName(tester, name);
    await tester.tap(continueButton());
    await tester.pumpAndSettle();
  }

  Future<void> chooseGoalAndStart(WidgetTester tester,
      [LearningGoal goal = LearningGoal.examPrep]) async {
    await tester.ensureVisible(find.byKey(OnboardingScreen.goalKey(goal)));
    await tester.tap(find.byKey(OnboardingScreen.goalKey(goal)));
    await tester.pump();
    await tester.tap(startButton());
    await tester.pump();
  }

  /// The avatar whose semantics node sits at the carousel's centre: the one
  /// selected, read as a screen reader would.
  String centeredAvatarLabel(WidgetTester tester) {
    final center = tester.getCenter(find.byType(PageView)).dx;
    for (final avatar in Avatar.values) {
      final finder = find.bySemanticsLabel(avatar.semanticLabel);
      if (finder.evaluate().isEmpty) continue;
      final rect = tester.getRect(finder);
      if (rect.left <= center && center <= rect.right) {
        return avatar.semanticLabel;
      }
    }
    throw StateError('no centered avatar found');
  }

  group('step 1: companion and name', () {
    testWidgets(
        'the carousel sits above the name — face and name are one identity '
        'step — with no Done button of its own', (tester) async {
      await pump(tester);
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Meet your learning companion.'), findsOneWidget);
      expect(
          tester.getTopLeft(find.byType(PageView)).dy,
          lessThan(
              tester.getTopLeft(find.byKey(OnboardingScreen.nameFieldKey)).dy));
      expect(find.widgetWithText(FilledButton, 'Done'), findsNothing);
    });

    testWidgets(
        'every avatar is reachable with Next (16, then the loop back), the '
        'caption names it, and the one chosen is the one saved',
        (tester) async {
      UserProfile? completed;
      await pump(tester, onComplete: (p) => completed = p);
      final seen = <String>{};
      for (var i = 0; i < Avatar.count; i++) {
        seen.add(centeredAvatarLabel(tester));
        final caption =
            tester.widget<Text>(find.byKey(AvatarCarousel.captionKey)).data!;
        expect(caption, startsWith('${centeredAvatarLabel(tester)} · '));
        expect(caption, endsWith(' / ${Avatar.count}'));
        await tester.tap(find.byKey(AvatarCarousel.nextKey));
        await tester.pumpAndSettle();
      }
      expect(seen, Avatar.values.map((a) => a.semanticLabel).toSet());

      await tester.tap(find.byKey(AvatarCarousel.previousKey));
      await tester.pumpAndSettle();
      final chosen = centeredAvatarLabel(tester);
      await toGoalStep(tester);
      await chooseGoalAndStart(tester);
      expect(completed!.avatar!.semanticLabel, chosen);
      expect(Avatar.fromJson(completed!.avatar!.toJson()), completed!.avatar);
    });

    testWidgets(
        'a swipe changes the avatar that is saved, not one re-rolled at the '
        'end', (tester) async {
      UserProfile? completed;
      await pump(tester, onComplete: (p) => completed = p);
      final before = centeredAvatarLabel(tester);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      final after = centeredAvatarLabel(tester);
      expect(after, isNot(before));
      await toGoalStep(tester);
      await chooseGoalAndStart(tester);
      expect(completed!.avatar!.semanticLabel, after);
    });

    testWidgets(
        'never touching the carousel still saves a real avatar (PRD v2 '
        '§13.5)', (tester) async {
      UserProfile? completed;
      await pump(tester, onComplete: (p) => completed = p);
      await toGoalStep(tester);
      await chooseGoalAndStart(tester);
      expect(Avatar.values, contains(completed!.avatar));
    });

    testWidgets(
        'the name is required: Continue is disabled while it is empty or '
        'only spaces, enabled and orange once there is one', (tester) async {
      await pump(tester);
      expect(enabled(tester, continueButton()), isFalse);
      await enterName(tester, '   ');
      expect(enabled(tester, continueButton()), isFalse);
      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2'), findsOneWidget);

      await enterName(tester, 'Ada');
      expect(enabled(tester, continueButton()), isTrue);
      final theme = buildAppTheme(Brightness.light);
      final style = tester.widget<FilledButton>(continueButton()).style!;
      expect(style.backgroundColor!.resolve({}), theme.colorScheme.primary);
      expect(style.foregroundColor!.resolve({}), theme.colorScheme.onPrimary);
      expect(tester.getSize(continueButton()).height, greaterThanOrEqualTo(54));
      expect((style.shape!.resolve({})! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(17));
    });

    testWidgets(
        'the name is trimmed, keeps its Unicode, and stops at 40 characters '
        'with no counter (O2)', (tester) async {
      UserProfile? completed;
      await pump(tester, onComplete: (p) => completed = p);
      final field =
          tester.widget<TextField>(find.byKey(OnboardingScreen.nameFieldKey));
      expect(field.maxLength, UserProfile.maxNameLength);
      await enterName(tester, 'x' * 60);
      expect(field.controller!.text.length, 40);
      expect(find.textContaining('/ 40'), findsNothing);

      await toGoalStep(tester, name: '  Çağrı İnce Öztürk  ');
      await chooseGoalAndStart(tester);
      expect(completed!.name, 'Çağrı İnce Öztürk');
    });

    testWidgets(
        'with the keyboard open the name field and Continue are above it; the '
        'companion scrolls away instead', (tester) async {
      await pump(tester, size: const Size(375, 667), keyboard: 260);
      await tester.tap(find.byKey(OnboardingScreen.nameFieldKey));
      await enterName(tester, 'Ada');
      await tester.pumpAndSettle();
      const keyboardTop = 667.0 - 260;
      expect(tester.getRect(continueButton()).bottom,
          lessThanOrEqualTo(keyboardTop));
      expect(tester.getRect(find.byKey(OnboardingScreen.nameFieldKey)).bottom,
          lessThanOrEqualTo(keyboardTop));
      expect(tester.takeException(), isNull);
    });
  });

  group('step 2: goal', () {
    testWidgets(
        'the copy says why it is asked, with no promise of personalized '
        'lessons; the old line is gone', (tester) async {
      await pump(tester);
      await toGoalStep(tester);
      expect(find.text('HELP SHAPE GRAMMARLENS'), findsOneWidget);
      expect(
          find.text('Choose what matters most to you. Your answer helps us '
              'decide what to improve next.'),
          findsOneWidget);
      expect(find.text('This helps us suggest where to start.'), findsNothing);
      expect(find.textContaining('suggest'), findsNothing);
      expect(find.text('Everyday confidence'), findsOneWidget);
      expect(find.text('General fluency'), findsNothing);
      expect(find.text('One more thing, Ada.'), findsOneWidget);
    });

    testWidgets(
        'no goal is preselected: Start stays disabled until one is chosen; '
        'Skip is always there', (tester) async {
      await pump(tester);
      await toGoalStep(tester);
      for (final goal in LearningGoal.values) {
        expect(tester.getSemantics(find.byKey(OnboardingScreen.goalKey(goal))),
            isSemantics(hasCheckedState: true, isChecked: false));
        expect(
            tester.getSize(find.byKey(OnboardingScreen.goalKey(goal))).height,
            greaterThanOrEqualTo(91));
      }
      expect(enabled(tester, startButton()), isFalse);
      expect(
          tester
              .widget<TextButton>(find.byKey(OnboardingScreen.skipGoalKey))
              .onPressed,
          isNotNull);
      await tester.tap(find.byKey(OnboardingScreen.goalKey(LearningGoal.work)));
      await tester.pump();
      expect(enabled(tester, startButton()), isTrue);
      expect(
          tester.getSemantics(
              find.byKey(OnboardingScreen.goalKey(LearningGoal.work))),
          isSemantics(hasCheckedState: true, isChecked: true));
    });

    testWidgets('Skip finishes with no goal (stored as skipped)',
        (tester) async {
      UserProfile? completed;
      await pump(tester, onComplete: (p) => completed = p);
      await toGoalStep(tester);
      await tester.tap(find.byKey(OnboardingScreen.skipGoalKey));
      await tester.pump();
      expect(completed!.learningGoal, isNull);
      expect(completed!.toMap()['learning_goal'], 'skipped');
    });

    testWidgets(
        'Back returns to step 1 with the name, the companion and the goal '
        'as they were', (tester) async {
      UserProfile? completed;
      await pump(tester, onComplete: (p) => completed = p);
      await tester.tap(find.byKey(AvatarCarousel.nextKey));
      await tester.pumpAndSettle();
      final avatar = centeredAvatarLabel(tester);
      await toGoalStep(tester, name: 'Ada');
      await tester.tap(find.byKey(OnboardingScreen.goalKey(LearningGoal.work)));
      await tester.pump();

      await tester.tap(find.byKey(OnboardingScreen.backKey));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byKey(OnboardingScreen.nameFieldKey))
              .controller!
              .text,
          'Ada');
      expect(centeredAvatarLabel(tester), avatar);

      await tester.tap(continueButton());
      await tester.pumpAndSettle();
      expect(enabled(tester, startButton()), isTrue,
          reason: 'the goal is still chosen');
      await tester.tap(startButton());
      await tester.pump();
      expect(completed!.learningGoal, LearningGoal.work);
      expect(completed!.avatar!.semanticLabel, avatar);
    });

    testWidgets(
        'the privacy line says what really happens: the name stays, the goal '
        'goes with usage data; the AI facts are one tap away', (tester) async {
      await pump(tester);
      await toGoalStep(tester);
      expect(
          onboardingPrivacyNote,
          'Your name stays on this device. Your goal is sent with app usage '
          'data, never with your name. Usage and crash data is collected.');
      await tester.ensureVisible(find.text(onboardingPrivacyNote));
      expect(find.text(onboardingPrivacyNote), findsOneWidget);
      expect(find.textContaining('never sent'), findsNothing);
      expect(find.textContaining('goal stay'), findsNothing);

      await tester.ensureVisible(find.byKey(OnboardingScreen.dataLinkKey));
      await tester.tap(find.byKey(OnboardingScreen.dataLinkKey));
      await tester.pumpAndSettle();
      final sheet = onboardingDataFacts.map((f) => '${f.$1} ${f.$2}').join();
      expect(sheet, contains('Anthropic (Claude)'));
      expect(sheet, contains('We ask for your permission first.'));
      expect(sheet, contains('It does not personalize your lessons.'));
      for (final (heading, _) in onboardingDataFacts) {
        expect(
            find.descendant(
                of: find.byType(Dialog),
                matching: find.textContaining(heading, findRichText: true)),
            findsOneWidget);
      }
    });
  });

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          '$width pt, Large text, ${brightness.name}: both steps, keyboard '
          'open on step 1, no overflow, no ellipsis', (tester) async {
        final height = width < 360 ? 568.0 : 844.0;
        final keyboard = width < 360 ? 260.0 : 336.0;
        await pump(tester,
            size: Size(width, height),
            keyboard: keyboard,
            brightness: brightness,
            textSize: AppTextSize.large);
        await tester.tap(find.byKey(OnboardingScreen.nameFieldKey));
        await enterName(tester, 'Maximiliana Alexandrina Konstantinou');
        await tester.pumpAndSettle();
        expect(tester.getRect(continueButton()).bottom,
            lessThanOrEqualTo(height - keyboard));
        expect(tester.takeException(), isNull);

        await tester.tap(continueButton());
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        await tester.ensureVisible(
            find.byKey(OnboardingScreen.goalKey(LearningGoal.general)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          expect(text.overflow, isNot(TextOverflow.ellipsis),
              reason: text.data);
        }
      });
    }
  }
}
