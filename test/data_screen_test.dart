import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/utils/haptics.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';

import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/screens/data_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';

import 'support/recording_analytics_sink.dart';

/// Counts resets instead of touching sqflite (no platform channel in tests).
class _FakeStorageService extends StorageService {
  int resets = 0;
  bool throwOnReset = false;
  AiConsent? consent;
  bool failConsentRead = false;
  bool failConsentWrite = false;

  @override
  Future<AiConsent?> getAiConsent() async {
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
  Future<void> resetProgressData() async {
    if (throwOnReset) throw Exception('simulated storage failure');
    resets++;
  }
}

/// Opens the confirmation from the page's reset button.
Future<void> openReset(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(DataScreen.resetKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(DataScreen.resetKey));
  await tester.pumpAndSettle();
}

/// R08: the companion dialog's own "Reset progress data" (the page's button
/// has the same label).
Finder confirmReset() => find.byKey(DataScreen.resetConfirmKey);

void main() {
  Future<void> pumpData(
    WidgetTester tester,
    StorageService storage, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness),
        home: DataScreen(storageService: storage),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the reset explanation and the reset button',
      (tester) async {
    await pumpData(tester, _FakeStorageService());

    expect(find.text('Data'), findsOneWidget); // page title
    expect(find.text('Reset progress'), findsOneWidget);
    expect(find.text('Clear your practice history and saved weak spots.'),
        findsOneWidget);
    expect(find.text('Your name, goal and theme stay as they are.'),
        findsOneWidget);
    expect(find.byKey(DataScreen.resetKey), findsOneWidget);
  });

