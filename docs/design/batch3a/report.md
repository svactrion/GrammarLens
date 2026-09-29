# 1.1.0 design side tracks — Batch 3a: trail geometry candidates

**Date:** 2026-09-30. **Branch:** `1.1.0-design` at `81e8a55` (`1.1.0` merged
first: "Already up to date"). **Scope:** study only. No product code, test,
config or asset changed; this folder is the only thing written. Nothing here
is a decision: the owner decides, and this report ends with one
recommendation.

Context: [`1.1.0-design-side-tracks.md`](../../1.1.0-design-side-tracks.md)
("Trail and scene", "Decisions after Batch 0" 4–6) and
[`1.1.0-design-batch0-report.md`](../../1.1.0-design-batch0-report.md)
(C3–C5, items 1–5, 12–13).

## How the numbers and images were made

- A throwaway harness kept outside the repository (session scratchpad, not
  committed), run with `flutter test` against the real package:
  - it imports `ClimbRoute`, `ClimbThemes.greenSlope`, `AvatarTile` and
    `buildAppTheme` from `lib/`;
  - it paints with a line-for-line copy of `_MountainPainter`
    (`lib/widgets/monthly_climb/monthly_mountain.dart`). The copy takes the
    trail, the steps, the landmark positions and the summit from a layout
    instead of from `ClimbRoute`. The mountain polygons, stroke widths (26
    and 21), step boxes (20 × 13), landmark drawings and palette are
    unchanged.
- **The images show the whole 320 × 740 scene at Home's card width** (375 pt
  screen → 341.25 pt, 320 pt screen → 288 pt), @3x:
  - Home itself shows only a **350 pt window** onto the scene. The two
    dashed lines mark that window with the pawn on day 12, placed the way
    `_follow` places it (pawn at 72 % of the window).
  - Everything outside the dashed lines is off screen on Home at that moment.
- **Avatar:** the snail (`avatar_02`). Its art faces left, so the mirroring
  is visible: the snail is flipped when its last move went right.
- **Measurements:**
  - Taken with Flutter's own `PathMetric` on the same paths that are drawn.
  - Lengths are in scene units; **pt figures are at 320 pt screen width**
    (scale 0.900). At 375 pt, multiply the units by 1.066.
  - Rules the measurements use, where a rule is needed:
    - **Turn:** a local extreme of x along the trail. Its radius is the
      smallest radius of curvature within ±40 units of that extreme.
    - **Leg:** the trail between two turns, or between a turn and the start
      or the end.
    - **Facing:** the sign of the last sideways move. Moves of under 3 units
      sideways keep the previous facing.
    - **Hop:** a parabola between two step centers, 14 units high at the
      middle.
    - **Avatar box:** 58 × 58, standing on the step, as today.
    - **Landmark box:** the union of the four drawings, 58 × 50.
- **Landmark placement:**
  - **Current trail:** the product's rule (42 toward the scene center, 22
    up).
  - **Candidates:** a rule written for this study. It picks the closest spot
    beside the landmark's own step, on either side, that is 4+ units off the
    trail band, covers no step, stays on the mountain and away from the
    summit. When no such spot exists, the fallback is 44 units along the
    normal; the report says where that happened.
- **Environment areas** (the `_free-areas` images):
  - The blocked zone is:
    - the trail band plus 6 units;
    - the avatar's box above every point of the trail, plus 4;
    - the landmarks plus 6;
    - the summit flag plus 6;
    - a 6-unit scene margin.
  - Greedy fill: the largest free rectangle with both sides at least 56
    units, then the next one at least 8 units away from those already
    taken, up to 6.
  - Boxes in the sky are still usable (birds, clouds). "On the mountain"
    below counts the boxes whose center is inside the mountain polygon.

## 0. Home size, re-measured after the C1–C3 merge

