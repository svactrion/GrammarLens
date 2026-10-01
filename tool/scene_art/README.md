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

Stage 2: the save point objects and the summit flag,
`assets/climb/objects/<name>.webp` (192 px wide, WebP quality 90, alpha
kept lossless).
- **Cleaning:** invisible stray pixels are zeroed, before and after the
  resize.
- **Flame layer:** `campfire_flame.webp`, the flame only, by a colour
  threshold.
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
- **Alternatives:** every other assignment, measured.
- **Generated table:** the script writes
  `lib/widgets/monthly_climb/climb_save_point_table.dart`;
  `test/climb_save_point_table_test.dart` fails until it matches.
- **Order after a source change:** run `extract_trail.py` and
  `export_objects.py` first, then `scripts/generate_climb_trail.sh`.

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
- **Profile and release builds ignore it:** it is guarded by
  `kDebugMode`.
- **Hot restart keeps the define; changing the day needs a new
  `flutter run`.**

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
