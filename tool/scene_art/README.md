# scene_art

Measuring code for Scene Art Batch 0
(`docs/design/scene-art/batch0/report.md`): it reads the illustrated
backgrounds and objects in `docs/design/scene-art/source/` and reproduces
every figure and image of that report. Nothing in `lib/` imports it, and
`flutter test` does not run it.

Python, because the work is image analysis (masking, skeletons, distance
maps) that the Dart side has no library for. Versions are pinned.

## Setup (once)

The environment lives in `build/` (git-ignored).

```bash
python3 -m venv build/scene_art_venv
```

```bash
build/scene_art_venv/bin/pip install -r tool/scene_art/requirements.txt
```

## Runs

Run from the repository root. Output goes to
`docs/design/scene-art/batch0/`, or to `SCENE_ART_OUT` when it is set. Each
run is deterministic: the same sources give byte-identical text and JSON.

```bash
build/scene_art_venv/bin/python tool/scene_art/extract_trail.py
```

Step 2: the trail's center line, bends and clearings from
`green/background_light.png` (`trail_green.json`, `trail_numbers.txt`,
`verify_trail.jpg`).

```bash
build/scene_art_venv/bin/python tool/scene_art/check_theme.py
```

The theme consistency check (S4: every theme's image keeps Green's trail,
clearings and START flag). Pass the images to check (relative to
`source/`, or absolute); with no arguments it checks
`green/background_dark.png`. Exit code 1 on a failure. Thresholds and their
reasons are at the top of the file.

**How it checks (since Batch 4, 2026-10-02).** At Green's known positions,
not by re-detecting:
1. **Trail.** Green's centre line must lie on the image's trail: 600
   points within ΔE 20 of the image's own trail colour. The points at
   ±0.6 of the half width must match the centre (ΔE 15).
2. **Clearings.** There must be flat ground (median local L* deviation
   ≤ 1.0) inside each of Green's six clearing ellipses.
3. **START flag.** Its edge correlation, unchanged.

**Why the first version was replaced.** It re-ran the trail and clearing
extraction on each image and compared the results. That extraction is
tuned on Green, and on the Batch 4 themes it failed images that are
aligned (START flags within 2 px):
- Ember's C6 is as dark and flat as the rock around it;
- the canyon's trail mask leaked into same-coloured sand;
- the glacier and canyon clearings touch the trail with no grass rim, so
  growing them by colour pulled their centres 12–14 px.

Crops of each failure: `docs/design/scene-art/batch4/check/`, made by
`check_theme_detail.py`.

The Batch 0 outputs in `docs/design/scene-art/batch0/` are from the first
version.

```bash
build/scene_art_venv/bin/python tool/scene_art/check_theme_detail.py <out dir> <image> ...
```

A close look at what the *first* version failed on: each failing
clearing and the trail's worst point, the reference and the image side by
side. Kept as the record of why the check changed. It uses the extraction,
so it does not explain a failure of the current check.

```bash
build/scene_art_venv/bin/python tool/scene_art/break_check.py [<image> ...]
```

The check's deliberate-break run, on `green/background_dark.png` and any
image given, made in memory: moved 8 px and 20 px, scaled 1.5 %, and
clearing C3 painted over. Every copy must fail.

```bash
build/scene_art_venv/bin/python tool/scene_art/export_assets.py
```

Stage 1: the app's background assets,
`assets/climb/<theme>/background_<mode>.webp` (1536 × 2048, WebP quality
80; byte-identical on a re-run).

```bash
build/scene_art_venv/bin/python tool/scene_art/stage1_sheet.py
```

Stage 1's real-Home renders as JPEGs and an overview
(`docs/design/scene-art/stage1/`), from the PNGs that
`tool/design_measure/scene_art/home_render_test.dart` writes
(`tool/design_measure/README.md`).

```bash
build/scene_art_venv/bin/python tool/scene_art/export_objects.py
```

Stage 2: the save point objects and the summit flag, and since Batch 5
the C5 signpost (decoration, N11, N18), `assets/climb/objects/<name>.webp`
(192 px wide, WebP quality 90, alpha kept lossless).
- **Cleaning:** invisible stray pixels are zeroed, before and after the
  resize.
- **Flame layer:** `campfire_flame.webp`, the flame only, by a colour
  threshold.
