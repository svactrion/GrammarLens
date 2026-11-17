import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/lucky_wheel_screen.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/buddy_picker.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';

/// Onboarding in three steps (UI polish V03–V05): the buddy on the
/// turntable (or the wheel), the required name, the optional goal.
/// (Replaces the 1.2.0 two-step tests: the carousel and the combined
/// companion + name step are gone.)
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<UserProfile>? onComplete,
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      home: OnboardingScreen(onComplete: onComplete ?? (_) {}),
    ));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<PressableButton>(find.byKey(key)).onPressed != null;

  Future<void> toNameStep(WidgetTester tester) async {
    await tester.tap(find.byKey(BuddyPicker.confirmKey));
    await tester.pumpAndSettle();
  }

  Future<void> toGoalStep(WidgetTester tester, {String name = 'Ada'}) async {
    await toNameStep(tester);
    await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), name);
    await tester.pump();
    await tester.tap(find.byKey(OnboardingScreen.continueKey));
    await tester.pumpAndSettle();
  }

  group('step 1: choose your buddy (V03)', () {
    testWidgets('Fox is in front first: "Climb with Fox", 1 / 9, its traits',
        (tester) async {
      await pump(tester);
      expect(find.text('Choose your climbing buddy'), findsOneWidget);
      expect(find.text('Climb with Fox'), findsOneWidget);
      expect(find.text('1 / 9'), findsOneWidget);
      expect(find.text('Curious'), findsOneWidget);
      expect(find.text('Try my luck'), findsOneWidget);
    });

    testWidgets('› and a drag turn the ring; the front hero is the one saved',
        (tester) async {
      UserProfile? saved;
      await pump(tester, onComplete: (p) => saved = p);
      await tester.tap(find.byKey(BuddyPicker.nextKey));
      await tester.pumpAndSettle();
      expect(find.text('Climb with Panda'), findsOneWidget);
      // A drag to the right brings the hero on the left (the next one) to
      // the front: the ring turns with the finger.
      await tester.drag(find.byKey(BuddyPicker.ringKey), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(find.text('Climb with Koala'), findsOneWidget);
      await tester.tap(find.byKey(BuddyPicker.previousKey));
      await tester.pumpAndSettle();
      expect(find.text('Climb with Panda'), findsOneWidget);
      await tester.tap(find.byKey(BuddyPicker.confirmKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
      await tester.pump();
      await tester.tap(find.byKey(OnboardingScreen.continueKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(OnboardingScreen.skipGoalKey));
      await tester.pump();
      expect(saved!.avatar, Avatar.panda);
    });

    testWidgets('the ring loops: ‹ from Fox is Crab', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(BuddyPicker.previousKey));
      await tester.pumpAndSettle();
      expect(find.text('Climb with Crab'), findsOneWidget);
    });

    testWidgets(
        '"Try my luck" opens the wheel; its result, confirmed, is the buddy',
        (tester) async {
      UserProfile? saved;
      await pump(tester, onComplete: (p) => saved = p);
      await tester.tap(find.byKey(BuddyPicker.tryLuckKey));
      await tester.pumpAndSettle();
      expect(find.byType(LuckyWheelScreen), findsOneWidget);
      expect(find.text('Let a buddy pick you'), findsOneWidget);
      await tester.tap(find.byKey(LuckyWheelScreen.spinKey));
      await tester.pumpAndSettle();
      final title = tester
          .widgetList<Text>(find.textContaining('picked you!'))
          .single
          .data!;
      final hero =
          Avatar.values.firstWhere((a) => title.startsWith(a.semanticLabel));
      expect(hero, isNot(Avatar.fox));
      await tester.tap(find.byKey(LuckyWheelScreen.confirmKey));
      await tester.pumpAndSettle();
      // On to the name step with the wheel's buddy.
      await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
      await tester.pump();
      await tester.tap(find.byKey(OnboardingScreen.continueKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(OnboardingScreen.skipGoalKey));
      await tester.pump();
      expect(saved!.avatar, hero);
    });

    testWidgets('"All buddies" brings the landed hero to the front of the ring',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(BuddyPicker.tryLuckKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LuckyWheelScreen.spinKey));
      await tester.pumpAndSettle();
      final title = tester
          .widgetList<Text>(find.textContaining('picked you!'))
          .single
          .data!;
      final hero =
          Avatar.values.firstWhere((a) => title.startsWith(a.semanticLabel));
      await tester.tap(find.byKey(LuckyWheelScreen.allBuddiesKey));
      await tester.pumpAndSettle();
      expect(find.text('Climb with ${hero.semanticLabel}'), findsOneWidget);
    });
  });

  group('step 2: the name (V04)', () {
    testWidgets('the buddy asks in its bubble; Continue waits for a name',
        (tester) async {
      await pump(tester);
      await toNameStep(tester);
      expect(find.text('What should I call you?'), findsOneWidget);
      expect(enabled(tester, OnboardingScreen.continueKey), isFalse);
      await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), '   ');
      await tester.pump();
      expect(enabled(tester, OnboardingScreen.continueKey), isFalse);
      await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
      await tester.pump();
      expect(enabled(tester, OnboardingScreen.continueKey), isTrue);
    });

    testWidgets('the name is trimmed, keeps its Unicode, stops at 40',
        (tester) async {
      UserProfile? saved;
      await pump(tester, onComplete: (p) => saved = p);
      await toNameStep(tester);
      final field =
          tester.widget<TextField>(find.byKey(OnboardingScreen.nameFieldKey));
      expect(field.maxLength, UserProfile.maxNameLength);
      await tester.enterText(
          find.byKey(OnboardingScreen.nameFieldKey), '  Zeynep Ünlü  ');
      await tester.pump();
      await tester.tap(find.byKey(OnboardingScreen.continueKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(OnboardingScreen.skipGoalKey));
      await tester.pump();
      expect(saved!.name, 'Zeynep Ünlü');
    });

    testWidgets('Back returns to the buddy with the same hero in front',
        (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(BuddyPicker.nextKey));
      await tester.pumpAndSettle();
      await toNameStep(tester);
      await tester.tap(find.byKey(OnboardingScreen.backKey));
      await tester.pumpAndSettle();
      expect(find.text('Climb with Panda'), findsOneWidget);
    });
  });

  group('step 3: the goal (V05)', () {
    testWidgets(
        'greets by name, four cards with no preselection; Continue waits for '
        'one; Skip is always there', (tester) async {
      await pump(tester);
      await toGoalStep(tester);
      expect(find.text('Nice to meet you, Ada!'), findsOneWidget);
      expect(find.text('What brings you to English, Ada?'), findsOneWidget);
      for (final goal in LearningGoal.values) {
        expect(find.byKey(OnboardingScreen.goalKey(goal)), findsOneWidget);
      }
      expect(enabled(tester, OnboardingScreen.startKey), isFalse);
      expect(enabled(tester, OnboardingScreen.skipGoalKey), isTrue);
    });

    for (final size in [const Size(390, 844), const Size(428, 926)]) {
      testWidgets(
          'fix round 2 (SPEC §1.14): four goals in the board\'s order and copy; '
          'School & university has the lilac tile and the book; all four and '
          'Continue fit the first view at $size', (tester) async {
        expect(LearningGoal.values, [
          LearningGoal.examPrep,
          LearningGoal.work,
          LearningGoal.school,
          LearningGoal.general,
        ]);
        expect(LearningGoal.school.toJson(), 'school');
        expect(LearningGoalInfo.fromStored('school'), LearningGoal.school);
        {
          await pump(tester, size: size);
          await toGoalStep(tester);
          for (final (title, detail) in [
            ('Exam prep', 'IELTS, TOEFL or another English exam'),
            ('Work', 'Emails, reports and professional English'),
            ('School & university', 'Homework, essays and academic writing'),
            ('Everyday English', 'Write with confidence every day'),
          ]) {
            expect(find.text(title), findsOneWidget);
            expect(find.text(detail), findsOneWidget);
          }
          final tops = [
            for (final g in LearningGoal.values)
              tester.getTopLeft(find.byKey(OnboardingScreen.goalKey(g))).dy
          ];
          expect(tops, orderedEquals([...tops]..sort()));
          final school =
              find.byKey(OnboardingScreen.goalKey(LearningGoal.school));
          expect(
              find.descendant(
                  of: school, matching: find.byIcon(Icons.menu_book_rounded)),
              findsOneWidget);
          const c = AppColors.light;
          final tile = tester.widget<Container>(find
              .ancestor(
                  of: find.descendant(
                      of: school,
                      matching: find.byIcon(Icons.menu_book_rounded)),
                  matching: find.byType(Container))
              .first);
          expect((tile.decoration! as BoxDecoration).color, c.lilac);
          final last = tester.getBottomLeft(
              find.byKey(OnboardingScreen.goalKey(LearningGoal.general)));
          expect(last.dy, lessThanOrEqualTo(size.height));
          expect(tester.getBottomLeft(find.byKey(OnboardingScreen.startKey)).dy,
              lessThanOrEqualTo(size.height));
        }
        await tester
            .tap(find.byKey(OnboardingScreen.goalKey(LearningGoal.school)));
        await tester.pumpAndSettle();
        expect(find.text('“School & university it is! Let’s ace it.”'),
            findsOneWidget);
      });
    }

    testWidgets('choosing a card shows the buddy\'s reaction inside it',
        (tester) async {
      await pump(tester);
      await toGoalStep(tester);
      await tester.tap(find.byKey(OnboardingScreen.goalKey(LearningGoal.work)));
      await tester.pumpAndSettle();
      expect(find.text('“Work it is! I’ll cheer you on.”'), findsOneWidget);
      expect(enabled(tester, OnboardingScreen.startKey), isTrue);
    });

    testWidgets('the copy promises no personalised content (SPEC §1.12)',
        (tester) async {
      await pump(tester);
      await toGoalStep(tester);
      expect(find.textContaining('personal'), findsNothing);
      expect(find.text('Pick one. It helps us decide what to improve next.'),
          findsOneWidget);
    });

    for (final goal in LearningGoal.values) {
      testWidgets('${goal.name}: Continue finishes with the goal and the buddy',
          (tester) async {
        UserProfile? saved;
        await pump(tester, onComplete: (p) => saved = p);
        await toGoalStep(tester);
        await tester.ensureVisible(find.byKey(OnboardingScreen.goalKey(goal)));
        await tester.tap(find.byKey(OnboardingScreen.goalKey(goal)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(OnboardingScreen.startKey));
        await tester.pump();
        expect(saved!.learningGoal, goal);
        expect(saved!.avatar, Avatar.fox);
        expect(saved!.name, 'Ada');
      });
    }

    testWidgets('Skip finishes with no goal (stored as skipped)',
        (tester) async {
      UserProfile? saved;
      await pump(tester, onComplete: (p) => saved = p);
      await toGoalStep(tester);
      await tester.tap(find.byKey(OnboardingScreen.goalKey(LearningGoal.work)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(OnboardingScreen.skipGoalKey));
      await tester.pump();
      expect(saved!.learningGoal, isNull);
      expect(saved!.toMap()['learning_goal'], 'skipped');
    });

    testWidgets(
        'the privacy line stays (the goal is reported with usage data); the '
        'AI facts are one tap away', (tester) async {
      await pump(tester);
      await toGoalStep(tester);
      expect(find.text(onboardingPrivacyNoteEnglish), findsOneWidget);
      await tester.ensureVisible(find.byKey(OnboardingScreen.dataLinkKey));
      await tester.tap(find.byKey(OnboardingScreen.dataLinkKey));
      await tester.pumpAndSettle();
      expect(find.text('Your data & AI'), findsOneWidget);
      await tester.tap(find.byKey(OnboardingScreen.gotItKey));
      await tester.pumpAndSettle();
      expect(find.text('Your data & AI'), findsNothing);
    });

    testWidgets('Back returns to the name step with the name kept',
        (tester) async {
      await pump(tester);
      await toGoalStep(tester, name: 'Ada');
      await tester.tap(find.byKey(OnboardingScreen.backKey));
      await tester.pumpAndSettle();
      expect(find.text('Ada'), findsOneWidget);
    });
  });

  for (final width in [320.0, 390.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          '$width pt, Large text, ${brightness.name}: every step without '
          'overflow', (tester) async {
        await pump(tester,
            size: Size(width, 700),
            brightness: brightness,
            textSize: AppTextSize.large);
        expect(tester.takeException(), isNull);
        await toNameStep(tester);
        expect(tester.takeException(), isNull);
        await tester.enterText(
            find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
        await tester.pump();
        await tester.tap(find.byKey(OnboardingScreen.continueKey));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(OnboardingScreen.goalKey(LearningGoal.examPrep)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

/// The privacy line in English (the onboarding test pins its wording to
/// what the app does).
const onboardingPrivacyNoteEnglish =
    'Your name stays on this device. Your goal is sent with app usage data, '
    'never with your name. Usage and crash data is collected.';
