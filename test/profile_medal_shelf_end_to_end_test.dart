import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

import 'support/recording_analytics_sink.dart';

final _questions = [
  for (var i = 0; i < 5; i++)
    DailyTestQuestion(
        item: PracticeItem(
            id: 'q$i',
            type: PracticeItemType.fillInBlank,
            instruction: 'Question $i'),
        topicId: 'tenseSelection',
        correctAnswer: 'cooking',
        commonWrongAnswers: const []),
];

/// Batch 5 (N34), end to end on a real database: the running month's
/// medal on Profile's shelf is its theme's Bronze faded while it has no
/// tier, and Bronze, Silver, then Gold from the Daily Test whose save
/// crosses each threshold. Profile reads the medals each time its tab
/// becomes active, so the change shows the first time Profile opens after
/// that save.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late StorageService storage;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('profile-shelf-test-');
    storage = StorageService(dbName: join(dir.path, 'app.db'));
    // November 2026: 30 days, Ember Peak by the calendar.
    StorageService.clockForTesting = () => DateTime(2026, 11, 30, 12);
  });
  tearDown(() async {
    StorageService.clockForTesting = DateTime.now;
    await dir.delete(recursive: true);
  });

  testWidgets(
      "the running month's shelf medal: faded Bronze, then Bronze, Silver "
      'and Gold from the save that crosses each threshold', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    /// Saves day [day]'s Daily Test with every answer correct (10 points).
    Future<void> saveDay(int day) => tester.runAsync(() async {
          final key = '2026-11-${day.toString().padLeft(2, '0')}';
          await storage.saveDailyTestSet(_questions, day: key);
          // Returns whether the Welcome badge was just earned.
          await storage.completeDailyTest(
              {for (final q in _questions) q.item.id: 'cooking'}, const [],
              day: key, completedAt: DateTime(2026, 11, day, 9));
        });

    final active = ValueNotifier(true);
    addTearDown(active.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: active,
        builder: (context, isActive, _) => SettingsScreen(
          active: isActive,
          themeMode: AppThemeMode.system,
          onSelectThemeMode: (_) {},
          textSize: AppTextSize.medium,
          onSelectTextSize: (_) {},
          profile: const UserProfile(
              name: 'Ada', learningGoal: LearningGoal.general),
          storageService: storage,
          onProfileUpdated: (_) {},
          analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
          onResetOnboarding: () {},
        ),
      ),
    ));

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    /// Leaves Profile's tab and comes back to it, as after a Daily Test.
    Future<void> reopenProfile() async {
      active.value = false;
      await tester.pump();
      active.value = true;
      await settle();
    }

    MedalBadge shelfMedal() {
      final slot = find.byKey(MonthlyMedalCollection.slotKey(2026, 11));
      expect(slot, findsOneWidget);
      return tester.widget<MedalBadge>(
          find.descendant(of: slot, matching: find.byType(MedalBadge)));
    }

    void expectMedal(MedalTier tier, {required bool earned, String? why}) {
      final badge = shelfMedal();
      expect(badge.asset, MedalArt.monthly('ember_peak', tier), reason: why);
      expect(badge.earned, earned, reason: why);
    }

    await settle();
    expectMedal(MedalTier.bronze, earned: false, why: 'no test yet');

    var day = 0;
    for (final tier in MedalTier.values) {
      final threshold = MonthlyMedalRules.threshold(2026, 11, tier);
      // Up to the save before the threshold: still the tier below.
      while ((day + 1) * 10 < threshold) {
        await saveDay(++day);
      }
      await reopenProfile();
      if (tier == MedalTier.bronze) {
        expectMedal(MedalTier.bronze,
            earned: false, why: '${day * 10} points, under Bronze');
      } else {
        expectMedal(MedalTier.values[tier.index - 1],
            earned: true, why: '${day * 10} points, under ${tier.label}');
      }
      // The save that crosses it.
      await saveDay(++day);
      await reopenProfile();
      expectMedal(tier, earned: true, why: '${day * 10} points');
      expect(
          find.bySemanticsLabel(RegExp(
              '^November 2026, Ember Peak, ${tier.label} medal, in progress')),
          findsOneWidget);
    }
    expect(day, 23); // 230 points: Gold at 225.
  });
}
