import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/screens/avatar_picker_screen.dart';

void main() {
  testWidgets(
      'settling debounces before calling onAvatarChanged — a fast settle '
      "doesn't write immediately", (tester) async {
    final changes = <Avatar>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AvatarPickerScreen(
          currentAvatar: Avatar.values[3],
          onAvatarChanged: changes.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Settled, but the 500ms debounce window hasn't elapsed yet.
    expect(changes, isEmpty);

    await tester.pump(const Duration(milliseconds: 600));
    expect(changes, hasLength(1));
  });

  testWidgets(
      'leaving before the debounce fires still flushes the pending change '
      "instead of losing it", (tester) async {
    final changes = <Avatar>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AvatarPickerScreen(
                    currentAvatar: Avatar.values[3],
                    onAvatarChanged: changes.add,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(changes, isEmpty); // still inside the debounce window

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(changes, hasLength(1));
  });

  testWidgets('the centered avatar carries a Hero for the flight back to '
      "Settings' preview row", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AvatarPickerScreen(
          currentAvatar: Avatar.values[3],
          onAvatarChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heroes = tester.widgetList<Hero>(find.byType(Hero));
    expect(heroes.any((h) => h.tag == avatarHeroTag), isTrue);
  });
}
