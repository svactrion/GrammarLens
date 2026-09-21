import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/data_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';

/// Counts resets instead of touching sqflite (no platform channel in tests).
class _FakeStorageService extends StorageService {
  int resets = 0;
  bool throwOnReset = false;

  @override
  Future<void> resetProgressData() async {
    if (throwOnReset) throw Exception('simulated storage failure');
    resets++;
  }
}

void main() {
  Future<void> pumpData(
    WidgetTester tester,
    StorageService storage, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness),
        home: DataScreen(storageService: storage),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the reset explanation and the reset button',
      (tester) async {
    await pumpData(tester, _FakeStorageService());

    expect(find.text('Data'), findsOneWidget); // page title
    expect(find.text('Reset progress'), findsOneWidget);
    expect(find.textContaining('Clears practice history and weak spots'),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reset progress data'),
        findsOneWidget);
  });

  testWidgets('asks for confirmation and Cancel resets nothing',
      (tester) async {
    final storage = _FakeStorageService();
    await pumpData(tester, storage);

    await tester.tap(find.text('Reset progress data'));
    await tester.pumpAndSettle();
    expect(find.text('Reset progress?'), findsOneWidget);
    expect(find.textContaining('This can\'t be undone.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Reset progress?'), findsNothing);
    expect(storage.resets, 0);
  });

  testWidgets('confirming Reset clears the progress data once', (tester) async {
    final storage = _FakeStorageService();
    await pumpData(tester, storage);

    await tester.tap(find.text('Reset progress data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Reset progress?'), findsNothing);
    expect(storage.resets, 1);
  });

  for (final brightness in Brightness.values) {
    group('destructive colors ($brightness)', () {
      Color? fill(ButtonStyleButton b) =>
          b.style?.backgroundColor?.resolve(const {});
      Color? label(ButtonStyleButton b) =>
          b.style?.foregroundColor?.resolve(const {});
      Color? border(ButtonStyleButton b) =>
          b.style?.side?.resolve(const {})?.color;

      testWidgets('the Reset progress data button uses the destructive role',
          (tester) async {
        await pumpData(tester, _FakeStorageService(), brightness: brightness);
        final scheme = buildAppTheme(brightness).colorScheme;

        final button = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Reset progress data'));
        expect(fill(button), scheme.destructive);
        expect(label(button), scheme.onDestructive);
      });

      testWidgets(
          'in the dialog, Reset is destructive and Cancel is a neutral text '
          'button, not primary', (tester) async {
        await pumpData(tester, _FakeStorageService(), brightness: brightness);
        final scheme = buildAppTheme(brightness).colorScheme;

        await tester.tap(find.text('Reset progress data'));
        await tester.pumpAndSettle();

        final reset = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Reset'));
        expect(fill(reset), scheme.destructive);
        expect(label(reset), scheme.onDestructive);

        final cancel = tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Cancel'));
        expect(label(cancel), scheme.onSurface);
        expect(label(cancel), isNot(scheme.primary));
        expect(border(cancel), scheme.onSurfaceVariant);
        expect(border(cancel), isNot(scheme.primary));
        expect(fill(cancel), isNull);
        // Nothing else in the dialog is a filled button but Reset.
        expect(
          find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(FilledButton)),
          findsOneWidget,
        );
      });

      testWidgets('Cancel stays above Reset, both full width', (tester) async {
        await pumpData(tester, _FakeStorageService(), brightness: brightness);
        await tester.tap(find.text('Reset progress data'));
        await tester.pumpAndSettle();

        final cancel =
            tester.getRect(find.widgetWithText(OutlinedButton, 'Cancel'));
        final reset =
            tester.getRect(find.widgetWithText(FilledButton, 'Reset'));
        expect(cancel.bottom, lessThan(reset.top));
        expect(cancel.width, reset.width);
        expect(cancel.height, 52);
      });
    });
  }
}
