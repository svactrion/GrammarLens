import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/screens/avatar_picker_screen.dart';
import 'package:grammar_lens/screens/credits_screen.dart';
import 'package:grammar_lens/screens/data_screen.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';
import 'package:grammar_lens/widgets/section_title.dart';

/// 1.2.0 Batch 7: Profile laid out as the mockup — the page header, the
/// identity card with the name edited in place (N8), the medal strip (Q7)
/// and its progress card (N9), the settings and App information cards.
class _Storage extends StorageService {
  final List<UserProfile> saved = [];
  final bool history;
  final int score;
  _Storage({this.history = false, this.score = 7});

  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];

  @override
  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() async =>
      MonthlyMedalProgress(
        year: 2026,
        month: 10,
        score: score,
        maxScore: MonthlyMedalRules.maxScore(2026, 10),
        activeDays: 1,
        correct: 0,
        wrong: 0,
        skipped: 0,
      );

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => [
        if (history)
          for (final (m, tier) in [
            (8, MedalTier.silver),
            (9, MedalTier.gold),
            (7, null),
          ])
            MonthlyMedalResult(
              year: 2026,
              month: m,
              score: 100,
              maxScore: MonthlyMedalRules.maxScore(2026, m),
              activeDays: 12,
              correct: 0,
              wrong: 0,
              skipped: 0,
              tier: tier,
              ruleVersion: 1,
              finalizedAt: DateTime(2026, m + 1, 1),
            ),
      ];

  @override
  Future<WelcomeBadge?> getWelcomeBadge() async => history
      ? WelcomeBadge(
          earnedAt: DateTime(2026, 7, 2), ruleVersion: 1, backfilled: false)
      : null;

  @override
  Future<Map<(int, int), String>> getClimbMonthThemes() async => const {};

  @override
  Future<void> saveUserProfile(UserProfile profile) async => saved.add(profile);
}

const _longName = 'Maximiliana Alexandrina Konstantinopoulou-Wolfeschlegel '
    'Steinhausenberger';

