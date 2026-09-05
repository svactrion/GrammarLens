import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/widgets/weak_spot_card.dart';

/// Covers the two bugs this card used to have (docs/build-log.md), with a
/// record shaped like each of the two sources that feed the error profile
/// (see ErrorSource): a Topic Practice record has a real explanation and
/// an errorType finer than its topic; a Daily Test record has none of
/// that — its errorType is exactly the topic id (no finer per-mistake
/// classification, see ErrorSource's doc comment).
void main() {
  const gerundTopic = Topic(
    id: TopicId.gerundVsInfinitive,
    title: 'Gerund vs. Infinitive',
    description: 'x',
    icon: Icons.compare_arrows,
  );
  const articlesTopic = Topic(
    id: TopicId.articles,
    title: 'Articles',
    description: 'x',
    icon: Icons.abc,
  );

  final topicPracticeSpot = WeakSpot(
    topicId: 'articles',
    errorType: 'missing_article',
    frequency: 3,
    lastSeen: DateTime(2026, 1, 1),
    latestExplanation: 'You left out "the" before a specific noun.',
  );

  // errorType == topic id, exactly what a Daily Test-sourced weak spot
  // looks like — see ErrorEntry.errorType's fallback for Daily Test.
  final dailyTestSpot = WeakSpot(
    topicId: 'gerundVsInfinitive',
    errorType: 'gerundVsInfinitive',
    frequency: 2,
    lastSeen: DateTime(2026, 1, 1),
    latestExplanation: null,
  );

  Future<void> pump(
    WidgetTester tester, {
    required Topic topic,
    required WeakSpot spot,
    bool locked = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeakSpotCard(topic: topic, spot: spot, locked: locked, onTap: () {}),
        ),
      ),
    );
  }

  group('Topic Practice-sourced record (finer errorType, real explanation)', () {
    testWidgets('title is the error type name, never the explanation text',
        (tester) async {
      await pump(tester, topic: articlesTopic, spot: topicPracticeSpot);

      expect(find.text('Missing Article'), findsOneWidget);
      expect(
        find.text('You left out "the" before a specific noun.'),
        findsOneWidget,
      );
      // The explanation must be its own line, never the title itself.
      expect(
        find.text('You left out "the" before a specific noun.'),
        isNot(find.text('Missing Article')),
      );
    });

    testWidgets('topic name is shown as a subtitle since it differs from '
        'the title', (tester) async {
      await pump(tester, topic: articlesTopic, spot: topicPracticeSpot);
      expect(find.text('Articles'), findsOneWidget);
    });
  });

  group('Daily Test-sourced record (errorType == topic id, no explanation)', () {
    testWidgets(
        'title is the topic name (the most specific name available) — '
        'not a fabricated explanation', (tester) async {
      await pump(tester, topic: gerundTopic, spot: dailyTestSpot);
      expect(find.text('Gerund vs. Infinitive'), findsOneWidget);
    });

    testWidgets(
        'the topic name is not printed a second time as a subtitle — the '
        'exact "X · X" duplicate bug this card used to have',
        (tester) async {
      await pump(tester, topic: gerundTopic, spot: dailyTestSpot);
      // Exactly one occurrence anywhere in the card, not two.
      expect(find.text('Gerund vs. Infinitive'), findsOneWidget);
      expect(find.textContaining('Gerund vs. Infinitive ·'), findsNothing);
    });

    testWidgets('no explanation line renders when there is none to show '
        '(never fabricated)', (tester) async {
      await pump(tester, topic: gerundTopic, spot: dailyTestSpot);
      // Nothing besides the title, the frequency chip and the chevron —
      // in particular no second text pretending to be an explanation.
      expect(find.byType(Text), findsNWidgets(2));
    });
  });

  testWidgets('locked shows the lock glyph next to the title', (tester) async {
    await pump(tester, topic: articlesTopic, spot: topicPracticeSpot, locked: true);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });

  testWidgets('tapping the card calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeakSpotCard(
            topic: articlesTopic,
            spot: topicPracticeSpot,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(WeakSpotCard));
    expect(tapped, isTrue);
  });
}
