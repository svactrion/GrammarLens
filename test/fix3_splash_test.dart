import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/brand_mark.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

/// Fix round 3, C1 (SPEC V01, v11): the first launch takes about 2.2 s, the
/// small lens scanning the word in 900 ms; later launches show only the
/// square and the wordmark and finish within 800 ms.
void main() {
  const screen = Size(402, 874);

  Future<List<bool>> pumpSplash(WidgetTester tester,
      {Future<bool>? firstLaunch}) async {
    tester.view.physicalSize = screen * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final done = <bool>[];
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: screen),
      child: LaunchSplash(firstLaunch: firstLaunch, onIntroDone: done.add),
    ));
    return done;
  }

  // The scanning lens: the small brand mark over the wordmark.
  final lens = find.byWidgetPredicate((w) => w is BrandMark && w.size == 52);

  testWidgets(
      'first launch: the lens crosses the word from 1.15 s for 900 ms, left '
      'to right; the intro ends at 2.2 s', (tester) async {
    final done = await pumpSplash(tester, firstLaunch: Future.value(true));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(lens, findsNothing, reason: 'not before the scan');
    await tester.pump(const Duration(milliseconds: 200)); // 1.3 s
    expect(lens, findsOneWidget);
    final early = tester.getRect(lens).left;
    await tester.pump(const Duration(milliseconds: 500)); // 1.8 s
    expect(lens, findsOneWidget);
    expect(tester.getRect(lens).left, greaterThan(early + 100));
    await tester.pump(const Duration(milliseconds: 300)); // 2.1 s
    expect(lens, findsNothing, reason: 'the scan has ended');
    expect(done, isEmpty);
    await tester.pump(const Duration(milliseconds: 120)); // 2.22 s
    expect(done, [false]);
  });

  testWidgets('a later launch: no scanning lens, done within 800 ms (600 ms)',
      (tester) async {
    final done = await pumpSplash(tester, firstLaunch: Future.value(false));
    for (var ms = 0; ms < 600; ms += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(lens, findsNothing);
    }
    await tester.pump(const Duration(milliseconds: 20));
    expect(done, [false]);
    expect(LaunchTiming.introShort.inMilliseconds, lessThanOrEqualTo(800));
  });
}
