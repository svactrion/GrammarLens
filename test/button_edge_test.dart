import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/screens/data_screen.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/destructive_dialog_actions.dart';

/// 1.2.0 Batch 8 (owner): the dark mode #5C7CFA edge (Q1) belongs to the
/// navy filled button only. A filled button with any other fill — the
/// destructive red (the confirm dialogs), the orange "See Premium" on
/// Review's used card, the orange forward action (`forwardButtonStyle`,
/// final screens A1) — has no edge. In light mode no filled button has one.
/// (Data's own "Reset progress data" is a low-intensity outlined button
/// since the final screens, brief §3; its dialog's confirm is the red one.)
class _Storage extends StorageService {
  @override
  Future<AiConsent?> getAiConsent() async => null;
}

/// Every enabled filled button on screen, as (label, fill, edge).
List<(String, Color?, BorderSide)> _buttons(WidgetTester tester) => [
      for (final e in find.byType(FilledButton).evaluate())
        if ((e.widget as FilledButton).onPressed != null)
          () {
            final material = tester.widget<Material>(find
                .descendant(
                    of: find.byWidget(e.widget),
                    matching: find.byType(Material))
                .first);
            final label = find
                .descendant(
                    of: find.byWidget(e.widget), matching: find.byType(Text))
                .evaluate()
                .map((t) => (t.widget as Text).data)
                .join();
            return (
              label,
              material.color,
              (material.shape! as OutlinedBorder).side,
            );
          }(),
    ];

void main() {
  for (final b in Brightness.values) {
    testWidgets(
        '${b.name}: the edge only on the navy fill — the theme\'s button, '
        'not the destructive or orange ones', (tester) async {
      tester.view.physicalSize = const Size(390, 1600) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(b),
        home: Scaffold(
          body: ListView(children: [
            FilledButton(onPressed: () {}, child: const Text('Navy')),
            Builder(
              builder: (context) => FilledButton(
                onPressed: () {},
                style: forwardButtonStyle(context),
                child: const Text('Forward'),
              ),
            ),
            DestructiveDialogActions(
              cancelLabel: 'Cancel',
              confirmLabel: 'Delete',
              onCancel: () {},
              onConfirm: () {},
            ),
            DailyPracticeCard(remaining: 0, onSeePremium: () {}),
            SizedBox(
                height: 700, child: DataScreen(storageService: _Storage())),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      final buttons = _buttons(tester);
      final labels = [for (final (l, _, _) in buttons) l];
      for (final label in ['Navy', 'Forward', 'Delete', 'See Premium']) {
        expect(labels, contains(label));
      }
      final palette = AppPalette.of(tester.element(find.text('Navy')));
      for (final (label, fill, side) in buttons) {
        final navy = fill == palette.button;
        final edged = side.style != BorderStyle.none && side.width > 0;
        if (b == Brightness.dark && navy) {
          expect(side.color, const Color(0xFF5C7CFA), reason: label);
        } else {
          expect(edged, isFalse, reason: '$label ($fill)');
        }
      }
      // The fills are what the names say.
      final scheme = Theme.of(tester.element(find.text('Navy'))).colorScheme;
      Color? fillOf(String l) => buttons.firstWhere((x) => x.$1 == l).$2;
      expect(fillOf('Navy'), palette.button);
      expect(fillOf('Delete'), scheme.destructive);
      expect(fillOf('Forward'), scheme.primary);
      expect(fillOf('See Premium'), scheme.primary);
    });
  }
}
