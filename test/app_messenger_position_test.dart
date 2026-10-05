import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/widgets/brand_scaffold.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';

/// Where a message appears (1.2.0 final pass, owner): above the floating
/// nav bar on a tab screen, Flutter's own place elsewhere, above the
/// keyboard while a field is being edited.
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });
  tearDown(AppMessenger.clear);

  const screen = Size(390, 844);
  const safeBottom = 34.0;

  void phone(WidgetTester tester, {double keyboard = 0}) {
    tester.view.physicalSize = screen * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view.viewPadding =
        const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);
  }

  /// The tab-root harness: the real shell over a tab screen with a field
  /// and a button that saves, closing the field, like Profile's name.
  Widget app({
    AppTextSize textSize = AppTextSize.medium,
    Brightness brightness = Brightness.light,
  }) =>
      MaterialApp(
        theme: buildAppTheme(brightness, textSize: textSize),
        scaffoldMessengerKey: AppMessenger.key,
        navigatorObservers: [AppMessenger.navigatorObserver],
        home: FloatingNavShell(
          body: const _TabRoot(),
          tabs: const [
            NavShellTab(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home'),
            NavShellTab(
                icon: Icons.history_outlined,
                activeIcon: Icons.history,
                label: 'Review'),
            NavShellTab(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile'),
          ],
          selectedIndex: 2,
          onTabChange: (_) {},
        ),
      );

  Rect message(WidgetTester tester) => tester.getRect(find.descendant(
      of: find.byType(SnackBar), matching: find.byType(Material)).first);

  Rect bar(WidgetTester tester) =>
      tester.getRect(find.byKey(FloatingNavShell.barKey));

  for (final brightness in Brightness.values) {
    testWidgets(
        'a tab screen: the message sits above the nav bar, the measured '
        'clearance\'s gap between them (${brightness.name})', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(brightness: brightness));
      await tester.pump();
      AppMessenger.show('Name saved');
      await tester.pumpAndSettle();
      expect(message(tester).bottom, lessThan(bar(tester).top));
      expect(bar(tester).top - message(tester).bottom,
          closeTo(NavBarClearance.gap, 0.5));
      // The bar keeps working under the message's margin.
      expect(
          tester
              .getRect(find.descendant(
                  of: find.byKey(FloatingNavShell.barKey),
                  matching: find.text('Profile')))
              .center
              .dy,
          greaterThan(message(tester).bottom));
    });
  }

  testWidgets(
      'a screen without the bar keeps Flutter\'s own place, and a pushed '
      'route over a tab screen counts as one', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      scaffoldMessengerKey: AppMessenger.key,
      home: const Scaffold(body: SizedBox.expand()),
    ));
    AppMessenger.show('Progress reset.');
    await tester.pumpAndSettle();
    final plain = message(tester);
    expect(plain.bottom, closeTo(screen.height - safeBottom - 10, 0.5));
    AppMessenger.clear();
    await tester.pumpAndSettle();

    await tester.pumpWidget(app());
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: SizedBox.expand())));
    await tester.pumpAndSettle();
    AppMessenger.show('Progress reset.');
    await tester.pumpAndSettle();
    expect(message(tester).bottom, closeTo(plain.bottom, 0.5));
  });

  testWidgets(
      'a results screen\'s bottom bar is still not covered '
      '(BrandScaffold.bottomBar)', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      scaffoldMessengerKey: AppMessenger.key,
      home: BrandScaffold(
        title: const Text('Results'),
        bottomBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(onPressed: () {}, child: const Text('Done')),
          ),
        ),
        children: const [Text('Body')],
      ),
    ));
    AppMessenger.show('Could not save your Daily Test results: x');
    await tester.pumpAndSettle();
    expect(message(tester).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(FilledButton)).top));
  });

  testWidgets(
      'a tab screen with the keyboard up: the message sits above the '
      'keyboard', (tester) async {
    phone(tester, keyboard: 336);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    AppMessenger.show('Could not save profile: disk full');
    await tester.pump(); // the frame the message waits for
    await tester.pumpAndSettle();
    expect(message(tester).bottom,
        closeTo(screen.height - 336 - NavBarClearance.gap, 0.5));
  });

  testWidgets(
      'Profile\'s Save: the editor closes as the message shows, so it goes '
      'above the bar, not above the keyboard that is going away',
      (tester) async {
    phone(tester, keyboard: 336);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Save'));
    // The keyboard is still reported while it slides away.
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Name saved'), findsOneWidget);
    expect(bar(tester).top - message(tester).bottom,
        closeTo(NavBarClearance.gap, 0.5));
  });

  testWidgets('a screen change drops a message still waiting for its frame',
      (tester) async {
    phone(tester, keyboard: 336);
    await tester.pumpWidget(app());
    await tester.pump();
    AppMessenger.show('Late');
    AppMessenger.clear();
    await tester.pumpAndSettle();
    expect(find.text('Late'), findsNothing);
  });

  for (final width in const [320.0, 390.0]) {
    testWidgets(
        '${width.toInt()} pt, Large text: a long message wraps and stays '
        'clear of the nav bar; Dismiss is at least 44 pt', (tester) async {
      phone(tester);
      tester.view.physicalSize = Size(width, 844) * 3;
      await tester.pumpWidget(app(textSize: AppTextSize.large));
      await tester.pump();
      AppMessenger.show('Could not change this setting: the database is '
          'locked by another operation, please try again in a moment.');
      await tester.pumpAndSettle();
      final text = tester.getRect(find.textContaining('Could not change'));
      expect(text.height, greaterThan(40), reason: 'wraps');
      expect(message(tester).bottom, lessThan(bar(tester).top));
      expect(tester.takeException(), isNull);

      final dismiss = tester.getSize(find.ancestor(
          of: find.text('Dismiss'), matching: find.byType(TextButton)));
      expect(dismiss.height, greaterThanOrEqualTo(44));
      expect(dismiss.width, greaterThanOrEqualTo(44));
    });
  }
}

class _TabRoot extends StatefulWidget {
  const _TabRoot();

  @override
  State<_TabRoot> createState() => _TabRootState();
}

class _TabRootState extends State<_TabRoot> {
  bool _editing = true;

  @override
  Widget build(BuildContext context) => BrandScaffold(
        isTabRoot: true,
        title: const Text('Profile'),
        children: [
          if (_editing) const TextField(),
          TextButton(
            onPressed: () {
              setState(() => _editing = false);
              AppMessenger.show('Name saved');
            },
            child: const Text('Save'),
          ),
        ],
      );
}