The real `HomeScreen` inside the real `FloatingNavShell`, with the bundled
NunitoSans font and fake storage. The fake shows 12 of 31 steps in October
2026, no Daily Test done, a free user, and no weak spots. Status bar and home
indicator insets are 20/0 pt, or 44/34 pt on the 812 pt tall screen.

| Screen | Text size | Card (mountain) | Scale | Window | Aspect w:h | Scene units visible | Mountain top | Fold (nav bar top) | Mountain above fold |
|---|---|---|---|---|---|---|---|---|---|
| 375 × 667 | Medium | 341.25 × 350 pt | 1.066 | 350 pt | 0.975 | 328 of 740 | 390 | 575 | 185 |
| 320 × 568 | Small | 288 × 350 pt | 0.900 | 350 pt | 0.823 | 389 of 740 | 397 | 477 | 80 |
| 320 × 568 | **Medium** | 288 × 350 pt | 0.900 | 350 pt | 0.823 | 389 of 740 | 411 | 476 | **65** |
| 320 × 568 | Large | 288 × 350 pt | 0.900 | 350 pt | 0.823 | 389 of 740 | 456 | 474 | 18 |
| 375 × 812 | Medium | 341.25 × 350 pt | 1.066 | 350 pt | 0.975 | 328 of 740 | 414 | 686 | 272 |

- **Size and aspect are unchanged since Batch 0** (item 12): card width
  `width − 2 × clamp(width × 0.045, 16, 28)`, a fixed 350 pt window, and the
  scene scaled to width.
- **The mountain now starts lower.** At 320 × 568 Medium it starts 14 pt
  lower than Batch 0 measured (411 vs 397), so 65 pt of it shows above the
  fold instead of 79. The climb header is now one row ("Monthly Climb ·
  October 2026", 351–377) plus the steps line.
- **Cause of the shift: not isolated.** The difference sits above the
  header: C1's Today card in this state, or a different month string. It
  does not change the scene's size; it only changes how much of it shows
  before scrolling.

## 1. The current trail: what is wrong

Measured on `ClimbRoute` as it is today; the images are named `current_*`.

| Days | Legs (units) | Turns: smallest radius (units) | Step spacing along the trail (pt) | Closest neighbouring steps (gap between boxes, pt) | End vs summit |
|---|---|---|---|---|---|
| 28 | 219, 218, 194, 154 | 44.6, 45.2, 53.1 | 19.4 – 28.4 | 3.6 (days 16→17) | 64 units |
| 29 | 216, 214, 191, 165, **40** | 41.9, 42.5, 50.0, **6.4** | 21.2 – **35.1** | 2.3 (24→25) | 64 units |
| 30 | 213, 210, 188, 162, 52 | 39.4, 40.1, 47.1, **14.6** | 20.7 – 27.4 | 1.7 (24→25) | 64 units |
| 31 | 210, 207, 185, 158, 66 | 37.1, 37.8, 44.6, 26.5 | 19.8 – 27.0 | **1.1** (24→25) | 64 units |

- **The last turn is a kink.**
  - Why: in 29–31-day months the trail gets a fifth "leg" after day 28, only
    40–66 units long, that bends back toward x = 160.
  - Its radius is 6.4 units in 29-day months and 14.6 in 30-day months,
    both narrower than the 26-unit trail itself. At the kink the stroke
    folds over itself.
  - This is the main reason the turns read as failed. The other turns are
    reasonable (37–53 units).
- **Every turn is an S-bend, not a switchback.**
  - Each leg is one cubic that leaves its stop vertically, crosses nearly
    flat and arrives vertically. Direction changes therefore happen in the
    middle of a leg, not at a turn.
  - Where two legs meet, the trail runs straight up for a moment, and steps
    are bunched along the diagonal.
- **Spacing is uneven.** Steps are spaced by leg and not along the whole
  trail, so spacing runs from 19.4 to 35.1 pt at 320 pt. Batch 0 measured the
  same figures, 22.0–39.6 units.
- **Where the markers come closest:**
  - **Neighbouring steps on the flattest stretch** (days 24→25, just before
    the last kink): their boxes are 1.1 pt apart in 31-day months, so they
    nearly touch.
  - **Steps on either side of a turn:** 55.4 pt apart at the closest (31
    days).
- **The landmarks sit on the trail.**
  - Why: the fixed "42 toward the center" offset lands on the next leg.
  - **31-day month:** all four overlap the trail band (0.0 units from its
    centerline) and cover steps:
    - campfire: days 8–10;
    - tent: days 15–17;
    - cabin: days 22–24;
    - lookout: days 29–31.
  - **28-day month:** three of the four overlap.
  - Visible in `current_375_light_31d.png`: the campfire sits on the trail.
- **Summit and end are two points.** The trail ends at (160, 120), and the
  peak and flag stand at (162, 56), 64 units higher. This is unchanged from
  Batch 0 (C5).
- **The avatar covers another leg while standing on 8 days** of a 31-day
  month (4 in a 28-day month): days 5, 6, 12, 13, 19, 21, 25 and 27.

## 2. The three candidates

In every candidate:

- **One path for all month lengths.** The path is shared by 28–31-day
  months, and only the spacing changes: day d sits at `L × d / days` along
  it.
- **Day 0 is at the foot.**
- **The last day is the trail's end at (162, 84), and the summit (flag
  base) sits exactly there.** That point is 28 units below today's peak
  vertex, so it lies inside the stone cap. The theme's summit layer would
  own everything above it (Batch 0 recommendation b).
