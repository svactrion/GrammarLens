import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/tab_switcher.dart';

/// 1.2.0 Batch 9: the one tab switcher. Batch 6's fade-through for every
/// switch (this file began as Batch 6's `tab_fade_through_test.dart`), and
/// the slide only from Home's "Go to Review" card.
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
  TabTransition transition = TabTransition.fade;
  void go(int i, [TabTransition t = TabTransition.fade]) => setState(() {
        index = i;
        transition = t;
      });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(
          size: const Size(400, 800), disableAnimations: widget.reduceMotion),
      child: MaterialApp(
        home: FloatingNavShell(
          body: TabSwitcher(index: index, transition: transition, children: [
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
            of: find.byKey(TabSwitcher.slotKey(i), skipOffstage: false),
            matching: find.byType(Offstage, skipOffstage: false))
        .first)
    .offstage;

/// The opacity of tab [i]'s slot.
double _opacity(WidgetTester tester, int i) => tester
    .widget<FadeTransition>(find
        .descendant(
            of: find.byKey(TabSwitcher.slotKey(i), skipOffstage: false),
            matching: find.byType(FadeTransition, skipOffstage: false))
        .first)
    .opacity
    .value;

void main() {
  test('the values: Batch 6\'s fade; the card\'s slide, shorter than 500 ms',
      () {
    expect(TabSwitcher.fadeDuration, const Duration(milliseconds: 220));
    expect(TabSwitcher.fadeCurve, Curves.easeOut);
    expect(TabSwitcher.fadeStartScale, .98);
    expect(TabSwitcher.slideDuration, const Duration(milliseconds: 320));
    expect(TabSwitcher.slideCurve, Curves.easeOutCubic);
  });

  testWidgets('the first tab shows without a transition', (tester) async {
    await _pump(tester);
    expect(tester.hasRunningAnimations, isFalse);
    expect(_opacity(tester, 0), 1);
    expect([_shown(tester, 0), _shown(tester, 1), _shown(tester, 2)],
        [true, false, false]);
  });

  testWidgets(
      'fade: the new tab fades in over 220 ms ease-out from 0.98; the old '
      'one goes at once; nothing moves sideways', (tester) async {
    final harness = await _pump(tester);
    harness.go(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final mid = _opacity(tester, 1);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    expect(_shown(tester, 0), isFalse, reason: 'the old tab goes at once');
    expect(_x(tester, 'review'), greaterThan(0), reason: 'scaled, centred');
    expect(_x(tester, 'review'), lessThan(400 * .02));
    await tester.pumpAndSettle();
    expect(_opacity(tester, 1), 1);
    expect(_x(tester, 'review'), 0);
  });

  testWidgets(
      'slide: to a tab on the right the content moves left — the old tab '
      'leaves to the left, the new one comes in from the right',
      (tester) async {
    final harness = await _pump(tester);
    harness.go(1, TabTransition.slide);
    await tester.pump();
    expect(_x(tester, 'review'), 400);
    expect(_x(tester, 'home'), 0);

    await tester.pump(const Duration(milliseconds: 160));
    final t = Curves.easeOutCubic.transform(.5);
    expect(_x(tester, 'review'), moreOrLessEquals(400 * (1 - t), epsilon: .5));
    expect(_x(tester, 'home'), moreOrLessEquals(-400 * t, epsilon: .5));
    expect([_shown(tester, 0), _shown(tester, 1)], [true, true]);
    expect(_opacity(tester, 1), 1, reason: 'a slide does not fade');

    await tester.pump(const Duration(milliseconds: 150));
    expect(_x(tester, 'review'), greaterThan(0));
    await tester.pumpAndSettle();
    expect(_x(tester, 'review'), 0);
    expect([_shown(tester, 0), _shown(tester, 1), _shown(tester, 2)],
        [false, true, false]);
  });

  testWidgets(
      'the tabs keep their State and scroll position through both looks',
      (tester) async {
    final harness = await _pump(tester);
    final homeState =
        tester.state<_TabState>(find.byKey(const ValueKey('home')));
    final reviewState = tester.state<_TabState>(
        find.byKey(const ValueKey('review'), skipOffstage: false));
    final homeScroll =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    homeScroll.jumpTo(600);
    await tester.pump();

    harness.go(1, TabTransition.slide);
    await tester.pumpAndSettle();
    harness.go(0);
    await tester.pumpAndSettle();
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

  for (final t in TabTransition.values) {
    testWidgets('with reduce motion a ${t.name} is immediate', (tester) async {
      final harness = await _pump(tester, reduceMotion: true);
      harness.go(1, t);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_x(tester, 'review'), 0);
      expect(_opacity(tester, 1), 1);
      expect([_shown(tester, 0), _shown(tester, 1), _shown(tester, 2)],
          [false, true, false]);
    });
  }

  testWidgets('a nav bar tap mid-slide lands on the tab tapped, with the fade',
      (tester) async {
    final harness = await _pump(tester);
    harness.go(1, TabTransition.slide);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('P'));
    await tester.pump();
    expect(harness.index, 2);
    expect([_shown(tester, 0), _shown(tester, 1)], [false, false],
        reason: 'the slide stops: no tab left half way');
    expect(_x(tester, 'profile'), lessThan(400 * .02));
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

    harness.go(1, TabTransition.slide);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5));
    final button = tester.getCenter(find.text('home button'));
    expect(button.dx, lessThan(_x(tester, 'review')));
    expect(button.dx, greaterThan(0));
    await tester.tapAt(button);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('the nav bar stays put while the content slides', (tester) async {
    final harness = await _pump(tester);
    final bar = tester.getRect(find.byKey(FloatingNavShell.barKey));
    harness.go(2, TabTransition.slide);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_shown(tester, 0), isTrue, reason: 'mid-slide');
    expect(tester.getRect(find.byKey(FloatingNavShell.barKey)), bar);
    await tester.pumpAndSettle();
  });

  group('in the app: which switch slides', () {
    Future<void> pumpApp(WidgetTester tester,
        {List<WeakSpot> spots = const []}) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester
          .pumpWidget(GrammarLensApp(storageService: _AppStorage(spots)));
      await tester.pumpAndSettle();
    }

    TabTransition transition(WidgetTester tester) =>
        tester.widget<TabSwitcher>(find.byType(TabSwitcher)).transition;
    int index(WidgetTester tester) =>
        tester.widget<TabSwitcher>(find.byType(TabSwitcher)).index;

    testWidgets(
        'Home\'s "Go to Review" card slides; the nav bar and Review\'s "Go to '
        'Daily Test" fade', (tester) async {
      // A weak spot: Home shows its "Go to Review" card.
      await pumpApp(tester, spots: [
        WeakSpot(
            topicId: 'tenses',
            errorType: 'tense',
            frequency: 2,
            lastSeen: DateTime(2026, 10, 5)),
      ]);
      expect(find.byType(HomeScreen), findsOneWidget);

      // The nav bar: a fade.
      await tester.tap(find.text('Review').last);
      await tester.pump();
      expect((index(tester), transition(tester)), (1, TabTransition.fade));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect((index(tester), transition(tester)), (0, TabTransition.fade));

      // Home's card: the slide, the nav bar's selection at once.
      final card = find.byKey(HomeScreen.reviewCalloutKey);
      await tester.scrollUntilVisible(card, 300,
          scrollable: find
              .descendant(
                  of: find.byType(HomeScreen),
                  matching: find.byWidgetPredicate((w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pump();
      expect((index(tester), transition(tester)), (1, TabTransition.slide));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          tester.getTopLeft(find.byType(ReviewScreen, skipOffstage: false)).dx,
          greaterThan(0),
          reason: 'Review comes in from the right');
      await tester.pumpAndSettle();

      // Review's empty state (no weak spot): "Go to Daily Test", a fade. A
      // fresh app, so nothing loaded above carries over.
      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester);
      await tester.tap(find.text('Review').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Daily Test'));
      await tester.pump();
      expect((index(tester), transition(tester)), (0, TabTransition.fade));
      await tester.pumpAndSettle();
    });
  });
}

/// Enough storage for the app to reach its tabs with no weak spots (so
/// Review shows its empty state); everything else falls through to the real
/// service, which has no platform channel here and throws — a path the app
/// already tolerates (see widget_test.dart).
class _AppStorage extends StorageService {
  final List<WeakSpot> spots;
  _AppStorage(this.spots);

  @override
  Future<UserProfile?> getUserProfile() async =>
      const UserProfile(name: 'Ada', learningGoal: LearningGoal.work);

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      spots;

  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];
}
