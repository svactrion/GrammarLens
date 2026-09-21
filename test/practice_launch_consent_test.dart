import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';

import 'support/recording_analytics_sink.dart';

/// `launchPracticeSet` is the one function every Topic Practice generation
/// goes through, so the permission to send answers to the AI provider is
/// proved here from BOTH of its callers against the same fakes, and against
/// the things a refusal must not touch (generation, the session count, the
/// free tier's daily practice).

class _Subscription extends SubscriptionService {
  final bool hasAccess;
  _Subscription({required this.hasAccess});

  @override
  Future<bool> get hasFullAccess async => hasAccess;
}

class _Storage extends StorageService {
  AiConsent? consent;
  bool failConsentRead = false;
  bool failConsentWrite = false;
  int consentReads = 0;
  int sessionCount = 0;
  int freePracticeCount = 0;
  int pickerLengthWrites = 0;

  _Storage({this.consent});

  @override
  Future<AiConsent?> getAiConsent() async {
    consentReads++;
    if (failConsentRead) throw StateError('read failed');
    return consent;
  }

  @override
  Future<void> setAiConsent(
      {required bool granted, DateTime? decidedAt}) async {
    if (failConsentWrite) throw StateError('write failed');
    consent = AiConsent(
      granted: granted,
      decidedAt: decidedAt ?? DateTime(2026, 1, 1),
      version: AiConsent.currentVersion,
    );
  }

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};

  @override
  Future<int> getSessionCountForToday() async => sessionCount;

  @override
  Future<void> recordSessionStarted() async => sessionCount++;

  @override
  Future<int> getFreePracticeCountForToday() async => freePracticeCount;

  @override
  Future<void> recordFreePracticeStarted() async => freePracticeCount++;

  @override
  Future<PracticeLength> getPracticeLength() async => PracticeLength.standard;

  @override
  Future<void> setPracticeLength(PracticeLength length) async =>
      pickerLengthWrites++;

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<List<ErrorEntry>> getRecentMistakes(
    String topicId,
    String errorType, {
    int limit = 3,
  }) async =>
      const [];
}

class _Claude extends ClaudeService {
  int generateCalls = 0;

  @override
  Future<PracticeSet> generatePracticeSet(
    Topic topic, {
    required String deviceId,
    int count = 5,
  }) async {
    generateCalls++;
    return PracticeSet(
      topicId: topic.id.name,
      items: List.generate(
        count,
        (i) => PracticeItem(
          id: 'q$i',
          type: PracticeItemType.fillInBlank,
          instruction: 'Question $i',
        ),
      ),
    );
  }
}

AiConsent _grant({int version = AiConsent.currentVersion}) => AiConsent(
      granted: true,
      decidedAt: DateTime(2026, 1, 1),
      version: version,
    );

WeakSpot _weakSpot() => WeakSpot(
      topicId: kTopics.first.id.name,
      errorType: 'missing_article',
      frequency: 3,
      lastSeen: DateTime.now(),
    );

