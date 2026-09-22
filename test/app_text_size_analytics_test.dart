import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

import 'support/recording_analytics_sink.dart';

/// Just enough persistence for the app to reach its tab shell with a stored
/// text size; every other read falls through to the real service, which has
/// no platform channel in a widget test and throws — a path the app already
/// tolerates (see widget_test.dart).
class _Storage extends StorageService {
  AppTextSize stored;
  _Storage(this.stored);

  @override
  Future<UserProfile?> getUserProfile() async =>
      const UserProfile(name: 'Ada', learningGoal: LearningGoal.work);

  @override
  Future<AppTextSize> getTextSize() async => stored;

  @override
  Future<void> setTextSize(AppTextSize size) async => stored = size;

  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];
}

void main() {
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

  Future<void> pumpApp(
    WidgetTester tester,
    _Storage storage,
    RecordingAnalyticsSink sink,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GrammarLensApp(
      storageService: storage,
      analyticsService: AnalyticsService(sink: sink),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the stored text size becomes the text_size user property at '
      'startup, without a text_size_changed event', (tester) async {
    final sink = RecordingAnalyticsSink();
    await pumpApp(tester, _Storage(AppTextSize.large), sink);

    expect(sink.userProperties['text_size'], 'large');
    expect(sink.named('text_size_changed'), isEmpty);
  });

  testWidgets(
      'changing the size reports text_size_changed and updates the property; '
      're-selecting the current size reports nothing', (tester) async {
    final sink = RecordingAnalyticsSink();
    await pumpApp(tester, _Storage(AppTextSize.medium), sink);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Large'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Re-selecting the size already in effect is not a change.
    await tester.tap(find.text('Medium'));
    await tester.pumpAndSettle();
    expect(sink.named('text_size_changed'), isEmpty);

    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();

    final changes = sink.named('text_size_changed');
    expect(changes, hasLength(1));
    expect(changes.single.parameters, {'size': 'large', 'previous': 'medium'});
    expect(sink.userProperties['text_size'], 'large');
  });
}
