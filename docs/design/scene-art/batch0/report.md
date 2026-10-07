# Scene Art Batch 0 — import, measure, report

**Date:** 2026-10-01. **Branch:** `1.1.0-design`. `1.1.0` was merged in
first: a fast-forward to `b34fd06`, no conflict. **No product code changed**
(`lib/`, `ios/` and `test/` are untouched). Nothing is pushed, and nothing
is merged into `1.1.0` or `main`. Decisions S1–S5:
[`1.1.0-design-side-tracks.md`](../../../1.1.0-design-side-tracks.md),
"Scene art (2026-10-01)".

This report measures and proposes. **It decides nothing.** Every open
point is in §6, each with one recommended option for the owner.

## Look at these first

1. **[`verify_trail.jpg`](verify_trail.jpg)**: the extracted center line, the
   31 steps of a 31-day month and the six clearings, drawn on
   `green/background_light.png`.
2. **[`framing_overview.jpg`](framing_overview.jpg)**: the four framings at
   375 pt, on day 3 and day 25, next to the whole mountain.
3. [`objects_closeups.jpg`](objects_closeups.jpg): each clearing at app
   size, in light, dark as is, and dark with the filter.
4. [`objects_whole.jpg`](objects_whole.jpg): the C1–C4 proposal on the
   whole mountain, light and dark.
5. [`theme_check.jpg`](theme_check.jpg) and the two
   `theme_check_worst_*.jpg` crops: the theme consistency check.
6. [`framing_320.jpg`](framing_320.jpg), [`framing_375.jpg`](framing_375.jpg)
   and [`framing_430.jpg`](framing_430.jpg): every framing at every width.
7. [`objects_ratio.jpg`](objects_ratio.jpg),
   [`objects_edges.jpg`](objects_edges.jpg) and
   [`webp_crops.jpg`](webp_crops.jpg).

## Commits

| Commit | What |
|---|---|
| `fac3bca` | Step 1: source images and PROMPTS.md; decisions S1–S5; build-log entry; roadmap order |
| `051331f` | Step 2 tool: `tool/scene_art/` (trail, clearings, theme check, break run) |
| `d84a288` | Step 2 output: polyline JSON, numbers, verification image, theme check |
| `331a6fd` | Step 3: framing tool and renders |
| `5178e59` | Step 4: objects tool and renders |
| `f8f5b30` | Step 5.1: WebP tool and numbers |
| *this commit* | This report and the build-log line |

## Sizes in the repository

- **`source/`: 30 MB.** These are the owner's files, byte-identical: green
  light 9.8 MB and dark 9.0 MB, their pre-upscale `raw/` 2.6 and 2.3 MB,
  volcanic 2.2 MB, objects 0.9–1.7 MB each.
  - Git LFS is not used. These 30 MB stay in history even if the files are
    deleted later. *(Flagged; not changed.)*
- **`batch0/`: 9.0 MB.** The JPEG renders are 8.9 MB of that; the text and
  JSON files are 0.06 MB.
  - The three per-width framing sheets are the largest, at 1.1–1.3 MB each.

## Reproducing

```bash
python3 -m venv build/scene_art_venv
```

```bash
build/scene_art_venv/bin/pip install -r tool/scene_art/requirements.txt
```

Then, from the repository root, each step's tool. They are listed in
[`tool/scene_art/README.md`](../../../../tool/scene_art/README.md):

- `extract_trail.py`;
- `check_theme.py`;
- `break_check.py`;
- `framing.py`;
- `objects.py`;
- `webp_size.py`.

Each run is deterministic. A second run of `extract_trail.py` gave
byte-identical JSON and text.

---

## 1. Files and decisions (step 1)

- **Copied.** `~/Desktop/scene-art/` went to `source/` (green with `raw/`,
  volcanic, objects; `.DS_Store` left out), and `PROMPTS.md` sits next to
  this folder.
  - Every PNG was compared with `cmp`: all identical.
  - `PROMPTS.md` is in Turkish. It was copied as written, as a source
    record.
