import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/text_format.dart';
import 'package:grammar_lens/widgets/locked_premium_pill.dart';
import 'package:grammar_lens/widgets/section_title.dart';

/// 1.2.0 Batch 9: Topic Practice laid out as the mockup. Presentation only:
/// the topics come from `kTopics`, the status line is the existing one
/// (N18) without the activity bar (Q8), a tap starts the existing launch
/// (`launchPracticeSet`), and the screen shows no paywall or lock.
class _Subscription extends SubscriptionService {
  final bool access;
  _Subscription(this.access);

  @override
  Future<bool> get hasFullAccess async => access;
}

class _Storage extends StorageService {
  Map<String, TopicStats> stats;
  int statsReads = 0;
  _Storage([this.stats = const {}]);

  @override
  Future<Map<String, TopicStats>> getTopicStats() async {
    statsReads++;
    return stats;
  }

  @override
  Future<AiConsent?> getAiConsent() async => AiConsent(
        granted: true,
        decidedAt: DateTime(2026, 1, 1),
        version: AiConsent.currentVersion,
      );

  @override
  Future<int> getSessionCountForToday() async => 0;

  @override
  Future<void> recordSessionStarted() async {}

  @override
  Future<int> getFreePracticeCountForToday() async => 0;

  @override
  Future<void> recordFreePracticeStarted() async {}

  @override
  Future<PracticeLength> getPracticeLength() async => PracticeLength.standard;

  @override
  Future<void> setPracticeLength(PracticeLength length) async {}

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<List<ErrorEntry>> getRecentMistakes(String topicId, String errorType,
          {int limit = 3}) async =>
      const [];
}

class _Claude extends ClaudeService {
  int calls = 0;

  @override
  Future<PracticeSet> generatePracticeSet(Topic topic,
      {required String deviceId, int count = 5}) async {
    calls++;
    return PracticeSet(
      topicId: topic.id.name,
      items: [
        for (var i = 0; i < count; i++)
          PracticeItem(
              id: 'q$i',
              type: PracticeItemType.fillInBlank,
              instruction: 'Question $i'),
      ],
    );
  }
}

