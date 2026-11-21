import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/screens/avatar_picker_screen.dart';
import 'package:grammar_lens/screens/lucky_wheel_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/buddy_picker.dart';

/// R06: Change your buddy — the onboarding turntable opened from Profile,
/// "Save <Hero>" and "Try my luck". (Replaces the carousel's autosave
/// tests: the choice is saved with the button now.)
void main() {
  Future<List<Avatar>> pump(WidgetTester tester, Avatar current) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final saved = <Avatar>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AvatarPickerScreen(
                    currentAvatar: current, onAvatarChanged: saved.add))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets('opens with the current buddy in front and the R06 copy',
      (tester) async {
    await pump(tester, Avatar.giraffe);
    expect(find.text('Change your buddy'), findsOneWidget);
    expect(find.text('Your progress stays the same'), findsOneWidget);
    expect(find.text('Save Giraffe'), findsOneWidget);
    expect(find.text('6 / 9'), findsOneWidget);
  });

  testWidgets('Save saves the front buddy and closes', (tester) async {
    final saved = await pump(tester, Avatar.fox);
    await tester.tap(find.byKey(BuddyPicker.nextKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BuddyPicker.confirmKey));
    await tester.pumpAndSettle();
    expect(saved, [Avatar.panda]);
    expect(find.byType(AvatarPickerScreen), findsNothing);
  });

  testWidgets('saving the same buddy writes nothing', (tester) async {
    final saved = await pump(tester, Avatar.cat);
    await tester.tap(find.byKey(BuddyPicker.confirmKey));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
  });

  testWidgets('Back leaves without saving', (tester) async {
    final saved = await pump(tester, Avatar.fox);
    await tester.tap(find.byKey(BuddyPicker.nextKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AvatarPickerScreen.backKey));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.byType(AvatarPickerScreen), findsNothing);
  });

  testWidgets('the wheel reads "Save <Hero>" and saves what it lands on',
      (tester) async {
    final saved = await pump(tester, Avatar.fox);
    await tester.tap(find.byKey(BuddyPicker.tryLuckKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LuckyWheelScreen.spinKey));
    await tester.pumpAndSettle();
    final confirm = find.byKey(LuckyWheelScreen.confirmKey);
    expect(find.descendant(of: confirm, matching: find.textContaining('Save ')),
        findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single, isNot(Avatar.fox));
    expect(find.byType(AvatarPickerScreen), findsNothing);
  });
}
