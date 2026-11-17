import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/device_sync.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/widget_sync.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_native_bridge.dart';

class _Storage extends StorageService {
  UserProfile? profile = const UserProfile(
      name: 'Ada', learningGoal: LearningGoal.general, avatar: Avatar.fox);
  DailyTestSet? today;
  int steps = 1;
  int points = 18;
  List<WeakSpot> weak = const [];
  Map<(int, int), String> themes = const {};

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
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      'ember_peak';

  @override
  Future<Map<(int, int), String>> getClimbMonthThemes() async => themes;

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

Map<String, dynamic> _payload(FakeNativeBridge bridge) =>
    jsonDecode(utf8.decode(bridge.files['payload.json']!))
        as Map<String, dynamic>;

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void main() {
  late _Storage storage;
  late FakeNativeBridge bridge;
  var now = DateTime(2026, 11, 18, 14, 30);

  WidgetSync sync({String locale = 'en'}) => WidgetSync(
        storage: storage,
        bridge: bridge,
        locale: () => Locale(locale),
        clock: () => now,
      );

  setUp(() {
    storage = _Storage();
    bridge = FakeNativeBridge()..available = true;
    now = DateTime(2026, 11, 18, 14, 30);
  });

  testWidgets('writes the payload, the avatar and both crops, then reloads',
      (tester) async {
    final written = await tester.runAsync(() => sync().run());
    expect(written, isTrue);
    expect(bridge.files.keys.toSet(), {
      'payload.json',
      'avatar_14.png',
      'mountain_ember_peak_d30_s1_light.png',
      'mountain_ember_peak_d30_s1_dark.png',
    });
    expect(bridge.reloads, 1);
    final payload = _payload(bridge);
    expect(payload['schema'], 1);
    final climb = (payload['entries'] as List).first['climb'] as Map;
    expect(climb['title'], 'Step 2 is waiting');
    expect(climb['mediumSubtitle'], 'Ember Peak · November · 1/30');

    final images = await tester.runAsync(() async => [
          await _decode(bridge.files['avatar_14.png']!),
          await _decode(bridge.files['mountain_ember_peak_d30_s1_light.png']!),
        ]);
    expect([images![0].width, images[0].height], [240, 240]);
    expect([images[1].width, images[1].height], [1092, 510]);
  });

  testWidgets(
      'a second run renders nothing again; a new step replaces the '
      'old crops', (tester) async {
    await tester.runAsync(() => sync().run());
    final avatar = bridge.files['avatar_14.png'];
    await tester.runAsync(() => sync().run());
    expect(identical(bridge.files['avatar_14.png'], avatar), isTrue);
    expect(bridge.reloads, 2);

    storage
      ..steps = 2
      ..today = _done();
    await tester.runAsync(() => sync().run());
    expect(bridge.files.keys.toSet(), {
      'payload.json',
      'avatar_14.png',
      'mountain_ember_peak_d30_s2_light.png',
      'mountain_ember_peak_d30_s2_dark.png',
    });
    final climb = (_payload(bridge)['entries'] as List).first['climb'] as Map;
    expect(climb['state'], 'done');
    expect(climb['title'], 'Step 2 of 30');
  });

  testWidgets('the last day of a month also writes the next month\'s crops',
      (tester) async {
    now = DateTime(2026, 11, 30, 20);
    storage.themes = {(2026, 12): 'glacier_peak'};
    await tester.runAsync(() => sync().run());
    expect(
        bridge.files.keys, contains('mountain_glacier_peak_d31_s0_light.png'));
    final next = (_payload(bridge)['entries'] as List)[1]['climb'] as Map;
    expect(next['mediumSubtitle'], 'Glacier Peak · December · 0/31');
  });

  testWidgets('in the app\'s language', (tester) async {
    await tester.runAsync(() => sync(locale: 'de').run());
    final climb = (_payload(bridge)['entries'] as List).first['climb'] as Map;
    expect(climb['title'], 'Schritt 2 wartet');
    // The mountain's and the month's names are translated too.
    expect(climb['mediumSubtitle'], 'Glutgipfel · November · 1/30');
    await tester.runAsync(() => sync(locale: 'ar').run());
    expect(_payload(bridge)['rtl'], isTrue);
  });

  testWidgets('nothing without the App Group or before onboarding',
      (tester) async {
    bridge.available = false;
    expect(await tester.runAsync(() => sync().run()), isFalse);
    bridge.available = true;
    storage.profile = null;
    expect(await tester.runAsync(() => sync().run()), isFalse);
    expect(bridge.files, isEmpty);
    expect(bridge.reloads, 0);
  });

  group('DeviceSync', () {
    test('requests during a run coalesce into one more run', () async {
      var runs = 0;
      late DeviceSync device;
      device = DeviceSync([
        () async {
          runs++;
          if (runs == 1) {
            device.request();
            device.request();
          }
          await Future<void>.delayed(Duration.zero);
        },
      ]);
      device.request();
      await device.idle;
      expect(runs, 2);
    });

    test('a failing job does not stop the others', () async {
      final ran = <String>[];
      final device = DeviceSync([
        () async => throw StateError('boom'),
        () async => ran.add('second'),
      ]);
      device.request();
      await device.idle;
      expect(ran, ['second']);
    });

    test('requestUpdate without an instance is a no-op', () {
      DeviceSync.current = null;
      DeviceSync.requestUpdate();
    });
  });

  group('StorageService.onChanged', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Directory dir;
    late StorageService real;
    var calls = 0;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('device-sync-test-');
      real = StorageService(dbName: join(dir.path, 'app.db'));
      calls = 0;
      StorageService.onChanged = () => calls++;
    });

    tearDown(() async {
      StorageService.onChanged = null;
      await real.close();
      await dir.delete(recursive: true);
    });

    test('fires after the writes the widgets and reminders depend on',
        () async {
      await real.saveUserProfile(
          const UserProfile(name: 'Ada', learningGoal: LearningGoal.general));
      expect(calls, 1);
      await real.recordFreePracticeStarted();
      expect(calls, 2);
      await real.recordSessionStarted();
      expect(calls, 3);
      await real.recordPracticeCompletion('articles', 5);
      expect(calls, 4);
      await real.resetProgressData();
      expect(calls, 5);
    });

    test('reads do not fire it', () async {
      await real.getUserProfile();
      await real.getFreePracticeCountForToday();
      expect(calls, 0);
    });
  });
}
