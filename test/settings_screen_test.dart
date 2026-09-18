import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/avatar_picker_screen.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

/// sqflite has no platform channel in this test environment (see
/// widget_test.dart's note), so a real `StorageService.saveUserProfile`
/// call throws — this fake lets the one test that needs `onProfileUpdated`
/// to actually fire (it only fires after a successful save) work without
/// real persistence. Also stands in for the debug-access-override
/// persistence the Developer section reads/writes, in-memory instead of
/// real sqlite, so a test can both seed a starting value and assert what
/// got saved.
class _FakeStorageService extends StorageService {
  bool? debugAccessOverride;
  bool onboardingReset = false;
  bool throwOnResetOnboarding = false;

  @override
  Future<void> finalizePastMedalMonths() async {}

  @override
  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() async =>
      const MonthlyMedalProgress(
        year: 2026,
        month: 9,
        score: 0,
        maxScore: 300,
        activeDays: 0,
        correct: 0,
        wrong: 0,
        skipped: 0,
      );

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];

  @override
  Future<void> saveUserProfile(UserProfile profile) async {}

  @override
  Future<bool?> getDebugAccessOverride() async => debugAccessOverride;

  @override
  Future<void> setDebugAccessOverride(bool? hasFullAccess) async {
    debugAccessOverride = hasFullAccess;
  }

  @override
  Future<void> resetOnboarding() async {
    if (throwOnResetOnboarding) {
      throw Exception('simulated storage failure');
    }
    onboardingReset = true;
  }
}

/// Lets a test control exactly when each `_loadMedals` call's storage
/// reads resolve, and in what order — every `getCurrentMonthlyMedalProgress`/
/// `getMonthlyMedalResults` call returns a `Completer`-backed future that
/// stays pending until the test completes it explicitly, appended to
/// these lists in call order (index 0 is the first call made, etc).
class _RaceStorageService extends StorageService {
  final List<Completer<MonthlyMedalProgress>> progressCompleters = [];
  final List<Completer<List<MonthlyMedalResult>>> resultsCompleters = [];

  @override
  Future<void> finalizePastMedalMonths() async {}

  @override
  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() {
    final completer = Completer<MonthlyMedalProgress>();
    progressCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() {
    final completer = Completer<List<MonthlyMedalResult>>();
    resultsCompleters.add(completer);
    return completer.future;
  }
}

MonthlyMedalProgress _raceProgress(int score) => MonthlyMedalProgress(
      year: 2026,
      month: 9,
      score: score,
      maxScore: 300,
      activeDays: 0,
      correct: 0,
      wrong: 0,
      skipped: 0,
    );

void main() {
  const profile = UserProfile(name: 'Ada', learningGoal: LearningGoal.work);

  Future<void> pumpSettings(
    WidgetTester tester, {
    AppThemeMode themeMode = AppThemeMode.system,
    ValueChanged<AppThemeMode>? onSelectThemeMode,
    AppTextSize textSize = AppTextSize.medium,
    ValueChanged<AppTextSize>? onSelectTextSize,
    ValueChanged<UserProfile>? onProfileUpdated,
    StorageService? storageService,
    SubscriptionService? subscriptionService,
    VoidCallback? onResetOnboarding,
    UserProfile? profileOverride,
    bool active = true,
  }) async {
    // A phone-realistic size (same convention as home_screen_test.dart) —
    // the default test surface is small enough that the avatar row's own
    // height pushes Save/Data past the ListView's lazy-build cache
    // extent, so tests that need those widgets never even reach them.
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          active: active,
          themeMode: themeMode,
          onSelectThemeMode: onSelectThemeMode ?? (_) {},
          textSize: textSize,
          onSelectTextSize: onSelectTextSize ?? (_) {},
          profile: profileOverride ?? profile,
          storageService: storageService ?? _FakeStorageService(),
          onProfileUpdated: onProfileUpdated ?? (_) {},
          subscriptionService: subscriptionService,
          onResetOnboarding: onResetOnboarding ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills the current name from the profile', (tester) async {
    await pumpSettings(tester);
    expect(find.widgetWithText(TextField, 'Ada'), findsOneWidget);
  });

