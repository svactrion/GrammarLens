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
September 2026, 8 steps, the name "Ada"). `DESIGN_MEASURE_CLOCK` (an ISO
date-time), `DESIGN_MEASURE_STEPS` and `DESIGN_MEASURE_NAME` override them.

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

```bash
flutter test tool/design_measure/greeting_test.dart
```

Home's greeting row: how much of the user's name is drawn, for 3 screens × 3
text sizes × 3 greetings × 4 names (`greeting.txt`). It depends only on
`home_fakes.dart`, so it also runs on the 1.0.0 tree
(`docs/design/greeting-fix/report.md`).

```bash
flutter test tool/design_measure/greeting_options_test.dart
```

Fix options for the greeting row at 320 pt, measured and rendered.

```bash
flutter test tool/design_measure/greeting_after_test.dart
```

The fixed greeting on the real Home at 320 × 568 (Medium and Large, three
names, afternoon).

```bash
flutter test tool/design_measure/batch3c/numbers_test.dart
```

```bash
flutter test tool/design_measure/batch3c/framing_test.dart
```

```bash
flutter test tool/design_measure/batch3c/render_test.dart
```

Batch 3c-A (`docs/design/batch3c/report.md`): the two mountain candidates.
- `numbers_test.dart` measures legs, turns, spacing, marker gaps, covered
  days, D2 markers for 28–31 days and free area
  (`candidate_numbers.json`).
- `framing_test.dart` compares F1 with the whole-mountain framing
  (`framing_numbers.txt`).
- `render_test.dart` renders the candidates in the new card shell and
  measures the plaque and contrast (`shell_numbers.txt`).

The candidates' geometry is in `batch3c/geometry.dart`. The avatar is never
mirrored (D4, confirmed by Batch 3c K2); the 3c-A images, made before that
decision, showed a mirrored snail.

```bash
flutter test tool/design_measure/scene_art_test.dart
```

A composition guide for AI image tools (`docs/design/scene-art/`): the whole
mountain in flat grays, the trail in red, the turns in blue, the summit as a
star (`mountain_guide.png`); a copy with the F1 window on days 3 and 25
(`mountain_guide_f1_windows.png`); a copy with the silhouettes only
(`mountain_guide_clean.png`); plus the dimensions (`numbers.txt`).

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
