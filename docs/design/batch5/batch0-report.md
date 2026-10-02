# Batch 5 — Batch 0 report: medals, save point names, the C5 signpost

**Status: read, measured, rendered; nothing of Batch 5 is built.** Branch
`1.1.0-design` (`1.1.0` merged in first: already up to date, both at
`8301088`); not pushed. Written 2026-10-02. No `lib/` or `assets/` change.

The owner's decisions R1–R14 are recorded as **N1–N14** (same numbers):
"R1"–"R6" already name the Batch 3b report's items, which the side-tracks
file cites.

| Commit | What |
|---|---|
| `2ddef83` | Step 1: N1–N14 in `docs/1.1.0-design-side-tracks.md` and `docs/build-log.md`; 1.2 parks (N5, N6, N7) in `docs/roadmap.md` |
| `4a53de9` | Step 2: the owner's inputs (hashes verified), `build_medals.py` unchanged, `tool/medals/README.md` |
| `065d879` | Step 3: measuring tools under `tool/` and their outputs in this folder |
| this one | Step 4: this report |

Every number comes from a tool and is reproduced by the commands in [How
to reproduce](#how-to-reproduce). What I could not measure is marked
**not measured**; what I only looked at in a render is marked **seen, not
measured**. Text size goes only through `buildAppTheme(textSize:)`. Line
numbers are at `065d879`.

---

## Summary

1. **The Day-0 Welcome card is never on screen when it appears.** On the
   real result screen it sits under the five results: 980–1954 pt below
   the fold at every screen and text size. Today the user sees only the
   footer button turn into "Start my climb"; the confetti plays on that
   tap, as the exit. N8's "reuse the Welcome layout" would inherit this.
   §2.
2. **N6's label above the object hides the avatar's head.** The avatar
   stands on the trail beside the object it just reached; a label above
   the object overlaps the avatar art's box in 43 of 45 cases, by up to
   80 % (seen in the renders: the koala's head is under it). Placing the
   label above the object *and* the avatar clears it everywhere. §3.
3. **Profile would contradict N8.** Today Profile lights a tier only
   after the month is finalized; a user celebrated for Silver on the 18th
   would see Silver "Not earned" there until the month ends. §5.
4. **The month card's medal is 40 pt, under the stars' 48 readability
   floor.** At a 48 pt disc the summary card grows 10.7 pt and scrolls by
   2.2 pt at 320 × 568 Large; kept at 40 pt (whole image fitted), every
   Batch 6 height is unchanged. The card also has no previous-month theme
   to pick the medal by. §1.
5. **The signpost fits C5 at ratio 0.95, on a knife-edge** (1.0 and 0.90
   both touch the trail), and comes out as large as the tent (30 pt at
   375 pt). Colour separation from the ground is ΔE2000 ≥ 14.2 in all
   eight theme/mode cases. N11's step claim is right: C5 is reached on
   step 26 of 28 and 29 of 31. §4.
6. **Tier crossings and save points need no new record for "once per
   month":** each completion adds exactly one ledger row and the score
   only grows, so "before" is "after minus this completion". One edge
   needs a guard: a set completed after its month was finalized. §2, §6.
7. **Source images are at 97.51 MB** (28 files), 2.5 MB under G1's
   100 MB review line. The next theme crosses it. Step 2.
8. **Poppins' OFL text is not in the repository**, although the TTF now
   is. §1, §8.

Owner decisions needed: [§9](#9-questions-for-the-owner).

---

## Step 2 — inputs

- All 14 files matched their sha256 prefixes; nothing missing, nothing
  extra (`docs/design/medals/source/`: 12 files; `tool/medals/
  build_medals.py`; `docs/design/scene-art/source/objects/signpost.png`).
- `build_medals.py` ran unchanged with the scene-art environment (Pillow
  11.3.0, NumPy 2.0.2, Python 3.9.6) in about 2 s: **13 images** at 768 px
  (`medal_<theme>_<tier>.png` × 12, `medal_welcome.png`) into
  `build/medals/png/`. Two runs are byte-identical.
- **Not adapted to the tool layout.** It takes its paths as arguments,
  which works from the repository root; changing it would only add
  defaults, and the hash you recorded would then no longer describe it.
  So no before/after pixel comparison was needed.
- **Source images in the repository** (working tree = history: no older
  versions of these paths exist):

  | | Files | MB |
  |---|---|---|
  | `docs/design/scene-art/source/` (signpost included) | 17 | 86.10 |
  | `docs/design/medals/source/` (images) | 11 | 11.41 |
  | **All source images** | **28** | **97.51** |
  | + Poppins-Bold.ttf | 1 | 0.16 |

  G1 (open item): "looked at again if the total passes 100 MB". It is
  2.5 MB under. One more theme pair (light + dark) is about 17–19 MB.
  The whole `.git` is 148 MB.

---

## 1. Where medals are drawn, and the new images there

**Today.** One shared widget, `MedalBadge`
(`lib/widgets/medal_badge.dart:11-66`): a circle tinted with the tier's
colour, a landscape icon, a lock badge while not earned.

| Place | What | Size today | Code |
|---|---|---|---|
| Profile, tier row | three `MedalBadge`s, `Expanded` + `AspectRatio(1)` | 90.7 / 108.4 / 125.1 pt at 320 / 375 / 430 | `monthly_medal_collection.dart:59-72`, `:320-361` |
| Profile, Welcome row | trophy icon in a row card | 28 pt icon | `monthly_medal_collection.dart:101-188` |
| Profile, history rows | `workspace_premium` / lock icon | 24 pt icon | `monthly_medal_collection.dart:253-318` |
| Month card (summary) | `MedalBadge` | 40 pt, icon 20 | `month_card_sheet.dart:116-127` |
| Day-0 result, Welcome card | trophy in a tinted circle | 80 pt (44 + 2 × 18) | `daily_test_result_screen.dart:375-427` |
| Home score bar | tier colours on the marks and labels (no medal) | — | `climb_score_bar.dart:30-31`, `:113-130` |
| `lib/preview/monthly_medal_preview.dart` | debug preview of the collection | as Profile | — |

**The images' geometry** ([`medal_assets.txt`](medal_assets.txt)): every
medal shares one disc (the body), 681.95 px of the 768 px canvas. The
monthly medals' stars stand up to **5.6 % of the diameter above the
disc** and nowhere else. The Welcome ribbon crosses the round outline at
the top corners (up to 13.2 % past the disc) but stays **inside the
disc's bounding square**. So:
- circle kept at D: the monthly box is D wide and 1.056 D tall; Welcome
  D × D;
- whole image fitted in a square S: the disc is 0.947 S.

**Prototype** (`tool/design_measure/batch5/medal_prototype.dart`, copies
of today's widgets with the images; [`sites/`](sites/)): Profile today and
an N10 proposal, the month card at a 48 pt disc, the Welcome card and N8's
celebration in the same card at a 112 pt disc; 320 / 375 / 430 pt, light
and dark, three text sizes (18 renders, overviews in
`sites_light_medium.jpg`, `sites_dark_medium.jpg`,
`sites_320_textsizes_*.jpg`).

**The month card's heights** ([`sites/medal_sites.txt`](sites/medal_sites.txt)):
the sheet's content, Small / Medium / Large, the same at every width.

| Medal in the card | Height (pt) | Change | 320 × 568 (sheet at most 319.5 pt) |
|---|---|---|---|
| today (real `MonthCardSheet`) | 294 / 302 / 311 | — | fits |
| image fitted in the 40 pt box (disc 37.9) | 294 / 302 / 311 | **none** | fits |
| disc 40 (stars above) | 296.2 / 304.2 / 313.2 | +2.2 | fits |
| disc 48 | 304.7 / 312.7 / 321.7 | +10.7 | **scrolls 2.2 pt at Large** |
| disc 56 | 313.1 / 321.1 / 330.1 | +19.1 | scrolls at Medium and Large |

- The copy fitted in 40 pt gives exactly the real card's numbers, which
  checks the copy.
- The Batch 6 numbers equal these heights (`batch6/card/
  month_card_real_numbers.txt`: sheet 294 / 302 / 311); the sheet heights
  with a larger medal are **computed** as Batch 6's sheet + the measured
  change, not measured in a sheet over Home. At 375 × 667 (max 375.2 pt)
  every option fits. At 320 pt the mountain above the sheet shrinks by
  the same 10.7 pt (from 104 to about 93 pt at Medium).

**The Day-0 card**: 212–249 pt today; with a 112 pt image +32 pt.

**Seen, not measured:**
- At 48 pt the stars read in the renders; the Welcome ribbon's word reads
  at 112 pt and not in the 64 pt Profile row (N2's known limit).
- Faded medals (N10) look washed out on the light surface and muddy on
  the dark one; earned and faded stay distinguishable, Gold faded reads
  olive on dark.
- On dark the medals' own light rims carry them; Red Canyon on Bronze is
  the weakest pair, as N1 says.

**Asset size** ([`medal_assets.txt`](medal_assets.txt), WebP, alpha
lossless, method 6, 13 images):

| px | quality | all 13 | worst mean / p99 error (0–255) |
|---|---|---|---|
| 256 | 90 | 229.0 KB | 2.23 / 20.8 |
| 384 | 90 | 376.3 KB | 1.81 / 16.0 |
| 512 | 90 | 535.2 KB | 1.55 / 14.0 |

Today's `assets/` is 3.98 MB on disk (climb 2.55 MB).

**Recommendation.**
1. **Assets: 384 px WebP quality 90, 376 KB (+9.4 % of `assets/`).**
   *Why:* the largest planned use, a 112 pt disc, needs a 126 pt canvas,
   378 px at 3x; 384 covers it, and 512 costs 159 KB more for nothing
   shown. If the celebration grows past a 113 pt disc, go to 512. The
   tool exports from `build_medals.py`'s output; the composed PNGs stay
   out of the repository (N3).
2. **One widget, `MedalBadge`, drawing the image with the disc as its
   size and the stars above it** (box D × 1.056 D), faded through the save
   points' own matrix (`ClimbSavePoints.matrix(lit: 0)` is exactly N10's
   0.5 / 0.6, `climb_save_points.dart:181-215`). *Why:* M8 already routes
   Profile and the month card through it, so both follow.
3. **Month card: keep the 40 pt box with the image fitted** (disc 37.9).
   *Why:* every Batch 6 height stays as measured and accepted; the cost
   is unreadable stars there (below 48), which the "Silver medal" text
   beside it already says. A 48 pt disc would make the card scroll at
   320 pt Large (question Q3).
4. **The card needs last month's theme**: `MonthCardData.theme` is the
   new month's (`month_transition.dart:107`). `MonthTransition.load`
   resolves the previous month's theme too (a read; a past month without
   a row is Green Slope).

---

## 2. The Welcome celebration today, and N8's tier celebration

**Today, the Welcome badge.**
- `StorageService.completeDailyTest` (`storage_service.dart:979`) returns
  "just earned" from inside the save's transaction; the result screen
  turns it on (`daily_test_result_screen.dart:115-141`).
- The card eases in **at the end of the results list**
  (`:336-362`), deliberately below the results so it never pushes them
  down. The footer button becomes "Start my climb" (`:260-273`).
- The confetti plays **only when that button is tapped** (`:147-182`),
  from the button, and the screen leaves when it ends (`:194-205`).
  Reduce Motion: no confetti, the screen leaves at once.
- **Measured** ([`welcome/welcome_result.txt`](welcome/welcome_result.txt)):
  at the list's scroll top the card is **0 % on screen** on 320 × 568,
  375 × 667, 375 × 812 and 430 × 932, every text size; the list must
  scroll 980–1954 pt to show it. Nothing scrolls it into view.

**Today, when the score crosses a threshold:** nothing happens at that
moment.
- No code compares the score before and after a save; no event fires.
- On the next Home load the score bar's fill moves and the reached
  tier's label turns bold and coloured, without animation
  (`home_screen.dart:440`; `climb_score_bar.dart:30-31`, `:113-130`).
- The medal exists only after the month ends: `finalizePastMedalMonths`
  (`storage_service.dart:1118`) at the next launch, resume
  (`app.dart:95`, `:119`, `:137`) or Profile open
  (`settings_screen.dart:156-177`).

**Detecting the crossing** (no change to `DailyTestService` or the
storage transaction):
- each completion writes exactly one ledger row (`step` 0/1, its counts)
  and rows are never deleted, so for the set's month: *after* =
  `getClimbProgress` after the save; *before* = after − this completion's
  step and points. A tier is crossed when `tierFor(before) <
  tierFor(after)`; a save point when `before.steps < reachedOn(days) ≤
  after.steps`;
- one day is worth at most 10 points and every tier band is at least 70,
  so one completion crosses at most one tier; the Day-0 test can never
  cross Bronze (10 < 70), so the Welcome card and a tier never meet;
- **edge:** a set started before midnight on the month's last day, the
  app sent to the background and resumed (which finalizes that month)
  and then finished: its row lands in a month already frozen. A
  celebration there would show a tier the frozen medal does not have.
  Guard: no celebration when the set's month has a
  `monthly_medal_results` row.

**"Once per tier per month" needs no new record:** a set completes once
(`completeDailyTest` ignores a completed set) and the score only grows,
so each crossing happens on exactly one completion. The cost: a
celebration lost to an app killed on that screen is not shown again (the
month card still sums up the month).

**Where and in what order.**

| Moment | Where it happens | Can it meet a tier crossing? |
|---|---|---|
| Tier crossed | the result screen, right after the save | — |
| Avatar's step, save point fade (G8), label (N6) | Home, after the result screen is left | yes: from step 7 on, the same completion can cross a tier and reach a save point (a 28-day month with 7 fully correct days crosses Bronze on the step that reaches First Camp) |
| First run: zoom → step → Premium (M14) | Home after the first-launch flow | no: Day 0 cannot cross Bronze, and step 1 reaches no save point |
| Month card (M1) | the month's first Home open | no: it comes before the month's first test |

**Recommendation: the celebration happens on the result screen, as an
overlay that opens when the save lands** (the Welcome card's content: the
image at a 112 pt disc, the title, one line), with the confetti at the
opening, closed by one tap back to the results; the footer button stays
"See your climb". Then Home plays the step, the save point's fade and its
label. *Why:*
- the crossing is known there, before Home exists again, so N9's order
  (celebration, then step and label) needs no coordination;
- the Welcome card's place under the results is not seen (measured
  above); an overlay is;
- on Home it would compete with the hop, the label, the Day-0 paywall
  and the month card for the same few seconds.

The Welcome badge moves into the same overlay (question Q4: it changes
how the Day-0 celebration looks, and its confetti stops being the exit).

---

## 3. The save point label (N6)

**Today.** A save point lights with a 400 ms fade when the hop that
reaches it ends (`monthly_mountain.dart:153-176`, `:227-231`); with
Reduce Motion at once. The scene's VoiceOver label lists "tent at step 7"
etc. (`:249-257`). No name exists in the code.

**Reached on** ([`save_point_numbers.txt`](save_point_numbers.txt)):

| Days | First Camp (C1) | Halfway Hut (C2) | Mountain Spring (C3) | High Camp (C4) | C5 signpost | Summit (C6) |
|---|---|---|---|---|---|---|
| 28 | 7 | 14 | 19 | 23 | 26 | 28 |
| 29 | 7 | 14 | 20 | 24 | 27 | 29 |
| 30 | 7 | 15 | 20 | 25 | 28 | 30 |
| 31 | 7 | 15 | 21 | 26 | 29 | 31 |

**Prototype** (`save_point_label_test.dart`, over the real Home, October
2026, the avatar on each reach step; an opaque chip in the month and step
chips' style: palette `sky`, `ink` text, labelLarge bold, radius 8;
[`labels/`](labels/), numbers in
[`labels/save_point_labels.txt`](labels/save_point_labels.txt)):

- Labels are 63–143 pt wide and 22 / 24 / 26 pt tall (Small / Medium /
  Large). "Mountain Spring" at Large is the widest.
- **Placement A, above the object (N6 as written):** it overlaps the
  avatar art's box in 43 of 45 cases, by 5–80 % (High Camp at 320 pt
  Large the most). In the renders the label hides the avatar's head: the
  avatar stands on the trail right beside the object it just reached.
  ([`labels/labels_A_vs_B_375_light_medium.jpg`](labels/labels_A_vs_B_375_light_medium.jpg))
- **Placement B, above the object and the avatar together:**
  - never touches the avatar;
  - stays inside the window: the largest sideways move is 11.1 pt (First
    Camp at 320 pt Large, at the right edge);
  - the month and step chips: only "Summit" at 320 pt Medium and Large
    touches the month chip (25.6–27.6 pt below the window's top);
  - "High Camp" overlaps the flag's box on C6 (at step 26 the flag is
    still unlit and faded);
  - the plaque: never; the signpost's box: never.
- Dark mode at 375 pt: the same layout; the chip reads as in light
  ([`labels/labels_B_375_dark_medium.jpg`](labels/labels_B_375_dark_medium.jpg)).
  Contrast is the chips' (K4, ≥ 4.5:1), not measured again.

**Recommendation: placement B, centred on the object and moved sideways
to stay 6 pt inside the window; where it would meet the month or step
chip (Summit at 320 pt), it goes under the chip band instead, or the
chips hide while it shows.** Timing: it fades in over 200 ms together
with G8's 400 ms light-up at the hop's end, stays 2.5 s, fades out over
400 ms (about 3.1 s); with Reduce Motion it appears and goes without
animation and stays 3 s. Summit's label only on the month's last step,
which is when the flag lights. *Why:* B is the only placement that keeps
the arriving avatar visible at every width and text size; the chip
clash happens in one case and has two cheap ways out (question Q5 picks
one); the label rides on the moment the object comes alive, as N6 says,
and is gone before the user scrolls on. The durations are **not
measured on a device** (question Q6).

---

## 4. The C5 signpost (N11)

**Placement** ([`signpost/signpost_numbers.txt`](signpost/signpost_numbers.txt),
`tool/scene_art/batch5_signpost.py`): exported like the other objects
(192 × 218 px, 9 980 bytes, written to `build/`, not `assets/`), placed
by the save points' rule:

| Ratio of C5's width | 1.00 | **0.95** | 0.90 | 0.85 | 0.80 |
|---|---|---|---|---|---|
| Trail pixels covered (2172 px) | 15 | **0** | 3 | 48 | 134 |

- The rule picks **0.95**: 174.8 px at 2172 px, **25.5 / 30.2 / 34.6 pt
  wide** at 320 / 375 / 430 pt. That is the tent's size (26.4 / 31.3 /
  35.8) and larger than the campfire, the fountain and the flag (17–25).
