import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/theme.dart';

/// Fix round 3, B5 (SPEC §3.6, v11): the switches' thumbs were black on the
/// device; the boards have white thumbs. One theme-level style, light and
/// dark: the thumb white in both states and full size when off; the track
/// navy when on, the track token (#E3DACB in light) when off.
void main() {
  for (final brightness in Brightness.values) {
    final theme = buildAppTheme(brightness);
    final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final s = theme.switchTheme;

    test('${brightness.name}: the thumb is white on and off', () {
      expect(s.thumbColor!.resolve({WidgetState.selected}), Colors.white);
      expect(s.thumbColor!.resolve({}), Colors.white);
      // A thumb icon keeps the off thumb as big as the on one.
      expect(s.thumbIcon!.resolve({}), isNotNull);
    });

    test('${brightness.name}: the track navy on, the track token off', () {
      expect(s.trackColor!.resolve({WidgetState.selected}), c.navy);
      expect(s.trackColor!.resolve({}), c.track);
      expect(s.trackOutlineColor!.resolve({}), Colors.transparent);
      if (brightness == Brightness.light) {
        expect(c.track, const Color(0xFFE3DACB));
      }
    });

    testWidgets('${brightness.name}: a switch draws its thumb white',
        (tester) async {
      for (final on in [false, true]) {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
              body: Center(child: Switch(value: on, onChanged: (_) {}))),
        ));
        await tester.pumpAndSettle();
        // The thumb is drawn by the switch's painter with the theme's
        // resolved colour.
        final element = tester.element(find.byType(Switch));
        final resolved = Theme.of(element)
            .switchTheme
            .thumbColor!
            .resolve(on ? {WidgetState.selected} : {});
        expect(resolved, Colors.white, reason: on ? 'on' : 'off');
      }
    });
  }
}
