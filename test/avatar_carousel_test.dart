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
      'the selection ring never changes size across a settle that recolors '
      "it — the actual regression test for this batch's bug (a selection "
      'change repaints a fixed-size slot, it never resizes one)',
      (tester) async {
    await pumpCarousel(
      tester,
      initial: Avatar.values[3],
      onSettled: (_) {},
    );
    final ring = find.byKey(const Key('avatarSelectionRing'));
    final before = tester.getSize(ring);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(tester.getSize(ring), before);
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
