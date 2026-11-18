import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/motion.dart';
import 'package:grammar_lens/widgets/rest_scene.dart';
import 'package:grammar_lens/widgets/ticket.dart';

import 'support/fix3_render.dart';

/// Fix round 5, items 1 and 2 (SPEC V24f v13 "Panel", §1.27; V24 v13,
/// §1.30): V24f's panel is the ticket deck, built from X04's shapes — the
/// small used ticket and four tickets offset 7 pt diagonally — and the
/// night panel is the same in light and dark. With `FIX5_CAPTURE=1` the
/// renders go to `build/fix5-captures/`.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final tr = lookupAppLocalizations(const Locale('tr'));

  Widget deck({bool gathered = false, String title = 'Missing Article'}) =>
      Scaffold(
        backgroundColor: AppColors.restPanel,
        body: Center(
          child: SizedBox(
            width: 326,
            child: TicketDeck(
              eyebrow: 'NEXT UP',
              title: title,
              line: en.restAiFeedback,
              count: '+4',
              countLabel: 'TODAY',
              semantics: en.restDeckSemantics(4),
              gathered: gathered,
            ),
          ),
        ),
      );

  Offset at(WidgetTester tester, int i) =>
      tester.getTopLeft(find.byKey(TicketDeck.ticketKey(i)));

  group('the small used ticket (X04 used, made small)', () {
    testWidgets(
        '150 × 50 with its lip: USED, the time to the next ticket, '
        'NEXT; one label for the screen reader', (tester) async {
      await pumpFix3(
          tester,
          const Scaffold(
            backgroundColor: AppColors.restPanel,
            body: Center(
                child:
                    MiniUsedTicket(nextIn: Duration(hours: 10, minutes: 24))),
          ));
      final ticket = find.byType(MiniUsedTicket);
      expect(tester.getSize(ticket),
          const Size(MiniUsedTicket.width, MiniUsedTicket.height + 3));
      expect(find.text('USED'), findsOneWidget);
      expect(find.text('10:24'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(tester.getSemantics(ticket).label,
          'Used today. Next ticket in 10 h 24 min');
      // The stamp in the body, the time in the slot right of the tear.
      final box = tester.getRect(ticket);
      expect(tester.getRect(find.text('USED')).right,
          lessThan(box.left + MiniUsedTicket.body));
      expect(tester.getRect(find.text('10:24')).left,
          greaterThan(box.left + MiniUsedTicket.body));
      expect(tester.takeException(), isNull);
      await fix5Capture(tester, 'X04-mini-used');
    });

    testWidgets('Turkish: "KULLANILDI" fits the body and stays readable',
        (tester) async {
      await pumpFix3(
          tester,
          const Scaffold(
            backgroundColor: AppColors.restPanel,
            body: Center(
                child: MiniUsedTicket(nextIn: Duration(hours: 9, minutes: 5))),
          ),
          locale: const Locale('tr'));
      final stamp = find.text(tr.ticketStamp);
      expect(stamp, findsOneWidget);
      final shown = tester.getRect(stamp);
      final laid = tester.getSize(stamp);
      final box = tester.getRect(find.byType(MiniUsedTicket));
      expect(shown.right, lessThanOrEqualTo(box.left + MiniUsedTicket.body));
      // Scaled down at most a little (its own size is 10.5 pt).
      expect(shown.width / laid.width, greaterThan(.85));
      expect(find.text('9:05'), findsOneWidget);
      expect(find.text(tr.ticketNext), findsOneWidget);
      expect(tester.takeException(), isNull);
      await fix5Capture(tester, 'X04-mini-used-tr');
    });

    testWidgets('Arabic: mirrored like X04, no overflow', (tester) async {
      await pumpFix3(
          tester,
          const Scaffold(
            body: Center(
                child: MiniUsedTicket(nextIn: Duration(hours: 3, minutes: 0))),
          ),
          locale: const Locale('ar'));
      expect(tester.takeException(), isNull);
      // The slot (with the time) on the start side, the body on the end.
      final box = tester.getRect(find.byType(MiniUsedTicket));
      expect(tester.getRect(find.text('3:00')).right,
          lessThan(box.right - MiniUsedTicket.body));
    });
  });

  group('the deck (four X04 tickets, 7 pt apart)', () {
    testWidgets(
        'settled: the back tickets 7 pt apart diagonally; the front '
        'one with NEXT UP, the weak spot, the line and +4 / TODAY',
        (tester) async {
      await pumpFix3(tester, deck());
      expect(tester.getSize(find.byType(TicketDeck)).height, TicketDeck.height);
      for (var i = 1; i < TicketDeck.tickets; i++) {
        expect(at(tester, i) - at(tester, 0), Offset(7.0 * i, 7.0 * i));
      }
      final front = find.byKey(TicketDeck.ticketKey(0));
      for (final text in [
        'NEXT UP',
        'Missing Article',
        'AI feedback on every answer',
        '+4',
        'TODAY'
      ]) {
        expect(find.descendant(of: front, matching: find.text(text)),
            findsOneWidget,
            reason: text);
      }
      // The front ticket is the deck's width less the three offsets; its
      // stub is X04's at this height.
      expect(tester.getSize(front).width, 326 - 21);
      expect(tester.getSemantics(find.byType(TicketDeck)).label,
          'Premium: 4 more practices today');
      expect(tester.takeException(), isNull);
      await fix5Capture(tester, 'V24f-deck');
    });

    testWidgets('a long weak spot stays on one line (…)', (tester) async {
      await pumpFix3(tester,
          deck(title: 'The With Superlatives And Comparatives Together'));
      final title =
          find.text('The With Superlatives And Comparatives Together');
      expect(tester.getSize(title).height, lessThan(30));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'on entry the back tickets settle 60 ms apart, the front one '
        'last', (tester) async {
      await pumpFix3(tester, deck(), settle: false);
      double opacity(int i) => tester
          .widget<Opacity>(find
              .descendant(
                  of: find.byKey(TicketDeck.ticketKey(i)),
                  matching: find.byType(Opacity))
              .first)
          .opacity;
      await tester.pump(const Duration(milliseconds: 30));
      // The back-most has started; the front one has not.
      expect(opacity(3), greaterThan(0));
      expect(opacity(1), 0);
      expect(opacity(0), 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(opacity(1), greaterThan(0));
      expect(opacity(0), 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(opacity(0), greaterThan(0));
      await tester.pumpAndSettle();
      for (var i = 0; i < TicketDeck.tickets; i++) {
        expect(opacity(i), 1);
      }
    });

    testWidgets(
        'gathered (on Wake): into the front ticket in 150 ms, and '
        'back', (tester) async {
      await pumpFix3(tester, deck());
      await pumpFix3(tester, deck(gathered: true), settle: false);
      await tester.pump(const Duration(milliseconds: 75));
      final half = at(tester, 3) - at(tester, 0);
      expect(half.dx, greaterThan(0));
      expect(half.dx, lessThan(21));
      await tester.pump(const Duration(milliseconds: 80));
      for (var i = 1; i < TicketDeck.tickets; i++) {
        expect(at(tester, i), at(tester, 0));
      }
      await pumpFix3(tester, deck());
      expect(at(tester, 3) - at(tester, 0), const Offset(21, 21));
    });

    testWidgets('Reduce Motion: settled at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpFix3(tester, deck(), settle: false);
      await tester.pump();
      expect(at(tester, 3) - at(tester, 0), const Offset(21, 21));
    });

    testWidgets('the glint runs only while loops are on', (tester) async {
      final loops = AppMotion.loopsEnabled;
      addTearDown(() => AppMotion.loopsEnabled = loops);
      AppMotion.loopsEnabled = true;
      await pumpFix3(tester, deck(), settle: false);
      await tester.pump(const Duration(seconds: 1));
      expect(
          find.descendant(
              of: find.byKey(TicketDeck.ticketKey(0)),
              matching: find.byType(ClipPath)),
          findsOneWidget);
      AppMotion.loopsEnabled = false;
      await pumpFix3(tester, const SizedBox());
      await pumpFix3(tester, deck());
      expect(
          find.descendant(
              of: find.byKey(TicketDeck.ticketKey(0)),
              matching: find.byType(ClipPath)),
          findsNothing);
    });

    testWidgets('Arabic: the deck mirrored, the texts readable',
        (tester) async {
      await pumpFix3(tester, deck(), locale: const Locale('ar'));
      expect(tester.takeException(), isNull);
      // The back tickets step down to the left.
      expect((at(tester, 3) - at(tester, 0)).dy, 21);
      final front = tester.getRect(find.byKey(TicketDeck.ticketKey(0)));
      final back = tester.getRect(find.byKey(TicketDeck.ticketKey(3)));
      expect(back.left, lessThan(front.left));
    });
  });

  group('the night panel is the same in light and dark', () {
    for (final premium in [false, true]) {
      testWidgets(premium ? 'V24' : 'V24f', (tester) async {
        Color? panel;
        for (final brightness in Brightness.values) {
          await pumpFix3(
              tester,
              Scaffold(
                body: SingleChildScrollView(
                  child: RestScene(
                    theme: ClimbThemes.emberPeak,
                    days: 30,
                    steps: 3,
                    hero: Avatar.fox,
                    name: 'Ada',
                    testLine: en.restTestLine(4, 5, 9),
                    practiceLine: en.restSessionsLine(5, 5),
                    clock: () => DateTime(2026, 11, 18, 13, 36),
                    offer: premium
                        ? null
                        : RestOffer(
                            weakSpot: 'Missing Article',
                            trialDays: 7,
                            topics: 14,
                            onWake: () async {}),
                  ),
                ),
              ),
              brightness: brightness);
          final decoration = tester
              .widget<DecoratedBox>(find.byKey(RestScene.sheetKey))
              .decoration as BoxDecoration;
          expect(decoration.color, AppColors.restPanel);
          expect(decoration.gradient, isNull);
          panel ??= decoration.color;
          expect(decoration.color, panel);
          expect(tester.takeException(), isNull);
        }
      });
    }
  });
}
