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

**Removed in 1.2.0 Batch 2** (owner decision Q16: the stadium plaque
replaced the trail sign, so `TrailSignBorder` and `plaqueRadiusShare` are
gone, and so are this tool and `tool/scene_art/batch6_plaque_sheet.py`;
both are in git history before the 1.2.0 Batch 2 commits). Kept here as
the record of what it measured: Batch 6 Batch 0, step 2
(`docs/design/batch6/batch0-report.md`): the plaque's rounded corners. Per text size, the plaque's height, the asked
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

Batch 6 build (`docs/build-log.md`, 2026-10-02):

```bash
build/scene_art_venv/bin/python tool/scene_art/kc_band_colors.py
```

M11: each theme's K-c band colour per mode from its background asset's
side edges (`docs/design/batch6/kc_bands.txt`, `.json`). *Replaced by M22
(2026-10-02): the product no longer has these colours; the tool and its
output stay as the record.*

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch6_kc_bands flutter test tool/design_measure/batch6/kc_bands_render_test.dart
```

The K-c bands at 430 pt in light mode, four themes: the product's single
colour, and a vertical gradient painted over the bands for comparison only
(then `tool/scene_art/batch6_kc_bands_sheet.py` →
`docs/design/batch6/kc_bands_430_light.jpg`).

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch6_scroll flutter test tool/design_measure/batch6/scroll_check_test.dart
```

Batch 6 step 5's stop condition (M10): after Home scrolls for the month
card, how much of the Today card (the Daily Test entry) is on screen, and
how much of the mountain window shows above Batch 0's summary-card
prototype, for three scrolls (`card`, `peek`, `today`) at three screens and
text sizes (`scroll_check.txt`); then `tool/scene_art/batch6_scroll_sheet.py`
→ `docs/design/batch6/scroll/`. The renders show Home's daily framing and
Batch 0's prototype copy; only the geometry is measured.

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch6_card flutter test tool/design_measure/batch6/month_card_real_render_test.dart
```

Batch 6 step B: the real month card, opened by the real Home after the
M21 scroll, both variants, three screens × light/dark × three text sizes:
sheet and content heights, scrolling, overflow, the Today card's visible
height, the mountain window above the sheet
(`month_card_real_numbers.txt`); then `tool/scene_art/batch6_card_sheet.py`
→ `docs/design/batch6/card/`.

```bash
build/scene_art_venv/bin/python tool/scene_art/export_blur.py
```

```bash
build/scene_art_venv/bin/python tool/scene_art/check_theme.py --blur
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch6_blur flutter test tool/design_measure/batch6/kc_blur_render_test.dart
```

Batch 6, M22: the K-c blurred backdrops. `export_blur.py` writes the eight
`assets/climb/<theme>/background_<mode>_blur.webp` (192 × 256, sigma =
`STRENGTH` × width) and `docs/design/batch6/blur/blur_assets.txt`; with
`--candidates` it writes light / medium / strong versions to
`build/scene_art/blur/`. `check_theme.py --blur` checks the assets exist
and match their sources (`blur_check.txt`). The render shows K-c at
430 pt for four themes × two modes × three strengths, then
`tool/scene_art/batch6_blur_sheet.py` writes `blur_430_<mode>.jpg` and the
seam measure `blur_seam.txt`.

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch6_card DESIGN_MEASURE_CARD_SCREENS=375x667 flutter test tool/design_measure/batch6/month_card_real_render_test.dart
```

The same real-card measure for the iPhone SE size (375 × 667, safe areas
20 / 0): `month_card_real_numbers_375x667.txt`; then
`tool/scene_art/batch6_card_sheet.py se` → `overview_375x667.jpg`.
`DESIGN_MEASURE_CARD_SCREENS` takes any of 320x568, 375x812, 430x932,
375x667.

## Batch 5 Batch 0 (`docs/design/batch5/batch0-report.md`)