- Smaller ratios cover *more* trail: the base stays put while the board
  shrinks toward it, into the trail's edge. The margin is thin on both
  sides of 0.95.

**Avatar:** the resting avatar's tile overlaps the signpost's box on one
step per month, the step before C5: 25 / 26 / 27 / 28 in 28–31-day
months, 10–27 % of the signpost's box, the same at every width (boxes,
not pixels; the avatar is drawn above the objects). The save points see
the same: 0–11 % at 375 pt.

**Four themes, light and dark**
([`signpost/signpost_themes.jpg`](signpost/signpost_themes.jpg); signpost
always lit, G6 at 0.5 in dark mode, the campfire lit and the flag faded
as on a late day). Separation of the wood from the ground around it,
CIEDE2000:

| | Green | Ember | Glacier | Canyon |
|---|---|---|---|---|
| light | 27.6 | 14.5 | 35.9 | 14.9 |
| dark | 19.5 | 23.4 | 29.4 | 14.2 |

For scale: G10's orange pennant failed at 8.4; its blue was accepted at
16.4. Seen in the renders: readable in all eight; on Red Canyon wood on
red rock is the weakest, as the numbers say.

**The source.** The wood is mid brown (mean RGB 168, 105, 68; HSV value
0.66), not the "dark wood" of N11. Its body alpha is 253, not 255 (0.4 %
of inner pixels fully opaque): 1 % of the ground shows through.
291 stray alpha specks are zeroed by the export's cleaning.

