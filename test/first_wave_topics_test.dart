import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/data/topic_hints.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/home_practice.dart';

import 'support/l10n_support.dart';

/// UI polish SPEC §1.11: the first-wave practice topics are in the code
/// (data, titles, hint cards, the proxy's table) but switched off; the Daily
/// Test keeps its five. Both switch states are covered here (the proxy's in
/// `proxy/test/topics.test.ts`).
class _Storage extends StorageService {
  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};
}

class _Subs extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => true;
}

void main() {
  const firstWave = [
    TopicId.conditionals,
    TopicId.passiveVoice,
    TopicId.prepositions,
    TopicId.relativeClauses,
    TopicId.comparativesSuperlatives,
  ];

  test('the switch is on (1.5.0): Topic Practice offers all ten', () {
    expect(kFirstWaveTopicsEnabled, isTrue);
    expect(practiceTopics(), [...kTopics, ...kFirstWaveTopics]);
    expect(practiceTopics(), hasLength(10));
  });

  test('flag off: Topic Practice offers the five, as before', () {
    expect(practiceTopics(firstWave: false), kTopics);
    expect(practiceTopics(firstWave: false).map((t) => t.id),
        isNot(contains(TopicId.conditionals)));
  });

  test('the Daily Test keeps its five topics', () {
    expect(kTopics.map((t) => t.id), [
      TopicId.gerundVsInfinitive,
      TopicId.modalVerbs,
      TopicId.modalPastForms,
      TopicId.tenseSelection,
      TopicId.articles,
    ]);
    for (final id in firstWave) {
      expect(kTopics.map((t) => t.id), isNot(contains(id)));
    }
  });

  test('a stored weak spot finds its topic, a first-wave one included', () {
    for (final t in [...kTopics, ...kFirstWaveTopics]) {
      expect(topicOfWeakSpot(t.id.name), t);
    }
    // A name this version does not know: the first topic, as before.
    expect(topicOfWeakSpot('phrasalVerbs'), kTopics.first);
  });

  test('flag on: the five plus the first wave, each fully described', () {
    final topics = practiceTopics(firstWave: true);
    expect(topics, hasLength(10));
    expect(topics.map((t) => t.id).skip(5), firstWave);
    const c = AppColors.light;
    for (final t in kFirstWaveTopics) {
      expect(t.title(en), isNotEmpty);
      expect(t.description(en), isNotEmpty);
      expect(kTopicHints[t.id], hasLength(4), reason: t.id.name);
      expect(topicTileColors(c, t.id), isNotNull);
      expect(topicByName(t.id.name), t);
    }
    expect(kFirstWaveTopics.map((t) => t.title(en)), [
      'Conditionals',
      'Passive Voice',
      'Prepositions',
      'Relative Clauses',
      'Comparatives & Superlatives',
    ]);
  });

  Future<void> pump(WidgetTester tester, {required bool firstWave}) async {
    tester.view.physicalSize = const Size(390, 2000) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: TopicPracticeScreen(
        claudeService: ClaudeService(),
        storageService: _Storage(),
        analyticsService: AnalyticsService(),
        subscriptionService: _Subs(),
        firstWaveTopics: firstWave,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Topic Practice, flag off: no first-wave topic is visible',
      (tester) async {
    await pump(tester, firstWave: false);
    for (final t in kTopics) {
      expect(find.byKey(TopicPracticeScreen.cardKey(t)), findsOneWidget);
    }
    for (final t in kFirstWaveTopics) {
      expect(find.byKey(TopicPracticeScreen.cardKey(t)), findsNothing);
      expect(find.text(t.title(en)), findsNothing);
    }
  });

  testWidgets('Topic Practice, flag on: every first-wave topic has a card',
      (tester) async {
    await pump(tester, firstWave: true);
    for (final t in [...kTopics, ...kFirstWaveTopics]) {
      expect(find.byKey(TopicPracticeScreen.cardKey(t)), findsOneWidget,
          reason: t.id.name);
    }
    expect(tester.takeException(), isNull);
  });
}
