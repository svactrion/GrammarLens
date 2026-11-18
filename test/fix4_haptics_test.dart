import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/haptics.dart';
import 'package:grammar_lens/widgets/practice_step_footer.dart';

/// Fix round 4, item 6 (SPEC §3.4 v12): the practice's forward button
/// (Next, then Submit on the last question) gives light on tap; the
/// Daily Test's are in `daily_test_check_test.dart`.
void main() {
  setUp(() => HapticMap.log = []);
  tearDown(() => HapticMap.log = null);

  Future<void> pump(WidgetTester tester,
      {required bool enabled, required VoidCallback onPrimary}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        bottomNavigationBar: PracticeStepFooter(
          primaryLabel: 'Next',
          primaryEnabled: enabled,
          onPrimary: onPrimary,
          onSkip: () {},
        ),
      ),
    ));
  }

  testWidgets('Next / Submit: light on tap, once', (tester) async {
    var taps = 0;
    await pump(tester, enabled: true, onPrimary: () => taps++);
    await tester.tap(find.byKey(PracticeStepFooter.primaryKey));
    await tester.pump();
    expect(taps, 1);
    expect(HapticMap.log, ['light']);
  });

  testWidgets('disabled: no tap, no haptic', (tester) async {
    await pump(tester, enabled: false, onPrimary: () {});
    await tester.tap(find.byKey(PracticeStepFooter.primaryKey),
        warnIfMissed: false);
    await tester.pump();
    expect(HapticMap.log, isEmpty);
  });

  testWidgets('Skip is not a forward button: no haptic', (tester) async {
    await pump(tester, enabled: true, onPrimary: () {});
    await tester.tap(find.byKey(PracticeStepFooter.skipKey));
    await tester.pump();
    expect(HapticMap.log, isEmpty);
  });
}
