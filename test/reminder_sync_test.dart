import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/reminder_settings.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/app_link.dart';
import 'package:grammar_lens/services/native_bridge.dart';
import 'package:grammar_lens/services/reminder_plan.dart';
import 'package:grammar_lens/services/reminder_sync.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';

import 'support/fake_native_bridge.dart';

class _Storage extends StorageService {
  ReminderSettings settings = const ReminderSettings().turnedOn();
  UserProfile? profile = const UserProfile(
      name: 'Ada', learningGoal: LearningGoal.general, avatar: Avatar.fox);
  DailyTestSet? today;
  int steps = 1;
  int points = 10;
  int freeUsed = 0;
  List<WeakSpot> weak = const [];

  @override
  Future<ReminderSettings> getReminderSettings() async => settings;

  @override
  Future<UserProfile?> getUserProfile() async => profile;

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => today;

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: steps, correct: steps, wrong: 0, skipped: 0);

  @override
  Future<MonthlyMedalProgress> getMonthlyMedalProgress(
          int year, int month) async =>
      MonthlyMedalProgress(
          year: year,
          month: month,
          score: points,
          maxScore: 300,
          activeDays: steps,
          correct: 0,
          wrong: 0,
          skipped: 0);

  @override
  Future<int> getFreePracticeCountForToday() async => freeUsed;

  @override
  Future<Map<(int, int), String>> getClimbMonthThemes() async => const {};

  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      'ember_peak';

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      weak;
}

DailyTestSet _done() => DailyTestSet(
      day: '2026-11-18',
      questions: [
        DailyTestQuestion(
          item: const PracticeItem(
              id: 'q0',
              type: PracticeItemType.fillInBlank,
              instruction: 'Question'),
          topicId: 'articles',
          correctAnswer: 'the',
          commonWrongAnswers: const [],
        ),
      ],
      completedAt: DateTime(2026, 11, 18, 9),
      answers: const {'q0': 'the'},
    );

final _en = lookupAppLocalizations(const Locale('en'));

ReminderNames _names({String? weakSpot}) => ReminderNames(
      buddy: 'Fox',
      mountainFor: (year, month) => month == 12 ? 'Glacier Peak' : 'Ember Peak',
      weakSpot: weakSpot,
    );

PlannedReminder _planned(ReminderKind kind,
        {int stepsDone = 0,
        int step = 1,
        DateTime? at,
        MedalTier? tier,
        int pointsToGo = 0}) =>
    PlannedReminder(
      at: at ?? DateTime(2026, 11, 18, 20),
      kind: kind,
      step: step,
      stepsDone: stepsDone,
      tier: tier,
      pointsToGo: pointsToGo,
    );