- **Flag parts (G10):** `summit_flag_pennant.webp` and
  `summit_flag_base.webp`, the pennant and the flag without it, by a
  colour threshold. Their alphas add up to the flag's. A theme that
  recolours the pennant draws these two.
- **Data:** the sizes, the threshold and the dark-mode gain go to
  `docs/design/scene-art/stage2/objects.json`, which the save point table
  generator reads.

```bash
build/scene_art_venv/bin/python tool/scene_art/place_save_points.py
```

```bash
scripts/generate_climb_save_points.sh
```

Stage 2: where the save points and the summit flag stand
(`docs/design/scene-art/stage2/placement.json`).
- **Assignment:** G9's, with each object's largest width ratio (≤ 1.0)
  that keeps its shape off the trail.
- **Decoration (Batch 5):** the signpost on C5 by the same rule, written
  as `decor`; the rule gives 0.95 (1.0 touches the trail by 15 px and 0.90
  by 3 on Green). The table's `climbDecorTable`.
- **Alternatives:** every other assignment, measured.
- **Pinned steps (Batch 5, N31, N32):** `scripts/generate_climb_trail.sh`
  also reads `placement.json`: each save point's step (the nearest whole
  number to its arc share × the days), the arc of every day (even between
  pinned steps) and the flag's arc, for both endings
  (`ClimbRoute.endsAtFlagSetting`). Run it after a placement change.
- **Generated table:** the script writes
  `lib/widgets/monthly_climb/climb_save_point_table.dart`;
  `test/climb_save_point_table_test.dart` fails until it matches.
- **Order after a source change:** run `extract_trail.py` and
  `export_objects.py` first, then `scripts/generate_climb_trail.sh`.

## The debug panel (N27)

In debug and profile builds Settings ends with a **Debug** row. Its panel
changes the settings below while the app runs, with no rebuild:

- **Theme:** the scene's theme, or the month's real one.
- **Day:** the step the scene shows (0–31), or the real progress.
- **Milestones:** `bronze`, `silver`, `gold`, `first_camp`,
  `halfway_hut`, `mountain_spring`, `high_camp`, `summit`.
- **Month card:** `summary_gold`, `summary_none`, `summary_near`,
  `fresh`, `first_run`.
- **Reset local data (first-day flow):** after a confirmation, deletes
  the app's whole local database and starts again at Welcome.

A milestone or a month card closes the panel and plays on Home at once;
the same one can be played again. Theme and day last until the app is
closed (memory only). Nothing the panel does is stored or sent as an
event, except the reset (it deletes) and the month card's existing
`CLIMB_DEBUG_MONTH_CARD_EVENTS` opt-in. The `--dart-define` values below
still apply, as the starting values at launch. A release build has no
row, no panel and no effect.

To feel the real app's speed, run a profile build on the device:

```bash
flutter run --profile
```

Starting values work there too:

```bash
flutter run --profile --dart-define=CLIMB_DEBUG_THEME=glacier_peak --dart-define=CLIMB_DEBUG_DAY=20
```

**What "Reset local data" covers.** Every table of the app's SQLite
database: the profile (name, avatar, goal), Daily Test sets and answers,
mistakes and practice counts, the climb's ledger, month themes, medals
and the Welcome badge, the one-time flags (first-day paywall, zooms, month
cards), AI consent, appearance and text size, practice and review
settings, usage counters, the debug entitlement override and the
anonymous device id the proxy counts quota by. **Not covered:** purchases
(the App Store and RevenueCat's own SDK storage keep them, so a
subscriber stays one), Firebase's app instance and the analytics already
sent, Crashlytics, and the shared Daily Test sets on the proxy. The
panel's own theme and day stay as set.

## Checking a day on a device

In a debug build the climb scene can show any step of the month instead
of the real progress (`ClimbDebugDay`, `lib/widgets/monthly_climb/`):

```bash
flutter run --dart-define=CLIMB_DEBUG_DAY=15
```

- **What it changes:** the avatar's place, the passed-day dots and the
  shrink at the summit. A value past the month's length stops at the
  summit.
- **What it leaves alone:** the real progress, the Daily Test, `dayKey`
  and the card's month and step chips.
- **Release builds ignore it** (N27: debug and profile builds apply it;
  `kReleaseMode`).
- **Hot restart keeps the define; changing the day needs a new
  `flutter run`.**

## Checking a theme on a device