- **Construction:** straight legs joined by true circular arcs (fillets),
  so the turn radius is a design value and not a by-product.

**(a) Refined serpentine: five straight legs, even hairpins.**

- Keeps today's structure: five legs zigzagging over the same width
  (turn x ≈ 94–222).
- Replaces the S-bends and the short kinked fifth leg with straight
  diagonals and four equal turns of radius 34 units. Inside the turn, the
  trail's inner edge has a radius of 21 units.
- Corners: (96, 694) → (248, 592) → (76, 470) → (244, 352) → (84, 234) →
  (162, 84).
- Length 862 units.

**(b) Wide S: three long legs, two broad bends.**

- Fewer, longer legs. The trail crosses the mountain twice with bends of
  radius 89 and 109 units, then climbs straight to the summit.
- Corners: (64, 700) → (270, 566) → (50, 338) → (162, 84), fillets 110.
- Length 762 units, the shortest of the four.

**(c) Silhouette: long legs at the foot, switchbacks tightening toward the
summit.**

- The legs follow the mountain's width: nearly the full 250 units at the
  foot, down to ≈ 90 near the summit. Turn radii fall with them, from 37 to
  22 units, like a real mountain road.
- Corners: (40, 708) → (290, 640) → (28, 540) → (272, 430) → (74, 330) →
  (232, 246) → (118, 170) → (162, 84), fillets 40 → 22.
- Length 1067 units, the longest, so it has the widest step spacing.

The brief's three examples were kept, because each tests a different lever:

- (a) better turns and nothing else;
- (b) fewer turns;
- (c) more trail length.

A fourth idea was tried in the first draft and dropped: the rounded corners
there were not circular, and it came out as a variant of (a).

## 3. Comparison

At 320 pt (scale 0.900). Two numbers are given as **31 days / 28 days**.

