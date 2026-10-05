import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/widgets/tab_fade_through.dart';

/// 1.2.0 Batch 6: the tab switch transition over the shell's IndexedStack.
class _Tab extends StatefulWidget {
  final String name;
  const _Tab(this.name, {super.key});

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return ListView(
      key: PageStorageKey(widget.name),
      children: [
        for (var i = 0; i < 60; i++)
          SizedBox(height: 50, child: Text('${widget.name} $i')),
      ],
    );
  }
}

class _Harness extends StatefulWidget {
  final bool reduceMotion;
  const _Harness({this.reduceMotion = false});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int index = 0;
  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: widget.reduceMotion),
      child: MaterialApp(
        home: TabFadeThrough(
          index: index,
          child: IndexedStack(index: index, children: const [
            _Tab('home', key: ValueKey('home')),
            _Tab('review', key: ValueKey('review')),
            _Tab('profile', key: ValueKey('profile')),
          ]),
        ),
      ),
    );
  }
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find
        .descendant(
            of: find.byType(TabFadeThrough),
            matching: find.byType(FadeTransition))
        .first)
    .opacity
    .value;

void main() {
  testWidgets('the first tab shows without a transition', (tester) async {
    await tester.pumpWidget(const _Harness());
    expect(_opacity(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
      'a switch fades the new tab in over 220 ms ease-out and settles; the '
      'tabs keep their State and scroll position', (tester) async {
    await tester.pumpWidget(const _Harness());
    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    final homeState =
        tester.state<_TabState>(find.byKey(const ValueKey('home')));
    final homeScroll =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    homeScroll.jumpTo(600);
    await tester.pump();

    harness.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final mid = _opacity(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    expect(find.text('review 0'), findsOneWidget);

    harness.go(0);
    await tester.pumpAndSettle();
    // The same State object, the same scroll position: nothing rebuilt
    // from scratch.
    expect(tester.state<_TabState>(find.byKey(const ValueKey('home'))),
        same(homeState));
    expect(homeScroll.pixels, 600);
  });

  testWidgets('with reduce motion the switch is immediate', (tester) async {
    await tester.pumpWidget(const _Harness(reduceMotion: true));
    tester.state<_HarnessState>(find.byType(_Harness)).go(2);
    await tester.pump();
    expect(_opacity(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('profile 0'), findsOneWidget);
  });

  testWidgets(
      'switching again mid-transition lands on the last tab, fully shown',
      (tester) async {
    await tester.pumpWidget(const _Harness());
    final harness = tester.state<_HarnessState>(find.byType(_Harness));
    harness.go(1);
    await tester.pump(const Duration(milliseconds: 60));
    harness.go(2);
    await tester.pump(const Duration(milliseconds: 60));
    harness.go(2); // a second tap on the same tab changes nothing
    await tester.pumpAndSettle();
    expect(find.text('profile 0'), findsOneWidget);
    expect(find.text('review 0'), findsNothing);
    expect(_opacity(tester), 1);
  });
}