In a debug build the climb scene can show any theme instead of the
month's (`ClimbDebugTheme`, `lib/widgets/monthly_climb/`). The ids are
`green_slope`, `ember_peak`, `glacier_peak` and `red_canyon`:

```bash
flutter run --dart-define=CLIMB_DEBUG_THEME=ember_peak
```

It combines with `CLIMB_DEBUG_DAY`:

```bash
flutter run --dart-define=CLIMB_DEBUG_THEME=glacier_peak --dart-define=CLIMB_DEBUG_DAY=31
```

- **What it changes:** the scene only. The month's recorded theme, the
  rotation, the Daily Test and `dayKey` are untouched.
- **An unknown id has no effect.**
- **Release builds ignore it** (N27: debug and profile builds apply it;
  `kReleaseMode`).

## Checking a milestone on a device

In a debug build Home can play a milestone on every launch and hot
restart (`ClimbDebugMilestone`, Batch 5, N13, N22):

```bash
flutter run --dart-define=CLIMB_DEBUG_MILESTONE=silver
```

```bash
flutter run --dart-define=CLIMB_DEBUG_MILESTONE=halfway_hut
```

- **The values:** `bronze`, `silver`, `gold` open the celebration layer
  over Home for the current month and its theme; `first_camp`,
  `halfway_hut`, `mountain_spring`, `high_camp`, `summit` mount the scene
  one step before that save point's step (the flag's for `summit`) and
  hop onto it about 0.6 s after Home shows, so the light-up and the label
  play.
- **With the others:** `CLIMB_DEBUG_THEME` picks the theme (the medal and
  the scene); a save point value takes the place of `CLIMB_DEBUG_DAY` in
  the scene; with `CLIMB_DEBUG_MONTH_CARD` the card and its zoom come
  first, then the milestone (a hop waits for the zoom to end).
- **What it leaves alone:** no stored record is read or written beyond
  Home's own load, and no event is sent (the real ones come only from a
  saved Daily Test).
- **Release builds ignore it** (N27: debug and profile builds apply it).
  A hot restart replays it; a resume does not.

```bash
flutter run --dart-define=CLIMB_DEBUG_THEME=red_canyon --dart-define=CLIMB_DEBUG_MILESTONE=summit
```

## How the trail is found (`trail.py`)

1. **Mask.** Lab colour distance under 14 from the trail's own colour,
   sampled at a seed on the lowest long leg (normalized 0.444, 0.6215; the
   same in every theme by decision S4), refined three times; the connected
   region through the seed, closed and hole-filled.
2. **Center line.** The mask's skeleton, its longest path (a tree
   diameter), smoothed. Each end is cut back one trail width, where the
   skeleton wanders, and joined to the centroid of the trail piece beyond.
3. **Bends.** Where the horizontal direction reverses by more than 2 % of
   the image width.
4. **Clearings.** For each bend, the largest flat region (local L*
   deviation under 1.0 at a common 1086 px analysis width) beyond the
   bend's outer edge and within 48 px (at 2172) of the trail, grown by
   colour to include its shaded rim.

## Batch 5 Batch 0 (`docs/design/batch5/batch0-report.md`)

```bash
build/scene_art_venv/bin/python tool/scene_art/batch5_signpost.py
```

The C5 signpost (N11), as measured in Batch 0: exported like the save
point objects but into `build/scene_art/batch5/` (the app's asset now comes
from `export_objects.py`), placed on C5 by the save
points' rule with every ratio's trail contact listed, rendered in the four
themes, light and dark, with its colour separation from the ground
(`docs/design/batch5/signpost/`). `placement.json` is read by
`tool/design_measure/batch5/save_point_numbers_test.dart`.

```bash
build/scene_art_venv/bin/python tool/scene_art/check_theme.py --signpost
```

N18: the signpost where the app draws it must touch none of each theme
image's own trail near C5 (all eight sources). **Result 2026-10-03:**
Green and Ember pass; Glacier light (36 px), Glacier dark (69 px) and
Canyon dark (5 px) fail: the signpost's stones graze the trail's edge,
which sits a few pixels closer to C5 there than on Green (at most
2.7 pt² on a 430 pt phone). `--signpost-break` runs its deliberate breaks
in memory. Outputs: `docs/design/batch5/signpost/signpost_check*`.

```bash
build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py sites
```

The report's JPEGs from the Batch 5 Flutter tools' PNGs (`sites`,
`welcome`, `labels`; `tool/design_measure/README.md`).