**What the tools need for a non-save-point object:**
- `export_objects.py`: `signpost` in `OBJECTS` (no flame, no pennant);
- `place_save_points.py`: a `decor` entry (C5, signpost) by the same
  rule, written into `placement.json` beside `save_points` and `flag`;
- the generator (`tool/climb_table/`) and
  `climb_save_point_table.dart`: a `climbDecor` constant; the table test
  covers it;
- `ClimbSavePoints`: a `decor` list that `MonthlyMountain` draws between
  the dots and the avatar through `matrix(lit: 1, darkGain: …)`. It is
  left out of `_objects` (so out of "reached", the fade and the label)
  and out of the VoiceOver label.
- `check_theme.py` needs nothing: C5 is one of the six clearings it
  already checks.

**Recommendation: build it at the rule's 0.95 and the theme's dark
filter, always lit.** *Why:* it is the only ratio that keeps it off the
trail, it separates from the ground in every theme better than G10's
accepted threshold, and the filter is what keeps the other objects from
reading as stickers at dusk. Its size equal to the tent's is the one
thing to judge on the device (question Q7).

---

## 5. The collection (N10)

**Today** (`monthly_medal_collection.dart`):
- a Welcome row, then **three all-time specimens**: a tier is "Earned"
  if any finalized month reached it or higher (`:33-44`: the "Gold
  unlocks Bronze and Silver" ladder is computed over every month);
- "This month": a progress bar and points only, no tier (`:190-251`);
- "History": one row per finalized month with a generic icon (`:253-318`).
- No theme anywhere. `MonthlyMedalResult` has no theme field.

**Where a month's theme comes from:** `climb_month_themes`, through
`resolveClimbMonthTheme` (`storage_service.dart:1269`): a stored row
wins; a past month without one is Green Slope. That covers every month
before October 2026 (1.0 showed only Green Slope) and any 1.1.0 month,
since the first view or completion writes its row. Profile would need a
read of all rows at once (no schema change).

**Prototype** (`ProtoCollection`; render 2 in [`sites/`](sites/)): each
month a row of its theme's three medals, earned in colour (a Gold month
lights all three), the rest faded (0.5 / 0.6); the running month first,
with tiers already reached lit; the Welcome image in its row. Heights:
522–608 pt against today's 538–626 pt.