  testWidgets('asks for confirmation and Cancel resets nothing',
      (tester) async {
    final storage = _FakeStorageService();
    await pumpData(tester, storage);

    await openReset(tester);
    expect(find.text('Reset your progress?'), findsOneWidget);
    // R08: the companion dialog's body holds both sentences.
    expect(
        find.textContaining(
            'This clears your practice history and saved weak spots.'),
        findsOneWidget);
    expect(
        find.textContaining('Your name, goal and theme will stay as they are.'),
        findsOneWidget);

    await tester.tap(find.text('Keep my progress'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your progress?'), findsNothing);
    expect(storage.resets, 0);
  });

  testWidgets('confirming Reset clears the progress data once', (tester) async {
    final storage = _FakeStorageService();
    await pumpData(tester, storage);

    await openReset(tester);
    await tester.tap(confirmReset());
    await tester.pumpAndSettle();

    expect(find.text('Reset your progress?'), findsNothing);
    expect(storage.resets, 1);
  });

  for (final brightness in Brightness.values) {
    group('destructive colors ($brightness)', () {
      Color? fill(ButtonStyleButton b) =>
          b.style?.backgroundColor?.resolve(const {});
      Color? label(ButtonStyleButton b) =>
          b.style?.foregroundColor?.resolve(const {});
      Color? border(ButtonStyleButton b) =>
          b.style?.side?.resolve(const {})?.color;

      testWidgets(
          'the page\'s Reset progress data button is low-intensity: an '
          'error tint, an error edge and an error label (brief §3)',
          (tester) async {
        await pumpData(tester, _FakeStorageService(), brightness: brightness);
        final scheme = buildAppTheme(brightness).colorScheme;

        final button =
            tester.widget<OutlinedButton>(find.byKey(DataScreen.resetKey));
        final card = scheme.surfaceContainerHigh;
        expect(label(button), scheme.error);
        expect(fill(button),
            Color.alphaBlend(scheme.error.withValues(alpha: 0.08), card));
        expect(border(button),
            Color.alphaBlend(scheme.error.withValues(alpha: 0.40), card));
      });

      testWidgets(
          'R08: the companion asks (a heavy haptic); keeping is the primary '
          'button, the reset the quiet one under it', (tester) async {
        await pumpData(tester, _FakeStorageService(), brightness: brightness);
        HapticMap.log = [];
        await openReset(tester);
        expect(HapticMap.log, contains('heavy'));
        final keep =
            tester.widget<PressableButton>(find.byKey(DataScreen.keepKey));
        expect(keep.label, 'Keep my progress');
        expect(keep.tone, ButtonTone.navy);
        expect(tester.getRect(find.byKey(DataScreen.keepKey)).bottom,
            lessThanOrEqualTo(tester.getRect(confirmReset()).top));
      });
    });
  }

  group('AI feedback permission', () {
    late RecordingAnalyticsSink sink;

    setUp(() => sink = RecordingAnalyticsSink());

    AiConsent grant() => AiConsent(
          granted: true,
          decidedAt: DateTime(2026, 1, 1),
          version: AiConsent.currentVersion,
        );

    Future<void> pumpWithAnalytics(
      WidgetTester tester,
      StorageService storage, {
      Size size = const Size(390, 844),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        scaffoldMessengerKey: AppMessenger.key,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: DataScreen(
          storageService: storage,
          analyticsService: AnalyticsService(sink: sink),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Finder switchTile() => find.byType(SwitchListTile);
    bool switchOn(WidgetTester tester) =>
        tester.widget<SwitchListTile>(switchTile()).value;

    testWidgets('sits above Reset and says what it controls', (tester) async {
      await pumpWithAnalytics(tester, _FakeStorageService());

      expect(find.text('AI feedback'), findsOneWidget);
      expect(find.text('Allow AI feedback'), findsOneWidget);
      expect(
          find.text('Off · Practice sessions need permission'), findsOneWidget);
      expect(find.text('Daily Test works without this permission.'),
          findsOneWidget);
      expect(tester.getTopLeft(find.text('AI feedback')).dy,
          lessThan(tester.getTopLeft(find.text('Reset progress')).dy));
      expect(tester.getBottomLeft(switchTile()).dy,
          lessThan(tester.getTopLeft(find.text('Reset progress')).dy));
    });

    testWidgets('never asked, the switch is off', (tester) async {
      await pumpWithAnalytics(tester, _FakeStorageService());
      expect(switchOn(tester), isFalse);
    });

    testWidgets('a declined decision shows off', (tester) async {
      await pumpWithAnalytics(
          tester,
          _FakeStorageService()
            ..consent = AiConsent(
              granted: false,
              decidedAt: DateTime(2026, 1, 1),
              version: AiConsent.currentVersion,
            ));
      expect(switchOn(tester), isFalse);
    });

    testWidgets('a current grant shows on', (tester) async {
      await pumpWithAnalytics(tester, _FakeStorageService()..consent = grant());
      expect(switchOn(tester), isTrue);
    });

    testWidgets('an unreadable decision shows off (fails closed)',
        (tester) async {
      await pumpWithAnalytics(
          tester,
          _FakeStorageService()
            ..consent = grant()
            ..failConsentRead = true);
      expect(switchOn(tester), isFalse);
    });

    testWidgets(
        'switching on shows the permission screen; Agree stores it, turns '
        'the switch on and reports granted from data_settings', (tester) async {
      final storage = _FakeStorageService();
      await pumpWithAnalytics(tester, storage);

      await tester.tap(switchTile());
      await tester.pumpAndSettle();
      expect(find.byType(AiConsentScreen), findsOneWidget);
      expect(storage.consent, isNull);

      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();

      expect(find.byType(AiConsentScreen), findsNothing);
      expect(storage.consent!.allowsSending, isTrue);
      expect(switchOn(tester), isTrue);
      expect(sink.named('ai_consent_result').single.parameters, {
        'outcome': 'granted',
        'source': 'data_settings',
        'consent_version': AiConsent.currentVersion,
      });
    });

    testWidgets(
        'declining from the permission screen leaves the switch off '
        'and reports declined', (tester) async {
      final storage = _FakeStorageService();
      await pumpWithAnalytics(tester, storage);

      await tester.tap(switchTile());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(switchOn(tester), isFalse);
      expect(storage.consent!.granted, isFalse);
      expect(sink.named('ai_consent_result').single.parameters!['outcome'],
          'declined');
    });

    testWidgets(
        'switching off takes effect at once with no screen, says practice '
        'sessions will ask again, and reports revoked', (tester) async {
      final storage = _FakeStorageService()..consent = grant();
      await pumpWithAnalytics(tester, storage);

      await tester.tap(switchTile());
      await tester.pumpAndSettle();

      expect(find.byType(AiConsentScreen), findsNothing);
      expect(switchOn(tester), isFalse);
      expect(storage.consent!.allowsSending, isFalse);
      expect(find.text('Practice sessions will ask again.'), findsOneWidget);
      expect(sink.named('ai_consent_result').single.parameters, {
        'outcome': 'revoked',
        'source': 'data_settings',
        'consent_version': AiConsent.currentVersion,
      });
    });

    testWidgets('a failed save on switch-off keeps it on and says so',
        (tester) async {
      final storage = _FakeStorageService()
        ..consent = grant()
        ..failConsentWrite = true;
      await pumpWithAnalytics(tester, storage);

      await tester.tap(switchTile());
      await tester.pumpAndSettle();

      expect(switchOn(tester), isTrue);
      expect(
          find.textContaining('Could not change this setting'), findsOneWidget);
      expect(sink.named('ai_consent_result'), isEmpty);
    });

    testWidgets('Reset progress leaves the permission alone', (tester) async {
      final storage = _FakeStorageService()..consent = grant();
      await pumpWithAnalytics(tester, storage);

      await openReset(tester);
      await tester.tap(confirmReset());
      await tester.pumpAndSettle();

      expect(storage.resets, 1);
      expect(storage.consent!.allowsSending, isTrue);
      expect(switchOn(tester), isTrue);
    });

    testWidgets('fits the smallest screen at large text with no overflow',
        (tester) async {
      await pumpWithAnalytics(tester, _FakeStorageService(),
          size: const Size(320, 568), textScale: 2);

      await tester.scrollUntilVisible(switchTile(), 100);
      expect(switchTile(), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Reset progress data'), 200);
      expect(find.text('Reset progress data'), findsOneWidget);
    });
  });
}