- **Not app assets.** Nothing was added to `assets/` or `pubspec.yaml`.
- **S1–S5** are in the side-tracks file, with the decisions each one
  replaces.
  - **One addition of mine, marked for the owner to confirm:** S4 also
    replaces Batch 0 decision 3, "external WebP layers are the same in both
    modes", for the background.
  - S2's reason is also mine. No separate reason was recorded, so S2 cites
    S1.

## 2. The trail from the image (step 2)

**Method** (`tool/scene_art/trail.py`), all automatic:

1. **Mask.** Colour distance under 14 (Lab ΔE) from the trail's own
   colour, sampled at one seed point on the lowest leg.
2. **Center line.** The mask's skeleton, its longest path, smoothed.
3. **Ends.** Each end is cut back one trail width and joined to the
   centroid of the trail piece beyond.

Numbers: [`trail_numbers.txt`](trail_numbers.txt). Data:
[`trail_green.json`](trail_green.json), which holds the normalized
polyline, widths, bends, clearings and the 28–31-day step tables.

**The polyline:**

| | Value |
|---|---|
| Image | 2172 × 2896 px (3:4) |
| Points | 739, every 7.24 px (0.0025 of the height) |
| Arc length | **5344.8 px** = 1.846 × height = 2.461 × width; 2.351 in normalized (x/w, y/h) units |
| Start (foot, at the START mat) | px (581.4, 2469.7), norm (0.2677, 0.8528) |
| End (summit, under the snow cap) | px (1157.0, 482.1), norm (0.5327, 0.1665) |

**Trail width.** Measured across the trail, in image space, with the end
caps left out:

| | Min | Median | Max |
|---|---|---|---|
| px | 43.5 | 73.0 | 160.0 |
| ÷ width | 0.0200 | 0.0336 | 0.0737 |

- Perspective narrows the trail with height. The median per tenth of the
  trail, foot to summit, is 96 → 106 → 91 → 73 → 76 → 60 → 69 → 60 → 56 →
  51 px.
- The maximum is at bend B1, where the cross-section is horizontal and is
  not foreshortened.

**Bends: 6**, alternating right and left. A bend is where the horizontal
direction reverses by more than 2 % of the width.

| Bend | Side | Apex (norm) | Share of the trail's length |
|---|---|---|---|
| B1 | right | (0.7827, 0.7246) | 0.228 |
| B2 | left | (0.2670, 0.5553) | 0.466 |
| B3 | right | (0.7007, 0.4449) | 0.660 |
| B4 | left | (0.3809, 0.3335) | 0.810 |
| B5 | right | (0.5895, 0.2615) | 0.908 |
| B6 | left | (0.4824, 0.2110) | 0.963 |

- B5 and B6 are a small wiggle just under the summit.
- K1's coded trail had 5 legs and 4 turns. The image has 6 bends.

**Clearings: 6, found automatically**, one beyond each bend's outer edge.
They are the flattest ground in the image (local L* deviation < 1.0),
grown by colour to include their shaded rim. **None is marked by hand.**

| | Side | Center (norm) | Box (norm) | Box (px) | Day reached (28 / 29 / 30 / 31 days) |
|---|---|---|---|---|---|
| C1 | right | (0.8622, 0.7475) | 0.0925 × 0.0380 | 201 × 110 | 6 / 6 / 7 / 7 |
| C2 | left | (0.1936, 0.5438) | 0.0797 × 0.0335 | 173 × 97 | 13 / 14 / 14 / 14 |
| C3 | right | (0.7658, 0.4400) | 0.0576 × 0.0269 | 125 × 78 | 19 / 19 / 20 / 20 |
| C4 | left | (0.3173, 0.3371) | 0.0612 × 0.0252 | 133 × 73 | 23 / 23 / 24 / 25 |
| C5 | right | (0.6331, 0.2825) | 0.0847 × 0.0259 | 184 × 75 | 25 / 26 / 27 / 28 |
| C6 | left | (0.4308, 0.2053) | 0.0534 × 0.0173 | 116 × 50 | 27 / 28 / 29 / 30 |

