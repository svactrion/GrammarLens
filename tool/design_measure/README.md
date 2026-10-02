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

*Removed in Scene Art Stage 1 (2026-10-01), with the coded mountain they
measured:* `scene_art_test.dart` (the composition guide in
`docs/design/scene-art/`), `batch3c/after_numbers_test.dart` and
`batch3c/capacity_test.dart`. Their outputs stay in `docs/design/`, and
the code is in the history before that commit. `after_test.dart`,
`batch3c/after_render_test.dart` and `batch3c/render_test.dart` still run;
they now render the illustrated scene, so their images no longer match the
3b/3c reports.

```bash
DESIGN_MEASURE_OUT=docs/design/scene-art/stage1 flutter test tool/design_measure/scene_art/numbers_test.dart
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/scene_art_stage1 flutter test tool/design_measure/scene_art/home_render_test.dart
```

Scene Art Stage 1 (`docs/design/scene-art/stage1/`), on the product's own
classes:
- `numbers_test.dart`: per card width, a day's step, the gap between
  passed-day dots, the avatar's size on each day and at the summit, the
  day the summit comes into view, and the added asset bytes
  (`numbers.txt`);
- `home_render_test.dart`: the real Home (shell, HomeScreen, ClimbCard)
  at 320 and 375 pt, light and dark, days 1, 15 and 31 of October 2026,
  each cut to the climb card at 3x, with the images really decoded.
  `tool/scene_art/stage1_sheet.py` turns those PNGs into the report's
  JPEGs and `overview.jpg`.

```bash
DESIGN_MEASURE_OUT=docs/design/scene-art/stage2 flutter test tool/design_measure/scene_art/stage2_numbers_test.dart
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/scene_art_stage2 DESIGN_MEASURE_SCREENS=375 DESIGN_MEASURE_DAYS=1,10,20,31 flutter test tool/design_measure/scene_art/home_render_test.dart
```

Scene Art Stage 2 (`docs/design/scene-art/stage2/`).
- `stage2_numbers_test.dart` measures, on the real Home on day 31 at 320,
  375 and 430 pt, the flag's box against the month and step chips,
  the plaque and the avatar on the summit, plus the object assets' bytes
  (`numbers.txt`).
- `home_render_test.dart` takes its screens and days from
  `DESIGN_MEASURE_SCREENS` and `DESIGN_MEASURE_DAYS` (Stage 1's when
  unset) and decodes the object assets too.
- `tool/scene_art/stage1_sheet.py stage2 375 1,10,20,31` makes the JPEGs
  and `overview.jpg`.

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

```bash
DESIGN_MEASURE_OUT=docs/design/batch6/plaque flutter test tool/design_measure/batch6/plaque_numbers_test.dart
```

Batch 6 Batch 0, step 2 (`docs/design/batch6/batch0-report.md`): the
plaque's rounded corners. Per text size, the plaque's height, the asked
radius (`ClimbCard.frameRadius × plaqueRadiusShare`), the radius each
corner gets, and the largest share that no corner fits down
(`plaque_numbers.txt`). The before/after images come from
`scene_art/home_render_test.dart` (which now also writes the plaque's
box) run on the commit before and after the change, then
`tool/scene_art/batch6_plaque_sheet.py`.

```bash
DESIGN_MEASURE_OUT=docs/design/batch6 flutter test tool/design_measure/batch6/medal_numbers_test.dart
```

```bash
DESIGN_MEASURE_OUT=docs/design/batch6 flutter test tool/design_measure/batch6/zoom_numbers_test.dart
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch6_sheet flutter test tool/design_measure/batch6/month_card_render_test.dart
```

Batch 6 Batch 0, step 3 (`docs/design/batch6/batch0-report.md`):
- `medal_numbers_test.dart`: rule v1's maximum and thresholds for 28–31
  days, the score bands, and the near-miss candidates (which scores show
  the line); checks a next-tier helper against `tierFor`
  (`medal_numbers.txt`).
- `zoom_numbers_test.dart`: K-c (whole image, fitted to the window's
  height) against `ClimbCamera`'s daily framing on the real Home at 320 /
  375 / 430 pt: scales, offsets, s0, the avatar's place and size, the
  daily layer's pixel size (`zoom_numbers.txt`).
- `month_card_render_test.dart` with `month_card_prototype.dart`: the
  month card prototype (fullest summary card, fresh-start card) as a real
  modal bottom sheet over the real Home, the climb card redrawn in K-c
  under the barrier; 3 screens × light/dark × 3 text sizes × Home at its
  top or scrolled to the card; sheet height, content height, scrolling,
  overflow, how much of the window shows (`month_card_numbers.txt`).
  `tool/scene_art/batch6_sheet_sheet.py` writes the JPEGs to
  `docs/design/batch6/sheet/`. The prototype is for measuring only.
