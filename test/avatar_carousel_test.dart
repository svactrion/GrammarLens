import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/widgets/avatar_carousel.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

void main() {
  Future<void> pumpCarousel(
    WidgetTester tester, {
    required Avatar initial,
    required ValueChanged<Avatar> onSettled,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarCarousel(initialAvatar: initial, onSettled: onSettled),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('never reports the initial avatar on mount', (tester) async {
    final settled = <Avatar>[];
    await pumpCarousel(
      tester,
      initial: Avatar.values[3],
      onSettled: settled.add,
    );
    expect(settled, isEmpty);
  });

  testWidgets('swiping settles on a different avatar and reports it exactly',
      (tester) async {
    final settled = <Avatar>[];
    final initial = Avatar.values[3];
    await pumpCarousel(tester, initial: initial, onSettled: settled.add);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(settled, isNotEmpty);
    expect(settled.last, isNot(initial));
  });

  testWidgets(
      "the carousel's own box never changes size across a settle — the "
      'general form of this batch\'s original regression test (a selection '
      'change repaints a fixed-size slot, it never resizes one), no longer '
      'ring-specific now that selection has no background chrome at all',
      (tester) async {
    await pumpCarousel(
      tester,
      initial: Avatar.values[3],
      onSettled: (_) {},
    );
    final carousel = find.byType(AvatarCarousel);
    final before = tester.getSize(carousel);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(tester.getSize(carousel), before);
  });

  testWidgets(
      'the settled avatar renders at full scale/opacity; its neighbor does '
      'not', (tester) async {
    await pumpCarousel(tester, initial: Avatar.values[3], onSettled: (_) {});

    Widget findOpacityAncestor(Avatar avatar) => tester.widget<Opacity>(
          find.ancestor(
            of: find.bySemanticsLabel(avatar.semanticLabel),
            matching: find.byType(Opacity),
          ),
        );

    final settledOpacity =
        (findOpacityAncestor(Avatar.values[3]) as Opacity).opacity;
    expect(settledOpacity, 1.0);

    // A fully off-screen neighbor isn't laid out by PageView at all, so
    // this only asserts against a neighbor that IS currently built —
    // enough to confirm the interpolation is actually wired, not a no-op.
    final builtNeighbors = Avatar.values
        .where((a) => a != Avatar.values[3])
        .where((a) =>
            find.bySemanticsLabel(a.semanticLabel).evaluate().isNotEmpty);
    expect(builtNeighbors, isNotEmpty);
    for (final neighbor in builtNeighbors) {
      final opacity = (findOpacityAncestor(neighbor) as Opacity).opacity;
      expect(opacity, lessThan(1.0),
          reason: '${neighbor.semanticLabel} should be faded, not settled');
    }
  });

  testWidgets(
      'semantics marks exactly the settled avatar as selected, even with '
      'no visual ring behind it', (tester) async {
    final initial = Avatar.values[3];
    final settled = <Avatar>[];
    await pumpCarousel(tester, initial: initial, onSettled: settled.add);

    Tristate isSelectedFor(Avatar avatar) => tester
        .getSemantics(find.bySemanticsLabel(avatar.semanticLabel))
        .flagsCollection
        .isSelected;

    expect(isSelectedFor(initial), Tristate.isTrue);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(settled, isNotEmpty);
    final newlySettled = settled.last;

    expect(
      isSelectedFor(initial),
      isNot(Tristate.isTrue),
      reason: 'the original avatar is no longer centered after the drag',
    );
    expect(isSelectedFor(newlySettled), Tristate.isTrue);
  });

  testWidgets('settling fires exactly one selection-click haptic',
      (tester) async {
    final hapticCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpCarousel(tester, initial: Avatar.values[3], onSettled: (_) {});
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(hapticCalls, hasLength(1));
  });

  testWidgets(
      'the settle-triggered pop animation is one-shot and never hangs '
      'pumpAndSettle', (tester) async {
    await pumpCarousel(tester, initial: Avatar.values[3], onSettled: (_) {});

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    // Would hang here if the pop animation ever looped instead of settling.
    await tester.pumpAndSettle();
  });

  testWidgets('each page is reachable by its character name via Semantics',
      (tester) async {
    await pumpCarousel(tester, initial: Avatar.values[3], onSettled: (_) {});
    expect(
        find.bySemanticsLabel(Avatar.values[3].semanticLabel), findsOneWidget);
  });

  group('loops in both directions (Batch 8)', () {
    // The test surface is 800 px wide and the default viewportFraction is
    // 0.45, so one page is 360 px: a 250 px drag moves exactly one page.
    const onePageForward = Offset(-250, 0);
    const onePageBack = Offset(250, 0);

    testWidgets('dragging forward from the last avatar selects the first',
        (tester) async {
      final settled = <Avatar>[];
      await pumpCarousel(
        tester,
        initial: Avatar.values.last,
        onSettled: settled.add,
      );

      await tester.drag(find.byType(PageView), onePageForward);
      await tester.pumpAndSettle();

      expect(settled, [Avatar.values.first]);
    });

    testWidgets('dragging back from the first avatar selects the last',
        (tester) async {
      final settled = <Avatar>[];
      await pumpCarousel(
        tester,
        initial: Avatar.values.first,
        onSettled: settled.add,
      );

      await tester.drag(find.byType(PageView), onePageBack);
      await tester.pumpAndSettle();

      expect(settled, [Avatar.values.last]);
    });

    testWidgets(
        'from every start, one page forward and one page back select the '
        'next and previous avatar modulo Avatar.count — the onboarding '
        'carousel starts on a random one', (tester) async {
      for (var i = 0; i < Avatar.count; i++) {
        final settled = <Avatar>[];
        // A fresh key per start, so each iteration mounts a new carousel
        // instead of updating the previous one.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarCarousel(
                key: ValueKey(i),
                initialAvatar: Avatar.values[i],
                onSettled: settled.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(PageView), onePageForward);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), onePageBack);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), onePageBack);
        await tester.pumpAndSettle();

        expect(
          settled,
          [
            Avatar.values[(i + 1) % Avatar.count],
            Avatar.values[i],
            Avatar.values[(i - 1) % Avatar.count],
          ],
          reason: 'start ${Avatar.values[i].semanticLabel}',
        );
      }
    });

    for (final (initial, left, right) in [
      (Avatar.values.first, Avatar.values.last, Avatar.values[1]),
      (
        Avatar.values.last,
        Avatar.values[Avatar.count - 2],
        Avatar.values.first
      ),
    ]) {
      testWidgets(
          'on mount, ${initial.semanticLabel} has a neighbor on both sides '
          '(${left.semanticLabel} left, ${right.semanticLabel} right)',
          (tester) async {
        await pumpCarousel(tester, initial: initial, onSettled: (_) {});

        double centerX(Avatar a) =>
            tester.getCenter(find.bySemanticsLabel(a.semanticLabel)).dx;

        expect(centerX(left), lessThan(centerX(initial)));
        expect(centerX(right), greaterThan(centerX(initial)));
      });
    }

    testWidgets(
        'a full lap back to the same avatar reports nothing and fires no '
        'haptic — only a change of avatar counts, not a change of page',
        (tester) async {
      final hapticCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final initial = Avatar.values[3];
      final settled = <Avatar>[];
      await pumpCarousel(tester, initial: initial, onSettled: settled.add);
      final pageView = find.byType(PageView);
      final startPixels = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;

      // One page at a time, `Avatar.count` times, so each step settles on
      // its own and no fling can overshoot the lap.
      for (var i = 0; i < Avatar.count; i++) {
        await tester.drag(pageView, onePageForward);
        await tester.pumpAndSettle();
      }
      final lapPixels = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;
      expect(lapPixels - startPixels, closeTo(Avatar.count * 360.0, 0.5),
          reason: 'the drags must have moved exactly one lap');
      expect(settled.last, initial);
      settled.clear();
      hapticCalls.clear();

      // The same lap in one settle: the raw page moves by Avatar.count,
      // the avatar doesn't.
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      position.jumpTo(startPixels);
      await tester.pumpAndSettle();
      position.jumpTo(lapPixels);
      await tester.pumpAndSettle();

      expect(settled, isEmpty);
      expect(hapticCalls, isEmpty);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(initial.semanticLabel))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    });

    testWidgets(
        'when several copies of one avatar are built at once, only the '
        'centered copy is settled — one centerTileBuilder wrap, one '
        'selected node', (tester) async {
      const tag = 'carousel-hero';
      // A narrow page slot builds more than one lap on screen at once:
      // 800 px / (800 * 0.02) = 50 pages visible, so the centered avatar's
      // own copies one lap away (±16 pages) are built too. The builder
      // wraps a Hero, exactly as AvatarPickerScreen does; two Heroes with
      // one tag would break the flight back to Settings.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarCarousel(
              initialAvatar: Avatar.values[3],
              onSettled: (_) {},
              centerRadius: 6,
              viewportFraction: 0.02,
              centerTileBuilder: (avatar, tile) => Hero(tag: tag, child: tile),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copies = find.byWidgetPredicate(
        (w) => w is AvatarTile && w.avatar == Avatar.values[3],
      );
      expect(copies.evaluate().length, greaterThan(1),
          reason: 'the setup must actually build duplicate copies');

      expect(
        tester.widgetList<Hero>(find.byType(Hero)).where((h) => h.tag == tag),
        hasLength(1),
      );
      final selectedFlags = tester
          .widgetList<Semantics>(
            find.ancestor(of: copies, matching: find.byType(Semantics)),
          )
          .map((s) => s.properties.selected)
          .where((selected) => selected != null);
      expect(selectedFlags.where((selected) => selected!), hasLength(1));
    });
  });
}
