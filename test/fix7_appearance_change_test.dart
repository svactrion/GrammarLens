import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/screens/mountain_intro_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/app_sheet.dart';

/// Fix round 7, item 2 (SPEC §3.6). Seen in the iPad tour: with N01 (and
/// the length picker) open, the system switched from light to dark; the
/// sheet kept its cream background while its text took the dark theme, so
/// the title and "Not now" were almost unreadable until it was closed.
///
/// Cause: `showAppSheet` passed `AppColors.of(context).card` of the screen
/// that opened it as the route's background, a value fixed for the life
/// of the route. Now the sheet's surface reads the colour in its own build.
///
/// The mountain intro was suspected of the same; its "dark" capture in the
/// tour was taken before the app had drawn the new appearance at all (the
/// whole screen, the status bar and the light image included). It reads
/// its colours in `build`, and the test below holds that.
void main() {
  const sheetTitle = 'When do you have 2 minutes?';

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> switchTo(WidgetTester tester, Brightness brightness) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    await tester.pumpAndSettle();
  }

  /// The colour the sheet's surface is painted with: the nearest coloured
  /// Material above the sheet's content.
  Color sheetSurface(WidgetTester tester) {
    final materials = tester
        .widgetList<Material>(find.ancestor(
            of: find.text(sheetTitle), matching: find.byType(Material)))
        .where((m) => m.color != null && m.color!.a > 0);
    return materials.first.color!;
  }

  Color titleColor(WidgetTester tester) =>
      tester.widget<Text>(find.text(sheetTitle)).style!.color!;

  Widget opener() => Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAppSheet<void>(
                context: context,
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(sheetTitle,
                      style: TextStyle(color: AppColors.of(context).text)),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

  for (final (from, to) in [
    (Brightness.light, Brightness.dark),
    (Brightness.dark, Brightness.light),
  ]) {
    testWidgets(
        'a sheet opened in ${from.name} follows a switch to ${to.name} '
        'while open: its surface and its text', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = from;
      await pumpApp(tester, opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final before =
          from == Brightness.light ? AppColors.light : AppColors.dark;
      final after = to == Brightness.light ? AppColors.light : AppColors.dark;
      expect(sheetSurface(tester), before.card);
      expect(titleColor(tester), before.text);
      await switchTo(tester, to);
      expect(sheetSurface(tester), after.card);
      expect(titleColor(tester), after.text);
      // Still a sheet: rounded at the top, closed by a tap outside.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      expect(find.text(sheetTitle), findsNothing);
    });
  }

  for (final (from, to) in [
    (Brightness.light, Brightness.dark),
    (Brightness.dark, Brightness.light),
  ]) {
    testWidgets(
        'the mountain intro follows a switch from ${from.name} to ${to.name} '
        'while open: its page, its panel and its title', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = from;
      await pumpApp(
          tester,
          MountainIntroScreen(
            theme: ClimbThemes.emberPeak,
            days: 30,
            monthName: 'November',
            hero: Avatar.fox,
            onStart: () {},
          ));
      Color panel() => (tester
              .widgetList<Container>(find.ancestor(
                  of: find.text('This month’s mountain'),
                  matching: find.byType(Container)))
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .first)
          .color!;
      Color title() =>
          tester.widget<Text>(find.text('This month’s mountain')).style!.color!;
      Color page() =>
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;
      final before =
          from == Brightness.light ? AppColors.light : AppColors.dark;
      final after = to == Brightness.light ? AppColors.light : AppColors.dark;
      expect(panel(), before.page);
      expect(title(), before.text);
      expect(page(), before.page);
      await switchTo(tester, to);
      expect(panel(), after.page);
      expect(title(), after.text);
      expect(page(), after.page);
    });
  }
}