| | Current | (a) Refined serpentine | (b) Wide S | (c) Silhouette |
|---|---|---|---|---|
| Legs / turns | 4–5 / 3–4 (changes with the month) | 5 / 4 | **3 / 2** | 7 / 6 |
| Smallest turn radius (units) | **6.4** (29 d), 14.6 (30 d), 26.5 (31 d), 44.6 (28 d) | 33 | **89** | 22 |
| Step spacing along the trail (pt) | 19.4 – 35.1, uneven | 25.0 / 27.7, even | 22.1 / 24.5, even | **31.0 / 34.3**, even |
| Closest neighbouring steps, box gap (pt) | 1.1 / 3.6 | 3.6 / 6.3 | **0.6** / 3.0 | **8.7 / 12.0** |
| Closest steps across a turn, box gap (pt) | 55.4 / 57.1 | 62.0 / 52.4 | **65.5 / 73.9** | 49.4 / 54.9 |
| Closest two parts of the trail, centerlines (pt; bands touch at 23.4) | 59.7 – 70.2 | 62.9 | **77.8** | 55.8 |
| Days the resting avatar covers another part of the trail | 8 / 4 | 7 / 7 | **1 / 0** | 10 / 9 |
| Hop arc crosses another leg | never (clearance ≥ 21.6 pt) | never (≥ 21.3) | never (≥ 22.9) | never (≥ 21.5) |
| Avatar facing changes in the month | 4 / 3 | 4 / 4 | **2 / 2** | 6 / 6 |
| Trail end vs summit | 64 units apart | 0 | 0 | 0 |
| Landmarks | 4 of 4 on the trail (31 d), covering 3 steps each | clear; **no clear spot for day 28 in 28/29-day months** | clear; **no clear spot for day 28 in 28/29-day months** | clear except: **day 28 in 28/29-day months, day 14 in 30/31-day months** |
| Environment boxes ≥ 56 × 56: all / on the mountain / ≥ 80 on both sides (31 d) | 4 / 2 / 1 | 6 / 4 / 0 | **5 / 4 / 2** | 5 / 3 / 1 |
| Free area left for environment items (31 d) | 32.6 % | 28.9 % | **36.2 %** | 27.6 % |

**Risk points, by candidate.** Touch does not apply: on Home the scene takes
no taps and no user scrolling (`allowUserScroll: false`), so the risks are
about readability.

- **Current:**
  - the 29/30-day kink below the lookout;
  - landmarks drawn over steps;
  - the summit flag unreachable.
- **(a):**
  - The legs sit about as close as today (62.9 pt), and the avatar covers
    the leg above it on 7 days.
  - Neighbouring steps are 3.6 pt apart at the closest (31 days, days
    4→5, on the first leg).
  - The day-28 lookout has no clear spot in 28/29-day months. Its fallback
    sits 11.0 and 5.3 units from the centerline, on the trail band.
- **(b):**
  - The first leg is the flattest (−33°), so neighbouring steps nearly
    touch in 31-day months: 0.6 pt between boxes (days 1→2). Today's worst
    case is 1.1 pt.
  - The day-28 lookout has no clear spot near the summit in 28/29-day months
    (12.3 and 6.3 units from the centerline).
  - The last leg is a 250-unit straight line. On Home, a window can show a
    single straight stretch with no turn in view.
- **(c):**
  - The legs sit closest of all (55.8 pt between centerlines, in the upper
    half around (179, 274)), and the avatar covers another leg on 9–10 days.
  - The six turns mean the avatar turns around every 4–6 days.
  - The upper switchbacks (radius 22–24) are the tightest of the three
    candidates.
  - Two landmarks lack a clear spot.

## 4. Findings that apply to any geometry

- **Mirroring only shows on 4 of the 12 avatars.**
  - Koala, elephant, frog, chick, crab, cat, penguin and giraffe face the
    viewer and are nearly symmetric, so a horizontal flip does not change
    them visibly.
  - Snail, bee, turtle and hedgehog are side-on, and they do not all face
    the same way: the snail faces left.
  - So "faces the direction it walks" needs a native facing per avatar.
    Without one, half the side-on avatars would walk backwards.
- **The hop never crosses another leg in any layout**, including today's,
  at a 14-unit arc. The closest pass is 21.3 pt from another leg's
  centerline, outside the 11.7 pt half-band.
  - Crossing is therefore not what limits the hop height.
  - What limits it: on the three candidates, the avatar's box already sits
    over the leg above on 1–10 days of the month, and a higher arc adds to
    that.
