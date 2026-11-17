import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/reminder_settings.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// INTEGRATE.md §2 (database): the live App Store build, 1.4.0 (build 7,
/// `c37757a`), stores schema v26; `ui-polish-widgets` is v27 (the widgets
/// branch's `reminder_settings`). An install over 1.4.0 must migrate in
/// one step and keep everything the learner has.
///
/// The old database is built from `test/fixtures/storage_v26_140.sql`, the
/// 1.4.0 `onCreate` frozen verbatim, with a row in every table, then opened
/// through today's `StorageService`, so `onUpgrade` runs the code path a
/// phone updating from the App Store runs.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late String path;
  Database? inspection;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('upgrade-140-');
    path = join(dir.path, 'app.db');
    StorageService.clockForTesting = () => DateTime(2026, 11, 18, 9, 30);
  });

  tearDown(() async {
    await inspection?.close();
    inspection = null;
    await databaseFactory.deleteDatabase(path);
    await dir.delete(recursive: true);
    StorageService.clockForTesting = DateTime.now;
  });

  final questions = [
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

  /// One row per 1.4.0 table, as a 1.4.0 learner in their third month
  /// would have them: a retired hero (Tiger, `avatar_03`), the exam goal,
  /// two completed Daily Tests this month and one last month, mistakes in
  /// two weak spots, October's silver medal, the Welcome badge, the AI
  /// permission, settings and flags.
  Map<String, List<Map<String, Object?>>> rows140() => {
        'error_entries': [
          {
            'id': 7,
            'topic_id': 'articles',
            'error_type': 'missing_article',
            'timestamp': '2026-11-16T08:10:00.000',
            'prompt': 'She is ___ engineer.',
            'user_answer': 'a',
            'corrected_answer': 'an',
            'explanation': 'Use "an" before a vowel sound.',
            'rule': 'a / an',
            'source': 'daily_test',
            'user_blanks': '["a"]',
            'feedback_json': '{"summary":"Almost."}',
          },
          {
            'id': 8,
            'topic_id': 'articles',
            'error_type': 'missing_article',
            'timestamp': '2026-11-17T08:12:00.000',
            'prompt': 'It was ___ honour.',
            'user_answer': 'a',
            'corrected_answer': 'an',
            'explanation': 'A silent h takes "an".',
            'rule': 'a / an',
            'source': 'topic_practice',
            'user_blanks': null,
            'feedback_json': null,
          },
          {
            'id': 9,
            'topic_id': 'tenseSelection',
            'error_type': 'wrong_tense',
            'timestamp': '2026-11-02T19:00:00.000',
            'prompt': 'I ___ (live) here since May.',
            'user_answer': 'live',
            'corrected_answer': 'have lived',
            'explanation': '"Since" takes the present perfect.',
            'rule': 'present perfect',
            'source': 'daily_test',
            'user_blanks': null,
            'feedback_json': null,
          },
        ],
        'review_settings': [
          {'id': 0, 'sort_order': 'frequent'}
        ],
        'theme_settings': [
          {'id': 0, 'mode': 'dark'}
        ],
        'text_size_settings': [
          {'id': 0, 'size': 'large'}
        ],
        'language_settings': [
          {'id': 0, 'language': 'de'}
        ],
        'practice_settings': [
          {'id': 0, 'question_count': 10}
        ],
        'topic_practice_stats': [
          {'topic_id': 'articles', 'questions_answered': 23}
        ],
        'user_profile': [
          {
            'id': 0,
            'name': 'Ada',
            'learning_goal': 'exam_prep',
            'avatar': 'avatar_03',
          }
        ],
        'daily_session_usage': [
          {'day': '2026-11-17', 'session_count': 2}
        ],
        'free_practice_usage': [
          {'day': '2026-11-17', 'session_count': 1}
        ],
        'daily_test_sets': [
          {
            'day': '2026-11-17',
            'questions_json':
                jsonEncode(questions.map((q) => q.toJson()).toList()),
            'completed_at': '2026-11-17T08:15:00.000',
            'answers_json': '{"q0":"cooking"}',
            'source': 'generated',
          }
        ],
        'debug_settings': [
          {'id': 0, 'access_override': null}
        ],
        'device_identity': [
          {'id': 0, 'device_id': 'device-from-140'}
        ],
        'climb_daily_entries': [
          {
            'day': '2026-10-01',
            'completed_at': '2026-10-01T09:00:00.000',
            'step': 1,
            'correct_count': 4,
            'wrong_count': 1,
            'skipped_count': 0,
            'rule_version': 1,
          },
          {
            'day': '2026-11-16',
            'completed_at': '2026-11-16T08:15:00.000',
            'step': 1,
            'correct_count': 3,
            'wrong_count': 1,
            'skipped_count': 1,
            'rule_version': 1,
          },
          {
            'day': '2026-11-17',
            'completed_at': '2026-11-17T08:15:00.000',
            'step': 1,
            'correct_count': 5,
            'wrong_count': 0,
            'skipped_count': 0,
            'rule_version': 1,
          },
        ],
        'monthly_medal_results': [
          {
            'month': '2026-10',
            'tier': 'silver',
            'score': 61,
            'max_score': 93,
            'active_days': 19,
            'correct_count': 70,
            'wrong_count': 20,
            'skipped_count': 5,
            'rule_version': 1,
            'finalized_at': '2026-11-01T00:00:05.000',
          }
        ],
        'welcome_badge': [
          {
            'id': 0,
            'earned_at': '2026-10-01T09:00:00.000',
            'rule_version': 1,
            'backfilled': 0,
          }
        ],
        'ai_consent': [
          {
            'id': 0,
            'granted': 1,
            'decided_at': '2026-10-01T08:58:00.000',
            'consent_version': 1,
          }
        ],
        'one_time_flags': [
          {'key': 'day0_paywall', 'set_at': '2026-10-01T09:01:00.000'},
          {'key': 'month_card:2026-11', 'set_at': '2026-11-02T19:05:00.000'},
        ],
        'climb_month_themes': [
          {
            'month': '2026-10',
            'theme_id': 'green_slope',
            'assigned_at': '2026-10-01T09:00:00.000',
          },
          {
            'month': '2026-11',
            'theme_id': 'ember_peak',
            'assigned_at': '2026-11-02T19:05:00.000',
          },
        ],
      };

  Future<Map<String, List<Map<String, Object?>>>> seed140() async {
    final old = await openDatabase(path, version: 26, onCreate: (db, _) async {
      final sql =
          await File('test/fixtures/storage_v26_140.sql').readAsString();
      for (final statement in sql.split(';')) {
        if (statement.trim().isNotEmpty) await db.execute(statement);
      }
    });
    final rows = rows140();
    for (final table in rows.entries) {
      for (final row in table.value) {
        await old.insert(table.key, row);
      }
    }
    final before = {for (final t in rows.keys) t: await old.query(t)};
    await old.close();
    return before;
  }

  Future<Database> inspect() async => inspection ??= await openDatabase(path);

  test('the fixture is exactly 1.4.0: v26 with its 19 tables', () async {
    await seed140();
    final db = await openDatabase(path);
    expect(await db.getVersion(), 26);
    final tables = (await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table' "
                "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'"))
        .map((r) => r['name'])
        .toSet();
    await db.close();
    expect(tables, rows140().keys.toSet());
    expect(tables, isNot(contains('reminder_settings')));
  });

  test(
      'an install over 1.4.0 migrates v26 -> v27 in one step and keeps every '
      'row; only the retired hero becomes Fox', () async {
    final before = await seed140();
    final storage = StorageService(dbName: path);

    // The profile: name and goal kept; Tiger (retired) is Fox now.
    final profile = (await storage.getUserProfile())!;
    expect(profile.name, 'Ada');
    expect(profile.learningGoal, LearningGoal.examPrep);
    expect(profile.avatar, same(Avatar.fox));

    // Completions: this month's two steps and last month's, and the first
    // test on record (Profile's "since").
    expect(await storage.getClimbProgress(2026, 11),
        (steps: 2, correct: 8, wrong: 1, skipped: 1));
    expect(await storage.getClimbProgress(2026, 10),
        (steps: 1, correct: 4, wrong: 1, skipped: 0));
    expect(
        await storage.getFirstDailyTestCompletion(), DateTime(2026, 10, 1, 9));
    final today = (await storage.getDailyTestSet('2026-11-17'))!;
    expect(today.questions, hasLength(5));
    expect(today.completedAt, DateTime(2026, 11, 17, 8, 15));

    // Weak spots, most frequent first.
    final spots =
        await storage.getWeakSpots(sortOrder: ReviewSortOrder.frequent);
    expect([
      for (final s in spots) (s.topicId, s.errorType, s.frequency)
    ], [
      ('articles', 'missing_article', 2),
      ('tenseSelection', 'wrong_tense', 1),
    ]);

    // Medals: October's silver and the Welcome badge.
    final medals = await storage.getMonthlyMedalResults();
    expect(medals, hasLength(1));
    expect((medals.single.year, medals.single.month, medals.single.tier),
        (2026, 10, MedalTier.silver));
    expect(medals.single.score, 61);
    expect((await storage.getWelcomeBadge())!.backfilled, isFalse);

    // Settings and permissions carried over.
    expect(await storage.getLanguage(), AppLanguage.de);
    expect(await storage.getTextSize(), AppTextSize.large);
    expect(await storage.getThemeMode(), AppThemeMode.dark);
    expect(await storage.getReviewSortOrder(), ReviewSortOrder.frequent);
    expect((await storage.getAiConsent())!.granted, isTrue);
    expect(await storage.getOrCreateDeviceId(), 'device-from-140');
    expect((await storage.getClimbMonthThemes())[(2026, 11)], 'ember_peak');

    // Reminders: the new table exists and reads as the defaults — every
    // kind off, 20:00, not asked — so N01 may ask once.
    expect(await storage.getReminderSettings(), const ReminderSettings());
    await storage.close();

    final db = await inspect();
    expect(await db.getVersion(), 27);
    expect(await db.query('reminder_settings'), isEmpty);
    for (final table in before.keys) {
      final expected = table == 'user_profile'
          ? [
              for (final row in before[table]!) {...row, 'avatar': 'avatar_14'}
            ]
          : before[table];
      expect(await db.query(table), expected, reason: table);
    }
  });

  test('a current hero and the new School goal round-trip after the upgrade',
      () async {
    await seed140();
    final db = await openDatabase(path);
    await db.update('user_profile', {'avatar': 'avatar_07'});
    await db.close();
    final storage = StorageService(dbName: path);
    final profile = (await storage.getUserProfile())!;
    expect(profile.avatar, same(Avatar.crab));
    await storage
        .saveUserProfile(profile.copyWith(learningGoal: LearningGoal.school));
    expect((await storage.getUserProfile())!.learningGoal, LearningGoal.school);
    await storage.close();
  });
}