- "Day reached" is the step nearest the clearing.
- C6 is the smallest, as PROMPTS.md says. C5 is wide but shallow.
- **Hand-placed values in the tools.** None of these is a clearing:
  - the seed point on the lowest leg;
  - the summit peak (`framing.py`: the snow joins the sky in any colour
    mask);
  - the START flag's search box (`check_theme.py`);
  - the summit flag's offset (`objects.py`).

**Steps.** Steps are spread evenly by arc length; day 0 is the foot and
the last day is the summit.

| Month | Px per step along the trail |
|---|---|
| 28 days | 190.9 |
| 29 days | 184.3 |
| 30 days | 178.2 |
| 31 days | 172.4 |

In a 31-day month, neighbouring steps are 135.3–172.4 px apart in a
straight line.

### Theme consistency (step 2.5)

`check_theme.py` repeats the extraction on any image and compares it with
the green light reference. **S4's claim holds on the measured images.**
Numbers: [`theme_check.txt`](theme_check.txt).

| | Green dark | Volcanic light (1086 px, ×2) |
|---|---|---|
| Trail body (3–97 % of its length): max | 7.6 px (0.0026 h) | 12.2 px (0.0042 h) |
| Trail body: mean | 1.1 px | 2.1 px |
| Trail ends: foot / summit | 16.6 / 2.5 px | 32.5 / 15.6 px |
| Clearing centers | 0.2–0.9 px | 1.4–5.8 px |
| START flag (edge correlation) | **0 px** | **1 px** |
| Verdict | PASS | PASS |

- **The ends are checked on their own, with a looser limit.** At the foot
  the trail is cut square against the mat, and where it "ends" depends on
  how the mask's edge falls.
  - The flag (0–1 px) and the clearings (≤ 1 px in dark) show that the
    images themselves agree.
- **Volcanic's worst body point is at bend B2.** In the crop
  ([`theme_check_worst_volcanic_background_light.jpg`](theme_check_worst_volcanic_background_light.jpg))
  the trail's edges coincide; the center line moves with how the inner rim
  is segmented.
  - Volcanic is also half resolution, which doubles the px quantization.

**Proposed thresholds** (share of the image height):

| Measure | Limit | About |
|---|---|---|
| Trail body, max | 0.005 | 14 px |
| Trail body, mean | 0.0015 | |
| Each end | 0.012 | |
| Clearing center | 0.004 | |
| START flag | **0.002** | 6 px |

- **0.004 was tried first for the body.** Volcanic measured 0.0042 there,
  so 0.005 is proposed: about a fifth of the median trail width, and under
  3 pt on screen.
- **The flag carries the tight limit** because its offset is exact to the
  pixel.

**Deliberate break** (`break_check.py`): altered copies of the dark image,
made in a temporary directory, never in `source/`.

