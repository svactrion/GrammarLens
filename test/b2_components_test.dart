import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/utils/haptics.dart';
import 'package:grammar_lens/widgets/companion_dialog.dart';
import 'package:grammar_lens/widgets/error_state.dart';
import 'package:grammar_lens/widgets/score_capsule.dart';
import 'package:grammar_lens/widgets/step_bar.dart';

/// The shared components of SPEC §3.6 (B2).
void main() {
  setUp(() => HapticMap.log = []);

  group('CompanionDialog (R10)', () {
    Future<CompanionDialogResult?> open(WidgetTester tester) async {
      CompanionDialogResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCompanionDialog(
                  context: context,
                  hero: Avatar.fox,
                  title: 'Leave today’s test?',
                  body: 'Your answers so far won’t be saved.',
                  primaryLabel: 'Keep going',
                  secondaryLabel: 'Leave',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('opens with a warning, Keep going returns primary',
        (tester) async {
      await open(tester);
      expect(find.text('Leave today’s test?'), findsOneWidget);
      expect(HapticMap.log, ['warning']);
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(find.text('Leave today’s test?'), findsNothing);
    });

    testWidgets('Leave plays medium and returns secondary', (tester) async {
      CompanionDialogResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCompanionDialog(
                  context: context,
                  hero: Avatar.fox,
                  title: 'T',
                  body: 'B',
                  primaryLabel: 'Keep going',
                  secondaryLabel: 'Leave',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(result, CompanionDialogResult.secondary);
      expect(HapticMap.log, ['warning', 'medium']);
    });
  });

  group('ErrorState (R11)', () {
    testWidgets('warns once, retries with dots, light on success',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ErrorState(
              hero: Avatar.panda,
              onRetry: () async {
                calls++;
                await Future<void>.delayed(const Duration(milliseconds: 100));
                return true;
              },
            ),
          ),
        ),
      ));
      expect(find.text('Can’t reach the mountain right now'), findsOneWidget);
      expect(HapticMap.log, ['warning']);
      await tester.tap(find.byKey(ErrorState.retryKey));
      await tester.pump();
      expect(find.text('Try again'), findsNothing, reason: 'busy dots');
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, 1);
      expect(find.text('Try again'), findsOneWidget);
      expect(HapticMap.log, ['warning', 'medium', 'light']);
    });

    testWidgets('each kind has its own copy', (tester) async {
      for (final (kind, title) in [
        (ErrorKind.offline, 'Can’t reach the mountain right now'),
        (ErrorKind.server, 'Something went wrong on our side'),
        (ErrorKind.quota, 'That’s all for today'),
      ]) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
                child: ErrorState(hero: Avatar.fox, kind: kind)),
          ),
        ));
        expect(find.text(title), findsOneWidget);
      }
    });
  });

  group('StepBar', () {
    testWidgets('fills new segments one by one and reports each',
        (tester) async {
      final filled = <int>[];
      Widget bar(List<Color?> segments) => MaterialApp(
            home: Center(
              child: SizedBox(
                width: 140,
                child: StepBar(
                    segments: segments,
                    track: Colors.grey,
                    onFilled: filled.add),
              ),
            ),
          );
      await tester.pumpWidget(bar(const [null, null, null]));
      await tester.pumpWidget(bar(const [Colors.green, Colors.orange, null]));
      await tester.pump(const Duration(milliseconds: 300));
      expect(filled, [0]);
      await tester.pumpAndSettle();
      expect(filled, [0, 1]);
    });
  });

  group('ScoreCapsule', () {
    test('the next tier and the progress come from MonthlyMedalRules', () {
      final bronze = MonthlyMedalRules.threshold(2026, 11, MedalTier.bronze);
      final silver = MonthlyMedalRules.threshold(2026, 11, MedalTier.silver);
      expect(ScoreCapsule.nextTier(0, 2026, 11), MedalTier.bronze);
      expect(ScoreCapsule.nextTier(bronze, 2026, 11), MedalTier.silver);
      expect(ScoreCapsule.progress(bronze, 2026, 11), 0);
      expect(ScoreCapsule.progress((bronze + silver) ~/ 2, 2026, 11),
          closeTo(.5, .02));
      expect(ScoreCapsule.nextTier(10000, 2026, 11), isNull);
    });

    testWidgets('"N to Bronze" and the +N badge after today', (tester) async {
      final bronze = MonthlyMedalRules.threshold(2026, 11, MedalTier.bronze);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
              child: ScoreCapsule(points: 9, year: 2026, month: 11, today: 9)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('${bronze - 9} to Bronze'), findsOneWidget);
      expect(find.text('+9'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('no badge before today', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body:
                Center(child: ScoreCapsule(points: 9, year: 2026, month: 11))),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('+'), findsNothing);
    });
  });
}