  testWidgets('is presented as Profile and exposes three text sizes',
      (tester) async {
    await pumpSettings(tester);

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Large'), findsOneWidget);
  });

  testWidgets('selecting Large reports the new text-size preference',
      (tester) async {
    AppTextSize? selected;
    await pumpSettings(
      tester,
      onSelectTextSize: (value) => selected = value,
    );

    await tester.tap(find.text('Large'));
    await tester.pump();
    expect(selected, AppTextSize.large);
  });

  testWidgets('Profile shows an explicitly empty monthly medal collection',
      (tester) async {
    await pumpSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Monthly medals'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Monthly medals'), findsOneWidget);
    expect(find.text('Not earned'), findsNWidgets(3));
    expect(find.text('Earned'), findsNothing);
  });

  testWidgets(
      'a stale in-flight medal read cannot overwrite a newer one that '
      'started later (generation token guards SettingsScreen._loadMedals)',
      (tester) async {
    final storage = _RaceStorageService();

    // Same phone-realistic size `pumpSettings` uses — see its own doc
    // comment: the default test surface is too small for "This month" to
    // reach the ListView's lazy-build cache extent.
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pump({required bool active}) => tester.pumpWidget(
          MaterialApp(
            home: SettingsScreen(
              active: active,
              themeMode: AppThemeMode.system,
              onSelectThemeMode: (_) {},
              textSize: AppTextSize.medium,
              onSelectTextSize: (_) {},
              profile: profile,
              storageService: storage,
              onProfileUpdated: (_) {},
              onResetOnboarding: () {},
            ),
          ),
        );

    Future<void> reveal() => tester.scrollUntilVisible(
          find.text('This month'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

    // initState's own call (index 0, issued regardless of `active`).
    // Resolved immediately with a baseline so the screen reaches a
    // stable, non-loading state before the actual race begins below.
    await pump(active: false);
    storage.progressCompleters[0].complete(_raceProgress(10));
    storage.resultsCompleters[0].complete(const []);
    await tester.pump();
    await tester.pump();
    await reveal();
    expect(find.text('10 / 300 points · 0 active days'), findsOneWidget);

    // Tab re-entry #1 (`false` -> `true`, the only transition that
    // triggers another load per `didUpdateWidget`): the older of the two
    // overlapping reads. Deliberately left in flight.
    await pump(active: true);
    expect(storage.progressCompleters, hasLength(2));

    // A second, genuinely new `false` -> `true` transition, started
    // before read #1 above resolves — the real scenario this guards:
    // a fast double tab re-entry. Also left in flight for now.
    await pump(active: false);
    await pump(active: true);
    expect(storage.progressCompleters, hasLength(3));

    // The *newer* read (#2) resolves first...
    storage.progressCompleters[2].complete(_raceProgress(90));
    storage.resultsCompleters[2].complete(const []);
    await tester.pump();
    await tester.pump();
    await reveal();
    expect(find.text('90 / 300 points · 0 active days'), findsOneWidget);

    // ...then the older, now-stale read (#1) resolves after it. Without
    // the generation token, this stale result would win simply by
    // finishing last, silently reverting the UI to older data.
    storage.progressCompleters[1].complete(_raceProgress(40));
    storage.resultsCompleters[1].complete(const []);
    await tester.pump();
    await tester.pump();

    expect(
      find.text('90 / 300 points · 0 active days'),
      findsOneWidget,
      reason: 'the more-recently-started read must still win',
    );
    expect(
      find.text('40 / 300 points · 0 active days'),
      findsNothing,
      reason: 'a stale read finishing later must not overwrite a newer one',
    );
  });

  testWidgets('Save is disabled once the name is cleared', (tester) async {
    await pumpSettings(tester);
    FilledButton saveButton() =>
        tester.widget(find.widgetWithText(FilledButton, 'Save'));

    expect(saveButton().onPressed, isNotNull);

    await tester.enterText(find.widgetWithText(TextField, 'Ada'), '');
    await tester.pump();
    expect(saveButton().onPressed, isNull);
  });

  testWidgets('the avatar row previews the profile\'s current avatar',
      (tester) async {
    final koala = Avatar.values.firstWhere((a) => a.semanticLabel == 'Koala');
    await pumpSettings(
      tester,
      profileOverride: const UserProfile(
        name: 'Ada',
        learningGoal: LearningGoal.work,
      ).copyWith(avatar: koala),
    );
    final tile = tester.widget<AvatarTile>(find.byType(AvatarTile));
    expect(tile.avatar, koala);
  });

  testWidgets(
      'a legacy profile with no avatar yet still shows a real one, not the '
      'placeholder — the picker has no empty state either', (tester) async {
    await pumpSettings(tester); // default profile has avatar: null
    final tile = tester.widget<AvatarTile>(find.byType(AvatarTile));
    expect(tile.avatar, isNotNull);
  });

  testWidgets('tapping the avatar row opens the avatar picker', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.byType(AvatarTile));
    await tester.pumpAndSettle();
    expect(find.byType(AvatarPickerScreen), findsOneWidget);
  });

  testWidgets(
      'changing the avatar in the picker persists it and updates the '
      "row after returning — decoupled from the profile form's own Save "
      'button entirely', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    UserProfile? saved;
    final storage = _FakeStorageService();
    // A StatefulBuilder standing in for app.dart's own onProfileUpdated ->
    // setState -> re-pass-profile-down loop, so this test exercises the
    // real round trip (autosave actually reaching the row it's a preview
    // of) rather than just the autosave call in isolation.
    //
    // Starts with an explicit avatar, not the plain `profile` const (whose
    // avatar is null): a null avatar makes the picker fall back to
    // Avatar.random(), which occasionally lands near the end of the list,
    // where a fixed-direction drag has nowhere further to go and never
    // settles on a different avatar at all — the same flake already found
    // and fixed in onboarding_screen_test.dart. Avatar.values[3] is safely
    // clear of either boundary regardless of drag direction.
    var currentProfile = profile.copyWith(avatar: Avatar.values[3]);
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => SettingsScreen(
            active: true,
            themeMode: AppThemeMode.system,
            onSelectThemeMode: (_) {},
            textSize: AppTextSize.medium,
            onSelectTextSize: (_) {},
            profile: currentProfile,
            storageService: storage,
            onProfileUpdated: (p) {
              saved = p;
              setState(() => currentProfile = p);
            },
            onResetOnboarding: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AvatarTile));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600)); // past the debounce

    expect(saved, isNotNull);
    expect(saved!.avatar, isNotNull);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // The Save button was never touched — this is the point of the
    // decoupling.
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    final tile = tester.widget<AvatarTile>(find.byType(AvatarTile));
    expect(tile.avatar, saved!.avatar);
  });

  testWidgets('picking a theme segment calls onSelectThemeMode',
      (tester) async {
    AppThemeMode? selected;
    await pumpSettings(
      tester,
      onSelectThemeMode: (mode) => selected = mode,
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(selected, AppThemeMode.dark);
  });

  testWidgets('reset progress asks for confirmation before doing anything',
      (tester) async {
    await pumpSettings(tester);

    await reveal(tester, find.text('Reset progress data'));
    await tester.tap(find.text('Reset progress data'));
    await tester.pumpAndSettle();
    expect(find.text('Reset progress?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset progress?'), findsNothing);
    // sqflite has no platform channel in this test environment, so a real
    // reset call would surface as an error snackbar — its absence here
    // confirms Cancel never triggered one.
    expect(find.textContaining('Could not reset'), findsNothing);
  });

  group('Developer section (debug-only entitlement override)', () {
    testWidgets('shows the three override options', (tester) async {
      await pumpSettings(tester, storageService: _FakeStorageService());
      await reveal(tester, find.text('Developer'));

      expect(find.text('Developer'), findsOneWidget);
      expect(find.text('Real'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Full access'), findsOneWidget);
    });

    // `_DebugAccessChoice` is private to settings_screen.dart, so this
    // identifies the Developer section's SegmentedButton by elimination —
    // the only other one on screen is the theme picker, whose selection is
    // an `AppThemeMode`.
    Finder debugSegmentedButtonFinder() => find.byWidgetPredicate((w) {
          if (w is! SegmentedButton) return false;
          return (w as dynamic).selected.first is! AppThemeMode;
        });

    // Reads the selection via `toString()`, which — unlike the enum's
    // `.name` getter — isn't stripped from this test build.
    String selectedDebugChoiceName(WidgetTester tester) {
      final button = tester.widget(debugSegmentedButtonFinder()) as dynamic;
      return (button.selected.first as Object).toString().split('.').last;
    }

    testWidgets(
      'the initial selection reflects subscriptionService.debugAccessOverride '
      'at mount time, not always "Real"',
      (tester) async {
        final subscriptionService = SubscriptionService();
        await subscriptionService.setDebugAccessOverride(true);
        addTearDown(() => subscriptionService.setDebugAccessOverride(null));

        await pumpSettings(
          tester,
          storageService: _FakeStorageService(),
          subscriptionService: subscriptionService,
        );
        await reveal(tester, find.text('Developer'));

        expect(selectedDebugChoiceName(tester), 'full');
      },
    );

    testWidgets(
      'picking "Full access" forces hasFullAccess and persists the choice',
      (tester) async {
        final storage = _FakeStorageService();
        final subscriptionService = SubscriptionService();
        addTearDown(() => subscriptionService.setDebugAccessOverride(null));

        await pumpSettings(
          tester,
          storageService: storage,
          subscriptionService: subscriptionService,
        );
        await reveal(tester, find.text('Full access'));

        await tester.tap(find.text('Full access'));
        await tester.pumpAndSettle();

        expect(await subscriptionService.hasFullAccess, isTrue);
        expect(storage.debugAccessOverride, isTrue);
      },
    );

    testWidgets(
      'picking "Free" forces hasFullAccess to false and persists it',
      (tester) async {
        final storage = _FakeStorageService();
        final subscriptionService = SubscriptionService();
        addTearDown(() => subscriptionService.setDebugAccessOverride(null));

        await pumpSettings(
          tester,
          storageService: storage,
          subscriptionService: subscriptionService,
        );
        await reveal(tester, find.text('Free'));

        await tester.tap(find.text('Free'));
        await tester.pumpAndSettle();

        expect(await subscriptionService.hasFullAccess, isFalse);
        expect(storage.debugAccessOverride, isFalse);
      },
    );

    testWidgets(
      'picking "Real" clears the override back to the actual status',
      (tester) async {
        final storage = _FakeStorageService();
        final subscriptionService = SubscriptionService();
        // Starts already on "Full access" — otherwise tapping "Real" (the
        // default selection) would be a same-segment tap, not a real change.
        await subscriptionService.setDebugAccessOverride(true);
        addTearDown(() => subscriptionService.setDebugAccessOverride(null));

        await pumpSettings(
          tester,
          storageService: storage,
          subscriptionService: subscriptionService,
        );
        await reveal(tester, find.text('Real'));

        await tester.tap(find.text('Real'));
        await tester.pumpAndSettle();

        expect(subscriptionService.debugAccessOverride, isNull);
        expect(storage.debugAccessOverride, isNull);
      },
    );

    testWidgets(
      'the control is the same width no matter which option is selected',
      (tester) async {
        await pumpSettings(tester, storageService: _FakeStorageService());
        await reveal(tester, find.text('Free'));

        final realWidth = tester.getSize(debugSegmentedButtonFinder()).width;

        await tester.tap(find.text('Free'));
        await tester.pumpAndSettle();
        final freeWidth = tester.getSize(debugSegmentedButtonFinder()).width;

        await reveal(tester, find.text('Full access'));
        await tester.tap(find.text('Full access'));
        await tester.pumpAndSettle();
        final fullWidth = tester.getSize(debugSegmentedButtonFinder()).width;

        expect(
          freeWidth,
          realWidth,
          reason: 'Real=$realWidth Free=$freeWidth Full=$fullWidth',
        );
        expect(
          fullWidth,
          realWidth,
          reason: 'Real=$realWidth Free=$freeWidth Full=$fullWidth',
        );
      },
    );
  });

  group('Developer section (debug-only paywall pricing preview)', () {
    testWidgets('shows the toggle, off by default', (tester) async {
      await pumpSettings(tester, storageService: _FakeStorageService());
      await tester.dragUntilVisible(
        find.text('Preview paywall pricing'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preview paywall pricing'), findsOneWidget);
      final tile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(tile.value, isFalse);
    });

    testWidgets(
      'the initial value reflects subscriptionService.debugFixtureOffering '
      'at mount time, not always off',
      (tester) async {
        final subscriptionService = SubscriptionService();
        subscriptionService.setDebugFixtureOffering(enabled: true);
        addTearDown(
          () => subscriptionService.setDebugFixtureOffering(enabled: false),
        );

        await pumpSettings(
          tester,
          storageService: _FakeStorageService(),
          subscriptionService: subscriptionService,
        );
        await tester.dragUntilVisible(
          find.byType(SwitchListTile),
          find.byType(ListView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        final tile = tester.widget<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(tile.value, isTrue);
      },
    );

    testWidgets(
      'toggling it on makes getOfferings return the fixture, and never '
      'writes to StorageService',
      (tester) async {
        final storage = _FakeStorageService();
        final subscriptionService = SubscriptionService();
        addTearDown(
          () => subscriptionService.setDebugFixtureOffering(enabled: false),
        );

        await pumpSettings(
          tester,
          storageService: storage,
          subscriptionService: subscriptionService,
        );
        await tester.dragUntilVisible(
          find.byType(SwitchListTile),
          find.byType(ListView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(await subscriptionService.getOfferings(), isNotNull);
        expect(storage.debugAccessOverride, isNull,
            reason: 'this preference must never reach persistent storage');
      },
    );

    testWidgets('toggling it off clears the fixture', (tester) async {
      final subscriptionService = SubscriptionService();
      subscriptionService.setDebugFixtureOffering(enabled: true);
      addTearDown(
        () => subscriptionService.setDebugFixtureOffering(enabled: false),
      );

      await pumpSettings(
        tester,
        storageService: _FakeStorageService(),
        subscriptionService: subscriptionService,
      );
      await tester.dragUntilVisible(
        find.byType(SwitchListTile),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(await subscriptionService.getOfferings(), isNull);
    });
  });

  group('First-launch flow reset (debug-only)', () {
    testWidgets('shows the reset action', (tester) async {
      await pumpSettings(tester, storageService: _FakeStorageService());
      await tester.dragUntilVisible(
        find.text('Reset first-launch state'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('First-launch flow'), findsOneWidget);
      expect(find.text('Reset first-launch state'), findsOneWidget);
    });

    testWidgets(
      'tapping it clears the profile in storage and calls onResetOnboarding',
      (tester) async {
        final storage = _FakeStorageService();
        var resetCalled = false;

        await pumpSettings(
          tester,
          storageService: storage,
          onResetOnboarding: () => resetCalled = true,
        );
        await tester.dragUntilVisible(
          find.text('Reset first-launch state'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reset first-launch state'));
        await tester.pumpAndSettle();

        expect(storage.onboardingReset, isTrue);
        expect(resetCalled, isTrue);
      },
    );

    testWidgets(
      'no confirmation dialog — unlike Reset progress data, this is a '
      'fast dev action',
      (tester) async {
        await pumpSettings(tester, storageService: _FakeStorageService());
        await tester.dragUntilVisible(
          find.text('Reset first-launch state'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reset first-launch state'));
        await tester.pump();

        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'a storage failure does not call onResetOnboarding — the app stays '
      'on Settings rather than pretending the reset worked',
      (tester) async {
        final storage = _FakeStorageService()..throwOnResetOnboarding = true;
        var resetCalled = false;

        await pumpSettings(
          tester,
          storageService: storage,
          onResetOnboarding: () => resetCalled = true,
        );
        await tester.dragUntilVisible(
          find.text('Reset first-launch state'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reset first-launch state'));
        await tester.pumpAndSettle();

        expect(resetCalled, isFalse);
        expect(find.text('Reset first-launch state'), findsOneWidget);
      },
    );
  });
}