| Copy | Result | Caught by |
|---|---|---|
| Shifted 8 px | **FAIL** | the flag only (the trail line's noise hides it) |
| Shifted 20 px | **FAIL** | four checks |
| Scaled 1.5 % | **FAIL** | four checks |

Details: [`theme_check_break.txt`](theme_check_break.txt).

**Use it on every new theme image** before it becomes an asset; exit code
1 means the image does not fit the shared coordinates.

## 3. Framing and scale (step 3)

**Fixed inputs:**
- The window is 350 pt tall, with the avatar at 72 % of its height.
- The card widths are 288 / 341.25 / 391.3 pt on 320 / 375 / 430 pt
  screens (`cardWidth`).
- All numbers are for a 31-day month.

**What the columns mean:**
- **Avatar fit:** the largest tile whose footprint fits the trail. The
  footprint is the ground shadow, 0.65 of the tile (`AvatarTile`). The
  limit is the trail's narrowest horizontal width on days 0–30.
  - *Body*: the widest avatar body (0.894 of the tile, `avatar_03`)
    fits instead.
  - *Summit*: the footprint fits the trail's tip, on day 31.
  - Today's avatar is 42.3 pt.
- **Gap:** neighbour centers minus today's 13.1 pt pill, if pills are
  kept.
- **Peak from:** the first day from which the snow cap's top stays in the
  window. *Clear* means it is also below the chip band, about the top
  48 pt.

Numbers: [`framing_numbers.txt`](framing_numbers.txt).

| Option | Screen | Image shown | Day step | Gap (center to center) | K1 | Avatar fit (body; summit) | Peak from / clear from | 3x: device px per image px |
|---|---|---|---|---|---|---|---|---|
| K-a | 320 | 91 % | 22.9 pt | 4.8 (17.9) | **fail** | 23 pt (17; 13) | day 0 / never | 0.40 |
| K-a | 375 | 77 % | 27.1 | 8.1 (21.3) | pass | 27 (20; 15) | 9 / 15 | 0.47 |
| K-a | 430 | 67 % | 31.1 | 11.2 (24.4) | pass | 31 (23; 17) | 14 / 18 | 0.54 |
| K-b 1.3 | 320 | 54 % | 29.7 | 10.2 (23.3) | **pass** | 30 (22; 17) | 13 / 16 | 0.52 |
| K-b 1.3 | 375 | 46 % | 35.2 | 14.5 (27.6) | pass | 35 (26; 20) | 15 / 21 | 0.61 |
| K-b 1.3 | 430 | 40 % | 40.4 | 18.6 (31.7) | pass | 40 (29; 23) | 20 / 22 | 0.70 |
| K-b 1.6 | 320 | 36 % | 36.6 | 15.6 (28.7) | **pass** | 37 (27; 21) | 16 / 21 | 0.64 |
| K-b 1.6 | 375 | 30 % | 43.3 | 20.9 (34.0) | pass | 43 (31; 24) | 21 / 23 | 0.75 |
| K-b 1.6 | 430 | 26 % | 49.7 | 25.9 (39.0) | pass | 50 (36; 28) | 22 / 25 | 0.86 |
| K-c | any | 100 % | 20.8 | 3.2 (16.3) | **fail** | 21 (15; 12) | 0 / never | 0.36 |

**K1** (at 320 pt, 31 days: a day's step ≥ 17 pt and neighbouring markers
≥ 5 pt apart):

| Option | Day step | Gap | Result |
|---|---|---|---|
| K-a | 22.9 | 4.8 | fails, on the gap only, if today's pills are kept; without pills the criterion has no marker to measure |
| K-b 1.3 | 29.7 | 10.2 | passes |
| K-b 1.6 | 36.6 | 15.6 | passes |
| K-c | 20.8 | 3.2 | fails |

**Findings beyond the table:**

- **The trail is narrower than today's avatar.**
  - With the "footprint fits the trail" rule, only K-b 1.6 at 375 and
    430 pt keeps today's 42 pt.
  - Everywhere else the avatar shrinks: 23–31 pt with K-a, 30–40 pt with
    K-b 1.3.
  - The narrowest point before the summit is day 30 (112 px across).
    Days 25 and 28 come next (123–124 px), just after a bend.
- **At the summit (day 31) the trail's tip is 63 px wide.** No framing
  fits today's avatar there; it stands over the tip's edges.
- **Sharpness.** No option needs more than 0.86 device px per image px on
  a 3x screen, so every option is sharp. The needed width is 1123–1878 px
  depending on the option (K-b 1.3: up to 1526 px).
- **K-c and the chips.** The peak always sits under the month and step
  chips (39.7 pt from the top). The same holds for the whole-mountain view
  at the month change.
- **Day 3 sits low.** On day 3 every option is clamped at the image's
  bottom, so the avatar sits below 72 % of the window. With K-b 1.6, the
  START flag is cut at the left edge.

Renders:
- [`framing_overview.jpg`](framing_overview.jpg) (375 pt);
- [`framing_320.jpg`](framing_320.jpg), [`framing_375.jpg`](framing_375.jpg),
  [`framing_430.jpg`](framing_430.jpg): day 3 and day 25 for each option,
  plus the whole mountain with all 31 steps.

The avatar in the renders is min(42.3 pt, avatar fit). The month and step
chips and the plaque are not drawn in these renders.

## 4. Objects (step 4)

Numbers: [`objects_numbers.txt`](objects_numbers.txt).

**Size study.** Close-ups are at app size: K-b 1.3 at 375 pt, rendered at
3 px per pt.
- Object width = clearing width × 0.8 / 1.0 / 1.25
  ([`objects_ratio.jpg`](objects_ratio.jpg)).
- **Proposed ratio: 1.0**, with the base 0.25 of the clearing's height
  below its center. At 1.25 the objects spill over the clearings' edges;
  at 0.8, C3, C4 and C6 shrink to about 20 pt.

On screen at 1.0:

| Clearing | K-b 1.3, 375 pt | K-a, 320 pt | K-a, 430 pt |
|---|---|---|---|
| C1 | 41 pt | 27 pt | 36 pt |
| C2 | 35 pt | 23 pt | 31 pt |
| C3 | 26 pt | 17 pt | 23 pt |
| C4 | 27 pt | 18 pt | 24 pt |
| C5 | 38 pt | 24 pt | 33 pt |
| C6 | 24 pt | 15 pt | 21 pt |

- **The summit flag** is 116 px wide (the size of C6). It stands beside
  the trail's end, offset (70, 10) px, placed by hand.

**Dark mode** ([`objects_closeups.jpg`](objects_closeups.jpg),
[`objects_whole.jpg`](objects_whole.jpg)):
- **As is**, the objects stay daylit on the dusk scene. They read as
  stickers, the fountain and the campfire's stones most of all.
- **Filtered:** one per-channel gain, R 0.483 G 0.517 B 0.674. It is
  measured as dark ÷ light over the six clearings' ground, so it is the
  same relighting the dusk image applied.
  - In Flutter this is a single `ColorFilter.matrix`.
  - The objects then sit in the scene, but the campfire's flame dims with
    them and the fountain's water turns grey.

**Edges, smoke and stray pixels** ([`objects_edges.jpg`](objects_edges.jpg)):
- **No smoke is left on the campfire.** Its alpha covers only the stones,
  logs and flames. The smoke went with the background removal, as
  PROMPTS.md feared.
- **No halo.**
  - The soft edge band is about 2 px at 2508 px. At app size that is
    0.1–0.2 device px (C6's tent to C1's campfire, K-b 1.3 at 375 pt, 3x),
    so it is invisible.
  - The edge is not lighter or greyer than the object: its mean lightness
    is 2–13 below the inside.
  - At 1:1 on near-black there is no light rim.
- **One alpha component per object.**
  - The only traces away from the bodies are **12 pixels of alpha 1 at
    the canvas corners**, in the campfire, fountain, cabin and flag. They
    are invisible.
  - They are the `avatar_16` edge class (build-log, Batch 8). The asset
    pipeline should zero them, or the crop removes them.
- **Light direction is not checked here.** The objects were not mirrored,
  so they keep their upper-left light, like the scene. PROMPTS.md's flipX
  note would move it.

## 5. Size and the replacement plan (step 5)

### 5.1 WebP

Lossy, Pillow's libwebp at method 6. Each encode is compared with the
same-size resized source, as PSNR and SSIM on lightness. Numbers:
[`webp_numbers.txt`](webp_numbers.txt).

| Background | Width | q70 | q80 | q90 |
|---|---|---|---|---|
| Green light | 1536 | 282 KB (SSIM 0.966) | **366 KB (0.977)** | 587 KB (0.989) |
| Green light | 2172 | 423 KB | 548 KB | 898 KB |
| Green dark | 1536 | 205 KB (0.959) | **272 KB (0.972)** | 447 KB (0.986) |
| Volcanic light | 1536 | 181 KB | 232 KB | 383 KB |

- **The visible difference** ([`webp_crops.jpg`](webp_crops.jpg), the
  START flag at 2×):
  - q70 smears the grass;
  - q80 is hard to tell from the source;
  - q90 adds 60 % for little visible gain.
- **Recommended resolution: 1536 px wide** (1536 × 2048). It is the K-b 1.3
  need at 430 pt (1526 px), rounded up, and covers K-a too. K-b 1.6 would
  need 1878 px.
- **Recommended quality: q80.**
- **Per theme:** about 0.64 MB for the green pair (366 + 272 KB) at
  1536/q80, against 18.8 MB as PNG.
- **4 themes × 2 modes:** about 2.0–2.6 MB in the app at 1536/q80. The
  upper end is green's pair × 4; volcanic light alone is 232 KB. At q90
  it is about 4.1 MB. The 16 avatars are 0.72 MB for scale.
- **The five objects:** about 55 KB in total, as 256 px WebP q90.
  - The largest object on screen is about 58 pt (C1 at 430 pt, K-b 1.6),
    which is 174 px at 3x, so 256 px is enough.
- **Volcanic is only 1086 px.** It would need upscaling, as green had, for
  anything above K-a at 375 pt.

### 5.2 Replacing the polygon mountain

**What changes.** Protected and unchanged: `dayKey`, `completedDays`, the
Daily Test flow and the medal rule. The scene stays a visual layer.

| File / class | Fate |
|---|---|
| `climb_scene.dart`: `ClimbScene` (silhouette, ridges, faces, cap, foothills, `onGround`, environment) and `ClimbSceneTones` | **Removed.** The image replaces all of it. |
| `climb_route.dart`: `ClimbRoute` | **Kept as the API** (`pointAt`, `stepAt`, `summit`, `markers`). Corners, fillets and `sharedPath` give way to the polyline. `sceneSize` becomes the image's 3:4 space. `stepAngle` and `stepMarkerSize` go if no pills are drawn (§6). Marker days become save points. |
| `climb_table.dart` | **Regenerated, in a new form.** It has three parts: `climbStepTable` (28–31 days) from the polyline; `climbMarkerTable` replaced by a save point table (fixed clearing positions and the day each is reached per month length); `climbEnvironmentTable` removed. |
| Coordinate generator: `tool/climb_table/*`, `scripts/generate_climb_table.sh` | **Rewritten.** Two stages. (1) Image → polyline: the Python tool writes a generated Dart file with the normalized polyline and the source image's SHA-256. (2) Polyline → step table: Dart, as today, with its test. |
| `climb_camera.dart`: `ClimbCamera` | **Rewritten** for the chosen framing: scale from image px; two-axis follow for K-b; `pawnAt` 0.72 kept; clamping on both axes; the avatar size per width (min of 42.3 pt and the fit). |
| `monthly_mountain.dart`: `MonthlyMountain` and `_MountainPainter` | **The painter goes.** The widget draws the background image, the save point objects and the avatar. Kept: the motion controller, `onMotionEnd`, Reduce Motion and the hop, re-expressed in pt or image px instead of scene units. The vertical `SingleChildScrollView` gives way to an offset transform (two axes). The VoiceOver label's "Milestones" become the save points. |
| `climb_card.dart`: `ClimbCard` | **Kept** (frame, plaque, month and steps). The chip colour comes from the theme's data instead of `palette.sky`, which no longer matches the image's sky. The K3 gate and the K4 4.5:1 contrast are re-measured. |
| `climb_score_bar.dart` | **Unchanged.** |
| `climb_theme.dart`: `ClimbThemes` and `ClimbPalette` | **Kept as the registry.** The mountain-painting palette roles (`mountain`, `ridge`, `trail`, `stone`) lose their painter. New per-theme data: light and dark background asset paths, a summit flag yes/no, the chip colour, and the dark object filter. Rotation and readiness are unchanged. |
| `climb_month_themes` table and `StorageService.resolveClimbMonthTheme` | **Unchanged** (protected logic). |
| `lib/preview/monthly_climb_preview.dart` | Updated to the new widget. |
| `tool/design_measure/` (the `batch3c/` harness, `scene_art_test.dart`, `home_layout_test.dart`) | **The parts that import `ClimbScene` or the old route are removed** when it goes; `flutter analyze` covers `tool/`. Their outputs stay committed in `docs/design/`, and the commits that made them stay in history. `home_layout_test.dart` is kept and updated (the K3 gate). |

**Tests.**

| Test | Today | Fate |
|---|---|---|
| `climb_scene_test.dart` | 6: tones, concave silhouette, trail on the ground | **Removed.** Replaced by: each ready theme and mode has its background asset, decodes, is 3:4 and 1536 px wide. |
| `climb_environment_test.dart` | 3: pine and shrub | **Removed.** Replaced by the save point tests. |
| `climb_markers_test.dart` | 3: weekly days, D2, VoiceOver | **Replaced** by save point tests: 4 save points at fixed positions in every month; the day each is reached for 28–31 days; VoiceOver names them; D2 is gone. |
| `climb_table_test.dart` | 2 | **Rewritten.** The step table is exactly what the polyline generates. One entry per day, on the polyline. The polyline file's image hash equals the hash of the committed source. |
| `climb_acceptance_test.dart` | 4 | **Kept as K1, re-pinned** to the new camera: a day's step ≥ 17 pt at 320 pt. The gap criterion follows §6's marker decision. The turned-pill test goes if pills go. |
| `climb_camera_test.dart` | 5 | **Rewritten:** scale per width, two-axis follow and clamping, the summit day, and the avatar size and foot position. |
| `climb_card_test.dart` (no mirroring), `monthly_mountain_motion_test.dart`, `climb_score_bar_test.dart`, `climb_theme_test.dart`, `home_climb_card_test.dart`, `first_launch_climb_test.dart` | | **Kept.** Finders and sizes are adjusted where they read the painter. |

**The theme check outside `flutter test`.** `check_theme.py` runs in the
asset pipeline, not in `flutter test`: no image analysis in Dart. The
hash test above is what ties the code to the checked image.

**How the batches reshape:**

- **Batch 3d (save points)** becomes objects on 4 of the 6 clearings (§6),
  from the save point table:
  - each appears when reached;
  - each is filtered in dark mode;
  - D2 and the weekly days are retired, as G3 planned;
  - G3's open question ("inside or outside the turn?") is answered by the
    image: outside.
- **Batch 4 (4a infrastructure, 4b themes)** loses the code-drawn layers,
  palettes and environment items. Per theme it becomes:
  - a light and dark background pair;
  - the summit flag yes/no;
  - the chip colour;
  - the object filter.

  4a is the data and the asset loading. 4b is producing Ember Peak, Glacier
  Peak and Red Canyon pairs (owner's art work, with the same prompts), each
  passing `check_theme.py`. The D5b "ridge/summit silhouette slot" is
  covered by the image.
- **Batch 6 (month change)** zooms from the whole mountain (K-c) to the
  daily framing (K-b) at the avatar. The chips cover the peak in K-c, so
  they fade out during the zoom or start hidden.

**Build order, in small commits** (each tested; nothing protected
touched):

1. **Asset export.** A `tool/scene_art/` exporter writes
   `assets/climb/green/background_{light,dark}.webp` (1536 px, q80) and
   the five objects (256 px, q90, corner alpha zeroed). It adds the
   `pubspec` entry and an asset test (exists, decodes, size).
2. **The polyline as generated Dart.** Normalized points plus the source
   hash, with the hash test.
3. **Step table and save point table** generated from the polyline.
   `climb_table_test` rewritten.
4. **`ClimbRoute` on the polyline.** Corners and fillets removed; route
   tests.
5. **`ClimbCamera` for the chosen framing**, with the avatar size rule.
   Camera tests; K1 re-pinned.
6. **`MonthlyMountain` draws the image and the avatar.** The hop in the
   new units; the Reduce Motion test stays green.
7. **Removals:** `ClimbScene`, `ClimbSceneTones`, the environment items,
   the pills (if decided), their tests, and the `tool/design_measure`
   parts that import them.
8. **Theme data:** background paths, chip colour, object filter. The chips
   read the theme; K3 and K4 are re-measured.
9. **Batch 3d:** save points on the chosen clearings, appearing when
   reached, filtered in dark; VoiceOver; marker tests replaced.
10. **The summit flag object** (themes that have one).
11. **After-build measurements and renders**, then the owner's device
    check.

## 6. Open questions (one recommendation each)

1. **Framing. Recommended: K-b 1.3 for the daily view; K-c only as the
   month change's starting view (Batch 6).**
   - It is the only option that passes K1 at 320 pt with or without
     pills.
   - It keeps the avatar at 30–40 pt.
   - The summit is in view from day 13–20.
   - It shows 40–54 % of the image, against 26–36 % with K-b 1.6. That
     matters because D5's original problem was "in close framing the
     mountain does not read".
   - It is sharp at 1536 px.
2. **Avatar size. Recommended: one size per screen width, min(42.3 pt, the
   footprint fit)** (30 / 35 / 40 pt with K-b 1.3). No size change along
   the trail.
   - Shrinking with perspective would look like a bug on a character that
     is the user's identity.
   - Accept that on the summit day the avatar stands over the trail's
     63 px tip.
3. **Which 4 clearings. Recommended: C1–C4** (2 right, 2 left), reached on
   days 7 / 14 / 20 / 25 of 31 and 6 / 13 / 19 / 23 of 28.
   - That spacing is close to the old weekly rhythm.
   - C5 and C6 are within 3 steps of the summit in every month length.
     That would bring back exactly the crowding D2 was written for.
   - C6 is also the smallest.
   - PROMPTS.md records "3 right / 2 left" from Ahmet, which is five, not
     four. **Flagged.**
4. **Step markers under the avatar. Recommended: none; the image's trail
   only.**
   - Pills on a painted trail look pasted on, for the same reason S2 moved
     the trail into the image.
   - 32 markers would clutter the illustration.
   - Progress is already shown by the counter and by the save points as
     they appear.
   - K1's second criterion then becomes a center-to-center distance. With
     K-b 1.3 at 320 pt it is 23.3 pt, or 10.2 pt if pills were kept.
5. **Dark-mode objects. Recommended: the colour filter** (one
   `ColorFilter.matrix`, gain measured from the clearings).
   - As is, the objects read as stickers on the dusk scene.
   - Check on the device whether the campfire's flame should be lifted
     out of the filter. It is the one object that should glow at dusk.
6. **The campfire has lost its smoke. Recommended: accept it.** The
   object reads as a campfire without smoke at 26–41 pt, and the edges are
   clean. Re-making it would reopen an accepted asset.
7. **Volcanic resolution. Recommended: upscale it 2× as green was, before
   it becomes an asset.** At 1086 px it is below the 1526 px K-b 1.3
   needs. It is also temporary; its dark version is not made yet.
8. **The theme check's thresholds. Recommended: the proposed set** (body
   0.005 h, mean 0.0015 h, ends 0.012 h, clearings 0.004 h, flag 0.002 h).
   - The real images pass.
   - An 8 px shift, a 20 px shift and a 1.5 % scale all fail.
9. **S4 also replaces Batch 0 decision 3 for the background. Recommended:
   confirm it, and narrow the B-polish exception** to "theme backgrounds
   have their own dusk version; save point objects are filtered". The
   exception text is written at the end of the work, as planned.
10. **The image tool's terms and Credits. Recommended: check ChatGPT's
    image terms before the first asset ships, and add a Credits line if
    they require one.** This is the side-tracks rule "Production of the
    artwork".

## Not done here

- No product code, no assets, no `pubspec` change.
- Nothing on a device.
- No decision on §6.
- The object light direction was not compared with the scene's.
- The month and step chips were not drawn in the renders.
- The K3 gate was not re-measured.
