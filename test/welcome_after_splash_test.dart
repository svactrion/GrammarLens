import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/screens/welcome_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

/// On a first install Welcome is built under the launch splash. Its entrance
/// must start only once the splash's fade has finished, not play unseen.
void main() {
  const frame = Duration(microseconds: 16667);
  Future<void> frames(WidgetTester tester, Duration total) async {
    var elapsed = Duration.zero;
    while (elapsed < total) {
      await tester.pump(frame);
      elapsed += frame;
    }
  }

  // The Welcome title's own opacity (the splash has a "GrammarLens" too).
  double titleOpacity(WidgetTester tester) {
    final title = find.descendant(
      of: find.byType(WelcomeScreen),
      matching: find.text('GrammarLens'),
    );
    return tester
        .widget<Opacity>(
            find.ancestor(of: title, matching: find.byType(Opacity)).first)
        .opacity;
  }

  testWidgets(
      'first install: Welcome is held at its first frame under the splash '
      'and starts after the fade', (tester) async {
    // No sqflite in widget tests: the profile read fails and the app shows
    // Welcome, the same path a fresh install takes.
    await tester.pumpWidget(LaunchGate(
      initialize: () async {},
      app: (_) => const GrammarLensApp(),
    ));

    await frames(tester, const Duration(milliseconds: 300));
    expect(find.byType(WelcomeScreen), findsOneWidget,
        reason: 'built under the splash once launch work is done');
    expect(find.byType(LaunchSplash), findsOneWidget);

    // Up to the end of the splash's intro and fade, Welcome has not moved.
    await frames(tester, LaunchTiming.intro + LaunchTiming.exit);
    await frames(tester, frame * 2);
    expect(find.byType(LaunchSplash), findsNothing);
    expect(titleOpacity(tester), 0,
        reason: 'the title (450 ms delay) has not started yet');

    // Then the entrance plays as designed: the title is in by ~1.15 s.
    await frames(tester, const Duration(milliseconds: 300));
    expect(titleOpacity(tester), inExclusiveRange(0, 1));
    await frames(tester, const Duration(milliseconds: 1000));
    expect(titleOpacity(tester), 1);

    // Leave Welcome's endless ambient loops behind cleanly.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without a splash, Welcome starts at once (unchanged)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: WelcomeScreen(onGetStarted: () {}),
    ));
    await frames(tester, const Duration(milliseconds: 1200));
    expect(titleOpacity(tester), 1);

    await tester.pumpWidget(const SizedBox());
  });
}
