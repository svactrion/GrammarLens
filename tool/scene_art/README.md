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

Step 2.5: the theme consistency check. With no arguments it checks
`green/background_dark.png` and `volcanic/background_light.png` against
`green/background_light.png`; pass other paths (relative to `source/`, or
absolute) to check a new theme image. Exit code 1 on a failure.
Thresholds and their reasons are at the top of the file.

```bash
build/scene_art_venv/bin/python tool/scene_art/break_check.py
```

The check's deliberate-break run: shifted and scaled copies of the dark
image, made in a temporary directory, must all fail.

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
