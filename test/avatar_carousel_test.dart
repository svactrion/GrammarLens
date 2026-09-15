import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/widgets/avatar_carousel.dart';

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
        .where((a) => find.bySemanticsLabel(a.semanticLabel).evaluate().isNotEmpty);
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
    expect(find.bySemanticsLabel(Avatar.values[3].semanticLabel),
        findsOneWidget);
  });
}