void main() {
  tearDown(() => DebugTools.enabledForTesting = true);

  Future<_Storage> pump(
    WidgetTester tester, {
    double width = 390,
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
    String name = 'Ada',
    _Storage? storage,
    ValueChanged<UserProfile>? onProfileUpdated,
    bool withNav = true,
  }) async {
    tester.view.physicalSize = Size(width, 844) * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    final store = storage ?? _Storage();
    var profile = UserProfile(name: name, learningGoal: LearningGoal.general)
        .copyWith(avatar: Avatar.values[2]);
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: AppMessenger.key,
      theme: buildAppTheme(brightness, textSize: textSize),
      home: StatefulBuilder(
        builder: (context, setState) {
          final screen = SettingsScreen(
            active: true,
            themeMode: AppThemeMode.system,
            onSelectThemeMode: (_) {},
            textSize: textSize,
            onSelectTextSize: (_) {},
            profile: profile,
            storageService: store,
            onProfileUpdated: (p) {
              onProfileUpdated?.call(p);
              setState(() => profile = p);
            },
            onResetOnboarding: () {},
          );
          // The nav bar's own row overflows at 320 pt with Large text in the
          // test font (wider than Nunito Sans; the real-font render does
          // not), so the overflow sweep leaves it out.
          if (!withNav) return screen;
          return FloatingNavShell(
            body: screen,
            tabs: const [
              NavShellTab(
                  icon: Icons.home, activeIcon: Icons.home, label: 'Home'),
              NavShellTab(
                  icon: Icons.history,
                  activeIcon: Icons.history,
                  label: 'Review'),
              NavShellTab(
                  icon: Icons.person,
                  activeIcon: Icons.person,
                  label: 'Profile'),
            ],
            selectedIndex: 2,
            onTabChange: (_) {},
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  String shownName(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(SettingsScreen.nameKey)).data!;

  testWidgets(
      'the page title (34 / 900 / 1.10 / -1.1 at Medium) and its line, in '
      'the page', (tester) async {
    await pump(tester);
    final title = tester.widget<Text>(find.text('Profile').first);
    expect(title.style!.fontSize, 34);
    expect(title.style!.fontWeight, FontWeight.w900);
    expect(title.style!.height, 1.10);
    expect(title.style!.letterSpacing, -1.1);
    expect(find.text('Your journey, your way.'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Your journey, your way.')).dy,
        greaterThan(tester.getBottomLeft(find.text('Profile').first).dy));
  });

  testWidgets(
      'the identity card: "Your companion", the hero centred in a 158 pt box '
      'with its Hero tag, "Change your avatar", then the name row',
      (tester) async {
    await pump(tester);
    final card = find.byKey(SettingsScreen.identityCardKey);
    final tile = find.descendant(of: card, matching: find.byType(AvatarTile));
    expect(tester.getSize(tile), const Size(158, 158));
    expect(tester.getCenter(tile).dx, closeTo(tester.getCenter(card).dx, .5));
    final hero = tester
        .widget<Hero>(find.ancestor(of: tile, matching: find.byType(Hero)));
    expect(hero.tag, avatarHeroTag);
    double top(String text) => tester
        .getTopLeft(find.descendant(of: card, matching: find.text(text)))
        .dy;
    expect(top('Your companion'), lessThan(tester.getTopLeft(tile).dy));
    expect(
        top('Change your avatar'), greaterThan(tester.getBottomLeft(tile).dy));
    expect(top('Your name'), greaterThan(top('Change your avatar')));
    expect(
        find.descendant(of: card, matching: find.text('Edit')), findsOneWidget);

    await tester.tap(find.text('Change your avatar'));
    await tester.pumpAndSettle();
    expect(find.byType(AvatarPickerScreen), findsOneWidget);
  });

  group('N8: the name edited in place', () {
    testWidgets('Save stores the trimmed name, closes the editor and shows it',
        (tester) async {
      final updates = <UserProfile>[];
      final storage = await pump(tester, onProfileUpdated: updates.add);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      // The field opens in the same card, focused, with Save and Cancel.
      final card = find.byKey(SettingsScreen.identityCardKey);
      final field = find.descendant(of: card, matching: find.byType(TextField));
      expect(field, findsOneWidget);
      final focused = FocusManager.instance.primaryFocus!.context!.widget;
      expect(
          find.descendant(
              of: field,
              matching: find.byWidgetPredicate((w) => identical(w, focused))),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Save')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Cancel')),
          findsOneWidget);

      await tester.enterText(field, '  Ahmet  ');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(storage.saved.single.name, 'Ahmet');
      expect(updates.single.name, 'Ahmet');
      expect(find.byType(TextField), findsNothing);
      expect(shownName(tester), 'Ahmet');
      expect(find.text('Name saved'), findsOneWidget);
    });

    testWidgets(
        'Cancel puts the saved name back, stores nothing and returns the '
        'focus to Edit', (tester) async {
      final storage = await pump(tester);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Zed');
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(storage.saved, isEmpty);
      expect(find.byType(TextField), findsNothing);
      expect(shownName(tester), 'Ada');
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
          find.ancestor(
              of: find.byWidgetPredicate((w) => identical(w, focused.widget)),
              matching: find.widgetWithText(TextButton, 'Edit')),
          findsOneWidget);

      // Opening it again starts from the saved name, not the cancelled
      // text.
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Ada'), findsOneWidget);
    });

    for (final blank in ['', '   ']) {
      testWidgets('an empty or blank name is not saved ("$blank")',
          (tester) async {
        final storage = await pump(tester);
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), blank);
        await tester.pump();
        final save = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
        expect(save.onPressed, isNull);
        await tester.tap(find.text('Save'));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(storage.saved, isEmpty);
        expect(find.byType(TextField), findsOneWidget, reason: 'still editing');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(shownName(tester), 'Ada');
      });
    }

    testWidgets('no length limit: a long name is kept whole and wraps',
        (tester) async {
      final storage = await pump(tester, width: 320);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(
          tester.widget<TextField>(find.byType(TextField)).maxLength, isNull);
      await tester.enterText(find.byType(TextField), _longName);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(storage.saved.single.name, _longName);
      final name = tester.widget<Text>(find.byKey(SettingsScreen.nameKey));
      expect(name.data, _longName);
      expect(name.maxLines, isNull);
      expect(name.overflow, isNull);
      final line = tester.widget<Text>(find.text('Your name')).style!;
      expect(tester.getSize(find.byKey(SettingsScreen.nameKey)).height,
          greaterThan(line.fontSize! * 3),
          reason: 'more than one line');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
      'the medals from real data: the count, the running month first, the '
      'Welcome badge last, then the progress card', (tester) async {
    await pump(tester, storage: _Storage(history: true, score: 80));
    // Welcome, Gold September, Silver August; the running month (80 points
    // in October) is past Bronze; July has no medal.
    final bronze = MonthlyMedalRules.threshold(2026, 10, MedalTier.bronze);
    expect(80 >= bronze, isTrue);
    expect(tester.widget<Text>(find.byKey(SettingsScreen.earnedCountKey)).data,
        '4 earned');
    double x(Key key) => tester.getTopLeft(find.byKey(key)).dx;
    final keys = [
      MonthlyMedalCollection.slotKey(2026, 10),
      MonthlyMedalCollection.slotKey(2026, 9),
      MonthlyMedalCollection.slotKey(2026, 8),
      MonthlyMedalCollection.welcomeSlotKey,
    ];
    final xs = [for (final k in keys) x(k)];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(find.byKey(MonthlyMedalCollection.slotKey(2026, 7)), findsNothing);
    // The section title is the shared SectionTitle.
    expect(
        find.widgetWithText(SectionTitle, 'Medal collection'), findsOneWidget);
    expect(
        tester.getTopLeft(find.byKey(MonthlyProgressCard.cardKey)).dy,
        greaterThan(tester
                .getBottomLeft(find.byKey(MonthlyMedalCollection.stripKey))
                .dy -
            1));
  });

  testWidgets(
      'Appearance and App information are cards; Data and Credits open their '
      'screens', (tester) async {
    DebugTools.enabledForTesting = false;
    await pump(tester);
    final scrollable = find.byType(Scrollable).first;
    for (final title in ['Appearance', 'App information']) {
      await tester.scrollUntilVisible(find.text(title), 200,
          scrollable: scrollable);
      expect(find.widgetWithText(SectionTitle, title), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Medium'), -200,
        scrollable: scrollable);
    for (final label in [
      'Theme',
      'Text size',
      'System',
      'Light',
      'Dark',
      'Small',
      'Medium',
      'Large'
    ]) {
      expect(find.ancestor(of: find.text(label), matching: find.byType(Card)),
          findsOneWidget,
          reason: label);
    }
    for (final (label, screen) in [
      ('Data', DataScreen),
      ('Credits', CreditsScreen),
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200,
          scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(find.ancestor(of: find.text(label), matching: find.byType(Card)),
          findsOneWidget);
      expect(
          tester
              .getSize(find
                  .ancestor(
                      of: find.text(label), matching: find.byType(InkWell))
                  .first)
              .height,
          greaterThanOrEqualTo(64));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget, reason: label);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          '${width.toInt()} pt, Large text, ${brightness.name}, a long name: '
          'no overflow top to bottom, editing too', (tester) async {
        DebugTools.enabledForTesting = false;
        await pump(tester,
            width: width,
            brightness: brightness,
            textSize: AppTextSize.large,
            name: _longName,
            storage: _Storage(history: true, score: 80),
            withNav: false);
        expect(tester.takeException(), isNull);
        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 20; i++) {
          // Nothing but the medal strip is wider than the screen.
          for (final e in find.byType(Text).evaluate()) {
            final inStrip = find
                .ancestor(
                    of: find.byWidget(e.widget),
                    matching: find.byKey(MonthlyMedalCollection.stripKey))
                .evaluate()
                .isNotEmpty;
            if (inStrip) continue;
            final r = tester.getRect(find.byWidget(e.widget).first);
            expect(r.right, lessThanOrEqualTo(width + .01),
                reason: (e.widget as Text).data);
          }
          await tester.drag(scrollable, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Credits'), findsOneWidget, reason: 'the end');

        await tester.drag(scrollable, const Offset(0, 8000));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
        '${width.toInt()} pt: at the end of the page the last row clears the '
        'nav bar', (tester) async {
      DebugTools.enabledForTesting = false;
      await pump(tester, width: width);
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -6000));
      await tester.pumpAndSettle();
      final credits = tester.getRect(find
          .ancestor(of: find.text('Credits'), matching: find.byType(InkWell))
          .first);
      final bar = tester.getRect(find.byKey(FloatingNavShell.barKey));
      expect(credits.bottom, lessThanOrEqualTo(bar.top));
    });
  }

  testWidgets(
      'Batch 8: with the keyboard open the nav bar stays put (behind the '
      'keyboard); the name field, Save and Cancel stay in view',
      (tester) async {
    await pump(tester, width: 390);
    final bar = tester.getRect(find.byKey(FloatingNavShell.barKey));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    // The keyboard: 336 pt, the iPhone 14 Plus portrait keyboard's height.
    tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(FloatingNavShell.barKey)), bar);
    expect(bar.top, greaterThan(844 - 336.0),
        reason: 'the bar is where the keyboard is, so the keyboard hides it');
    final keyboardTop = 844 - 336.0;
    for (final f in [
      find.byType(TextField),
      find.widgetWithText(FilledButton, 'Save'),
      find.text('Cancel'),
    ]) {
      final r = tester.getRect(f);
      expect(r.bottom, lessThanOrEqualTo(keyboardTop), reason: '$f');
      expect(r.top, greaterThanOrEqualTo(0), reason: '$f');
    }
    expect(tester.takeException(), isNull);
  });
}
