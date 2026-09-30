# design_measure

Reproduces the numbers and images of the 1.1.0 design reports
(`docs/design/batch3b/report.md`). Measuring code only: nothing in `lib/`
imports it, and `flutter test` does not run it (it runs `test/` only).

Run from the repository root. Output goes to `build/design_measure/`
(git-ignored), or to `DESIGN_MEASURE_OUT` when it is set.

```bash
flutter test tool/design_measure/report_test.dart
```

R1 (curve), R2 (framing) and R6 (markers): `report_numbers.txt` and the
report's images.

```bash
flutter test tool/design_measure/sweep_test.dart
```

R1's steepening sweep: `sweep.txt`.

```bash
flutter test tool/design_measure/home_layout_test.dart
```

Home's vertical layout at 320 × 568, 375 × 667, 375 × 812 and 430 × 932 for
each text size: `home_layout.txt`. The inputs default to Batch 0's (15
September 2026, 8 steps). `DESIGN_MEASURE_CLOCK` (an ISO date-time) and
`DESIGN_MEASURE_STEPS` override them.

```bash
flutter test tool/design_measure/header_width_test.dart
```

Header text widths per text size: `header_width.txt`.

```bash
flutter test tool/design_measure/after_test.dart
```

The "after" images of the real product (Home at 320 × 568, 375 × 667 and
430 × 932, the mountain window at the three card widths, the markers near
the summit for 28–31 days). `home_layout_test.dart` also reports the
avatar's size and one day's step on screen.

To write the images straight into the report folder:

```bash
DESIGN_MEASURE_OUT=docs/design/batch3b flutter test tool/design_measure/report_test.dart
```

```bash
DESIGN_MEASURE_OUT=docs/design/batch3b flutter test tool/design_measure/after_test.dart
```

**Text size** is applied only the way the app applies it,
`buildAppTheme(textSize:)`, never with a `MediaQuery.textScaler` on top.
Batch 3a's tool did both, and so measured every size one step too large
(Batch 3b report, R4).

**What is a copy:** `scene.dart` copies 1.0's `_MountainPainter`, so candidate
geometries can be drawn without changing the product (`report_test.dart`
uses it; `after_test.dart` renders the product itself). `geo.dart` holds the
Batch 3a geometry and measuring rules.
