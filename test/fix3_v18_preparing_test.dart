import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/data/topic_hints.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/utils/content_width.dart';
import 'package:grammar_lens/utils/loading_view.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/practice_preparing.dart';

import 'support/fix3_render.dart';

/// Fix round 3, B7 (SPEC V18, v11): one "questions being prepared" screen
/// for topic and weak-spot practice, as on the board. On the owner's device
/// the weak-spot practice's skeletons were narrower than the "Did you
/// know?" card, the weak spot's name sat at the top left as a big title and
/// the hint card was yellow.
///
/// Both entry points are driven for real (a free user's quick set: 3
/// questions), with the generation held open so the loading screen stays.
/// With `FIX3_CAPTURE=1` the renders go to `build/fix3-captures/`.
class _Storage extends StorageService {
  @override
  Future<AiConsent?> getAiConsent() async => AiConsent(
        granted: true,
        decidedAt: DateTime(2026, 1, 1),
        version: AiConsent.currentVersion,
      );

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};

  @override
  Future<int> getSessionCountForToday() async => 0;

  @override
  Future<int> getFreePracticeCountForToday() async => 0;

  @override
  Future<PracticeLength> getPracticeLength() async => PracticeLength.quick;

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<List<ErrorEntry>> getRecentMistakes(String topicId, String errorType,
          {int limit = 3}) async =>
      const [];
}

/// Generation that has not finished: the screen stays on V18.
class _Writing extends ClaudeService {
  final pending = Completer<PracticeSet>();
  int? count;

  @override
  Future<PracticeSet> generatePracticeSet(Topic topic,
      {required String deviceId, int count = 5}) {
    this.count = count;
    return pending.future;
  }
}

class _Free extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => false;
}

final _topic = kTopics.first;

WeakSpot _spot() => WeakSpot(
      topicId: _topic.id.name,
      errorType: 'missing_article',
      frequency: 3,
      lastSeen: DateTime(2026, 11, 17),
    );

/// V18 as the board draws it, whichever page it is on.
void _expectBoard(WidgetTester tester, {required Brightness brightness}) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  expect(find.byType(PracticePreparing), findsOneWidget);
  final context = tester.element(find.byType(PracticePreparing));
  final l10n = context.l10n;

  // The message names the topic, and no number of questions (1.5.0: a set
  // may come a question short).
  expect(find.text(l10n.practicePreparingTopic(_topic.title(l10n))),
      findsOneWidget);
  expect(find.text('Writing your questions on ${_topic.title(l10n)}…'),
      findsOneWidget);
  expect(l10n.practicePreparingTopic(_topic.title(l10n)),
      isNot(contains(RegExp(r'\d'))));

  // Nothing above the companion: no page title.
  final companion = tester.getRect(find.byType(CompanionView));
  for (final e in find
      .descendant(of: find.byType(PageLoading), matching: find.byType(Text))
      .evaluate()) {
    final box = e.renderObject! as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    expect(top, greaterThan(companion.top),
        reason: '"${(e.widget as Text).data}" sits above the companion');
  }
  expect(companion.width, PracticePreparing.companionSize);

  // Two skeletons and the hint card, one width: the content's.
  final width = MediaQuery.sizeOf(context).width;
  final pad = ContentWidth.sidePaddingOf(context);
  final cards = [
    tester.getRect(find.byKey(PracticePreparing.skeletonKey(0))),
    tester.getRect(find.byKey(PracticePreparing.skeletonKey(1))),
    if (kTopicHints[_topic.id]?.isNotEmpty ?? false)
      tester.getRect(find.byKey(PracticePreparing.hintCardKey)),
  ];
  expect(find.byKey(PracticePreparing.skeletonKey(2)), findsNothing);
  expect(cards, hasLength(3));
  for (final r in cards) {
    expect(r.left, closeTo(pad, .01));
    expect(r.right, closeTo(width - pad, .01));
  }
  // In order, 16 apart.
  expect(cards[1].top - cards[0].bottom, closeTo(16, .01));
  expect(cards[2].top - cards[1].bottom, closeTo(16, .01));

  // The hint card is the sky card, not yellow.
  final hint =
      tester.widget<Container>(find.byKey(PracticePreparing.hintCardKey));
  final deco = hint.decoration! as BoxDecoration;
  expect(deco.color, c.sky);
  expect(deco.color, isNot(c.goldSoft));
  expect(find.text(l10n.practiceDidYouKnow.toUpperCase()), findsOneWidget);
  expect(find.byKey(PracticePreparing.hintKey(0)), findsOneWidget);
}

void main() {
  for (final b in Brightness.values) {
    final dark = b == Brightness.dark;
    final mode = dark ? 'dark' : 'light';

    testWidgets('topic practice ($mode): V18 as on the board', (tester) async {
      final claude = _Writing();
      await pumpFix3(
        tester,
        TopicPracticeScreen(
          claudeService: claude,
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: _Free(),
          hero: Avatar.fox,
        ),
        brightness: b,
      );
      await tester.tap(find.byKey(TopicPracticeScreen.cardKey(_topic)));
      await tester.pumpAndSettle();
      expect(claude.count, 3);
      _expectBoard(tester, brightness: b);
      await fix3Capture(tester, 'V18-topic', dark: dark);
    });

    testWidgets('weak-spot practice ($mode): the same V18, no big title',
        (tester) async {
      final claude = _Writing();
      await pumpFix3(
        tester,
        WeakSpotDetailScreen(
          topic: _topic,
          spot: _spot(),
          hero: Avatar.fox,
          claudeService: claude,
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: _Free(),
        ),
        brightness: b,
      );
      await tester.tap(find.text('Use today’s ticket'));
      await tester.pumpAndSettle();
      expect(claude.count, 3);
      _expectBoard(tester, brightness: b);
      await fix3Capture(tester, 'V18-weakspot', dark: dark);
    });
  }

  testWidgets(
      'Review\'s ticket shape: a page header passed with a topic is not '
      'drawn (V18 has no page title)', (tester) async {
    await pumpFix3(
      tester,
      PageLoading(
        header: const Text('Missing articles'),
        message: 'Preparing your questions…',
        topic: _topic,
        hero: Avatar.fox,
        questionCount: 5,
      ),
    );
    expect(find.text('Missing articles'), findsNothing);
    expect(
        find.text(
            'Writing your questions on ${_topic.title(tester.element(find.byType(PracticePreparing)).l10n)}…'),
        findsOneWidget);
  });
}
