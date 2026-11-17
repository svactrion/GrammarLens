import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';
import 'package:grammar_lens/widgets/profile_stage.dart';

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
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/medals_layer.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';
import 'package:grammar_lens/widgets/section_title.dart';

import 'support/l10n_support.dart';

/// 1.2.0 Batch 7: Profile laid out as the mockup — the page header, the
/// identity card with the name edited in place (N8), the medal strip (Q7)
/// and its progress card (N9), the settings and App information cards.
class _Storage extends StorageService {
  final List<UserProfile> saved = [];
  final bool history;
  final int score;
  final DateTime? firstCompletion;
  _Storage({this.history = false, this.score = 7, this.firstCompletion});

  @override
  Future<DateTime?> getFirstDailyTestCompletion() async => firstCompletion;

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
      'the page title (34 / 900 / 1.10 / -1.1 at Small, where the brief\'s '
      'sizes are since the final pass) and its line, in the page',
      (tester) async {
    await pump(tester, textSize: AppTextSize.small);
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
      'V23: the companion on its stage with Change, the ribbon with the name, '
      '"Climbing with <Hero>" and the pencil, then three stat tiles',
      (tester) async {
    await pump(tester);
    final card = find.byKey(SettingsScreen.identityCardKey);
    expect(find.descendant(of: card, matching: find.byType(CompanionView)),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Change')),
        findsOneWidget);
    expect(shownName(tester), isNotEmpty);
    expect(
        find.descendant(
            of: card, matching: find.textContaining('Climbing with')),
        findsOneWidget);
    expect(find.byKey(ProfileStage.pencilKey), findsOneWidget);
    for (final label in ['points this month', 'step', 'weak spots']) {
      expect(find.descendant(of: card, matching: find.text(label)),
          findsOneWidget);
    }
    await tester.tap(find.byKey(ProfileStage.changeKey));
    await tester.pumpAndSettle();
    expect(find.byType(AvatarPickerScreen), findsOneWidget);
  });

  testWidgets(
      'D9-1: the ribbon adds "· since <month year>" from the first Daily '
      'Test completed; without one it is left out', (tester) async {
    await pump(tester);
    final hero = Avatar.values[2].name(en);
    expect(tester.widget<Text>(find.byKey(ProfileStage.climbingKey)).data,
        'Climbing with $hero');

    await pump(tester,
        storage: _Storage(firstCompletion: DateTime(2026, 8, 14, 21, 5)));
    expect(tester.widget<Text>(find.byKey(ProfileStage.climbingKey)).data,
        'Climbing with $hero · since Aug 2026');
  });

  group('PF04: the name in a sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(ProfileStage.pencilKey));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'the pencil opens the sheet (the companion asks, the field holds the '
        'name); Save stores the trimmed name and shows "Name saved" with '
        'Undo', (tester) async {
      final updates = <UserProfile>[];
      final storage = await pump(tester, onProfileUpdated: updates.add);
      final before = shownName(tester);
      await openSheet(tester);
      expect(find.text('What should I call you?'), findsOneWidget);
      final field = find.byKey(SettingsScreen.nameFieldKey);
      expect(tester.widget<TextField>(field).controller!.text, before);
      await tester.enterText(field, '  Ahmet  ');
      await tester.pump();
      await tester.tap(find.byKey(SettingsScreen.saveNameKey));
      await tester.pumpAndSettle();
      expect(storage.saved.single.name, 'Ahmet');
      expect(updates.single.name, 'Ahmet');
      expect(find.byKey(SettingsScreen.nameFieldKey), findsNothing);
      expect(shownName(tester), 'Ahmet');
      expect(find.text('Name saved'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(storage.saved.last.name, before);
      expect(shownName(tester), before);
    });

    for (final blank in ['', '   ']) {
      testWidgets('an empty or blank name cannot be saved ("$blank")',
          (tester) async {
        final storage = await pump(tester);
        await openSheet(tester);
        await tester.enterText(find.byKey(SettingsScreen.nameFieldKey), blank);
        await tester.pump();
        expect(
            tester
                .widget<PressableButton>(find.byKey(SettingsScreen.saveNameKey))
                .onPressed,
            isNull);
        expect(storage.saved, isEmpty);
      });
    }

    testWidgets(
        'fix round 2: with the keyboard up the sheet sits on it, sized to its '
        'content, its top under the companion stage (not a full page); '
        'Cancel closes without saving', (tester) async {
      final storage = await pump(tester);
      await openSheet(tester);
      // The keyboard comes up (336 pt, an iPhone 14 Plus's).
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byKey(SettingsScreen.nameSheetKey));
      expect(sheet.bottom, closeTo(844 - 336, 1));
      final stage = tester.getRect(find
          .descendant(
              of: find.byKey(SettingsScreen.identityCardKey),
              matching: find.byType(CompanionView))
          .first);
      expect(sheet.top, greaterThan(stage.top),
          reason: 'the companion stays visible above the sheet');
      expect(sheet.height, lessThan(260));
      expect(find.text('What should I call you?'), findsOneWidget);
      expect(find.byKey(SettingsScreen.cancelNameKey), findsOneWidget);
      await tester.tap(find.byKey(SettingsScreen.cancelNameKey));
      await tester.pumpAndSettle();
      expect(find.byKey(SettingsScreen.nameSheetKey), findsNothing);
      expect(storage.saved, isEmpty);
    });

    testWidgets(
        'at most 40 characters (O2, as in onboarding); fix round 2: the '
        'counter inside the field counts to the real limit (the board\'s '
        '"/20" would contradict O2)', (tester) async {
      await pump(tester);
      await openSheet(tester);
      final field =
          tester.widget<TextField>(find.byKey(SettingsScreen.nameFieldKey));
      expect(field.maxLength, UserProfile.maxNameLength);
      expect(UserProfile.maxNameLength, 40);
      await tester.enterText(find.byKey(SettingsScreen.nameFieldKey), 'Ada');
      await tester.pump();
      expect(
          tester.widget<Text>(find.byKey(SettingsScreen.nameCounterKey)).data,
          '3/40');
      expect(
          find.descendant(
              of: find.byKey(SettingsScreen.nameFieldKey),
              matching: find.byKey(SettingsScreen.nameCounterKey)),
          findsOneWidget);
    });
  });

