import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/screens/data_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/widgets/page_header.dart';

import 'support/recording_analytics_sink.dart';

/// Profile → Data after the 1.2.0 final screens (brief §3).
class _Storage extends StorageService {
  AiConsent? consent;
  bool failWrite = false;
  bool failReset = false;
  Completer<void>? pendingReset;
  int resets = 0;

  @override
  Future<AiConsent?> getAiConsent() async => consent;

  @override
  Future<void> setAiConsent(
      {required bool granted, DateTime? decidedAt}) async {
    if (failWrite) throw StateError('write failed');
    consent = AiConsent(
        granted: granted,
        decidedAt: DateTime(2026, 1, 1),
        version: AiConsent.currentVersion);
  }

  @override
  Future<void> resetProgressData() async {
    if (pendingReset != null) await pendingReset!.future;
    if (failReset) throw StateError('disk full');
    resets++;
  }
}

AiConsent _grant() => AiConsent(
    granted: true,
    decidedAt: DateTime(2026, 1, 1),
    version: AiConsent.currentVersion);

void main() {
  tearDown(AppMessenger.clear);

  Future<RecordingAnalyticsSink> pump(WidgetTester tester, _Storage storage,
      {Size size = const Size(390, 844),
      AppTextSize textSize = AppTextSize.medium,
      Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sink = RecordingAnalyticsSink();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      scaffoldMessengerKey: AppMessenger.key,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DataScreen(
                    storageService: storage,
                    analyticsService: AnalyticsService(sink: sink)),
              )),
              child: const Text('open data'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open data'));
    await tester.pumpAndSettle();
    return sink;
  }

  bool switchOn(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  Future<void> openReset(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(DataScreen.resetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DataScreen.resetKey));
    await tester.pumpAndSettle();
  }

  Finder confirm() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Reset progress data'));

  testWidgets(
      'the header (back, "Data", its line) and two theme cards; the '
      'permission\'s wording names practice sessions', (tester) async {
    await pump(tester, _Storage()..consent = _grant());
    expect(find.byType(PageBackButton), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Your practice. Your choices.'), findsOneWidget);
    for (final key in [DataScreen.aiCardKey, DataScreen.resetCardKey]) {
      expect(find.descendant(of: find.byKey(key), matching: find.byType(Card)),
          findsOneWidget);
    }
    expect(
        find.textContaining('Practice sessions send your', findRichText: true),
        findsOneWidget);
    expect(find.text('On · Required for practice sessions'), findsOneWidget);
    expect(switchOn(tester), isTrue);
  });

  testWidgets('the back button returns to the page that opened Data',
      (tester) async {
    await pump(tester, _Storage());
    await tester.tap(find.byType(PageBackButton));
    await tester.pumpAndSettle();
    expect(find.text('open data'), findsOneWidget);
  });

  testWidgets(
      'switching on: a yes that could not be saved shows off, with a '
      'message (the consent flow itself is unchanged)', (tester) async {
    final storage = _Storage()..failWrite = true;
    final sink = await pump(tester, storage);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.byType(AiConsentScreen), findsOneWidget);
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expect(switchOn(tester), isFalse);
    expect(
        find.text('Off · Practice sessions need permission'), findsOneWidget);
    expect(find.textContaining('Could not save this setting'), findsOneWidget);
    // The existing event is still sent once, as before.
    expect(sink.named('ai_consent_result'), hasLength(1));
  });

  testWidgets('switching on and saving shows on', (tester) async {
    final storage = _Storage();
    await pump(tester, storage);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expect(switchOn(tester), isTrue);
    expect(storage.consent!.allowsSending, isTrue);
  });

  testWidgets('a tap outside the dialog and the back gesture delete nothing',
      (tester) async {
    final storage = _Storage();
    await pump(tester, storage);
    await openReset(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await openReset(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(storage.resets, 0);
  });

  testWidgets('a double tap opens one dialog; a double confirm resets once',
      (tester) async {
    final storage = _Storage()..pendingReset = Completer<void>();
    await pump(tester, storage);
    await tester.ensureVisible(find.byKey(DataScreen.resetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DataScreen.resetKey));
    await tester.tap(find.byKey(DataScreen.resetKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(confirm());
    await tester.tap(confirm(), warnIfMissed: false);
    await tester.pumpAndSettle();
    // While it runs, the page's button is disabled.
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(DataScreen.resetKey))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(DataScreen.resetKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    storage.pendingReset!.complete();
    await tester.pumpAndSettle();
    expect(storage.resets, 1);
    expect(find.text('Progress reset.'), findsOneWidget);
  });

  testWidgets('a failed reset says so and never says it worked',
      (tester) async {
    final storage = _Storage()..failReset = true;
    await pump(tester, storage);
    await openReset(tester);
    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(find.text('Progress reset.'), findsNothing);
    expect(find.textContaining('Could not reset progress'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(DataScreen.resetKey))
            .onPressed,
        isNotNull);
  });

  for (final width in const [320.0, 360.0, 390.0, 430.0]) {
    for (final size in AppTextSize.values) {
      for (final brightness in Brightness.values) {
        testWidgets(
            '${width.toInt()} pt, ${size.name}, ${brightness.name}: no '
            'overflow, the dialog included', (tester) async {
          await pump(tester, _Storage(),
              size: Size(width, 844), textSize: size, brightness: brightness);
          expect(tester.takeException(), isNull);
          await openReset(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