The composed medals need building first (`tool/medals/README.md`):

```bash
build/scene_art_venv/bin/python tool/medals/build_medals.py docs/design/medals/source build/medals/png
```

```bash
build/scene_art_venv/bin/python tool/medals/medal_assets.py
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_sites flutter test tool/design_measure/batch5/medal_sites_test.dart
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_welcome flutter test tool/design_measure/batch5/welcome_result_test.dart
```

```bash
DESIGN_MEASURE_OUT=docs/design/batch5 flutter test tool/design_measure/batch5/save_point_numbers_test.dart
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_labels flutter test tool/design_measure/batch5/save_point_label_test.dart
```

- `medal_sites_test.dart` with `batch5/medal_prototype.dart`: today's
  medal places (Profile's collection, the month card, the Day-0 Welcome
  card) and tool-only copies of them with the composed medals, read from
  `build/medals/webp/512/` (no asset is added); 320 / 375 / 430 pt, light
  and dark, three text sizes; the month card's content height with each
  medal option against the real `MonthCardSheet` (`medal_sites.txt`).
- `welcome_result_test.dart`: the real Day-0 result screen with the
  Welcome card; where the card is at the list's scroll top
  (`welcome_result.txt`).
- `save_point_numbers_test.dart`: the step each save point, the flag and
  C5 are reached on in 28–31-day months, and the resting avatar against
  the signpost's box (`save_point_numbers.txt`; needs
  `tool/scene_art/batch5_signpost.py` first).
- `save_point_label_test.dart`: N6's label as a prototype over the real
  Home in two placements, what it touches (`save_point_labels.txt`).

Then `tool/scene_art/batch5_sheet.py sites|welcome|labels` makes the
report's JPEGs and copies the text files into `docs/design/batch5/`.

## Batch 5 build

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_card DESIGN_MEASURE_CARD_SCREENS=320x568,375x812,430x932,375x667 flutter test tool/design_measure/batch6/month_card_real_render_test.dart
```

Step 3 (N16): the real month card with the 48 pt medal, then
`tool/scene_art/batch5_sheet.py card` (renders and `card_compare.txt`
against Batch 6's numbers, `docs/design/batch5/card/`).

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_profile flutter test tool/design_measure/batch5/profile_render_test.dart
```