void main() {
  Future<_Storage> pump(
    WidgetTester tester, {
    _Storage? storage,
    _Claude? claude,
    bool access = true,
    double width = 390,
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
  }) async {
    tester.view.physicalSize = Size(width, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = storage ?? _Storage();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      home: TopicPracticeScreen(
        claudeService: claude ?? _Claude(),
        storageService: store,
        analyticsService: AnalyticsService(),
        subscriptionService: _Subscription(access),
      ),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  final scrollable = find.byType(Scrollable).first;

  testWidgets(
      'the header: back, "Premium access", the title (32 / 900 / 1.10 / -1.0 '
      'at Medium) and its line', (tester) async {
    await pump(tester);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Premium access'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Topic Practice'));
    expect(title.style!.fontSize, 32);
    expect(title.style!.fontWeight, FontWeight.w900);
    expect(title.style!.height, 1.10);
    expect(title.style!.letterSpacing, -1.0);
    expect(find.text('Choose a topic to work on.'), findsOneWidget);
    // No app bar title: the title is in the page.
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
        findsNothing);
  });

  testWidgets('every topic of kTopics is listed, in order, with the real count',
      (tester) async {
    await pump(tester, textSize: AppTextSize.small);
    expect(find.widgetWithText(SectionTitle, 'Grammar topics'), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(TopicPracticeScreen.topicCountKey)).data,
        '${kTopics.length} topics');
    // Tall enough for the whole list at once, so the cards' places compare
    // in one frame.
    tester.view.physicalSize = const Size(390, 2400) * 3;
    await tester.pumpAndSettle();
    double? last;
    for (final topic in kTopics) {
      final card = find.byKey(TopicPracticeScreen.cardKey(topic));
      expect(find.descendant(of: card, matching: find.text(topic.title)),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(topic.description)),
          findsOneWidget);
      final top = tester.getTopLeft(card).dy;
      if (last != null) expect(top, greaterThan(last));
      last = top;
    }
  });

  testWidgets(
      'the status line: "Not started yet" without history, otherwise '
      'formatTopicStatsLine; no activity bar (Q8)', (tester) async {
    final first = kTopics.first, second = kTopics[1];
    await pump(tester,
        storage: _Storage({
          second.id.name: const TopicStats(practiced: 12, weakSpotCount: 2),
        }));
    String status(Topic t) =>
        tester.widget<Text>(find.byKey(TopicPracticeScreen.statusKey(t))).data!;
    expect(status(first), 'Not started yet');
    expect(status(second), formatTopicStatsLine(12, 2));
    expect(status(second), '12 practiced · 2 weak spots');
    // No bar, no score, no percentage.
    expect(find.bySemanticsLabel('Practice activity level'), findsNothing);
    for (final t in [first, second]) {
      final card = find.byKey(TopicPracticeScreen.cardKey(t));
      expect(
          find.descendant(
              of: card, matching: find.byType(FractionallySizedBox)),
          findsNothing);
      expect(
          find.descendant(
              of: card, matching: find.byType(LinearProgressIndicator)),
          findsNothing);
      expect(find.descendant(of: card, matching: find.textContaining('%')),
          findsNothing);
    }
  });

  testWidgets('each topic is one tap target', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    final card = find.byKey(TopicPracticeScreen.cardKey(kTopics.first));
    expect(find.descendant(of: card, matching: find.byType(InkWell)),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.byType(ButtonStyleButton)),
        findsNothing);
    semantics.dispose();
  });

  testWidgets(
      'a tap starts the existing launch: the length picker for full access',
      (tester) async {
    final claude = _Claude();
    await pump(tester, claude: claude);
    await tester.tap(find.byKey(TopicPracticeScreen.cardKey(kTopics.first)));
    await tester.pumpAndSettle();
    expect(find.text('How many questions?'), findsOneWidget);
    expect(claude.calls, 0, reason: 'nothing is generated before a choice');
  });

  testWidgets(
      'no paywall and no lock on this screen; "Premium access" is not a '
      'control', (tester) async {
    await pump(tester);
    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.byType(LockedPremiumPill), findsNothing);
    for (final icon in [
      Icons.lock,
      Icons.lock_outline,
      Icons.lock_rounded,
      Icons.lock_outline_rounded
    ]) {
      expect(find.byIcon(icon), findsNothing);
    }
    final label = find.byKey(TopicPracticeScreen.accessLabelKey);
    for (final type in [InkWell, GestureDetector, ButtonStyleButton]) {
      expect(
          find.ancestor(of: label, matching: find.byType(type)), findsNothing,
          reason: '$type');
      expect(
          find.descendant(of: label, matching: find.byType(type)), findsNothing,
          reason: '$type');
    }
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.byType(TopicPracticeScreen), findsOneWidget);
    expect(find.byType(PremiumScreen), findsNothing);
  });

  testWidgets('coming back from a practice set reads the stats again',
      (tester) async {
    final claude = _Claude();
    final storage = await pump(tester, claude: claude, access: false);
    expect(storage.statsReads, 1);
    expect(
        tester
            .widget<Text>(
                find.byKey(TopicPracticeScreen.statusKey(kTopics.first)))
            .data,
        'Not started yet');
    storage.stats = {
      kTopics.first.id.name: const TopicStats(practiced: 5, weakSpotCount: 1),
    };

    // Free tier: no picker, straight to the session.
    await tester.tap(find.byKey(TopicPracticeScreen.cardKey(kTopics.first)));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(claude.calls, 1);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(storage.statsReads, 2);
    expect(
        tester
            .widget<Text>(
                find.byKey(TopicPracticeScreen.statusKey(kTopics.first)))
            .data,
        '5 practiced · 1 weak spot');
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final b in Brightness.values) {
      testWidgets(
          '${width.toInt()} pt, Large text, ${b.name}: no overflow, long text '
          'wraps (no ellipsis)', (tester) async {
        await pump(tester,
            width: width,
            brightness: b,
            textSize: AppTextSize.large,
            storage: _Storage({
              for (final t in kTopics)
                t.id.name: const TopicStats(practiced: 128, weakSpotCount: 14),
            }));
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 12; i++) {
          for (final e in find.byType(Text).evaluate()) {
            final text = e.widget as Text;
            expect(text.overflow, isNot(TextOverflow.ellipsis),
                reason: text.data);
            expect(tester.getRect(find.byWidget(text)).right,
                lessThanOrEqualTo(width + .01),
                reason: text.data);
          }
          await tester.drag(scrollable, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.byKey(TopicPracticeScreen.cardKey(kTopics.last)),
            findsOneWidget,
            reason: 'reached the end');
      });
    }
  }
}
