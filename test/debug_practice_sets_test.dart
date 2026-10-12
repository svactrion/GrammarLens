import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/screens/debug_panel_screen.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/blanks.dart';
import 'package:grammar_lens/utils/debug_practice_sets.dart';
import 'package:grammar_lens/widgets/question_view.dart';

/// The Debug panel's multi-blank practice sets (question screen B3, device
/// check): what they cover, and how the panel opens them.

class _Storage extends StorageService {
  final AiConsent? consent;
  _Storage(this.consent);

  @override
  Future<AiConsent?> getAiConsent() async => consent;
}

Future<void> _pumpPanel(WidgetTester tester, {AiConsent? consent}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(Brightness.light),
    home: DebugPanelScreen(
      onResetLocalData: () async {},
      storageService: _Storage(consent),
      analyticsService: AnalyticsService(),
      subscriptionService: SubscriptionService(),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(find.byKey(key), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

final _granted = AiConsent(
    granted: true,
    decidedAt: DateTime(2026, 10, 12),
    version: AiConsent.currentVersion);

void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  group('the sets', () {
    test('articles: 2, 3 and 4 blanks, all multi-blank boxes', () {
      final counts = [
        for (final item in DebugPracticeSets.articles.items)
          AnswerDrafts.boxCountFor(item),
      ];
      expect(counts, [2, 3, 4]);
      expect(DebugPracticeSets.topicOf(DebugPracticeSets.articles),
          TopicId.articles);
    });

    test('articles: a blank that starts a sentence and one mid-sentence', () {
      final texts = [
        for (final item in DebugPracticeSets.articles.items) item.context!,
      ];
      expect(texts.where((t) => t.startsWith('____')), isNotEmpty);
      expect(
          texts.any((t) => blankPattern
              .allMatches(t)
              .any((m) => m.start > 0 && t[m.start - 1] == ' ')),
          isTrue);
    });

    test('gerund vs. infinitive: multi-blank, not articles', () {
      expect(DebugPracticeSets.topicOf(DebugPracticeSets.gerundVsInfinitive),
          isNot(TopicId.articles));
      for (final item in DebugPracticeSets.gerundVsInfinitive.items) {
        expect(item.type, PracticeItemType.fillInBlank);
        expect(AnswerDrafts.boxCountFor(item), greaterThan(1));
      }
    });

    test('ids are unique and marked debug', () {
      final ids = [
        for (final set in [
          DebugPracticeSets.articles,
          DebugPracticeSets.gerundVsInfinitive
        ])
          for (final item in set.items) item.id,
      ];
      expect(ids.toSet().length, ids.length);
      expect(ids.every((id) => id.startsWith('debug_')), isTrue);
    });
  });

  group('the panel', () {
    testWidgets('without services, no multi-blank section', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DebugPanelScreen(onResetLocalData: () async {}),
      ));
      await tester.pumpAndSettle();
      expect(
          find.byKey(DebugPanelScreen.multiBlankArticlesKey,
              skipOffstage: false),
          findsNothing);
    });

    testWidgets('articles: opens Practice with its boxes and the "—" button',
        (tester) async {
      await _pumpPanel(tester, consent: _granted);
      await _open(tester, DebugPanelScreen.multiBlankArticlesKey);
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(find.byKey(QuestionView.blankBoxKey(1)), findsOneWidget);
      expect(find.byKey(QuestionView.noArticleKey(0)), findsOneWidget);
    });

    testWidgets('gerund vs. infinitive: boxes, no "—" button', (tester) async {
      await _pumpPanel(tester, consent: _granted);
      await _open(tester, DebugPanelScreen.multiBlankGerundKey);
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(find.byKey(QuestionView.blankBoxKey(1)), findsOneWidget);
      expect(find.byKey(QuestionView.noArticleKey(0)), findsNothing);
    });

    testWidgets('no AI consent yet: asks first, as a real session does',
        (tester) async {
      await _pumpPanel(tester);
      await _open(tester, DebugPanelScreen.multiBlankArticlesKey);
      expect(find.byType(AiConsentScreen), findsOneWidget);
      expect(find.byType(PracticeScreen), findsNothing);
    });
  });
}