Correction round step 6 (N33, N34; replaced step 4's N17 rows): the real
`MonthlyMedalCollection`, the shelf and the threshold bar, in three cases
(only the running month; the Welcome badge and three months; twelve
months), 320 / 375 / 430 pt, light and dark, the twelve months at 320 in
three text sizes, and the medal detail open on a whole screen; then
`batch5_sheet.py profile` (`docs/design/batch5/profile/`).

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_celebration flutter test tool/design_measure/batch5/celebration_render_test.dart
```

Step 5 (N15): the real celebration layer over the real result screen
(Welcome, Bronze, Silver, Gold, Silver on Ember Peak), 320 × 568 /
375 × 812 / 430 × 932, light and dark, three text sizes, then
`batch5_sheet.py celebration` (`docs/design/batch5/celebration/`).

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_labels_real flutter test tool/design_measure/batch5/label_real_render_test.dart
```

Step 6 (N6, N19): the real save point label on the real Home, which is
given a pending step so it hops onto each save point (the flag on the
31st); what the label touches; then `batch5_sheet.py labels_real`
(`docs/design/batch5/labels_real/`).

## Batch 5 device-check round

```bash
DESIGN_MEASURE_OUT=docs/design/batch5/steps flutter test tool/design_measure/batch5/step_numbers_test.dart
```

Step 2 (N31, N32): each save point's step before and after, in both
endings; the neighbour gaps against the even gap; the flag's arc share;
the avatar against the C5 signpost (`docs/design/batch5/steps/`).

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_steps STEPS_LABEL=after flutter test tool/design_measure/batch5/steps_render_test.dart
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_steps STEPS_ENDING=flag STEPS_WIDTHS=320,375,430 flutter test tool/design_measure/batch5/steps_render_test.dart
```

(and `STEPS_ENDING=tip`). The "before" frames come from the same file
run with `STEPS_LABEL=before` in a worktree at `fd215e4` (the commit
before N31), with a `steps_render_hooks.dart` whose `setEnding` does
nothing; then `tool/scene_art/batch5_sheet.py steps`.

```bash
DESIGN_MEASURE_OUT=docs/design/batch5/card flutter test tool/design_measure/batch5/month_card_disc_test.dart
```

Step 5 (N30), redone for N37: the fullest summary card's height by
medal disc at four screens and three text sizes, and the largest disc up
to N37's cap (112 pt from 740 pt tall, 88 pt from 640, 48 pt below) that
does not scroll (`month_card_disc.txt`; N30's run kept as
`month_card_disc_N30.txt`). Then the real card on the real Home with
Batch 6's `month_card_real_render_test.dart` (four screens; 375 × 667's
images are named `375x667` so they do not overwrite 375 × 812's) and
`batch5_sheet.py card` (Batch 6 → N30 → N37 in `card_compare.txt`; N30's
numbers kept as `month_card_real_numbers_N30.txt`).

## 1.1.0 release: the iPad check

```bash
DESIGN_MEASURE_OUT=build/design_measure/ipad flutter test tool/design_measure/release/ipad_render_test.dart
```

```bash
build/scene_art_venv/bin/python tool/scene_art/release_ipad_sheet.py
```

The real screens 1.1.0 changed (launch splash, Home on days 1 / 15 / 31,
the month card, K-c, the save point label, the Welcome and Gold
celebrations, the Daily Test result, Profile and its medal detail, the
avatar picker) at 1032 × 1376, 834 × 1194 and 744 × 1133 (2x, portrait),
light and dark, Medium and Large; `IPAD_CASES` and `IPAD_DEVICES` narrow
the run. `ipad_numbers.txt` holds the measures; the sheet script writes
one JPEG per screen and 1:1 crops of the mountain window to
`docs/design/release-1.1.0/ipad/`
(`docs/design/release-1.1.0/ipad-and-screenshots-report.md`).

## 1.1.0 release: P1, the iPad content width

The same tool now covers every screen (25 states) and, with
`IPAD_DEVICES=iphone320,iphone375se,iphone375,iphone430`, the four iPhone
screens; `IPAD_CAP` (560, 640, 720) overrides `ContentWidth`'s cap for a
run. The iPhone renders before and after a change are compared pixel by
pixel with:

```bash
build/scene_art_venv/bin/python tool/scene_art/release_p1_compare.py build/design_measure/p1_before build/design_measure/p1_after
```

Commands and results: `docs/design/release-1.1.0/p1/report.md`.

## 1.2.0 Batch 7: Home's hero and Profile

```bash
DESIGN_MEASURE_OUT=build/design_measure/v120_hero DESIGN_MEASURE_TAG=after flutter test tool/design_measure/v120/hero_render_test.dart
```

Home's hero at 390 × 844 with the real font and avatar, light and dark:
the hero's square plus 28 pt, and the header. `DESIGN_MEASURE_TAG` names
the run (`before` was taken at `efa5b54`).

```bash
DESIGN_MEASURE_OUT=build/design_measure/v120_profile flutter test tool/design_measure/v120/profile_render_test.dart
```

The real Profile in the nav shell, the whole page, then the running
month's detail and the name being edited. `DESIGN_MEASURE_WIDTHS`,
`DESIGN_MEASURE_SIZES`, `DESIGN_MEASURE_MODES`, `DESIGN_MEASURE_SCORE`,
`DESIGN_MEASURE_NAME` and `DESIGN_MEASURE_HISTORY=1` (three finished
months and the Welcome badge) change the case. The card edges look darker
than on a device: the test engine draws `Card`'s elevation shadow harder.
