# 1.1.0 design side tracks — Batch 3c-A: mountain redesign candidates

**Date:** 2026-09-30. **Branch:** `1.1.0-design`; `1.1.0` merged first
("Already up to date": `1.1.0` is at `9dbab61`; this branch also carries
the greeting fix, which is waiting for the owner's device check). Decisions:
`133c53f` ([`1.1.0-design-side-tracks.md`](../../1.1.0-design-side-tracks.md),
"Batch 3c — mountain redesign"). **Scope:** study only.

- No product code, test or asset changed; this folder is the only thing
  written.
- Not touched in the design: the Daily Test data flow, `dayKey`, the medal
  rule.
- Nothing here is a decision; the report ends with one recommendation.

## Review first

1. `overview_375_light_31d.png`: today (Batch 3b), candidate 1 and
   candidate 2 side by side at 375 pt, 31 days, avatar on day 3 (top row)
   and day 25 (bottom row).
2. `c1_320_light_31d.png` and `c2_320_light_31d.png`: the smallest width.
3. `c1_375_dark_31d.png` and `c2_375_dark_31d.png`: dark mode.
4. `c1_framing_375_light_31d.png` and `c2_framing_375_light_31d.png`: F1
   against the whole mountain.
5. `c1_375_light_28d.png` and `c2_375_light_28d.png`: 28 days (D2 at work
   near the summit).

## How the images and numbers were made

- **A throwaway harness in the session scratchpad** (not committed), run
  with `flutter test` against the real package. It uses:
  - the product's Green Slope palettes (`ClimbThemes.greenSlope`), light and
    dark;
  - `AvatarTile`;
  - the real `ClimbScoreBar` with `MonthlyMedalRules` thresholds;
  - the app theme (`buildAppTheme`), with the bundled NunitoSans.

  The stop-marker drawings are a line-for-line copy of the product
  painter's private `_landmark`.
- **"Today" is built from the product:** the real `MonthlyMountain` and
  `ClimbScoreBar` under the two header rows copied from
  `HomeScreen._buildClimb`.
- **Scene space is today's:** 320 × 740 units. Framing F1 (480 units tall,
  0.729 pt per unit, pawn at 72 %) is today's camera (D5); "whole mountain"
  shows all 740 units (0.473 pt per unit).
- **Avatar: the snail** (`avatar_02`), the only side-facing avatar (Batch 3b
  R3), **mirrored to face its walking direction** (decision d). Score in the
  images: 7 points a day (about 70 % correct).
- **Measuring rules** are Batch 3a's unless stated:
  - the avatar box is 58 × 58 above its step;
  - "covers another part of the trail" is that box, less 4, within the
    trail band of a part more than 70 units away along the trail;
  - stop markers use the 3a placement rule, D2 applied;
  - free areas are greedy rectangles of 56 units or more on the ground,
    x 4–316.
- **Step markers are pills** 18 × 11 units, turned with the trail
  (decision d). Gaps are measured between their outlines.
- Raw numbers: [`candidate_numbers.json`](candidate_numbers.json),
  [`framing_numbers.txt`](framing_numbers.txt),
  [`shell_numbers.txt`](shell_numbers.txt).

## The two candidates

Both have:

- the card shell (1a–1c): a thin frame with the card's `outline` border,
  a trail-sign plaque centered on its top line, "October" at the top left
  and "3 / 31" at the top right, and today's score bar at the bottom;
- the trail ending exactly on the summit, with the flag there;
- Green Slope's two environment items, a pine and a shrub with
  wildflowers. With the 4 stop markers that is 6 objects (decision f).

**Candidate 1 — layered ridges.**

- A concave main peak (half-width 22 + 240 · t^1.25 from the summit down).
- A lit left face and a shadowed right face split along a jagged ridge
  line, and a pale rock cap.
- **Two lighter ridges behind**, far and mid, both leaning toward the sky.
- Two rounded foothills in front.
- Five legs, from a long 12° start to a 73° final climb.

**Candidate 2 — one big peak over a wide plain.**

- A broader massif (half-width 32 + 250 · t^1.1) with one strong ridge line
  separating light from shadow, and a darker crease facet on the lit face.
- A wide, almost flat plain across the foot, where the trail starts with a
  286-unit walk at 6°.
- Only one low, faint range behind, visible mainly in the wide framing.
- Six legs, 6° to 68°.

**Changes made while measuring**, each forced by a number:

- **The first versions had 7–8 legs and tight turns (18–40 units).**
  - The resting avatar covered another leg on 9–12 days a month.
  - C1 had no clear spot for the day-28 marker in 31-day months, nor for
    day 21 in 30-day months.
  - Cutting to 5–6 legs and widening the turns fixed both.