  testWidgets(
      'V23: the medals from real data on the shelf, newest first, at most '
      'three, in a card with "See all"; then the progress card',
      (tester) async {
    await pump(tester, storage: _Storage(history: true, score: 80));
    // V23's stage is taller: the shelf is further down.
    await tester.scrollUntilVisible(
        find.byKey(MonthlyProgressCard.cardKey), 200,
        scrollable: find.byType(Scrollable).first);
    // Gold September, Silver August; the running month (80 points in
    // October) is past Bronze; July has no medal; the Welcome badge (July)
    // is older than the three.
    final bronze = MonthlyMedalRules.threshold(2026, 10, MedalTier.bronze);
    expect(80 >= bronze, isTrue);
    double x(Key key) => tester.getTopLeft(find.byKey(key)).dx;
    final keys = [
      MonthlyMedalCollection.slotKey(2026, 10),
      MonthlyMedalCollection.slotKey(2026, 9),
      MonthlyMedalCollection.slotKey(2026, 8),
    ];
    final xs = [for (final k in keys) x(k)];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(find.byKey(MonthlyMedalCollection.slotKey(2026, 7)), findsNothing);
    expect(find.byKey(MonthlyMedalCollection.welcomeSlotKey), findsNothing);
    // The title, "See all" and the shelf share one card.
    final card = find.byKey(SettingsScreen.medalCardKey);
    for (final inside in [
      find.widgetWithText(SectionTitle, 'Medal collection'),
      find.byKey(SettingsScreen.seeAllMedalsKey),
      find.byKey(MonthlyMedalCollection.stripKey),
    ]) {
      expect(find.descendant(of: card, matching: inside), findsOneWidget);
    }
    expect(tester.getTopLeft(find.byKey(MonthlyProgressCard.cardKey)).dy,
        greaterThan(tester.getBottomLeft(card).dy - 1));
  });

  testWidgets(
      'PF02: "See all" opens every medal over the blurred profile; X closes '
      'it; a medal opens its detail (PF03)', (tester) async {
    await pump(tester, storage: _Storage(history: true, score: 80));
    final seeAll = find.byKey(SettingsScreen.seeAllMedalsKey);
    await tester.scrollUntilVisible(seeAll, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    // The count moved here from Profile's header (V23 has none).
    expect(tester.widget<Text>(find.byKey(MedalsLayer.earnedKey)).data,
        '4 earned');
    // Newest first: October (running), September, August; the Welcome
    // badge last.
    final order = [
      MonthlyMedalCollection.slotKey(2026, 10),
      MonthlyMedalCollection.slotKey(2026, 9),
      MonthlyMedalCollection.slotKey(2026, 8),
    ];
    final xs = [
      for (final k in order) tester.getTopLeft(find.byKey(k).last).dx
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(
        tester
            .getTopLeft(find.byKey(MonthlyMedalCollection.welcomeSlotKey).last)
            .dy,
        greaterThan(tester.getTopLeft(find.byKey(order.first).last).dy));
    expect(find.byTooltip('Close'), findsWidgets);
    final september = find.byKey(MonthlyMedalCollection.slotKey(2026, 9));
    expect(september, findsWidgets);
    await tester.tap(september.last);
    await tester.pumpAndSettle();
    expect(find.byKey(MonthlyMedalCollection.detailKey), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close').last);
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
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
          // Nothing is wider than the screen.
          for (final e in find.byType(Text).evaluate()) {
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
        // PF04: the name sheet.
        await tester.tap(find.byKey(ProfileStage.pencilKey));
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
}
