import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

/// The cold-start splash: finite, skipped with Reduce Motion, and the app
/// appears only once both the intro and launch work have finished.
void main() {
  const appKey = Key('app');
  const intro = LaunchTiming.intro;
  const exit = LaunchTiming.exit;

  Widget gate(Future<void> initialization) => LaunchGate(
        initialize: () => initialization,
        app: (_) => const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(key: appKey),
        ),
      );

  Finder splash() => find.byType(LaunchSplash);

  // One 60 Hz frame; [frames] pumps like a device does, frame by frame.
  const frame = Duration(microseconds: 16667);
  Future<void> frames(WidgetTester tester, Duration total) async {
    var elapsed = Duration.zero;
    while (elapsed < total) {
      await tester.pump(frame);
      elapsed += frame;
    }
  }

  Finder app() => find.byKey(appKey);

  // V01: the square's scale, read from the logo the splash draws.
  double logoScale(WidgetTester tester) =>
      tester.widgetList<LaunchLogo>(find.byType(LaunchLogo)).last.tileScale;

  double wordmarkOpacity(WidgetTester tester) {
    final fade = tester.widget<Opacity>(find
        .ancestor(of: find.text('GrammarLens'), matching: find.byType(Opacity))
        .first);
    return fade.opacity;
  }

  double splashOpacity(WidgetTester tester) {
    final fade = tester.widget<FadeTransition>(find
        .ancestor(of: splash(), matching: find.byType(FadeTransition))
        .first);
    return fade.opacity.value;
  }

  void setReduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  // V01 (UI polish): the first launch takes at most 1.4 s, later launches
  // at most 600 ms (was: 1.2 s with the fade).
  test('the first launch stays within 1.4 s, later launches within 600 ms', () {
    expect(intro, lessThanOrEqualTo(const Duration(milliseconds: 1400)));
    expect(LaunchTiming.introShort,
        lessThanOrEqualTo(const Duration(milliseconds: 600)));
  });

  testWidgets(
      'the first frame matches the static launch screen: the square at 50 %, '
      'no wordmark', (tester) async {
    await tester.pumpWidget(gate(Completer<void>().future));

    expect(logoScale(tester), LaunchSplashLayout.initialLogoScale);
    expect(wordmarkOpacity(tester), 0);

    final center = tester.getCenter(find.byType(LaunchLogo));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(center.dx, screen.width / 2);
    expect(center.dy, screen.height / 2 + LaunchSplashLayout.logoCenterOffsetY);
    expect(tester.getSize(find.byType(LaunchLogo)),
        const Size.square(LaunchSplashLayout.logoSize));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the animation is finite: pumpAndSettle returns', (tester) async {
    await tester.pumpWidget(gate(Future<void>.value()));
    await tester.pumpAndSettle();

    expect(splash(), findsNothing);
    expect(app(), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
      'the intro ends with the logo at full size and the wordmark shown',
      (tester) async {
    await tester.pumpWidget(gate(Completer<void>().future));
    await tester.pump(intro);

    expect(logoScale(tester), 1);
    expect(wordmarkOpacity(tester), 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'launch work shorter than the intro: the intro completes, then the '
      'splash fades over the app', (tester) async {
    await tester.pumpWidget(
        gate(Future<void>.delayed(const Duration(milliseconds: 300))));

    await frames(tester, const Duration(milliseconds: 400));
    // Built under the splash as soon as launch work is done.
    expect(app(), findsOneWidget);
    expect(splash(), findsOneWidget);
    expect(splashOpacity(tester), 1);

    // Still covered until the intro has finished.
    await frames(tester, intro - const Duration(milliseconds: 450));
    expect(splashOpacity(tester), 1, reason: 'intro still running');

    // Then the fade, and the splash is gone after it.
    await frames(tester, const Duration(milliseconds: 50) + exit ~/ 2);
    expect(splashOpacity(tester), inExclusiveRange(0, 1), reason: 'fading');
    await frames(tester, exit ~/ 2 + frame * 3);
    expect(splash(), findsNothing);
    expect(app(), findsOneWidget);
  });

  testWidgets(
      'launch work longer than the intro: the last frame holds, then the '
      'app appears', (tester) async {
    final done = Completer<void>();
    await tester.pumpWidget(gate(done.future));

    await frames(tester, intro + const Duration(seconds: 2));
    expect(app(), findsNothing);
    expect(splash(), findsOneWidget);
    expect(splashOpacity(tester), 1);
    expect(logoScale(tester), 1);
    expect(wordmarkOpacity(tester), 1);

    done.complete();
    await frames(tester, frame);
    expect(app(), findsOneWidget);

    await frames(tester, exit ~/ 2);
    expect(splashOpacity(tester), inExclusiveRange(0, 1), reason: 'fading');
    await frames(tester, exit ~/ 2 + frame * 3);
    expect(splash(), findsNothing);
  });

  testWidgets('a failed launch step still opens the app', (tester) async {
    await tester.pumpWidget(LaunchGate(
      initialize: () async => throw StateError('x'),
      app: (_) => const SizedBox.expand(key: appKey),
    ));
    await tester.pumpAndSettle();

    expect(app(), findsOneWidget);
    expect(splash(), findsNothing);
  });

  testWidgets(
      'Reduce Motion: no animation; static logo and wordmark; the app '
      'replaces the splash at once', (tester) async {
    setReduceMotion(tester);
    final done = Completer<void>();
    await tester.pumpWidget(gate(done.future));
    await tester.pump();

    // V01: one fade from the static launch screen's square to the finished
    // icon and the wordmark (150 ms), then nothing moves.
    final first = tester.widget<LaunchLogo>(find.byType(LaunchLogo).first);
    expect(first.scale, LaunchSplashLayout.initialLogoScale,
        reason: 'no jump from the static launch screen');
    await tester.pump(LaunchTiming.reducedFade);
    expect(wordmarkOpacity(tester), 1);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0,
        reason: 'nothing is animating');

    done.complete();
    await tester.pump(Duration.zero);
    expect(splash(), findsNothing);
    expect(app(), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('the splash does not come back on return from the background',
      (tester) async {
    await tester.pumpWidget(gate(Future<void>.value()));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(splash(), findsNothing);
    expect(app(), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('follows the system appearance (${brightness.name})',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(gate(Completer<void>().future));

      final box = tester.widget<ColoredBox>(find
          .descendant(of: splash(), matching: find.byType(ColoredBox))
          .first);
      expect(
          box.color, buildAppTheme(brightness).colorScheme.surfaceContainerLow);

      await tester.pumpWidget(const SizedBox());
    });
  }
}
