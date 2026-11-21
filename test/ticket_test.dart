import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/haptics.dart';
import 'package:grammar_lens/widgets/ticket.dart';

/// X04: the ticket in its three states; the size never changes.
void main() {
  setUp(() => HapticMap.log = []);

  Future<void> pump(WidgetTester tester, TicketState state,
      {bool compact = false, VoidCallback? onTorn, VoidCallback? onTap}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 350,
            child: Ticket(
              state: state,
              compact: compact,
              title: '1 free practice',
              subtitle: 'Pick a weak spot below.',
              nextIn: const Duration(hours: 20, minutes: 41),
              onTorn: onTorn,
              onTap: onTap,
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('free: the title, the line, tappable', (tester) async {
    var taps = 0;
    await pump(tester, TicketState.free, onTap: () => taps++);
    await tester.pumpAndSettle();
    expect(find.text('1 free practice'), findsOneWidget);
    expect(find.text('TODAY’S TICKET'), findsOneWidget);
    expect(find.text('USED'), findsNothing);
    await tester.tap(find.byType(Ticket));
    expect(taps, 1);
  });

  testWidgets('used: "Used today", the stamp and the time to the next ticket',
      (tester) async {
    await pump(tester, TicketState.used);
    await tester.pumpAndSettle();
    expect(find.text('Used today'), findsOneWidget);
    expect(find.text('USED'), findsOneWidget);
    expect(find.text('20:41'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Next ticket in 20 h 41 min')),
        findsOneWidget);
  });

  testWidgets('tearing: the stub falls, the stamp lands, then onTorn',
      (tester) async {
    var torn = 0;
    await pump(tester, TicketState.free);
    await pump(tester, TicketState.tearing, onTorn: () => torn++);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ticket used!'), findsOneWidget);
    expect(torn, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(torn, 1);
    expect(find.text('USED'), findsOneWidget);
    expect(HapticMap.log, ['medium', 'light']);
  });

  testWidgets('the size is the same in all three states', (tester) async {
    for (final compact in [false, true]) {
      final sizes = <Size>{};
      for (final state in TicketState.values) {
        await pump(tester, state, compact: compact);
        await tester.pump(const Duration(seconds: 1));
        sizes.add(tester.getSize(find.byType(Ticket)));
      }
      expect(sizes, hasLength(1));
      expect(sizes.single,
          Size(350, Ticket.heightOf(compact: compact) + Ticket.lip));
    }
  });
}
