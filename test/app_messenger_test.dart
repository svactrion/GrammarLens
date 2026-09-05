import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/app_messenger.dart';

/// Minimal app shell wiring `AppMessenger`'s key and navigator observer
/// exactly the way app.dart does, so these tests exercise the real
/// integration rather than a standalone `ScaffoldMessenger`.
class _Harness extends StatelessWidget {
  const _Harness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: AppMessenger.key,
      navigatorObservers: [AppMessenger.navigatorObserver],
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              onPressed: () => AppMessenger.show('Hello'),
              child: const Text('Show'),
            ),
            // Builder gives this button a context below MaterialApp's own
            // Navigator — `_Harness.build`'s own `context` sits above it,
            // so `Navigator.of` on that would find no Navigator at all.
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(),
                      body: const Text('Second page'),
                    ),
                  ),
                ),
                child: const Text('Push'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  // AppMessenger.key is a process-global GlobalKey, so a leftover message
  // from one test could otherwise bleed into the next.
  tearDown(() => AppMessenger.clear());

  testWidgets('a message disappears on its own once its duration elapses',
      (tester) async {
    await tester.pumpWidget(const _Harness());
    AppMessenger.show('Hello');
    await tester.pump();
    // Let the SnackBar's entrance animation finish before advancing time —
    // otherwise the jump below lands mid-entrance instead of mid-duration.
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
  });

  testWidgets('the Dismiss action actually closes the message', (tester) async {
    await tester.pumpWidget(const _Harness());
    AppMessenger.show('Hello');
    await tester.pump();
    // Let the entrance animation finish — tapping mid-slide-in hits
    // whatever's behind the not-yet-settled SnackBar instead of its action.
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
  });

  testWidgets('navigating to another screen clears a message left showing',
      (tester) async {
    await tester.pumpWidget(const _Harness());
    AppMessenger.show('Hello');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsNothing);
    expect(find.text('Second page'), findsOneWidget);
  });

  testWidgets(
    'popping back to the previous screen also clears a message left showing',
    (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();

      AppMessenger.show('Hello');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsNothing);
    },
  );

  testWidgets(
    'triggering the same message again replaces rather than queuing a '
    'second one behind it',
    (tester) async {
      await tester.pumpWidget(const _Harness());
      AppMessenger.show('Hello');
      await tester.pump();
      await tester.pumpAndSettle();
      // A second, rapid trigger of the same message — should replace the
      // first, not enqueue behind it.
      AppMessenger.show('Hello');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);

      // If the second call had queued rather than replaced, dismissing the
      // current one would reveal a second "Hello" right behind it.
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNothing);
    },
  );
}
