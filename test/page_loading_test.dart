import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/loading_view.dart';

/// A page's loading state keeps the page's own header (final screens A3).
void main() {
  testWidgets(
      'the header sits at the top of the page, left-aligned, the loading '
      'message under it, and the app bar has no title', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const PageLoading(
        header: Text('Topic Practice'),
        message: 'Preparing your questions…',
      ),
    ));
    await tester.pump();
    final header = tester.getRect(find.text('Topic Practice'));
    final message = tester.getRect(find.text('Preparing your questions…'));
    expect(header.left, lessThan(30));
    expect(message.top, greaterThan(header.bottom));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title, isA<SizedBox>());
  });

  test('Topic Practice and the weak spot detail load with PageLoading', () {
    for (final file in [
      'lib/screens/topic_practice_screen.dart',
      'lib/screens/weak_spot_detail_screen.dart',
    ]) {
      final source = File(file).readAsStringSync();
      expect(source, contains('PageLoading('), reason: file);
      expect(source, isNot(contains('LoadingView(')), reason: file);
    }
  });
}
