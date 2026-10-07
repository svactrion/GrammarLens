# Scene art — composition guide for AI image tools

**Date:** 2026-09-30. **Branch:** `1.1.0-design` (at `1.1.0`, `c7eff76`).
**Scope:** reference images only; no product code changed. Drawn from the
product's own geometry (`ClimbScene`, `ClimbRoute`, `ClimbCamera`) by
`tool/design_measure/scene_art_test.dart`:

```bash
DESIGN_MEASURE_OUT=docs/design/scene-art flutter test tool/design_measure/scene_art_test.dart
```

## The images

- **`mountain_guide.png`**, 1450 × 1850 px (2.5 px per scene unit). It shows:
  - a white background;
  - the mountain silhouette and its foothills in light gray (#CCCCCC);
  - the two back ridges lighter (#E3E3E3 mid, #EFEFEF far);
  - the boundary between the lit (left) and the shadowed (right) face as a
    thin gray line;
  - the trail's center line in thick red;
  - the 4 turns (future save points, Batch 3d) as blue circles, at the
    middle of each turn's arc;
  - the summit as a black star, at the trail's end.

  No text, labels or avatar.
- **`mountain_guide_f1_windows.png`**: the same, plus the daily window (F1,
  480 units tall) on a 375 pt screen:
  - **day 3 of 31**, short dashes, drawn 5 units in at the sides;
  - **day 25 of 31**, long dashes, at its exact edges.

  The two windows have the same width and overlap on y 260–480.
- **`mountain_guide_clean.png`**: the same size and aspect, **silhouettes
  only**: the mountain and foothills in light gray, the two back ridges
  lighter, and the lit/shadow boundary as a thin gray line. There is no
  trail line, no turn circles, no summit star and no window.
- **`numbers.txt`**: every figure below, as measured by the tool.

## Dimensions

- **The mountain space** (what the step, marker and item tables are
  normalized to): **320 × 740 units, aspect 0.4324 (width ÷ height), about
  1 : 2.31**.
- **The mountain is wider than that space.** Its silhouette at the scene's
  bottom spans x −94 to 414, and a wide phone's window shows beyond 0–320
  (at 430 pt, x −108 to 428).
  - So the images cover **x −130 to 450, y 0 to 740: 580 × 740 units,
    aspect 0.7838**.
  - The 320 × 740 mountain space is the band **x 325–1125 px** of the
    1450 px image, full height.
- **Sky above the peak:** the peak vertex is at y 72, so the top 72 units
  (180 px) are sky.

| | Scene units | Normalized (÷ 320, ÷ 740) |
|---|---|---|
| Trail center line | x 22.0–212.4, y 86.4–716.0 (190.4 × 629.6) | x 0.069–0.664, y 0.117–0.968 |
| Trail band (center line ± 13, the drawn trail) | x 9.0–225.4, y 73.4–729.0 (216.4 × 655.6) | x 0.028–0.704, y 0.099–0.985 |
| Mountain silhouette, inside the scene | x 0–320, y 72–740 | x 0–1, y 0.097–1 |
| Mountain silhouette, whole (to y 760) | x −102–422, y 72–760 | x −0.319–1.319, y 0.097–1.027 |

- **The trail occupies the left two-thirds of the mountain face**
  (normalized x 0.03–0.70) and nearly its full height (y 0.10–0.99).
  - It starts low at the left, (22, 716).
  - It ends on the summit, (160, 86), just under the peak vertex (160, 72).
- **The 4 turns** (arc middles), bottom to top:
  - (203.6, 648.5), (120.5, 535.7), (212.2, 397.7), (116.2, 248.8);
  - the legs' corners, which are outside the rounded trail: (276, 660),
    (70, 540), (236, 400), (110, 250).
- **The F1 window** is 480 units tall at every width. Its width grows with
  the screen:

  | Screen | Width (units) | x range |
  |---|---|---|
  | 320 pt | 395.0 | −37.5 to 357.5 |
  | 375 pt | 468.0 | −74 to 394 |
  | 430 pt | 536.6 | −108.3 to 428.3 |

  - On a 375 pt screen, day 3 shows y 260–740 (the foot).
  - Day 25 shows y 0–480 (the summit, with sky).

## Using it as a reference

- An image layer made from this guide should keep its **aspect ratio and
  positions**. A layer for the 320 × 740 mountain space is 0.4324 wide per
  unit of height. A layer that also covers the wide-phone margins is
  0.7838.
- **The trail band must stay clear** in environment layers: the red line
  plus 13 units each side. The external image template's "trail safe
  zone" (`1.1.0-design-side-tracks.md`, appendix) takes it from here.
