import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/debug_panel_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_controls.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_day.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_milestone.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_month_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/app.dart';

import 'support/month_card_support.dart';
import 'support/recording_analytics_sink.dart';

/// Records every one-time record access and every ledger write a replay
/// might make.
class _RecordingStorage extends CardStorage {
  _RecordingStorage() : super();
  final List<String> calls = [];
  @override
  Future<bool> hasOneTimeFlag(String key) async {
    calls.add('read $key');
    return false;
  }

  @override
  Future<bool> claimOneTimeFlag(String key) async {
    calls.add('write $key');
    return true;
  }
}

/// The debug panel (Batch 5, N27).
void main() {
  tearDown(() {
    ClimbDebugTheme.runtime = null;
    ClimbDebugDay.runtime = null;
    ClimbDebugControls.instance.resetForTesting();
    DebugTools.enabledForTesting = true;
  });

  Future<void> pumpPanel(WidgetTester tester,
      {Future<void> Function()? onReset}) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DebugPanelScreen(
                    onResetLocalData: onReset ?? () async {}))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('availability', () {
    test('debug and profile builds: available; a release build: none of it',
        () {
      expect(ClimbDebugControls.available, isTrue);
      ClimbDebugTheme.runtime = 'ember_peak';
      ClimbDebugDay.runtime = 9;
      expect(ClimbDebugTheme.value?.id, 'ember_peak');
      expect(ClimbDebugDay.value, 9);

      DebugTools.enabledForTesting = false;
      expect(ClimbDebugControls.available, isFalse);
      expect(ClimbDebugTheme.value, isNull);
      expect(ClimbDebugDay.value, isNull);
      ClimbDebugControls.instance.playMilestone(ClimbDebugMilestoneValue.gold);
      expect(ClimbDebugControls.instance.pending, isNull);
    });

    test('"real" overrides the define: theme \'\' and day −1 mean none', () {
      ClimbDebugTheme.runtime = '';
      ClimbDebugDay.runtime = -1;
      expect(ClimbDebugTheme.value, isNull);
      expect(ClimbDebugDay.value, isNull);
    });
  });

  group('the panel', () {
    testWidgets('theme chips and "Real theme" set the scene\'s theme',
        (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.byKey(DebugPanelScreen.themeKey('glacier_peak')));
      await tester.pump();
      expect(ClimbDebugTheme.value?.id, 'glacier_peak');
      await tester.tap(find.byKey(DebugPanelScreen.themeKey('real')));
      await tester.pump();
      expect(ClimbDebugTheme.value, isNull);
    });

    testWidgets('the day: off "Real day", a slider of steps 0–31',
        (tester) async {
      await pumpPanel(tester);
      expect(find.byKey(DebugPanelScreen.daySliderKey), findsNothing);
      await tester.tap(find.byKey(DebugPanelScreen.dayRealKey));
      await tester.pump();
      expect(ClimbDebugDay.value, 1);
      final slider =
          tester.widget<Slider>(find.byKey(DebugPanelScreen.daySliderKey));
      slider.onChanged!(17);
      await tester.pump();
      expect(ClimbDebugDay.value, 17);
      expect(find.text('Step 17'), findsOneWidget);
      await tester.tap(find.byKey(DebugPanelScreen.dayRealKey));
      await tester.pump();
      expect(ClimbDebugDay.value, isNull);
    });

    for (final v in ClimbDebugMilestoneValue.values) {
      testWidgets('${v.wireName}: closes the panel and asks Home to play it',
          (tester) async {
        await pumpPanel(tester);
        await tester.tap(find.byKey(DebugPanelScreen.milestoneKey(v)));
        await tester.pumpAndSettle();
        expect(find.byType(DebugPanelScreen), findsNothing);
        expect(ClimbDebugControls.instance.pending!.milestone, v);
      });
    }

    for (final v in ClimbDebugMonthCardValue.values) {
      testWidgets('${v.wireName}: closes the panel and asks Home to play it',
          (tester) async {
        await pumpPanel(tester);
        await tester.scrollUntilVisible(
            find.byKey(DebugPanelScreen.monthCardKey(v)), 200,
            scrollable: find.byType(Scrollable).first);
        await tester
            .ensureVisible(find.byKey(DebugPanelScreen.monthCardKey(v)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(DebugPanelScreen.monthCardKey(v)));
        await tester.pumpAndSettle();
        expect(find.byType(DebugPanelScreen), findsNothing);
        expect(ClimbDebugControls.instance.pending!.monthCard, v);
      });
    }

    testWidgets(
        'reset: nothing without the confirmation; the confirmation says what '
        'goes and what stays', (tester) async {
      var resets = 0;
      await pumpPanel(tester, onReset: () async => resets++);
      await tester.scrollUntilVisible(
          find.byKey(DebugPanelScreen.resetKey), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(DebugPanelScreen.resetKey));
      await tester.pumpAndSettle();
      expect(find.text(DebugPanelScreen.resetMessage), findsOneWidget);
      expect(DebugPanelScreen.resetMessage, contains('profile'));
      expect(DebugPanelScreen.resetMessage, contains('purchases'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(resets, 0);
      expect(find.byType(DebugPanelScreen), findsOneWidget);

      await tester.tap(find.byKey(DebugPanelScreen.resetKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete and restart'));
      await tester.pumpAndSettle();
      expect(resets, 1);
      expect(find.byType(DebugPanelScreen), findsNothing);
    });
  });

  group('on Home', () {
    final mountain = find.byType(MonthlyMountain);
    String sceneLabel(WidgetTester tester) =>
        tester.getSemantics(mountain).getSemanticsData().label;

    testWidgets('a theme or a day from the panel shows in the scene at once',
        (tester) async {
      await pumpHome(tester, _RecordingStorage()..usedBefore = false);
      expect(sceneLabel(tester), contains('Ember Peak. 0 of 30 steps'));
      ClimbDebugTheme.runtime = 'red_canyon';
      ClimbDebugDay.runtime = 12;
      await tester.pump();
      expect(sceneLabel(tester), contains('Red Canyon. 12 of 30 steps'));
      ClimbDebugTheme.runtime = '';
      ClimbDebugDay.runtime = -1;
      await tester.pump();
      expect(sceneLabel(tester), contains('Ember Peak. 0 of 30 steps'));
      await tester.pumpAndSettle();
    });

    for (final v
        in ClimbDebugMilestoneValue.values.where((v) => v.tier != null)) {
      testWidgets(
          '${v.wireName}: the celebration, twice in a row; no record, no event',
          (tester) async {
        final sink = RecordingAnalyticsSink();
        final storage = _RecordingStorage()..usedBefore = false;
        await pumpHome(tester, storage, sink: sink);
        final before = [...storage.calls];
        for (var i = 0; i < 2; i++) {
          ClimbDebugControls.instance.playMilestone(v);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('${v.tier!.label} medal earned'), findsOneWidget);
          await tester.tap(find.byType(MedalCelebration));
          await tester.pumpAndSettle();
          expect(find.byType(MedalCelebration), findsNothing);
        }
        expect(storage.calls, before);
        expect(sink.events, isEmpty);
      });
    }

    for (final v
        in ClimbDebugMilestoneValue.values.where((v) => v.tier == null)) {
      testWidgets('${v.wireName}: the step onto it and its label, twice',
          (tester) async {
        final sink = RecordingAnalyticsSink();
        final storage = _RecordingStorage()..usedBefore = false;
        await pumpHome(tester, storage, sink: sink);
        final before = [...storage.calls];
        final step = v.savePoint!.reachedOn(30);
        for (var i = 0; i < 2; i++) {
          ClimbDebugControls.instance.playMilestone(v);
          await tester.pump();
          await tester.pump();
          expect(sceneLabel(tester), contains('${step - 1} of 30 steps'));
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump(const Duration(milliseconds: 900));
          expect(sceneLabel(tester), contains('$step of 30 steps'));
          expect(
              tester
                  .widget<Text>(find.descendant(
                      of: find.byKey(MonthlyMountain.labelKey),
                      matching: find.byType(Text)))
                  .data,
              v.savePoint!.name);
          await tester.pumpAndSettle();
        }
        expect(storage.calls, before);
        expect(sink.events, isEmpty);
      });
    }

    for (final v in ClimbDebugMonthCardValue.values
        .where((v) => v != ClimbDebugMonthCardValue.firstRun)) {
      testWidgets(
          '${v.wireName}: the card, then the zoom, twice; no record, no event',
          (tester) async {
        final sink = RecordingAnalyticsSink();
        final storage = _RecordingStorage()..usedBefore = false;
        await pumpHome(tester, storage, sink: sink);
        final before = [...storage.calls];
        for (var i = 0; i < 2; i++) {
          ClimbDebugControls.instance.playMonthCard(v);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(MonthCardSheet), findsOneWidget);
          await tester.tapAt(const Offset(20, 120));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await settleZoom(tester);
          expect(tester.widget<MonthlyMountain>(mountain).zoom, isNull);
        }
        expect(storage.calls, before);
        expect(sink.events, isEmpty);
      });
    }

    testWidgets('first_run: the zoom from the whole mountain, twice; no event',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      final storage = _RecordingStorage()..usedBefore = false;
      await pumpHome(tester, storage, sink: sink);
      final before = [...storage.calls];
      for (var i = 0; i < 2; i++) {
        ClimbDebugControls.instance
            .playMonthCard(ClimbDebugMonthCardValue.firstRun);
        await tester.pump();
        await tester.pump();
        expect(tester.widget<MonthlyMountain>(mountain).zoom, isNotNull);
        await settleZoom(tester);
        expect(tester.widget<MonthlyMountain>(mountain).zoom, isNull);
      }
      expect(storage.calls, before);
      expect(sink.events, isEmpty);
    });
  });

  group('in the app (real SQLite)', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    const dbName = 'test_debug_panel_app.db';
    setUp(() async {
      await databaseFactory
          .deleteDatabase(join(await getDatabasesPath(), dbName));
      TestWidgetsFlutterBinding.ensureInitialized()
              .platformDispatcher
              .accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
    });
    tearDown(() => TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearAccessibilityFeaturesTestValue());

    Future<StorageService> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = StorageService(dbName: dbName);
      await tester.runAsync(() => storage.saveUserProfile(
          const UserProfile(name: 'Ada', learningGoal: LearningGoal.general)));
      await tester.pumpWidget(GrammarLensApp(
        storageService: storage,
        analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
      ));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      return storage;
    }

    testWidgets(
        'a replay asked for while Profile shows: the app shows Home, which '
        'plays it', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 300));
      ClimbDebugControls.instance.playMilestone(ClimbDebugMilestoneValue.gold);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Gold medal earned'), findsOneWidget);
      expect(ClimbDebugControls.instance.pending, isNull);
      await tester.tap(find.byType(MedalCelebration));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the reset brings the app back to Welcome', (tester) async {
      final storage = await pumpApp(tester);
      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
          find.byKey(SettingsScreen.debugRowKey), 300,
          scrollable: find
              .descendant(
                  of: find.byType(SettingsScreen),
                  matching: find.byType(Scrollable))
              .first);
      // Past the floating nav bar, to the list's end.
      await tester.drag(
          find
              .descendant(
                  of: find.byType(SettingsScreen),
                  matching: find.byType(Scrollable))
              .first,
          const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(SettingsScreen.debugRowKey));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.scrollUntilVisible(
          find.byKey(DebugPanelScreen.resetKey), 200,
          scrollable: find
              .descendant(
                  of: find.byType(DebugPanelScreen),
                  matching: find.byType(Scrollable))
              .first);
      await tester.tap(find.byKey(DebugPanelScreen.resetKey));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Delete and restart'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Get started'), findsOneWidget);
      expect(await tester.runAsync(storage.getUserProfile), isNull);
    });
  });

  group('resetAllLocalData (real SQLite)', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    const dbName = 'test_debug_reset.db';
    setUp(() async =>
        databaseFactory.deleteDatabase(join(await getDatabasesPath(), dbName)));

    test('deletes every table\'s data; the next read finds a fresh database',
        () async {
      final storage = StorageService(dbName: dbName);
      await storage.saveUserProfile(
          const UserProfile(name: 'Ada', learningGoal: LearningGoal.general));
      await storage.claimOneTimeFlag(StorageService.day0PaywallFlag);
      expect(await storage.getUserProfile(), isNotNull);
      await storage.resetAllLocalData();
      expect(await storage.getUserProfile(), isNull);
      expect(await storage.hasOneTimeFlag(StorageService.day0PaywallFlag),
          isFalse);
    });

    test('a release build: a no-op', () async {
      final storage = StorageService(dbName: dbName);
      await storage.saveUserProfile(
          const UserProfile(name: 'Ada', learningGoal: LearningGoal.general));
      DebugTools.enabledForTesting = false;
      await storage.resetAllLocalData();
      DebugTools.enabledForTesting = true;
      expect(await storage.getUserProfile(), isNotNull);
    });
  });
}