void main() {
  group('reminderMessage (N02, in English)', () {
    test('Daily Test: before the first save point, the mountain', () {
      final m = reminderMessage(
          _planned(ReminderKind.dailyTest, step: 1), _names(), _en);
      expect(m.title, 'Fox is waiting on Ember Peak');
      expect(m.body,
          'Today’s 5 questions take about 2 minutes. Step 1 is one test away.');
      expect(m.link, AppLink.dailyTest);
    });

    test('Daily Test: after a save point, its name', () {
      final firstCamp = ClimbRoute.savePointSteps(30)['C1']!;
      final m = reminderMessage(
          _planned(ReminderKind.dailyTest,
              stepsDone: firstCamp, step: firstCamp + 1),
          _names(),
          _en);
      expect(m.title, 'Fox is waiting at First Camp');
      expect(reachedSavePoint(firstCamp - 1, 30), isNull);
    });

    test('close to a medal', () {
      final m = reminderMessage(
          _planned(ReminderKind.closeToMedal,
              tier: MedalTier.bronze, pointsToGo: 4),
          _names(),
          _en);
      expect(m.title, 'So close to Bronze');
      expect(m.body, 'Just 4 points to go this month.');
      expect(
          reminderMessage(
                  _planned(ReminderKind.closeToMedal,
                      tier: MedalTier.silver, pointsToGo: 1),
                  _names(),
                  _en)
              .body,
          'Just 1 point to go this month.');
    });

    test('free ticket: opens Review, names the weak spot', () {
      final m = reminderMessage(_planned(ReminderKind.freeTicket),
          _names(weakSpot: 'The With Superlatives'), _en);
      expect(m.title, 'Your free ticket is back');
      expect(m.body, 'Practise “The With Superlatives” with AI feedback.');
      expect(m.link, AppLink.review);
      expect(
          reminderMessage(_planned(ReminderKind.freeTicket), _names(), _en)
              .body,
          'Practise a weak spot with AI feedback.');
    });

    test('new mountain: the new month\'s mountain', () {
      final m = reminderMessage(
          _planned(ReminderKind.newMountain, at: DateTime(2026, 12, 1, 20)),
          _names(),
          _en);
      expect(m.title, 'A new mountain: Glacier Peak');
      expect(m.body, 'Fox is at the start. Step 1 is one test away.');
    });

    test('every language has every reminder string', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final kind in ReminderKind.values) {
          final m = reminderMessage(
              _planned(kind, tier: MedalTier.bronze, pointsToGo: 3),
              _names(weakSpot: 'Articles'),
              l10n);
          expect(m.title, isNotEmpty, reason: '$locale $kind');
          expect(m.body, isNotEmpty, reason: '$locale $kind');
        }
      }
    });
  });

  group('ReminderSync', () {
    late _Storage storage;
    late FakeNativeBridge bridge;

    ReminderSync sync({bool premium = false, String locale = 'en'}) =>
        ReminderSync(
          storage: storage,
          bridge: bridge,
          locale: () => Locale(locale),
          hasFullAccess: () async => premium,
          clock: () => DateTime(2026, 11, 18, 9),
        );

    void reset() {
      storage = _Storage();
      bridge = FakeNativeBridge()
        ..permission = NotificationPermission.authorized;
    }

    setUp(reset);

    test('schedules seven days with the companion\'s picture and links',
        () async {
      expect(await sync().run(), 7);
      expect(bridge.scheduled.map((r) => r.id).first, 'gl.reminder.2026-11-18');
      final first = bridge.scheduled.first;
      expect(first.at, DateTime(2026, 11, 18, 20));
      expect(first.title, 'Fox is waiting on Ember Peak');
      expect(first.link, 'grammarlens://daily-test');
      expect(first.image, 'avatar_14.png');
    });

    test('after the test: today becomes the free ticket, for a free user',
        () async {
      storage
        ..today = _done()
        ..steps = 2;
      await sync().run();
      expect(bridge.scheduled.first.title, 'Your free ticket is back');
      expect(bridge.scheduled.first.link, 'grammarlens://review');

      storage.freeUsed = 1;
      await sync().run();
      expect(bridge.scheduled.first.at.day, 19, reason: 'today cancelled');

      storage.freeUsed = 0;
      await sync(premium: true).run();
      expect(bridge.scheduled.first.at.day, 19, reason: 'no ticket in Premium');
    });

    test('in the app\'s language', () async {
      await sync(locale: 'tr').run();
      expect(bridge.scheduled.first.title,
          'Tilki, Kor Zirvesi yolunda seni bekliyor');
    });

    test('nothing when not accepted, all off, no permission or no profile',
        () async {
      for (final setup in <void Function()>[
        () => storage.settings = const ReminderSettings(),
        () => storage.settings =
            const ReminderSettings(ask: ReminderAsk.declined),
        () => bridge.permission = NotificationPermission.denied,
        () => bridge.permission = NotificationPermission.notDetermined,
        () => storage.profile = null,
      ]) {
        reset();
        bridge.scheduled = [
          ReminderRequest(
              id: 'gl.reminder.old',
              at: DateTime(2026),
              title: '',
              body: '',
              link: '')
        ];
        setup();
        expect(await sync().run(), 0);
        expect(bridge.scheduled, isEmpty);
        expect(bridge.cancels, 1);
      }
    });
  });
}
