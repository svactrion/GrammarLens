import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/tab_slide_switcher.dart';

/// 1.2.0 Batch 7: the tab switch slides like the app's pushed pages (it
/// replaced Batch 6's fade-through, whose tests this file grew from).
class _Tab extends StatefulWidget {
  final String name;
  final VoidCallback? onTap;
  const _Tab(this.name, {super.key, this.onTap});

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        key: PageStorageKey(widget.name),
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 50,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onTap,
                child: Text('${widget.name} button'),
              ),
            ),
          ),
          for (var i = 0; i < 60; i++)
            SizedBox(height: 50, child: Text('${widget.name} $i')),
        ],
      ),
    );
  }
}

class _Harness extends StatefulWidget {
  final bool reduceMotion;
  final VoidCallback? onHomeTap;
  const _Harness({this.reduceMotion = false, this.onHomeTap});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int index = 0;
  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(
          size: const Size(400, 800), disableAnimations: widget.reduceMotion),
      child: MaterialApp(
        home: FloatingNavShell(
          body: TabSlideSwitcher(index: index, children: [
            _Tab('home', key: const ValueKey('home'), onTap: widget.onHomeTap),
            const _Tab('review', key: ValueKey('review')),
            const _Tab('profile', key: ValueKey('profile')),
          ]),
          tabs: const [
            NavShellTab(icon: Icons.home, activeIcon: Icons.home, label: 'H'),
            NavShellTab(
                icon: Icons.history, activeIcon: Icons.history, label: 'R'),
            NavShellTab(
                icon: Icons.person, activeIcon: Icons.person, label: 'P'),
          ],
          selectedIndex: index,
          onTabChange: go,
        ),
      ),
    );
  }
}

Future<_HarnessState> _pump(WidgetTester tester,
    {bool reduceMotion = false, VoidCallback? onHomeTap}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester
      .pumpWidget(_Harness(reduceMotion: reduceMotion, onHomeTap: onHomeTap));
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

/// Where tab [name]'s content is on screen: its first row's left edge.
double _x(WidgetTester tester, String name) =>
    tester.getTopLeft(find.text('$name 0', skipOffstage: false)).dx;

/// Whether tab [i] is drawn (its slot is not offstage).
bool _shown(WidgetTester tester, int i) => !tester
    .widget<Offstage>(find
        .descendant(
            of: find.byKey(TabSlideSwitcher.slotKey(i), skipOffstage: false),
            matching: find.byType(Offstage, skipOffstage: false))
        .first)
    .offstage;

void main() {
  test('the values are the iOS page route\'s (Premium opens with it)', () {
    expect(TabSlideSwitcher.duration, const Duration(milliseconds: 500));
    expect(TabSlideSwitcher.incomingCurve, Curves.fastEaseInToSlowEaseOut);
    expect(TabSlideSwitcher.outgoingCurve, Curves.linearToEaseOut);
    expect(TabSlideSwitcher.outgoingShift, 1 / 3);
  });

  testWidgets('the first tab shows without a transition', (tester) async {
    await _pump(tester);
    expect(tester.hasRunningAnimations, isFalse);
    expect(_x(tester, 'home'), 0);
    expect([_shown(tester, 0), _shown(tester, 1), _shown(tester, 2)],
        [true, false, false]);
  });

  testWidgets(
      'to a tab on the right: the new content comes in from the right over '
      '500 ms, the old leaves to the left; then only the new one is drawn',
      (tester) async {
    final harness = await _pump(tester);
    harness.go(1);
    await tester.pump();
    expect(_x(tester, 'review'), 400);
    expect(_x(tester, 'home'), 0);

    await tester.pump(const Duration(milliseconds: 250));
    expect(
        _x(tester, 'review'),
        moreOrLessEquals(
            400 * (1 - Curves.fastEaseInToSlowEaseOut.transform(.5)),
            epsilon: .5));
    expect(
        _x(tester, 'home'),
        moreOrLessEquals(-400 / 3 * Curves.linearToEaseOut.transform(.5),
            epsilon: .5));
    expect([_shown(tester, 0), _shown(tester, 1)], [true, true]);

    await tester.pump(const Duration(milliseconds: 240));
    expect(_x(tester, 'review'), greaterThan(0));
    await tester.pumpAndSettle();
    expect(_x(tester, 'review'), 0);
    expect([_shown(tester, 0), _shown(tester, 1), _shown(tester, 2)],
        [false, true, false]);
  });

  testWidgets(
      'to a tab on the left: the new content comes in from the left, the old '
      'leaves to the right', (tester) async {
    final harness = await _pump(tester);
    harness.go(2);
    await tester.pumpAndSettle();
    harness.go(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_x(tester, 'home'), lessThan(0));
    expect(_x(tester, 'home'), greaterThan(-400));
    expect(_x(tester, 'profile'), greaterThan(0));
    await tester.pumpAndSettle();
    expect(_x(tester, 'home'), 0);
  });

  testWidgets(
      'the tabs keep their State and scroll position; nothing is rebuilt '
      'from scratch', (tester) async {
    final harness = await _pump(tester);
    final homeState =
        tester.state<_TabState>(find.byKey(const ValueKey('home')));
    final reviewState = tester.state<_TabState>(
        find.byKey(const ValueKey('review'), skipOffstage: false));
    final homeScroll =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    homeScroll.jumpTo(600);
    await tester.pump();

    harness.go(1);
    await tester.pumpAndSettle();
    harness.go(0);
    await tester.pumpAndSettle();
    expect(tester.state<_TabState>(find.byKey(const ValueKey('home'))),
        same(homeState));
    expect(
        tester.state<_TabState>(
            find.byKey(const ValueKey('review'), skipOffstage: false)),
        same(reviewState));
    expect(homeScroll.pixels, 600);
  });

  testWidgets('with reduce motion the switch is immediate', (tester) async {
    final harness = await _pump(tester, reduceMotion: true);
    harness.go(2);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(_x(tester, 'profile'), 0);
    expect([_shown(tester, 0), _shown(tester, 1), _shown(tester, 2)],
        [false, false, true]);
  });

  testWidgets(
      'switching again mid-transition lands on the last tab tapped, fully '
      'shown', (tester) async {
    final harness = await _pump(tester);
    harness.go(1);
    await tester.pump(const Duration(milliseconds: 100));
    harness.go(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // From Review (the tab selected last), Profile comes in from the right.
    expect(_x(tester, 'profile'), greaterThan(0));
    harness.go(2); // a second tap on the same tab changes nothing
    await tester.pumpAndSettle();
    expect(_x(tester, 'profile'), 0);
    expect([_shown(tester, 0), _shown(tester, 1), _shown(tester, 2)],
        [false, false, true]);
  });

  testWidgets('a tap on the tab being left is swallowed during the slide',
      (tester) async {
    var taps = 0;
    final harness = await _pump(tester, onHomeTap: () => taps++);
    await tester.tap(find.text('home button'));
    expect(taps, 1);

    harness.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Home's button is still in view, left of the incoming tab.
    final button = tester.getCenter(find.text('home button'));
    expect(button.dx, lessThan(_x(tester, 'review')));
    await tester.tapAt(button);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('the nav bar stays put while the content slides', (tester) async {
    final harness = await _pump(tester);
    final bar = tester.getRect(find.byKey(FloatingNavShell.barKey));
    harness.go(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.hasRunningAnimations, isTrue);
    expect(tester.getRect(find.byKey(FloatingNavShell.barKey)), bar);
    await tester.pumpAndSettle();
  });
}
