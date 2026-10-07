import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/content_width.dart';
import 'package:grammar_lens/widgets/brand_scaffold.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';

/// P1 (1.1.0 release): on an iPad the content column is centred and capped
/// at [ContentWidth.maxContentWidth]; on an iPhone nothing changes.
void main() {
  group('ContentWidth.sidePadding', () {
    test('every iPhone keeps its own padding', () {
      for (final size in const [
        Size(320, 568),
        Size(375, 667),
        Size(375, 812),
        Size(430, 932),
        Size(440, 956),
      ]) {
        final base = ContentWidth.basePadding(size.width);
        expect(ContentWidth.sidePadding(size, base), base);
      }
    });

    test('an iPad caps the column and centres it', () {
      for (final size in const [
        Size(1032, 1376),
        Size(834, 1194),
        Size(744, 1133),
      ]) {
        final pad = ContentWidth.sidePadding(
            size, ContentWidth.basePadding(size.width));
        expect(size.width - 2 * pad, ContentWidth.maxContentWidth);
      }
    });

    test('a wide screen narrower than the cap keeps its own padding', () {
      const size = Size(640, 900);
      expect(ContentWidth.sidePadding(size, 28), 28);
    });
  });

  testWidgets(
      'BrandScaffold on a 13-inch iPad: the list is held to the column, the '
      'band stays full width', (tester) async {
    tester.view.physicalSize = const Size(1032, 1376) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const item = Key('item');
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const BrandScaffold(
        title: Text('Title'),
        children: [SizedBox(key: item, height: 40)],
      ),
    ));
    final r = tester.getRect(find.byKey(item));
    expect(r.width, ContentWidth.maxContentWidth);
    expect(r.center.dx, 1032 / 2);
    expect(tester.getSize(find.byType(PreferredSize).first).width, 1032);
    expect(tester.getRect(find.text('Title')).center.dx, 1032 / 2);
  });

  testWidgets('BrandScaffold on an iPhone is not wrapped', (tester) async {
    tester.view.physicalSize = const Size(430, 932) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const item = Key('item');
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const BrandScaffold(
        title: Text('Title'),
        children: [SizedBox(key: item, height: 40)],
      ),
    ));
    expect(tester.getSize(find.byKey(item)).width,
        430 - 2 * ContentWidth.basePadding(430));
    expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).appBar, isA<AppBar>());
  });

  group('P2: the floating nav bar', () {
    Future<Rect> pill(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: FloatingNavShell(
          body: const SizedBox.expand(),
          tabs: const [
            NavShellTab(icon: Icons.home, activeIcon: Icons.home, label: 'A'),
            NavShellTab(
                icon: Icons.person, activeIcon: Icons.person, label: 'B'),
          ],
          selectedIndex: 0,
          onTabChange: (_) {},
        ),
      ));
      // 1.2.0 (Q17): the bar is a solid box, no longer clipped glass.
      return tester.getRect(find.byKey(FloatingNavShell.barKey));
    }

    testWidgets('on a 13-inch iPad the pill spans the content column',
        (tester) async {
      final r = await pill(tester, const Size(1032, 1376));
      expect(r.width, ContentWidth.maxContentWidth);
      expect(r.center.dx, 1032 / 2);
    });

    testWidgets('on an iPhone it keeps 16 pt from each edge', (tester) async {
      final r = await pill(tester, const Size(430, 932));
      expect(r.left, 16);
      expect(r.right, 430 - 16);
    });
  });
}
