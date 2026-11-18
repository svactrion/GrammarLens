import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/theme.dart';

/// Fix round 3, D (SPEC SY03, v11): every text / background and icon /
/// background pair the screens use, in both themes, measured with WCAG's
/// contrast ratio: at least 4.5:1 for text and 3:1 for icons. Large text
/// (≥ 18 pt, or ≥ 14 pt bold) would need only 3:1; every text pair here is
/// held to 4.5:1. `FIX3_PRINT=1` prints the table that PROGRESS.md lists.
enum _Role {
  text(4.5),
  icon(3);

  final double min;
  const _Role(this.min);
}

typedef _Pair = (
  String,
  String,
  _Role,
  Color Function(AppColors),
  Color Function(AppColors)
);

double _luminance(Color c) {
  double ch(double v) =>
      v <= .04045 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
}

/// WCAG's ratio of [fg] over [bg] ([fg] blended onto [bg] if translucent).
double contrast(Color fg, Color bg) {
  final f = Color.alphaBlend(fg, bg);
  final a = _luminance(f), b = _luminance(bg);
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

void main() {
  final pairs = <_Pair>[
    // Body and secondary text on the page, cards and soft fills.
    for (final (bg, of) in <(String, Color Function(AppColors))>[
      ('page', (c) => c.page),
      ('card', (c) => c.card),
      ('sky', (c) => c.sky),
      ('cream', (c) => c.cream),
      ('orangeSoft', (c) => c.orangeSoft),
      ('goldSoft', (c) => c.goldSoft),
      ('greenSoft', (c) => c.greenSoft),
      ('redSoft', (c) => c.redSoft),
      ('lilac', (c) => c.lilac),
    ]) ...[
      ('text', bg, _Role.text, (c) => c.text, of),
      ('muted', bg, _Role.text, (c) => c.muted, of),
    ],
    // Accent text, icons and outlines (navy → light blue on dark, …).
    for (final (bg, of) in <(String, Color Function(AppColors))>[
      ('page', (c) => c.page),
      ('card', (c) => c.card),
    ]) ...[
      ('navyText', bg, _Role.text, (c) => c.navyText, of),
      ('orangeText', bg, _Role.text, (c) => c.orangeText, of),
      ('goldText', bg, _Role.text, (c) => c.goldText, of),
      ('greenText', bg, _Role.text, (c) => c.greenText, of),
      ('redText', bg, _Role.text, (c) => c.redText, of),
      ('green (icons)', bg, _Role.icon, (c) => c.green, of),
      ('red (icons)', bg, _Role.icon, (c) => c.red, of),
    ],
    ('navyText', 'sky', _Role.text, (c) => c.navyText, (c) => c.sky),
    (
      'orangeText',
      'orangeSoft',
      _Role.text,
      (c) => c.orangeText,
      (c) => c.orangeSoft
    ),
    ('orangeText', 'cream', _Role.text, (c) => c.orangeText, (c) => c.cream),
    ('goldText', 'goldSoft', _Role.text, (c) => c.goldText, (c) => c.goldSoft),
    (
      'greenText',
      'greenSoft',
      _Role.text,
      (c) => c.greenText,
      (c) => c.greenSoft
    ),
    ('redText', 'redSoft', _Role.text, (c) => c.redText, (c) => c.redSoft),
    // The soft fills' own text.
    ('onSky', 'sky', _Role.text, (c) => c.onSky, (c) => c.sky),
    (
      'onGreenSoft',
      'greenSoft',
      _Role.text,
      (c) => c.onGreenSoft,
      (c) => c.greenSoft
    ),
    ('onRedSoft', 'redSoft', _Role.text, (c) => c.onRedSoft, (c) => c.redSoft),
    ('onLilac', 'lilac', _Role.text, (c) => c.onLilac, (c) => c.lilac),
    // Fills that carry text or an icon.
    ('onNavy', 'navy', _Role.text, (c) => c.onNavy, (c) => c.navy),
    ('onNavyMuted', 'navy', _Role.text, (c) => c.onNavyMuted, (c) => c.navy),
    (
      'onRibbonMuted',
      'navy (ribbon)',
      _Role.text,
      (_) => AppColors.onRibbonMuted,
      (c) => c.navy
    ),
    (
      'onRibbonMuted',
      'ribbonTop',
      _Role.text,
      (_) => AppColors.onRibbonMuted,
      (_) => AppColors.ribbonTop
    ),
    ('onOrange', 'orange', _Role.text, (c) => c.onOrange, (c) => c.orange),
    (
      'onNavy (white)',
      'red (button)',
      _Role.text,
      (c) => c.onNavy,
      (c) => c.red
    ),
    (
      'onNavy (white)',
      'greenDeep (button)',
      _Role.text,
      (c) => c.onNavy,
      (c) => c.greenDeep
    ),
    (
      'onNavy (white tick)',
      'green (disc)',
      _Role.icon,
      (c) => c.onNavy,
      (c) => c.green
    ),
    ('onToast', 'toast', _Role.text, (c) => c.onToast, (c) => c.toast),
    // PF02's silver and bronze counters (their own light and dark pairs).
    (
      'PF02 silver counter',
      'its chip',
      _Role.text,
      (c) => c == AppColors.dark
          ? AppColors.onSilverSoftDark
          : AppColors.onSilverSoft,
      (c) =>
          c == AppColors.dark ? AppColors.silverSoftDark : AppColors.silverSoft
    ),
    (
      'PF02 bronze counter',
      'its chip',
      _Role.text,
      (c) => c == AppColors.dark
          ? AppColors.onBronzeSoftDark
          : AppColors.onBronzeSoft,
      (c) =>
          c == AppColors.dark ? AppColors.bronzeSoftDark : AppColors.bronzeSoft
    ),
    // A danger text button ("Leave", R10) on a dialog card.
    (
      'redText (danger button)',
      'card',
      _Role.text,
      (c) => c.redText,
      (c) => c.card
    ),
    (
      'onOrange (warning "!")',
      'orange (disc)',
      _Role.icon,
      (c) => c.onOrange,
      (c) => c.orange
    ),
    (
      'text',
      'night sheet (top)',
      _Role.text,
      (_) => const Color(0xFFFFFFFF),
      (c) => c.nightTop
    ),
  ];

  final rows = <String>[];
  for (final (name, theme) in [
    ('light', AppColors.light),
    ('dark', AppColors.dark),
  ]) {
    test('$name: every pair passes its ratio', () {
      final failures = <String>[];
      for (final (fg, bg, role, f, b) in pairs) {
        final r = contrast(f(theme), b(theme));
        rows.add('| $name | $fg | $bg | ${role.name} | '
            '${r.toStringAsFixed(2)} | ${role.min} |');
        if (r < role.min) {
          failures.add('$fg on $bg (${role.name}): ${r.toStringAsFixed(2)}');
        }
      }
      expect(failures, isEmpty);
    });
  }

  // The Material roles the older screens read (theme.dart).
  for (final b in Brightness.values) {
    test('${b.name}: the colour scheme\'s text roles pass 4.5:1', () {
      final s = buildAppTheme(b).colorScheme;
      final failures = <String>[];
      for (final (fg, bg, f, g) in <(String, String, Color, Color)>[
        (
          'onSurface',
          'surfaceContainerLow',
          s.onSurface,
          s.surfaceContainerLow
        ),
        (
          'onSurface',
          'surfaceContainerHigh',
          s.onSurface,
          s.surfaceContainerHigh
        ),
        (
          'onSurfaceVariant',
          'surfaceContainerLow',
          s.onSurfaceVariant,
          s.surfaceContainerLow
        ),
        (
          'onSurfaceVariant',
          'surfaceContainerHigh',
          s.onSurfaceVariant,
          s.surfaceContainerHigh
        ),
        (
          'secondary',
          'surfaceContainerLow',
          s.secondary,
          s.surfaceContainerLow
        ),
        (
          'secondary',
          'surfaceContainerHigh',
          s.secondary,
          s.surfaceContainerHigh
        ),
        (
          'onSecondaryContainer',
          'secondaryContainer',
          s.onSecondaryContainer,
          s.secondaryContainer
        ),
        ('onPrimary', 'primary', s.onPrimary, s.primary),
      ]) {
        final r = contrast(f, g);
        rows.add('| ${b.name} (scheme) | $fg | $bg | text | '
            '${r.toStringAsFixed(2)} | 4.5 |');
        if (r < 4.5) failures.add('$fg on $bg: ${r.toStringAsFixed(2)}');
      }
      expect(failures, isEmpty);
    });
  }

  tearDownAll(() {
    if (Platform.environment['FIX3_PRINT'] == '1') {
      // ignore: avoid_print
      print([
        '| Theme | Foreground | Background | Role | Ratio | Min |',
        '|---|---|---|---|---|---|',
        ...rows
      ].join('\n'));
    }
  });
}
