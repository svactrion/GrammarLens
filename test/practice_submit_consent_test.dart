import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/item_feedback.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/scoring_result.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/practice_launch.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/screens/results_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/widgets/practice_step_footer.dart';
import 'package:grammar_lens/widgets/question_view.dart';
import 'package:grammar_lens/utils/blank_assembly.dart';

/// App Review audit findings #6 and #7. Submit reads the AI permission
/// again before the answers leave the device, so a permission withdrawn
/// during a session sends nothing; and a failed practice request shows a
/// message for the user, never a Dart class name.

class _Claude extends ClaudeService {
  int scoreCalls = 0;
  Object? scoreError;
  Object? generateError;

  @override
  Future<ScoringResult> scoreAnswers({
    required String deviceId,
    required PracticeSet practiceSet,
    required Map<String, String> answers,
    Map<String, List<BlankAnswer>>? blankAnswers,
  }) async {
    scoreCalls++;
    if (scoreError != null) throw scoreError!;
    return ScoringResult(topicId: practiceSet.topicId, feedback: [
      for (final item in practiceSet.items)
        ItemFeedback(
          itemId: item.id,
          isCorrect: true,
          isSkipped: false,
          errorType: 'none',
          correctedAnswer: 'x',
          explanation: 'x',
        ),
    ]);
  }

  @override
  Future<PracticeSet> generatePracticeSet(
    Topic topic, {
    required String deviceId,
    int count = 5,
  }) async {
    throw generateError!;
  }
}

class _Storage extends StorageService {
  AiConsent? consent = _granted;
  bool failConsentRead = false;
  int consentReads = 0;

  @override
  Future<AiConsent?> getAiConsent() async {
    consentReads++;
    if (failConsentRead) throw StateError('read failed');
    return consent;
  }

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<int> getSessionCountForToday() async => 0;

  @override
  Future<int> getFreePracticeCountForToday() async => 0;
}

class _Subscription extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => false;
}

final _granted = AiConsent(
  granted: true,
  decidedAt: DateTime(2026, 1, 1),
  version: AiConsent.currentVersion,
);

final _withdrawn = AiConsent(
  granted: false,
  decidedAt: DateTime(2026, 1, 2),
  version: AiConsent.currentVersion,
);

const _item = PracticeItem(
  id: 'one',
  type: PracticeItemType.sentenceWriting,
  instruction: 'Write a sentence with "enjoy".',
);

Finder get _field => find.byKey(QuestionView.answerFieldKey);
Finder get _primary => find.byKey(PracticeStepFooter.primaryKey);

Future<void> _pumpPractice(
    WidgetTester tester, _Claude claude, _Storage storage) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(Brightness.light),
    scaffoldMessengerKey: AppMessenger.key,
    navigatorObservers: [AppMessenger.navigatorObserver],
    home: PracticeScreen(
      topic: kTopics.first,
      practiceSet: PracticeSet(topicId: kTopics.first.id.name, items: [_item]),
      claudeService: claude,
      storageService: storage,
      analyticsService: AnalyticsService(),
      subscriptionService: SubscriptionService(),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _answerAndSubmit(WidgetTester tester) async {
  await tester.enterText(_field, 'I enjoy swimming.');
  await tester.pump();
  await tester.tap(_primary);
  await tester.pumpAndSettle();
}

String _shownMessage(WidgetTester tester) {
  final bar = tester.widget<SnackBar>(find.byType(SnackBar));
  return (bar.content as Text).data!;
}

void main() {
  tearDown(() => AppMessenger.clear());

  group('Submit reads the AI permission again (audit #6)', () {
    testWidgets(
        'a permission withdrawn during the session sends nothing and says so',
        (tester) async {
      final claude = _Claude();
      final storage = _Storage();
      await _pumpPractice(tester, claude, storage);

      storage.consent = _withdrawn;
      await _answerAndSubmit(tester);

      expect(claude.scoreCalls, 0);
      expect(storage.consentReads, 1);
      expect(_shownMessage(tester), PracticeScreen.notSentMessage);
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(find.byType(ResultsScreen), findsNothing);
      expect(tester.widget<TextField>(_field).controller!.text,
          'I enjoy swimming.');
    });

    testWidgets('no permission on record sends nothing', (tester) async {
      final claude = _Claude();
      final storage = _Storage()..consent = null;
      await _pumpPractice(tester, claude, storage);

      await _answerAndSubmit(tester);

      expect(claude.scoreCalls, 0);
      expect(_shownMessage(tester), PracticeScreen.notSentMessage);
    });

    testWidgets('an unreadable permission fails closed', (tester) async {
      final claude = _Claude();
      final storage = _Storage()..failConsentRead = true;
      await _pumpPractice(tester, claude, storage);

      await _answerAndSubmit(tester);

      expect(claude.scoreCalls, 0);
      expect(_shownMessage(tester), PracticeScreen.notSentMessage);
    });

    testWidgets('a permission still granted scores the answers',
        (tester) async {
      final claude = _Claude();
      final storage = _Storage();
      await _pumpPractice(tester, claude, storage);

      await _answerAndSubmit(tester);

      expect(claude.scoreCalls, 1);
      expect(find.byType(ResultsScreen), findsOneWidget);
    });
  });

  group('failed requests show a message for the user (audit #7)', () {
    testWidgets('scoring: the exception message, without the class name',
        (tester) async {
      final claude = _Claude()
        ..scoreError = const ClaudeApiException(
          "Couldn't reach the practice service. Check your connection and "
          'try again.',
          kind: ClaudeApiErrorKind.network,
        );
      await _pumpPractice(tester, claude, _Storage());

      await _answerAndSubmit(tester);

      expect(
        _shownMessage(tester),
        "Could not score answers: Couldn't reach the practice service. "
        'Check your connection and try again.',
      );
    });

    testWidgets('scoring: any other error shows the general line',
        (tester) async {
      final claude = _Claude()..scoreError = Exception('socket closed');
      await _pumpPractice(tester, claude, _Storage());

      await _answerAndSubmit(tester);

      final message = _shownMessage(tester);
      expect(message,
          'Could not score answers: Something went wrong. Please try again.');
      expect(message, isNot(contains('Exception')));
    });

    testWidgets('generation: the exception message, without the class name',
        (tester) async {
      final claude = _Claude()
        ..generateError = const ClaudeApiException(
          'The practice service took too long to respond. Please try again.',
          kind: ClaudeApiErrorKind.network,
        );
      final storage = _Storage();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        scaffoldMessengerKey: AppMessenger.key,
        navigatorObservers: [AppMessenger.navigatorObserver],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => launchPracticeSet(
                context: context,
                topic: kTopics.first,
                claudeService: claude,
                storageService: storage,
                analyticsService: AnalyticsService(),
                subscriptionService: _Subscription(),
                setGenerating: (_) {},
                errorPrefix: 'Could not generate review set',
              ),
              child: const Text('Practice this'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Practice this'));
      await tester.pumpAndSettle();

      final message = _shownMessage(tester);
      expect(
        message,
        'Could not generate review set: The practice service took too long '
        'to respond. Please try again.',
      );
      expect(message, isNot(contains('ClaudeApiException')));
    });
  });
}
