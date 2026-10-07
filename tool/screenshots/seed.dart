// App Store screenshots (1.2.0): the fictional learner the capture app
// seeds before the real app starts. Kept apart from `capture_app.dart`
// (which needs `flutter_driver`) so `test/screenshot_seed_test.dart` can
// run it against a real SQLite file.
//
// Not part of the app: nothing in lib/ imports tool/
// (`test/tool_import_guard_test.dart`). Every hook used here is a debug
// or test seam that a release build ignores or never reaches.
//
// What a seeded install holds (1.2.0 screenshot decisions, 2026-10-06):
//   - "Sam", the Fox, exam prep: a made-up learner, no personal data;
//   - this month's climb in Glacier Peak, recorded as the month's theme,
//     so Home, Profile and the month's medal agree (a visual choice: the
//     rotation is not changed, the stored theme is);
//   - July, August and September finished at Bronze, Silver and Gold,
//     frozen by the app's own finalization, each recorded with its own
//     theme (Green Slope, Ember Peak, Red Canyon; Glacier Peak is this
//     month's alone);
//   - this month's Daily Tests done up to one step before Halfway Hut, so
//     today's test, taken live by the driver, lands the avatar on it;
//     today's set stored but not taken (the bundled day-0 questions, no
//     network);
//   - saved mistakes in two topics, Modal Verbs three times, so Premium
//     Review's Suggested Focus has a clear first choice;
//   - premium only: the debug entitlement override, persisted, which the
//     app applies at launch;
//   - the one-time records that would otherwise open the day-0 paywall,
//     the first-run zoom, this month's zoom or its month card.
import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';

/// The seeded learner's name: made up, the same as in the 1.1.0 set.
const screenshotName = 'Sam';

/// The hero of the 1.2.0 set.
final screenshotAvatar =
    Avatar.values.firstWhere((a) => a.semanticLabel == 'Fox');

/// This month's theme in the 1.2.0 set.
const screenshotTheme = ClimbThemes.glacierPeak;

/// The three finished months before this one, oldest first, and the tier
/// each ends on.
const pastMonthTiers = [MedalTier.bronze, MedalTier.silver, MedalTier.gold];

/// Those months' recorded themes, oldest first: three different ones, none
/// of them [screenshotTheme].
const pastMonthThemes = [
  ClimbThemes.greenSlope,
  ClimbThemes.emberPeak,
  ClimbThemes.redCanyon,
];

String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Today's answers as the driver types them: the first wrong (so the result
/// shows a corrected answer and its explanation), the rest right.
List<String> get screenshotTodayAnswers => [
      for (final (i, q) in kDayZeroQuestions.indexed)
        i == 0 ? 'to eat' : q.correctAnswer,
    ];