- **C2's peak was narrower** (half-width 18 at the top). There was no clear
  spot for its day-28 marker in 31-day months, even with 3a's
  "top into the sky" second pass. It was widened to 32.

## Measurements

Units are scene units unless marked; pt figures are at F1 (0.729 pt per
unit), the same at every width. "Today" is Batch 3b as built (its report,
R1–R2).

| | Today (3b) | Candidate 1 | Candidate 2 |
|---|---|---|---|
| Legs, bottom → top: angle (length) | 45° (190), then two broad bends | **12° (260), 30° (238), 40° (217), 50° (196), 73° (171)** | **6° (286), 31° (256), 39° (220), 47° (191), 62° (148), 68° (74)** |
| Turn radii | 85.5, 108.7 | 42, 69, 58, 46 | 38, 69, 56, 40, 26 |
| **Smallest turn radius** | 85.5 | **42** | **26** |
| Trail length | 730 | 968 | 1017 |
| Step spacing, 31 / 28 days (pt at 320, F1) | 17.2 / 19.0 | **20.6 / 22.8** | **22.0 / 24.4** |
| Closest neighbouring step markers, gap, 31 / 30 / 29 / 28 days (pt) | 2.7 (31 d; 3.3 in the 3b report, at 1.0's 0.9 pt per unit) | 5.2 / 5.8 / 6.4 / 7.2 | 6.0 / 7.0 / 7.6 / 8.3 |
| Closest step markers across a turn, gap (pt) | 51.6 (31 d; 63.7 in the 3b sweep, at 0.9 pt per unit) | 48.6 / 49.1 / 40.7 / 42.2 | 39.0 / 40.8 / 41.4 / 42.2 |
| **Days the resting avatar covers another part of the trail**, 31 / 30 / 29 / 28 | 1 / – / – / 0 | **3 / 5 / 3 / 5** | **5 / 5 / 4 / 6** |
| Avatar turns around in a month | – (never mirrored) | 4 | 5 |
| Stop markers, D2 applied | all placed | **all placed in 28–31**; closest to the trail band 4.3 units | **all placed in 28–31** after the widening; closest 4.1 |
| Environment items placed | – | pine (300, 556), shrub (64, 398); 94 / 85 units from the trail | pine (20, 520), shrub (28, 418); 85 / 117 units |
| Free area left for more items, after the 6 objects | not comparable: 3a's 36–38 % also counted boxes in the sky; here only the ground counts | **9.1 %**, 3 boxes: 76×144, 64×88, 76×64 | **14.2 %**, 3 boxes: 56×272, 92×120, 64×116 |
| Trail samples off the ground | 0 | 0 | 0 |

**Stop markers, where they fall** (drawing origin, units; D2 hides day 28
in 28–30-day months):

| Days | Candidate 1 | Candidate 2 |
|---|---|---|
| 31 | 7 (251, 667), 14 (84, 466), 21 (219, 299), 28 (183, 192) | 7 (265, 698), 14 (101, 477), 21 (219, 311), 28 (128, 148) |
| 30 | 7 (249, 653), 14 (98, 447), 21 (211, 290) | 7 (266, 682), 14 (120, 460), 21 (205, 295) |
| 29 | 7 (250, 638), 14 (115, 434), 21 (198, 273) | 7 (266, 665), 14 (133, 449), 21 (190, 279) |
| 28 | 7 (250, 622), 14 (126, 424), 21 (183, 256) | 7 (266, 646), 14 (145, 439), 21 (86, 329) |

- **What the new trail shape costs:** more legs and tighter turns than
  3b's two broad bends. So the resting avatar covers another part of the
  trail on 3–6 days a month instead of 0–1. Every such day is just past a
  turn.
- **What it gains:**
  - the flat start and steepening legs the decision asks for;
  - wider spacing (20.6–22.0 pt against 17.2 at 320 pt), because the trail
    is 33–39 % longer;
  - step markers that no longer come close to touching (5.2–8.3 pt against
    3.3).

### Framing: F1 against the whole mountain

At the card widths of 320 / 375 / 430 pt screens:

| | Avatar | One day's step | Summit in frame | Sky share of the window, day 3 / day 25 |
|---|---|---|---|---|
| C1, F1 | 42.3 pt | 20.6 pt | days 19–31 | 8–11 % / 55–59 % |
| C1, whole mountain | 27.4 pt | 13.4 pt | every day | 39–43 % / 39–43 % |
| C2, F1 | 42.3 pt | 22.0 pt | days 20–31 | 12–25 % / 54–66 % |
| C2, whole mountain | 27.4 pt | 14.3 pt | every day | 49–57 % / 49–57 % |

- The whole-mountain framing shows the summit every day and the most sky.
  - But the avatar drops to 27 pt, smaller than the step counter's text
    line, and a day's step to 13–14 pt.
  - That fits decision (g)'s one-time zoom at the month change (Batch 6),
    not a resting framing.
- In F1 the candidates, like today, show little sky in the first days. C1's
  ridges behind are what shows there instead.

### Card shell

- **Plaque:** 211.6 / 229.0 / 246.4 pt wide at Small / Medium / Large, and
  34 / 36 / 38 pt tall.
- **Plaque and the month/counter row at 320 pt:**
  - **no overlap** at any text size;
  - the row sits 6 pt below the plaque's bottom, at 40 / 42 / 44 pt from
    the frame's top.
  - The plaque leaves 29 pt (Medium) on each side at 320 pt, too little
    for "October". So the month and the counter cannot share the plaque's
    line; they sit on a row of their own just under it.
  - The longest row, "September · 30 / 30", fits in all cases.
- **The flag against the plaque at day 25** (window at the top): the flag
  top is 18.5 pt (C1) and 15.5 pt (C2) below the plaque's lower edge.
- **Contrast:**

  | | Light | Dark |
  |---|---|---|
  | Plaque text (`onSurface` on `surfaceContainerHigh`) | **13.64:1** | **11.06:1** |
  | Plaque border (`outline`) against the card / the body | 2.72 / 3.11 | 4.20 / 5.05 |
  | Month and counter (`ink`, labelLarge w700) on sky / far ridge / mid ridge / lit face | 10.05 / 8.29 / 7.31 / 6.22 | 12.36 / 9.09 / 7.35 / 5.63 |
  | ... on the **shadow face** | **3.78** | 7.83 |

  The plaque border matches the app's card border (the same `outline`
  role).
  - **Open point:** in light mode, `ink` on the shadow face is 3.78:1. That
    is under 4.5:1 for text of this size.
  - In every render the two labels sit over sky or the far and mid ridges,
    but nothing guarantees it on every day.
  - **Suggested fix, not applied:** a small backing chip in the sky color
    behind each label.