- **The day-28 landmark in 28/29-day months has no clean spot** in any
  candidate. In those months day 28 is the summit day or the day before it,
  and the narrow top leaves no room beside the trail that is not taken by
  the summit.
  - Options for Batch 3b: a fixed spot for that landmark, or let the summit
    layer stand in for it when day 28 is the summit.
- **Step boxes are 20 × 13 units.** Anywhere the trail is flatter than
  about 35°, even spacing below about 24 units makes neighbouring boxes
  nearly touch.
  - This applies today and to (b).
  - Batch 3b can fix it with a steeper first leg or a narrower box; either
    is a small change.

## 5. Recommendation

**(b) Wide S**, refined in Batch 3b on two points:

1. make the first leg steeper, so neighbouring steps keep at least 3 pt
   between them in 31-day months;
2. give the day-28 landmark a fixed spot for 28/29-day months.

Why:

- **It is the only candidate that clearly beats today on every measure of
  overlap:**
  - the legs are farthest apart (77.8 pt against today's 59.7–70.2);
  - the resting avatar covers another part of the trail on 0–1 days,
    against 4–8 today and 7–10 for (a) and (c);
  - steps across a turn are the farthest apart.
- **Its two turns are the gentlest** (radius 89–109 units, against today's
  worst of 6.4). This directly answers the observation that the turns fail.
- **The avatar turns around only twice a month.** Each flip is visible and
  means something. That also helps with the 8 front-facing avatars, where a
  flip shows nothing.
- **It leaves the most room for environment items:**
  - 36.2 % of the scene is free;
  - 4 of its 5 free boxes are on the mountain, and 2 are at least 80 units
    on both sides.
  - Batch 0 decision 6 allows 2 items per theme next to the 4 landmarks, so
    that is enough, with room to choose.
- **What it costs:**
  - The shortest trail, so the tightest even spacing (22.1 pt per step at
    320 pt in 31-day months). That is still more even than today's
    19.4–35.1.
  - A long straight last leg.

Why not the others:

- **(a)** fixes the turns but keeps today's closeness between legs.
- **(c)** gives the widest spacing but brings legs and avatar closest to each
  other and adds the most turns.

## Images

Names: `<layout>_<screen width>_<mode>_<days>d[_free-areas].png`.

- **Layouts:** `current`, `candidate-a`, `candidate-b`, `candidate-c`.
- **Screen width:**
  - `375` = 341.25 pt card, 1024 × 2368 px.
  - `320` = 288 pt card, 864 × 1998 px.
- **Per layout (8 images):**
  - 375 and 320, light and dark, 31 days;
  - 375 and 320, light, 28 days;
  - 375 and 320, light, 31 days, `_free-areas`.
- **Overview:** `overview_375_light_31d.png` puts all four side by side
  (current, a, b, c).
- **Every image:**
  - avatar on day 12;
  - landmarks at days 7, 14, 21 and 28;
  - summit flag at the trail's end (for `current`, at today's peak, 64 units
    above the end);
  - dashed lines at the edges of Home's 350 pt window.
- **Total:** 33 files, 5.64 MB (5,917,990 bytes).

**Suggested review order:**

1. `overview_375_light_31d.png`: the four shapes side by side.
2. `current_320_light_31d.png`: today's problems at the smallest width
   (landmarks on the trail, the kink below the lookout, flag off the trail).
3. `candidate-b_320_light_31d.png`, then `candidate-b_320_dark_31d.png`: the
   recommendation in both modes.
4. `candidate-b_320_light_28d.png`: the 28-day lookout with no clear spot.
5. `candidate-b_375_light_31d_free-areas.png` next to
   `candidate-a_375_light_31d_free-areas.png` and
   `candidate-c_375_light_31d_free-areas.png`: room for environment items.