void main() {
  tearDown(resetAiConsentPromptGuard);

  /// Both real callers of `launchPracticeSet`, each started the way a user
  /// would: tap the first topic card, tap "Practice this".
  final callers = <String,
      ({
    Widget Function(_Claude, _Storage, bool premium) screen,
    Future<void> Function(WidgetTester) start,
  })>{
    'TopicPracticeScreen': (
      screen: (claude, storage, premium) => TopicPracticeScreen(
            claudeService: claude,
            storageService: storage,
            analyticsService: AnalyticsService(),
            subscriptionService: _Subscription(hasAccess: premium),
          ),
      start: (tester) async => tester.tap(find.byType(InkWell).first),
    ),
    'WeakSpotDetailScreen': (
      screen: (claude, storage, premium) => WeakSpotDetailScreen(
            topic: kTopics.first,
            spot: _weakSpot(),
            claudeService: claude,
            storageService: storage,
            analyticsService: AnalyticsService(),
            subscriptionService: _Subscription(hasAccess: premium),
          ),
      start: (tester) async =>
          tester.tap(find.widgetWithText(FilledButton, 'Practice this')),
    ),
  };

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: screen,
    ));
    await tester.pumpAndSettle();
  }

  for (final entry in callers.entries) {
    final caller = entry.value;

    group('via ${entry.key}', () {
      testWidgets(
          'never asked before: the permission screen comes first, and '
          'nothing is generated or counted while it is open', (tester) async {
        final storage = _Storage();
        final claude = _Claude();
        await pump(tester, caller.screen(claude, storage, false));

        await caller.start(tester);
        await tester.pumpAndSettle();

        expect(find.byType(AiConsentScreen), findsOneWidget);
        expect(claude.generateCalls, 0);
        expect(storage.sessionCount, 0);
        expect(find.byType(PracticeScreen), findsNothing);
      });

      testWidgets(
          '"Agree and continue" stores the yes and starts the session (free '
          'tier: no picker, quota counted only now)', (tester) async {
        final storage = _Storage();
        final claude = _Claude();
        await pump(tester, caller.screen(claude, storage, false));

        await caller.start(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agree and continue'));
        await tester.pumpAndSettle();

        expect(storage.consent!.allowsSending, isTrue);
        expect(claude.generateCalls, 1);
        expect(find.byType(PracticeScreen), findsOneWidget);
        expect(storage.sessionCount, 1);
        expect(storage.freePracticeCount, 1);
      });

      testWidgets(
          '"Not now" generates nothing, records no session and spends none '
          'of the free practice, and the screen returns on the next attempt',
          (tester) async {
        final storage = _Storage();
        final claude = _Claude();
        await pump(tester, caller.screen(claude, storage, false));

        await caller.start(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();

        expect(find.byType(AiConsentScreen), findsNothing);
        expect(claude.generateCalls, 0);
        expect(storage.sessionCount, 0);
        expect(storage.freePracticeCount, 0);
        expect(storage.consent!.granted, isFalse);

        await caller.start(tester);
        await tester.pumpAndSettle();
        expect(find.byType(AiConsentScreen), findsOneWidget);
        expect(claude.generateCalls, 0);
      });

      testWidgets('the back arrow is a decline, not a yes', (tester) async {
        final storage = _Storage();
        final claude = _Claude();
        await pump(tester, caller.screen(claude, storage, false));

        await caller.start(tester);
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(AiConsentScreen), findsNothing);
        expect(claude.generateCalls, 0);
        expect(storage.consent!.allowsSending, isFalse);
      });

      testWidgets('an existing yes skips the screen entirely', (tester) async {
        final storage = _Storage(consent: _grant());
        final claude = _Claude();
        await pump(tester, caller.screen(claude, storage, false));

        await caller.start(tester);
        await tester.pumpAndSettle();

        expect(find.byType(AiConsentScreen), findsNothing);
        expect(claude.generateCalls, 1);
      });

      testWidgets('a yes given for an older version asks again',
          (tester) async {
        final storage = _Storage(consent: _grant(version: 0));
        final claude = _Claude();
        await pump(tester, caller.screen(claude, storage, false));

        await caller.start(tester);
        await tester.pumpAndSettle();

        expect(find.byType(AiConsentScreen), findsOneWidget);
        expect(claude.generateCalls, 0);
      });

      testWidgets(
          'fails closed: if the stored decision cannot be read, the user is '
          'asked rather than assumed to have agreed', (tester) async {
        final storage = _Storage(consent: _grant())..failConsentRead = true;
        final claude = _Claude();
        await pump(tester, caller.screen(claude, storage, false));

        await caller.start(tester);
        await tester.pumpAndSettle();

        expect(find.byType(AiConsentScreen), findsOneWidget);
        expect(claude.generateCalls, 0);
      });

      testWidgets(
          'if saving the yes fails, this session still starts (they did '
          'agree) and the next attempt asks again', (tester) async {
        final storage = _Storage()..failConsentWrite = true;
        final claude = _Claude();
        await pump(tester, caller.screen(claude, storage, false));

        await caller.start(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agree and continue'));
        await tester.pumpAndSettle();

        expect(claude.generateCalls, 1);
        expect(storage.consent, isNull);
      });
    });
  }

  testWidgets(
      'full access: the permission screen comes before the length picker, '
      'so a "Not now" never asks how many questions', (tester) async {
    final storage = _Storage();
    final claude = _Claude();
    await pump(
        tester, callers['TopicPracticeScreen']!.screen(claude, storage, true));

    await callers['TopicPracticeScreen']!.start(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AiConsentScreen), findsOneWidget);
    expect(find.text('How many questions?'), findsNothing);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('How many questions?'), findsNothing);
    expect(storage.pickerLengthWrites, 0);
    expect(claude.generateCalls, 0);

    await callers['TopicPracticeScreen']!.start(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expect(find.text('How many questions?'), findsOneWidget);
  });

  _analyticsTests();

  testWidgets(
      'a second tap while the permission check is in progress does not stack '
      'a second screen or start a second launch', (tester) async {
    final gate = Completer<AiConsent?>();
    final storage = _GatedStorage(gate);
    final claude = _Claude();
    await pump(
        tester, callers['TopicPracticeScreen']!.screen(claude, storage, false));

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();
    await tester.tap(find.byType(InkWell).first);
    await tester.pump();
    gate.complete(null);
    await tester.pumpAndSettle();

    expect(find.byType(AiConsentScreen), findsOneWidget);
    expect(storage.consentReads, 1);

    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expect(claude.generateCalls, 1);
    expect(storage.sessionCount, 1);
  });
}

/// Everything here reports outcome and place only, never anything written.
void _analyticsTests() {
  for (final decision in ['Agree and continue', 'Not now']) {
    testWidgets('reports "$decision" once, from practice_launch',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      tester.view.physicalSize = const Size(390, 844) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: TopicPracticeScreen(
          claudeService: _Claude(),
          storageService: _Storage(),
          analyticsService: AnalyticsService(sink: sink),
          subscriptionService: _Subscription(hasAccess: false),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(sink.named('ai_consent_result'), isEmpty,
          reason: 'nothing is reported until the user decides');
      await tester.tap(find.text(decision));
      await tester.pumpAndSettle();

      expect(sink.named('ai_consent_result').single.parameters, {
        'outcome': decision == 'Not now' ? 'declined' : 'granted',
        'source': 'practice_launch',
        'consent_version': AiConsent.currentVersion,
      });
    });
  }

  testWidgets('an existing grant reports nothing', (tester) async {
    final sink = RecordingAnalyticsSink();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: TopicPracticeScreen(
        claudeService: _Claude(),
        storageService: _Storage(consent: _grant()),
        analyticsService: AnalyticsService(sink: sink),
        subscriptionService: _Subscription(hasAccess: false),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(sink.named('ai_consent_result'), isEmpty);
  });
}

/// Holds the permission read open so a test can tap again mid-check.
class _GatedStorage extends _Storage {
  final Completer<AiConsent?> gate;
  _GatedStorage(this.gate);

  @override
  Future<AiConsent?> getAiConsent() {
    consentReads++;
    return gate.future;
  }
}