**Recommendation: per-month rows as in the prototype, the running month
included with its reached tiers lit.** *Why:* "every month its own
theme's medal" cannot apply to today's all-time specimens (they have no
month); and once N8 says "you reached Silver" mid-month, a Profile that
shows Silver as "Not earned" until the month ends contradicts it.

---

## 6. Measurement (N12)

**Today** (`docs/analytics-plan.md` §2): `welcome_badge_earned` (E3) at a
live earn; `medal_month_finalized` (E4) once per finalized month with
`tier`; `profile_medals_viewed` (E5); the Batch 6 month events. Nothing
for a save point or a tier during the month. The plan's "Events
considered and not proposed" already rules out "a separate
animation-played event".

**Proposal** (names ≤ 40 characters, values strings or ints, booleans
0/1):

| Event | Parameters | Fired |
|---|---|---|
| `save_point_reached` | `save_point` = `first_camp` / `halfway_hut` / `mountain_spring` / `high_camp` / `summit`; `step` (int); `days_in_month` (int) | once per save point per month, from the result screen after a durable save, when the completion crosses `reachedOn(days)` for the set's month |
| `medal_tier_reached` | `tier` = `bronze` / `silver` / `gold`; `day_of_month` (int, the set's day); `days_in_month` (int); `active_days` (int, steps so far); `rule_version` (int) | once per tier per month, same place, when `tierFor` rises; never for a month already finalized |

- Both are computed after the save, from "after − this completion" (§2),
  in the result screen next to `daily_test_completed`, without touching
  its `set_source` / `set_date`.
- No `theme_id`: the accepted Batch 6 deviation derives the theme from
  the date.
- To register: `save_point`, `step` (dimensions; `step` is new,
  `step_earned` exists); `tier`, `day_of_month`, `days_in_month`,
  `rule_version` are registered; `active_days` is a registered metric.
- **`tier` is reused** with the meaning it has on E4 (a tier earned),
  read per event name as `outcome` already is. Batch 6 chose a separate
  `medal_tier` because the card *shows* a past tier; here it is earned
  (question Q8).

**No separate events for the celebration or the label.** *Why:* both
follow from the data events deterministically (the celebration shows
unless the app is killed on that screen; the label plays when Home shows
the step), and the plan already declined presentation events.

---

## 7. Debug (N13)

**Today:** `CLIMB_DEBUG_DAY` and `CLIMB_DEBUG_THEME` (`kDebugMode`,
display only, `climb_debug_day.dart`, `climb_debug_theme.dart`);
`CLIMB_DEBUG_MONTH_CARD` (not in release, replays on every launch and hot
restart, no flags, no events unless `CLIMB_DEBUG_MONTH_CARD_EVENTS`,
`climb_debug_month_card.dart`).

**Recommendation: one define,
`CLIMB_DEBUG_MILESTONE=<bronze|silver|gold|first_camp|halfway_hut|mountain_spring|high_camp|summit>`,
debug builds only (`kDebugMode`).**
- A tier value opens the celebration overlay over Home on every launch
  and hot restart, with the current month's theme (or
  `CLIMB_DEBUG_THEME`'s) and sample numbers from `MonthlyMedalRules`.
- A save point value mounts the scene one step before that save point's
  step in the current month and hops to it once Home has loaded, so the
  fade and the label play; it takes the place of `CLIMB_DEBUG_DAY` for
  the scene. `summit` goes from the last step but one to the summit.
- No storage reads or writes, no events (M18's rule).
- With `CLIMB_DEBUG_MONTH_CARD` the card comes first and the milestone
  after it, which also checks the order.
- *Why debug only:* nothing here needs a profile-build frame time (M17's
  reason); one value per run keeps it one `flutter run` per check, like
  the others.

---

## 8. Implementation plan

**Commit order** (each with the full suite green and `flutter analyze`
clean):

1. **Assets.** `tool/medals/export_medal_assets.py` (384 px, WebP q90,
   from `build_medals.py`'s output) into `assets/medals/`; `pubspec.yaml`;
   one place that names them (`MedalArt.forTheme(themeId, tier)`,
   `MedalArt.welcome`). *Tests:* all 13 bundled at 384 px; every theme ×
   tier resolves; an unknown theme falls back to Green Slope.
2. **`MedalBadge` draws the image** (disc + stars box; faded by
   `ClimbSavePoints.matrix(lit: 0)`); the month card passes last month's
   theme (`MonthCardData.previousTheme`, resolved in `MonthTransition.load`).
   *Tests:* earned vs faded matrix; the card picks the previous month's
   theme; Batch 6's card heights unchanged at 40 pt (no overflow at 320 /
   375 / 430 × three text sizes).
3. **Profile (N10).** A read of all month themes; per-month rows with
   the running month. *Tests:* a month before October 2026 is Green
   Slope; Gold lights three, Silver two; the running month's reached
   tiers lit; `profile_medals_viewed` unchanged.
4. **Milestones, pure.** `ClimbMilestones.crossed(before, after, days)` →
   save points and tier. *Tests:* every score and step of 28–31-day
   months against `tierFor` and `reachedOn`; at most one tier per
   completion; Day 0 never crosses.
5. **Celebration (N8) and events (N12)** on the result screen: the
   overlay (Welcome moved into it if Q4 says so); `save_point_reached`,
   `medal_tier_reached`. *Tests:* once per crossing; none on a reopened
   result or a failed save; none for a finalized month; no confetti with
   Reduce Motion; one tap closes; `RecordingAnalyticsSink` keys; the
   all-events limits test.
6. **Label (N6)** in `MonthlyMountain`: names on `ClimbSavePoint`,
   placement B, the timing, Reduce Motion, the flag only on the last
   step; the scene's VoiceOver label uses the names. *Tests:* shown on a
   reached save point's fade, not on mount; gone after its time; no
   animation with Reduce Motion; inside the window at 320 / 375 / 430 ×
   three text sizes; `pumpAndSettle` settles.
7. **Signpost (N11).** The tool changes of §4, the generated table, drawn
   always lit. *Tests:* the table matches its sources; never in
   "reached", the fade, the label or the VoiceOver label; dark filter
   applied.
8. **`CLIMB_DEBUG_MILESTONE`.** *Tests:* the `resolve` truth table; no
   storage or event calls.
9. **Docs and renders.** `analytics-plan.md`, real-Home renders, build
   log, roadmap; the Poppins OFL text (see Risks).

**Your device checklist:**
- [ ] The medals on a dark background (N1's open item): Profile, the
      month card and the celebration, all four themes and three tiers,
      dark mode.
- [ ] The same in light mode; Red Canyon on Bronze in both.
- [ ] Profile: faded medals readable as "not earned" in light and dark;
      the running month's reached tiers lit.
- [ ] *(Batch 6, M8)* The month card with the new medals
      (`CLIMB_DEBUG_MONTH_CARD=summary_gold`, `summary_near`); stars at
      the card's size.
- [ ] *(Batch 6, M15)* Review the near-miss threshold (5 points): N4
      keeps the rule, so it stays unless you see a reason.
- [ ] Each tier's celebration (`CLIMB_DEBUG_MILESTONE=bronze|silver|gold`),
      Small and Large text; one tap closes it; Reduce Motion: no
      confetti.
- [ ] The Welcome celebration on a fresh install (Day-0 test).
- [ ] Each label (`CLIMB_DEBUG_MILESTONE=first_camp` …), light and dark,
      Small and Large: readable, the avatar visible, the timing.
- [ ] Summit's label at your width (the 320 pt chip clash only shows in
      renders on a 430 pt phone).
- [ ] The signpost in all four themes, light and dark
      (`CLIMB_DEBUG_THEME`, `CLIMB_DEBUG_DAY=29` in a 31-day month); its
      size beside the tent; the avatar passing it (`CLIMB_DEBUG_DAY=28`).
- [ ] Pre-release: Profile, the month card and the result screen may
      appear in App Store screenshots and case-study images.

**Risks.**
- The source total (97.51 MB) passes G1's 100 MB line with the next
  theme.
- **Poppins:** OFL 1.1 asks for the licence text to travel with the
  font. The TTF is now in the repository with only a pointer in its name
  table. The baked-in "WELCOME" itself is free to ship; the font file
  needs `OFL.txt` beside it (not downloaded: your call where it comes
  from).
- "WELCOME" is English inside an image: VoiceOver needs a text label,
  and a later localization needs a new image.
- The celebration code sits next to the protected `set_source` /
  `set_date` in `_reportCompletion`: additive only.
- Two clocks again (Home's and storage's) for the month in crossing
  detection: the set's day decides, not either clock.
- A celebration lost to an app killed on the result screen is not
  repeated (accepted by design in §2, or a flag per tier if not).
- The signpost's ratio sits between two failing ones; any re-export of
  the source can flip it.

**Decisions that look problematic from the code.**
- **N6, label above the object:** it hides the arriving avatar's head
  (§3). Placement B instead.
- **N8, reuse the Welcome layout:** that card is never on screen when it
  appears, and its confetti is the exit, not the celebration (§2).
- **N8 with today's Profile:** a celebrated tier shows as "Not earned"
  until the month ends, unless Profile lists the running month (§5).
- **N1 at the month card's 40 pt:** below the stars' 48 floor; making it
  readable makes the card scroll at 320 pt (§1).
- **N11 "dark wood"** and "decoration": the art is mid brown and, at the
  rule's ratio, as large as the largest save point (§4).
- **N10's 0.5 / 0.6** on a dark surface reads muddy rather than faded
  (seen, not measured).
- **"48 px" and "96 px" in the known limits:** I read them as on-screen
  points (logical pixels). If they are physical pixels, every size here
  clears them easily at 3x (question Q2).

---

## 9. Questions for the owner

1. **Q1, N-numbering:** keep N1–N14 for R1–R14 in the docs?
2. **Q2, readability floors:** are "48 px" (stars) and "96 px"
   ("WELCOME") on-screen points?
3. **Q3, month card medal:** keep the 40 pt box with the image fitted
   (no height change, stars unreadable), or a 48 pt disc (stars readable;
   scrolls 2.2 pt at 320 × 568 Large)?
4. **Q4, celebration place:** an overlay on the result screen when the
   save lands, confetti at the opening, one tap back to the results? And
   does the Welcome badge move into it (today's card is never on
   screen)?
5. **Q5, the label:** placement B (above object and avatar)? Where it
   meets the month chip (Summit at 320 pt): under the chip band, or hide
   the chips while it shows?
6. **Q6, label timing:** 200 ms in with the light-up, 2.5 s, 400 ms out
   (3 s still under Reduce Motion)?
7. **Q7, signpost:** the rule's 0.95 (tent-sized), or smaller to read as
   decoration (0.90 touches the trail by 3 px, below that more)? And is
   the mid-brown wood acceptable as "dark wood"?
8. **Q8, events:** `save_point_reached` and `medal_tier_reached` as in
   §6, with `tier` reused rather than a new name?
9. **Q9, Profile:** per-month rows with the running month first (§5)?
10. **Q10, debug:** `CLIMB_DEBUG_MILESTONE` with the eight values, debug
    builds only?
11. **Q11, assets:** 384 px WebP q90 (376 KB)?
12. **Q12, OFL:** add `OFL.txt` next to `Poppins-Bold.ttf` (from the
    Poppins project), or keep the TTF out of the repository and record
    where it came from?
13. **Q13, G1:** the sources are at 97.51 MB; look at G1 again now or
    with the next theme?

---

## How to reproduce

From the repository root, with the scene-art environment
(`tool/scene_art/README.md`, "Setup").

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
build/scene_art_venv/bin/python tool/scene_art/batch5_signpost.py
```

```bash
DESIGN_MEASURE_OUT=docs/design/batch5 flutter test tool/design_measure/batch5/save_point_numbers_test.dart
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch5_labels flutter test tool/design_measure/batch5/save_point_label_test.dart
```

Then, from `tool/scene_art/`:

```bash
../../build/scene_art_venv/bin/python batch5_sheet.py sites
```

(and `welcome`, `labels`). The source sizes in Step 2:

```bash
git rev-list --objects --all -- docs/design/scene-art/source docs/design/medals/source | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)'
```