/// Seeds [storage] as of [now] (a fresh install; an install that already
/// has a profile is left as it is). [premium] also stores the debug
/// entitlement override (debug builds only).
///
/// Theme records go through two of [StorageService]'s test seams, so
/// lib/ is unchanged. Storage writes a month's record only while that
/// month is its current one, at the month's first completion, and never
/// changes it afterwards. So each past month is seeded with
/// [StorageService.clockForTesting] inside it and
/// [StorageService.themeForNewMonthForTesting] naming its theme; then the
/// clock is put back as it was. The theme seam stays on [screenshotTheme]
/// for the rest of the process.
Future<void> seedScreenshotData(StorageService storage,
    {required DateTime now, required bool premium}) async {
  if (await storage.getUserProfile() != null) return;
  // ignore: invalid_use_of_visible_for_testing_member
  final clock = StorageService.clockForTesting;

  await storage.saveUserProfile(UserProfile(
      name: screenshotName,
      learningGoal: LearningGoal.examPrep,
      avatar: screenshotAvatar));

  // July, August, September (relative to [now]): each the middle of its
  // tier's band, every day all right, seeded "in" that month so its first
  // completion records its theme.
  try {
    for (final (i, tier) in pastMonthTiers.indexed) {
      final month = DateTime(now.year, now.month - pastMonthTiers.length + i);
      final days = _daysForTier(month.year, month.month, tier);
      // ignore: invalid_use_of_visible_for_testing_member
      StorageService.clockForTesting =
          () => DateTime(month.year, month.month, days, 20);
      // ignore: invalid_use_of_visible_for_testing_member
      StorageService.themeForNewMonthForTesting = (_, __) => pastMonthThemes[i];
      for (var d = 1; d <= days; d++) {
        await _completeDay(storage, DateTime(month.year, month.month, d), 5);
      }
    }
  } finally {
    // ignore: invalid_use_of_visible_for_testing_member
    StorageService.clockForTesting = clock;
    // ignore: invalid_use_of_visible_for_testing_member
    StorageService.themeForNewMonthForTesting = (_, __) => screenshotTheme;
  }
  await storage.finalizePastMedalMonths();

  final days = DateTime(now.year, now.month + 1, 0).day;
  final hut = ClimbSavePoints.all.firstWhere((p) => p.object == 'cabin');
  // Steps before today's test: one short of Halfway Hut.
  final before = hut.reachedOn(days) - 1;
  final dayNumbers = [
    for (var d = 1; d <= days; d++)
      if (d != now.day) d
  ].take(before).toList();

  // Every seeded day all right (10 points), unless that would let today's
  // 9 points cross a medal threshold (the result frame must show the
  // explanations, not a celebration): then the last seeded days drop a
  // question until it does not.
  final correct = List.filled(dayNumbers.length, 5);
  int score() => correct.fold(
      0, (s, c) => s + MonthlyMedalRules.score(correct: c, wrong: 5 - c));
  final todayPoints = MonthlyMedalRules.score(correct: 4, wrong: 1);
  final tiers = [
    for (final t in MedalTier.values)
      MonthlyMedalRules.threshold(now.year, now.month, t)
  ];
  bool crosses() => tiers.any((t) => score() < t && score() + todayPoints >= t);
  for (var i = correct.length - 1; crosses() && i >= 0; i--) {
    while (crosses() && correct[i] > 2) {
      correct[i]--;
    }
  }
  for (final (i, d) in dayNumbers.indexed) {
    await _completeDay(storage, DateTime(now.year, now.month, d), correct[i]);
  }
  await storage.saveDailyTestSet(kDayZeroQuestions,
      day: _key(now), source: DailyTestSource.shared);

  final seen = now.subtract(const Duration(days: 1));
  ErrorEntry modal(int daysAgo) => ErrorEntry(
      topicId: 'modalVerbs',
      errorType: 'modalVerbs',
      timestamp: seen.subtract(Duration(days: daysAgo)),
      prompt: 'She can speaks three languages.\nFind the mistake and '
          'rewrite the full corrected sentence.',
      userAnswer: 'She can speaks three languages',
      correctedAnswer: 'She can speak three languages',
      explanation: "After 'can', the verb stays in its plain form, even "
          "with 'she'.",
      rule: 'Plain verb after a modal',
      source: ErrorSource.dailyTest);
  await storage.insertErrors([
    modal(2),
    modal(6),
    modal(11),
    ErrorEntry(
        topicId: 'tenseSelection',
        errorType: 'tenseSelection',
        timestamp: seen.subtract(const Duration(days: 4)),
        prompt: 'I have seen that film last week.\nFind the mistake and '
            'rewrite the full corrected sentence.',
        userAnswer: 'I have seen that film last week',
        correctedAnswer: 'I saw that film last week',
        explanation: "'Last week' is a finished time, so the past simple: "
            "'I saw'.",
        rule: 'Past simple with a finished time',
        source: ErrorSource.dailyTest),
  ]);

  if (premium) await storage.setDebugAccessOverride(true);

  await storage.claimOneTimeFlag(StorageService.day0PaywallFlag);
  await storage.claimOneTimeFlag(StorageService.firstRunZoomFlag);
  await storage
      .claimOneTimeFlag(StorageService.monthZoomFlag(now.year, now.month));
  await storage
      .claimOneTimeFlag(StorageService.monthCardSeenFlag(now.year, now.month));
}

/// Days of all-right tests (10 points each) that put [year]/[month] in
/// the middle of [tier]'s band: between its threshold and the next tier's
/// (or the month's maximum for Gold).
int _daysForTier(int year, int month, MedalTier tier) {
  final low = MonthlyMedalRules.threshold(year, month, tier);
  final high = tier == MedalTier.gold
      ? MonthlyMedalRules.maxScore(year, month)
      : MonthlyMedalRules.threshold(
          year, month, MedalTier.values[tier.index + 1]);
  final perDay = MonthlyMedalRules.score(correct: 5, wrong: 0);
  return ((low + high) / 2 / perDay).ceil();
}

/// [day]'s Daily Test, done at 8:40 with [correct] of five right (the rest
/// wrong).
Future<void> _completeDay(
    StorageService storage, DateTime day, int correct) async {
  await storage.saveDailyTestSet(kDayZeroQuestions,
      day: _key(day), source: DailyTestSource.shared);
  await storage.completeDailyTest({
    for (final (j, q) in kDayZeroQuestions.indexed)
      q.item.id: j < correct ? q.correctAnswer : 'x',
  }, const [],
      day: _key(day),
      completedAt: DateTime(day.year, day.month, day.day, 8, 40));
}
