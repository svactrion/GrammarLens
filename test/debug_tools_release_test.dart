import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/utils/debug_tools.dart';

import 'support/recording_analytics_sink.dart';

/// Launch checklist item 8: developer tools must not exist in a release
/// build. `flutter test` always runs with `kDebugMode == true`, so a release
/// build is simulated by switching off [DebugTools.enabledForTesting], which
/// every gate ANDs with `kDebugMode`. Per-screen checks live beside their
/// screens' tests (settings_screen_test, daily_test_screen_test,
/// storage_service_reset_onboarding_test); this file covers the app shell, the
/// subscription seam and the source-level structure.
class _CountingStorage extends StorageService {
  int overrideReads = 0;

  @override
  Future<UserProfile?> getUserProfile() async =>
      const UserProfile(name: 'Ada', learningGoal: LearningGoal.general);

  @override
  Future<bool?> getDebugAccessOverride() async {
    overrideReads++;
    return null;
  }
}

void main() {
  tearDown(() => DebugTools.enabledForTesting = true);

  group('app launch', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized()
              .platformDispatcher
              .accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
    });
    tearDown(() {
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });

    testWidgets('a release build never loads a stored entitlement override',
        (tester) async {
      DebugTools.enabledForTesting = false;
      final storage = _CountingStorage();
      await tester.pumpWidget(GrammarLensApp(
        storageService: storage,
        analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
      ));
      await tester.pumpAndSettle();

      expect(storage.overrideReads, 0);
    });

    testWidgets('a debug build loads it at launch', (tester) async {
      final storage = _CountingStorage();
      await tester.pumpWidget(GrammarLensApp(
        storageService: storage,
        analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
      ));
      await tester.pumpAndSettle();

      expect(storage.overrideReads, 1);
    });
  });

  group('subscription service', () {
    final service = SubscriptionService();

    tearDown(() async {
      // The debug switch must be back on first, or the reset is a no-op.
      DebugTools.enabledForTesting = true;
      await service.setDebugAccessOverride(null);
      service.setDebugFixtureOffering(enabled: false);
    });

    test(
        'one switch turns off both the entitlement override and the pricing '
        'fixture', () async {
      await service.setDebugAccessOverride(true);
      service.setDebugFixtureOffering(enabled: true);
      expect(service.debugAccessOverride, isTrue);
      expect(service.debugFixtureOffering, isNotNull);

      DebugTools.enabledForTesting = false;

      expect(SubscriptionService.debugModeForTesting, isFalse);
      expect(service.debugAccessOverride, isNull);
      expect(service.debugFixtureOffering, isNull);
      expect(await service.hasFullAccess, isFalse);
      expect(await service.getOfferings(), isNull);
    });

    test('in a release build the setters change nothing', () async {
      DebugTools.enabledForTesting = false;
      await service.setDebugAccessOverride(true);
      service.setDebugFixtureOffering(enabled: true);
      DebugTools.enabledForTesting = true;

      expect(service.debugAccessOverride, isNull);
      expect(service.debugFixtureOffering, isNull);
    });
  });

  group('source structure', () {
    List<File> dartFiles(String dir) => Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test(
        'no app code outside lib/preview imports the standalone previews, so '
        'they cannot end up in a release build', () {
      for (final file in dartFiles('lib')) {
        if (file.path.startsWith('lib/preview/')) continue;
        expect(file.readAsStringSync(), isNot(contains('preview/monthly_')),
            reason: '${file.path} must not import a lib/preview entry point');
      }
    });

    test('every standalone preview refuses to run outside a debug build', () {
      for (final file in dartFiles('lib/preview')) {
        final source = file.readAsStringSync();
        if (!source.contains('void main()')) continue;
        expect(source, contains('if (!kDebugMode) throw'),
            reason: '${file.path} is an entry point without a debug guard');
      }
    });

    test(
        'no bare kDebugMode gate outside debug_tools remains in lib/screens '
        'or lib/app.dart: every gate also honours the test switch', () {
      final bare =
          RegExp(r'^\s*(if|\.\.\.)?.*\bif \(kDebugMode\)', multiLine: true);
      for (final file in [
        ...dartFiles('lib/screens'),
        File('lib/app.dart'),
      ]) {
        final code = file
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        expect(bare.hasMatch(code), isFalse,
            reason: '${file.path} gates on kDebugMode alone, so a release '
                'simulation cannot cover it');
      }
    });
  });
}