### Dark mode: proposed tones for the new layers

Each tone is derived from Green Slope's existing palette by one rule, so a
future theme gets its tones the same way:

- farther layers lean toward the sky (haze);
- the shadow face is the palette's `ridge`;
- ground in front leans toward `ridge`;
- trees lean toward whichever of `ink` and `sky` is darker.

In dark mode that means the far ridges get darker, closer to the night
sky, which is what distance does against a dark sky.

| Layer | Rule | Light | Dark |
|---|---|---|---|
| far ridge | mountain → sky 58 % | #D0DED1 | #293B39 |
| mid ridge | mountain → sky 32 % | #C0D2C0 | #334A45 |
| lit face | `mountain` | #ACC4AC | #405C53 |
| shadow face | `ridge` | #789B86 | #2E463F |
| crease (C2) | mountain → ridge 45 % | #95B29B | #38524A |
| rock cap | `stone` | #F5F0DF | #C8C8B9 |
| foothills | mountain → ridge 28 % | #9DB9A1 | #3B564D |
| plain (C2) | mountain → ridge 18 % | #A3BDA5 | #3D584F |
| pine / trunk | ridge → darker of ink and sky 38 % / 70 % | #597769 / #3F5950 | #263936 / #1F2E2E |
| shrub | mountain → ridge 78 % | #83A48E | #324B43 |

Flat colors only; no gradients (decision e).

## Recommendation: Candidate 1 (layered ridges)

- **It is the only one that fully meets (e) in the everyday framing.**
  - The lighter ridges behind the peak show in F1 on every day, at every
    width. That is what makes the first days of a month read as a mountain
    and not a green wall.
  - C2's single faint range is mostly hidden behind the plain in F1 and
    shows only in the whole-mountain framing.
- **It is the better trail by the measures that make the trail readable:**
  - the smallest turn is 42 units against 26;
  - the avatar covers another part of the trail on 3–5 days a month against
    4–6;
  - there are 5 legs against 6, so the snail turns around 4 times a month
    against 5.
- **What it costs against C2:**
  - less room for more items: 9.1 % free against 14.2 %;
  - a day's step at 320 pt of 20.6 pt against 22.0;
  - a first leg at 12° against 6°. It is still low and long (the longest
    leg), as the decision asks.
- **One more open point for either candidate:** the light-mode contrast of
  the month and counter on the shadow face (3.78:1).
