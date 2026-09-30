# 1.1.0 design side tracks — Batch 3b, step 2: measurements before building

**Date:** 2026-09-30. **Branch:** `1.1.0-design`, fast-forwarded to `1.1.0`
at `89a3de1`, then the decisions commit `5595060` (D1–D7). **Scope:**
measure and report only. No product code, test or asset changed; this
folder is the only thing written. Nothing here is a decision. Each open
point ends with one recommendation; the owner decides.

Context: [`1.1.0-design-side-tracks.md`](../../1.1.0-design-side-tracks.md),
"Decisions after Batch 3a" (D1–D6); [`../batch3a/report.md`](../batch3a/report.md).

## How the numbers and images were made

- A throwaway harness in the session scratchpad (not committed), run with
  `flutter test` against the real package. It reuses the Batch 3a harness:
  a line-for-line copy of `_MountainPainter`, the 3a geometry code, and its
  measurement rules (turn, leg, hop, avatar box 58 × 58, step box 20 × 13).
  No render or golden infrastructure was added to the repository: step 3's
  coordinate check compares a generated table against the curve and needs no
  images, so nothing here would be reused.
- **Trail (b)** as in 3a: corners (64, 700) → (270, 566) → (50, 338) →
  (162, 84), fillets 110, steps evenly spaced along the path, the last day on
  the summit.
- **Card width** on Home is `width − 2 × clamp(width × 0.045, 16, 28)`:
  **288** pt on a 320 pt screen, **341.25** on 375, **391.3** on 430. Today's
  scale is card width ÷ 320 (0.900 / 1.066 / 1.223 pt per scene unit).
- **Home layout** (R4) is measured on the real `HomeScreen` in the real
  `FloatingNavShell` with the bundled NunitoSans font, the same fake storage
  as Batch 0, insets 20/0 (568, 667 pt tall), 44/34 (812) and 59/34 (932).
- **Avatar** in the images: the koala (`avatar_01`, the default), never
  mirrored (D4). **Markers** in the images follow D2. Their positions use
  3a's study placement rule; the real placement is part of step 3.
- Images are rendered at 2× (pt × 2 = px).

---

## R1. Curve: (b) today and steeper

**How it was made steeper.** The first leg's corner (270, 566) stays; its
start moves right along y = 700. Moving the corner up instead (tested at
40°, 45°, 50°) makes the second leg flatter and brings back touching steps
there (0.7–0.8 pt at 45°–50°), so that family is dropped.

**Sweep, 31-day month** (the worst case, shortest steps); pt at 320:

| First leg | Start | Trail length (units) | Closest neighbouring steps, box gap (pt) | Rise over days 1–4 (pt, 320) | Days the resting avatar covers another leg |
|---|---|---|---|---|---|
| **33° (today's b)** | (64, 700) | 762 | **0.6** (days 3→4) | 48.2 | 1 (day 6) |
| 38° | (98.5, 700) | 746 | 1.6 | 53.3 | 0 |
| 42° | (121.2, 700) | 736 | 2.6 | 57.2 | 2 |
| **45°** | **(136, 700)** | **730** | **3.3** | **60.0** | **1 (day 4)** |
| 48° | (149.3, 700) | 725 | 3.4 | 62.6 | 2 |
| 50° | (157.6, 700) | 722 | 3.4 | 64.2 | 1 |
| 55° | (176.2, 700) | 716 | 3.3 | 68.1 | 1 |

Leg-to-leg distance (77.6–77.8 pt) and the two turn radii (85–89 and 109
units) are nearly the same for every row.

**Today's (b) against 45°, at the three widths:**

| | Width | First-leg angle | Rise per step, days 1–4 (pt) | Sideways per step (pt) | Rise over days 1–4, 31 d / 28 d (pt) | On screen with today's camera, days 0→4 (pt) |
|---|---|---|---|---|---|---|
| (b) today | 320 | 33.0° | 12.1 | 18.5 | 48.2 / 53.4 | 48.2 |
| | 375 | 33.0° | 14.3 | 22.0 | 57.2 / 63.3 | 55.3 |
| | 430 | 33.0° | 16.4 | 25.2 | 65.5 / 72.6 | 49.1 |
| **(b) 45°** | 320 | 45.0° | **15.0** | 15.0 | **60.0 / 66.4** | 60.0 |
| | 375 | 45.0° | **17.8** | 17.8 | **71.0 / 78.7** | 55.3 |
| | 430 | 45.0° | **20.4** | 20.4 | **81.5 / 90.2** | 49.1 |

- **Today's (b) does rise**, but mostly sideways: each step moves 1.5× more
  across than up. That is why it reads as flat. At 45° a step moves as much
  up as across. The rise per step grows 24 %.
- **Last column:** today's camera keeps the avatar at 72 % of the window
  once it has climbed far enough. At 375 and 430 it starts following after
  about day 3, so on screen the avatar stops at 55.3 and 49.1 pt, and the
  mountain scrolls from there. This is the same for both curves. The camera
  is decided separately in R2.
- Other effects of 45°:
  - the trail is 4 % shorter, so each step is 23.6 units instead of 24.6
    (31 d);
  - the avatar turns at days 9 and 22 instead of 11 and 22 (no mirroring,
    D4);
  - the bottom-left of the scene is freed. Free area 37.9 % against 36.3 %,
    3 boxes of 80+ units against 2.

**Recommendation: 45°, start at (136, 700).**

- It is the **smallest angle that keeps neighbouring steps at least 3 pt
  apart in 31-day months** (3.3 pt). That was the 3a condition, and 42°
  misses it (2.6 pt).
- Going steeper buys little: 48°–55° add 2.6–8 pt of rise over 4 days, but
  shorten the trail and pull its foot toward the center. 48° also covers
  one more day.
- **Acceptance criterion (D1):** over days 1–4, 60 / 71 / 81.5 pt of rise
  at 320 / 375 / 430 (31-day month), against 48 / 57 / 65.5 today. The rise
  now equals the sideways movement.

Images: `r1_curve_<320|375|430>_<light|dark>_31d.png`. Each shows today's
(b) and 45° side by side, the whole scene, avatar on day 4, dashed lines at
today's Home window.

## R2. Framing

Three cameras. Each keeps the card at 350 pt tall, so Home's layout does not
move. Each keeps the avatar at 72 % of the window height, clamped to the
scene. Trail (b) at 45°, 31-day month.

- **F0, today:** the scene is scaled to the card's width. The window shows
  389 / 328 / 286 scene units of height (320 / 375 / 430), so **the wider
  the phone, the less mountain it shows.**
- **F1:** 480 units tall at every width, centered on the mountain
  (x = 160).
- **F2:** 600 units tall at every width, centered.

| Camera | Width | pt per unit | Visible (units, w × h) | Avatar (pt) | One day's step on screen (pt) | Step box (pt) | Summit in frame | Mountain edge in frame (≥ 40 pt of outline) | Sky share of the window, day 4 / day 12 |
|---|---|---|---|---|---|---|---|---|---|
| F0 | 320 | 0.900 | 320 × 389 | 52.2 | 21.2 | 18.0 × 11.7 | days 21–31 | 32 of 32 days (only 88 pt on days 0–4) | 1 % / 14 % |
| F0 | 375 | 1.066 | 320 × 328 | 61.9 | 25.1 | 21.3 × 13.9 | days 22–31 | **27 of 32; none on days 0–4** | **0 %** / 9 % |
| F0 | 430 | 1.223 | 320 × 286 | 70.9 | 28.8 | 24.5 × 15.9 | days 24–31 | **25 of 32; none on days 0–6** | **0 %** / 7 % |
| **F1** | 320 | 0.729 | 395 × 480 | 42.3 | **17.2** | 14.6 × 9.5 | **days 17–31** | **32 of 32** | 13 % / 31 % |
| **F1** | 375 | 0.729 | 468 × 480 | 42.3 | 17.2 | 14.6 × 9.5 | days 17–31 | 32 of 32 | 25 % / 42 % |
| **F1** | 430 | 0.729 | 537 × 480 | 42.3 | 17.2 | 14.6 × 9.5 | days 17–31 | 32 of 32 | 35 % / 49 % |
| F2 | 320 | 0.583 | 494 × 600 | 33.8 | 13.7 | 11.7 × 7.6 | days 12–31 | 32 of 32 | 37 % / 50 % |
| F2 | 375 | 0.583 | 585 × 600 | 33.8 | 13.7 | 11.7 × 7.6 | days 12–31 | 32 of 32 | 47 % / 58 % |
| F2 | 430 | 0.583 | 671 × 600 | 33.8 | 13.7 | 11.7 × 7.6 | days 12–31 | 32 of 32 | 54 % / 64 % |

- **The problem in D5 is measured here.** With today's framing, on 375 and
  430 pt phones the first 5–7 days of every month show no sky at all: the
  window is 100 % mountain, with no edge and no summit. That is the "flat
  color" the owner saw. At 320 there is a thin sliver of edge in the
  corners.
- **Daily step at 320 pt:**
  - **F0:** 21.2 pt.
  - **F1:** 17.2 pt, about 40 % of the avatar's height (42 pt), and the 850 ms
    glide still covers a distance larger than a step box (14.6 pt).
    **Still noticeable.**
  - **F2:** 13.7 pt; step boxes shrink to 11.7 × 7.6 pt and the avatar to
    34 pt. **Borderline:** a day's move is about one box.
- **F1 and F2 are the same at every width.** Wider phones get more sky at
  the sides, not a different zoom. So the scene is the same everywhere,
  which also suits D3 (a width-independent table).
- **F1's side sky at 430 pt (35–49 %)** is empty sky beside the mountain.
  This is where D5b's ridge/summit silhouette layer (Batch 4) goes.

**Recommendation: F1 (480 units tall).**

- The mountain edge is in frame on every day at every width, and the summit
  from day 17.
- A day's step stays readable at 320 (17.2 pt).
- The avatar is 42 pt against 52 today at 320. It gets smaller, but it
  stays larger than the Home header's text.
- F2 makes the step and the avatar too small for the smallest phone.

**Not applied.** Step 3.4 keeps today's framing unless this is approved.
Either way the camera becomes its own layer (D3), so switching later is a
one-line constant.

**Flag for the pre-release check:** any framing change alters Home in App
Store screenshots and case-study images.

Images: `r2_framing_<320|375|430>_light_31d.png`. F0, F1 and F2 side by
side, with the avatar on days 4, 12 and 24 (rows), each at the real card
size and corner radius.

## R3. Side-on avatars: which way they face

Checked on the bundled art (`assets/avatars/avatar_NN.webp`, 508 × 508; no
source PNGs are in the repository):

| Avatar | File | Facing |
|---|---|---|
| Snail | `avatar_02` | **Side-on, facing left**: head and eyes on the left, shell on the right |
| Bee | `avatar_04` | **Front-facing**: face toward the viewer, wings on both sides, nearly symmetric |
| Turtle | `avatar_09` | **Front-facing**: face toward the viewer, shell behind |
| Hedgehog | `avatar_12` | **Front-facing**: face toward the viewer, symmetric |

**Correction to Batch 3a §4:** that report called the bee, the turtle and
the hedgehog side-on. They are not. **Only the snail is side-on** (facing
left), so under D4 the snail is the only avatar that visibly walks
"backwards", on legs that go right (the first leg and the last).
Information only; nothing is mirrored.

## R4. The 14 pt shift at 320 pt

**Finding: there is no shift in the app.** The 14 pt comes from how Batch
3a measured.

- **Cause:** the app applies the text size in one place,
  `buildAppTheme(textSize:)` (`lib/app.dart:296–297`, `lib/theme.dart:432`:
  font size × `scaleFactor`). Batch 3a's harness used the default theme,
  which is already Medium (1.1), **and** added `MediaQuery.textScaler`
  1.0 / 1.1 / 1.2 on top. So its "Small" was really Medium, its "Medium"
  was 1.1 × 1.1 = 1.21 (the real Large lays out the same way), and its
  "Large" was 1.32.
- **Proof** (320 × 568, Daily Test not done, same fake storage as Batch 0):

  | Build | Inputs | How text size is applied | Today card | Header | Mountain top | Above the fold |
  |---|---|---|---|---|---|---|
  | `c629397` (Batch 0) | 15 Sep, 8 steps | theme, Medium | 208–329 | 341–389 | **397** | **79** |
  | `89a3de1` (now) | 15 Sep, 8 steps | theme, Medium | 208–329 | 341–389 | **397** | **79** |
  | `89a3de1` (now) | 12 Oct, 12 steps | theme, Medium | 208–329 | 341–389 | **397** | **79** |
  | `89a3de1` (now) | 12 Oct, 12 steps | theme **+ scaler 1.1** (3a) | 210–339 | 351–403 | **411** | 64 |
  | `89a3de1` (now) | 12 Oct, 12 steps | theme, **Large** | 210–339 | 351–403 | **411** | 64 |

  The full grid (4 screen sizes × 3 text sizes × both methods) is
  **identical** on `c629397` and `89a3de1`. The only change to
  `home_screen.dart` since Batch 0 is one string interpolation
  (`DailyTestSet.questionCount`), which renders the same text.
- **The hypotheses, one by one:**
  - **A fixed-width element overflowing or aligned wrongly: ruled out.**
    Every element's rect is identical between the two builds.
  - **The mountain box's height from the width (rounding or clipping):
    ruled out.** The height is a constant 350 pt
    (`monthly_mountain.dart`, `SizedBox(height: 350)`); only the scale
    depends on the width. It measures 288.00 × 350.0 in every row.
  - **SafeArea or margin difference: ruled out.** `padding.top` is 20.0 on
    both, and the side margin is 16.0 on both.
  - **The header text scaling: this is the mechanism, but only in the
    harness.** The 14 pt is 10 pt from taller Greeting and Today-card text
    plus 4 pt from the taller header, all from the doubled text scale. In
    the app, the same 14 pt is exactly the difference between Medium and
    Large, which is expected behaviour.
  - **Another card or band: ruled out.** The Today card is 208–329 in both
    builds.
- **Independent of the new mountain code: yes.** There is nothing to fix.
  Under D6 it is **not fixed here**, and there is no regression to lock.
- **What is wrong instead is documentation:**
  - Batch 3a report §0 is wrong:
    - its Small / Medium / Large rows are really Medium / Large / 1.32;
    - its "Mountain above fold" at 320 × 568 Medium is **79 pt, not 65**;
    - the climb header there is **two rows**, not one.
  - D6's reason in the side-tracks file repeats the 65 pt.
  - **Recommendation:** correct both in the approval commit (a docs-only
    note), and remove step 3.6 from this batch.

## R5. Plan: hop, score bar, header

Source: side-tracks "Trail and scene", "Home title", Batch 0 decision 7 and
report items 5, 13, 14. Every open point has one recommendation.

### Hop

- **Plan:** in `MonthlyMountain`, the pawn's position stays
  `route.pointAt(day)`. A vertical lift is added:
  `h × sin(π × frac(day − from))`, one arc per whole step, so a move of
  several steps makes several hops. The duration stays 850 ms per move and
  the curve stays `easeInOut`. `onMotionEnd` semantics and the scroll-follow
  are unchanged; the follow uses the point without the lift, so the camera
  does not bob.
- **Reduce Motion:** no hop. The pawn already jumps with no animation.
- **Open: hop height.** **Recommendation: 14 units** (the 3a value): 12.6
  pt at 320 with F0, 10.2 pt with F1. 3a measured that no hop of this
  height crosses another leg (clearance ≥ 21 pt); lower reads as a slide.
- **Open: one hop per step or one per move?** **Recommendation: one per
  step.** A normal day moves one step. Multi-step moves happen only when a
  month is reloaded with more steps (for example after the Day-0 flow), and
  there a hop per step shows the count.
- **Tests:** the lift is 0 at whole days; the peak is at half a step;
  Reduce Motion never lifts; `pumpAndSettle` still settles.

### Score bar

- **Data:** Home already loads `getClimbProgress(year, month)` (steps,
  correct, wrong, skipped). Score = `MonthlyMedalRules.score(correct:,
  wrong:)`. The marks are `MonthlyMedalRules.threshold(year, month, tier)`
  for the three tiers, as a share of `maxScore`: 25 / 50 / 75 %, rounded up
  in points. Nothing is hard-coded, and no rule changes.
- **Open: where.** **Recommendation: a separate row directly under the
  mountain window, inside the same rounded card** (a 26–30 pt strip), not
  drawn over the scene. Batch 0 item 13: anything under the mountain only
  moves Topic Practice, so the mountain above the fold at 320 × 568 stays
  79 pt. Drawn over the scene, it would cover the lowest part of the
  trail, which is where the avatar stands in the first week.
- **Open: what it shows.** **Recommendation:**
  - a 6 pt track with the fill in the accent color;
  - three ticks labeled "Bronze", "Silver", "Gold" (labelSmall), with a
    reached tier's label in its medal color;
  - no numbers on the bar itself.

  At 320 the ticks sit 72 / 144 / 216 pt from the left, so the labels (about
  40 pt each) do not collide.
- **Semantics:** one label, for example "Score 46 of 310. Bronze at 78,
  Silver at 155, Gold at 233." **Open:** whether to speak points at all.
  **Recommendation: yes**, because VoiceOver has no other way to read the
  bar.
- **Tests:**
  - the marks for 28/29/30/31-day months equal `threshold()`;
  - fill at 0 and at the maximum;
  - labels do not overlap at 320 pt and Large text;
  - the semantics string.

### Header "Mountain of Learning · \<month\>"

- **Measured:**
  - "Mountain of Learning · September 2026" is **314.4 pt** wide at Medium
    (titleMedium, NunitoSans). The text column on a 320 pt screen is 288
    pt, so **the title itself wraps**. Even "… October 2026" is 291.0 pt.
  - Today "Monthly Climb · September 2026" is 262.7 pt and fits; the header
    is 2 rows only because "n / N steps" wraps under it.
  - With the new title the header becomes **3 rows at 320 pt** (the title
    on 2, then the steps). That is +24 pt, and the mountain above the fold
    drops from 79 to about 55 pt.
  - At 375 pt it still fits (341 pt column).
- **Open: layout.** **Recommendation:**
  - **row 1:** "Mountain of Learning";
  - **row 2:** "\<month\> · n / N steps".

  That keeps exactly 2 rows at every width and text size measured, with the
  same information and no loss above the fold. It changes the separator
  from Batch 0 decision 7 ("Mountain of Learning · [month]" on one line),
  so it needs the owner's yes. The fallback is to keep the one-line form
  and accept 3 rows at 320.
- The mountain's VoiceOver label keeps "Green Slope" (the theme name); the
  progress live region is unchanged.
- **Tests:** the header text; row count at 320 / 375 × Small / Medium /
  Large (with the theme's text size, not a `textScaler`, see R4).

## R6. Stop markers by month length, D2 applied

The marker at day d is drawn only if `days − d > 2`.

| Days | Day 7 | Day 14 | Day 21 | Day 28 |
|---|---|---|---|---|
| 28 | drawn | drawn | drawn | **not drawn: day 28 is the summit** |
| 29 | drawn | drawn | drawn | **hidden** (1 step before the summit) |
| 30 | drawn | drawn | drawn | **hidden** (2 steps before the summit) |
| 31 | drawn | drawn | drawn | drawn (3 steps before the summit) |

- In the 31-day month the lookout is drawn beside day 28, just under the
  summit.
- 3a's study rule found a clear spot for it with this curve. Its final
  placement is part of step 3, when the markers get their positions in the
  generated table.

Images: `r6_markers_<28|29|30|31>d_375_light.png`: the whole scene, trail (b)
at 45°, avatar on day 12.

---

## For approval

1. **Curve:** (b) with its first leg at **45°** (start (136, 700); the other
   corners and fillets unchanged). R1.
2. **Framing:** **F1, 480 units tall at every width**, or keep today's. R2.
3. **320 pt shift:** no fix. Correct Batch 3a §0 and D6's "65 pt"; drop
   step 3.6. R4.
4. **Hop:** 14 units, one per step. R5.
5. **Score bar:** its own strip under the mountain, inside the card, with
   the points in the semantics label. R5.
6. **Header:** "Mountain of Learning" on row 1, "\<month\> · n / N steps" on
   row 2. R5.

## Images

- `r1_curve_{320,375,430}_{light,dark}_31d.png` (6)
- `r2_framing_{320,375,430}_light_31d.png` (3)
- `r6_markers_{28,29,30,31}d_375_light.png` (4)
