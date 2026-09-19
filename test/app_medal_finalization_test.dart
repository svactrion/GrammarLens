import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

import 'support/recording_analytics_sink.dart';

/// Counts finalize calls and reports whatever months it is told to. Every
/// other storage read falls through to the real service, which has no
/// platform channel in a widget test and throws — the same path
/// widget_test.dart relies on, which the app already tolerates.
class _FinalizingStorage extends StorageService {
  int calls = 0;
  List<MonthlyMedalResult> nextResult = const [];

  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async {
    calls++;
    final result = nextResult;
    nextResult = const [];
    return result;
  }
}

MonthlyMedalResult _result({MedalTier? tier}) => MonthlyMedalResult(
      year: 2026,
      month: 9,
      score: 230,
      maxScore: 300,
      activeDays: 23,
      correct: 100,
      wrong: 30,
      skipped: 5,
      tier: tier,
      ruleVersion: 1,
      finalizedAt: DateTime(2026, 10, 5, 12),
    );

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

  testWidgets(
      'finalizes past medal months at launch and on resume, reporting '
      'each newly finalized month once', (tester) async {
    final storage = _FinalizingStorage()
      ..nextResult = [_result(tier: MedalTier.gold)];
    final sink = RecordingAnalyticsSink();

    await tester.pumpWidget(GrammarLensApp(
      storageService: storage,
      analyticsService: AnalyticsService(sink: sink),
    ));
    await tester.pumpAndSettle();

    expect(storage.calls, 1, reason: 'launch');
    expect(sink.named('medal_month_finalized'), hasLength(1));
    expect(sink.named('medal_month_finalized').single.parameters, {
      'tier': 'gold',
      'score_pct': 77,
      'active_days': 23,
      'days_in_month': 30,
      'rule_version': 1,
      'months_ago': 1,
    });

    // Going to the background does nothing; coming back finalizes again,
    // and with nothing left to freeze it reports nothing further.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(storage.calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(storage.calls, 2, reason: 'resume');
    expect(sink.named('medal_month_finalized'), hasLength(1));
  });

  testWidgets('a storage failure at launch never crashes the app',
      (tester) async {
    await tester.pumpWidget(GrammarLensApp(
      storageService: _ThrowingFinalizeStorage(),
      analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _ThrowingFinalizeStorage extends StorageService {
  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() =>
      throw StateError('disk unavailable');
}
