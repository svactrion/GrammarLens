import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/data_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';

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
  Future<void> pumpData(WidgetTester tester, StorageService storage) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: DataScreen(storageService: storage)),
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
    expect(find.widgetWithText(OutlinedButton, 'Reset progress data'),
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

  testWidgets('confirming Reset clears the progress data once',
      (tester) async {
    final storage = _FakeStorageService();
    await pumpData(tester, storage);

    await tester.tap(find.text('Reset progress data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Reset progress?'), findsNothing);
    expect(storage.resets, 1);
  });
}
