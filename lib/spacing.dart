/// Named spacing scale, alongside [buildAppTheme] in `theme.dart` — one
/// vocabulary for the gaps/padding new code writes, instead of each screen
/// picking its own numbers (docs/design-audit.md S6: "vertical rhythm
/// varies per screen; there is no spacing scale").
///
/// Scope note: this defines the scale for new code only. Migrating existing
/// screens' hardcoded `SizedBox`/`EdgeInsets` values onto it is separate,
/// deliberately unscheduled work (docs/roadmap.md v2.2 B-polish) — applying
/// it screen-by-screen belongs to that pass, not to introducing the scale
/// itself.
class Spacing {
  Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}
