# Batch 6 — Batch 0 report: month transition

**Status: read, measured, rendered; nothing of Batch 6 is built.** Branch
`1.1.0-design` (with `1.1.0` merged in first: already up to date at
`31cc1d6`); not pushed. Written 2026-10-02.

Commits of this Batch 0:

| Commit | What |
|---|---|
| `ac6c900` | Step 1: decisions M1–M9 in `docs/1.1.0-design-side-tracks.md` ("Batch 6 — month transition") and `docs/build-log.md`; 1.2 parks in `docs/roadmap.md` |
| `7642fe3` | Step 2: the "Mountain of Learning" plaque's corners rounded (the only `lib/` change) |
| `e2bf3b0` | Step 3: measuring tools under `tool/` and their outputs in this folder |
| this one | Step 4: this report |

Every number below comes from a tool in `tool/` and is reproduced by the
command in [How to reproduce](#how-to-reproduce). Things I could not
measure are marked **not measured**. Line numbers are at `7642fe3`.

---

## Summary

1. **The sheet hides the mountain on small screens.** With Home at its
   scroll top, the bottom sheet covers the whole 350 pt mountain window at
   320 × 568, and all but 0–27 pt of it at 375 × 812 (summary card). The
   K-c view behind the sheet (M4) is only seen if Home scrolls the climb
   card to the top first (then 44 % / 69–76 % / 86–87 % of the window at
   320 / 375 / 430). §5.
2. **The fullest summary card does not fit the default sheet at 320 pt**
   (content 321 / 332 / 344 pt at Small / Medium / Large; room 271.5 pt);
   it scrolls. It fits at 375 and 430 pt at every text size. The
   fresh-start card fits everywhere. No overflow in any of the 72 renders.
   §5.
3. **The zoom is small.** K-c (the whole image, fitted to the window's
   height) is 1.21× / 1.43× / 1.64× smaller than the daily framing at
   320 / 375 / 430 pt, and leaves 12.8 / 39.4 / 64.4 pt of empty window on
   each side. In light mode those bands are visibly lighter than the
   image. §6.
4. **The card must wait for last month's medal.** Finalization runs at
   launch and on resume without Home waiting for it. Recommended: the card
   path calls the (idempotent) finalization itself, then reads the frozen
   result. §2.
5. **Nothing records "seen" today.** `one_time_flags` has one user
   (`day0_paywall`) and only a claim operation. Recommended: three keys
   (card per month, zoom per month, first-run zoom) and one small read
   method. §2.
6. **"Next tier and gap" is not in the code**; a ten-line pure function
   on `MonthlyMedalRules` covers it (checked against `tierFor` for all
   1184 scores of 28–31-day months). Near-miss recommendation: **gap ≤ 5
   points**. §3.
7. **Debug builds send real events to the production Firebase project**
   (one project, no debug gate). A debug replay on every launch would
   pollute the month-card events. Recommended: the replay sends none. §8.
8. **M9 (debug only) and performance measurement collide:** the zoom's
   frame times have to be measured in a profile build, where a
   `kDebugMode` define does nothing. §6, §9.

Owner decisions needed: [§11](#11-questions-for-the-owner).

---

## Step 2 — the plaque (done, not on a device)

- The silhouette is kept; all six corners, the points included, are
  rounded (`TrailSignBorder`, `lib/widgets/monthly_climb/climb_card.dart:191`).
- The card radius is one constant, `appCardRadius` (20 pt,
  `lib/theme.dart`), used by `CardThemeData` and by `ClimbCard`'s frame
  (`ClimbCard.frameRadius`, `climb_card.dart:47`). The frame had its own
  literal 20 until now.
- The plaque's radius = `frameRadius × ClimbCard.plaqueRadiusShare`
  (`climb_card.dart:54`), **the one setting to try on a device**; 0.4 now,
  so 8 pt. A corner is fitted down only where its arc would take more than
  half an edge, so any value keeps the silhouette.
- Measured ([`plaque/plaque_numbers.txt`](plaque/plaque_numbers.txt)): the
  plaque is 34 / 36 / 38 pt tall at Small / Medium / Large; 8 pt fits every
  corner unchanged; each point moves in by 2.05 pt. Above a share of 0.70
  (Small) to 0.79 (Large) the points would be drawn smaller than asked.
- *How "same proportion as the frame" was read:* the plaque's radius is a
  named share of the frame's radius, not the frame's 20 pt itself. 20 pt
  does not fit a 34–38 pt sign with points (the points would be fitted
  down to about 15 pt, a different shape at each text size). If you meant
  something else, say so (question Q1).
- Renders: [`plaque/plaque_before_after.jpg`](plaque/plaque_before_after.jpg)
  (the plaque at 3x) and [`plaque/cards_before_after.jpg`](plaque/cards_before_after.jpg)
  (the whole card), 320 / 375 / 430 pt, light and dark, before (`ac6c900`)
  and after.
- 3 new tests; no golden files exist in the project, so none changed.
  1253 tests pass; `flutter analyze` is clean.

---

## 1. First-launch flow

**Today.** The screens in order:

1. The iOS launch screen, then the Flutter launch splash: `runApp` shows
   `LaunchGate` at once (`lib/main.dart:31-34`); the app is built under
   it after Firebase and RevenueCat (`main.dart:40-57`); the splash fades
   over it (about 1.2 s, side-tracks "Launch screen").
   `LaunchSplashScope.coveringOf` (`lib/widgets/launch_splash.dart:179-193`)
   tells a screen whether the splash still covers it.
2. A loading frame while the profile is read (`lib/app.dart:305-317`).
3. `FirstLaunchFlow` (`app.dart:318-330`;
   `lib/screens/first_launch_flow.dart:63`, `:151-179`): Welcome →
   Onboarding → "Setting things up…" (Day-0 set seeded, profile saved,
   `first_launch_flow.dart:82-106`) → the Day-0 Daily Test → its result
   (Welcome badge card; confetti on "Start my climb").
4. `onComplete` (`first_launch_flow.dart:138-144`) swaps in the tab shell
   with Home, handing it `initialPendingClimb` and `offerDay0Paywall`
   (`app.dart:323-345`).
5. Home mounts the mountain one step back (`home_screen.dart:283-292`),
   scrolls it into view (`Scrollable.ensureVisible`, alignment 0.35,
   250 ms, `:301-311`), hops the avatar to step 1 (850 ms,
   `monthly_mountain.dart:109-110`, `:189-203`), and 600 ms after the hop
   opens Premium by itself, once (`home_screen.dart:345-394`; flag
   `day0_paywall`).
6. If the user leaves the Day-0 test instead, Home opens with no pending
   step and no paywall (`first_launch_flow.dart:163-167`).

**Where M2's zoom fits.** On the Home of step 4, as its first motion:

- **Day-0 test finished:** zoom from K-c to the daily framing **at START**
  (where the mountain is mounted, one step back), then the existing hop to
  step 1, then the paywall's 600 ms. The paywall already waits for "the
  climb has landed" (`_climbAnimating`, `_onMountainMotionEnd`,
  `home_screen.dart:327-348`); the zoom joins that chain.
- **Day-0 test left:** zoom to the avatar on START; nothing follows.
- "To the avatar at START" holds in both only if the zoom comes **before**
  the hop. After the hop the avatar is on step 1.
- In the first case the user waits about 250 ms + the zoom + 850 ms + 600
  ms before Premium opens. **Not measured on a device.**

**Recommendation.** The first-run zoom is triggered only by a
`FirstLaunchFlow` completion: the app passes Home one more one-shot value,
like `offerDay0Paywall` (`app.dart:81-84`, `:344-345`), and Home claims
the flag `first_run_zoom` when the zoom starts. *Why:* "no flag yet" alone
would also fire for every device updating from a 1.0 TestFlight build
(their Home exists, their flag does not). Order on that Home: scroll into
view → zoom → hop (if any) → paywall (if any). The zoom waits for
`LaunchSplashScope` to stop covering, as Welcome does (on a fresh install
the flow, not Home, is under the splash, so in practice this only matters
for the month card, §2).

---

## 2. Month and theme resolution

**Today.**

- Home takes the month from its own clock (`HomeScreen.clock`,
  `home_screen.dart:60`, `:266-267`) in `_loadClimb` (`:261-343`), which
  runs at `initState` (`:191`), on resume (`:229-240`) and after a Daily
  Test (`:396-401`).
- It resolves the theme through
  `StorageService.resolveClimbMonthTheme` (`home_screen.dart:252-259`;
  `storage_service.dart:1255-1295`): a stored row wins; a past month
  without one is Green Slope; the **current** month without one gets its
  rotation theme written once (`INSERT OR IGNORE`). So the current month's
  row is written on its first Home view. If storage fails, the rotation's
  theme is shown and nothing is written.
- "Current" in storage is decided by a second clock,
  `StorageService.clockForTesting` (static, `storage_service.dart:70`),
  which also drives finalization, `_todayKey` and the flags' timestamps.

**Persistent state that exists:**

| Table | What | Lines |
|---|---|---|
| `climb_month_themes` | `month`, `theme_id`, `assigned_at`; one row per viewed month since 1.1.0 | `storage_service.dart:141-147` |
| `climb_daily_entries` | one row per completed Daily Test day: `step` 0/1, correct / wrong / skipped, `completed_at`, rule version | `:264-274` |
| `monthly_medal_results` | one row per finalized month | `:276-289` |
| `welcome_badge` | one row, ever | `:298-305` |
| `one_time_flags` | `key`, `set_at`; used once today, `day0_paywall` (`home_screen.dart:383-384`). Only `claimOneTimeFlag` (`storage_service.dart:1418-1427`), no read | `:129-134` |

**Not stored:** a "last month seen" or any per-month card record.

**Where "the month changed since the last view" and "seen" can live.**

- *Card seen:* `month_card:YYYY-MM`, written on dismissal (M6). Needs a
  read to decide whether to show, so one small method
  (`hasOneTimeFlag(key)`); writing reuses `claimOneTimeFlag`.
- *Zoom played:* `month_zoom:YYYY-MM`, claimed when the zoom starts (M6).
  `claimOneTimeFlag` already is "first caller wins", so two triggers
  (launch and resume racing) cannot both play it.
- *First-run zoom:* `first_run_zoom`, claimed at start (§1).
- *Returning user (gets a card) vs new user (M2, no card):* a
  `climb_month_themes` row **or** a `climb_daily_entries` row for a month
  before the current one. The theme row means "saw Home in an earlier
  month"; the ledger row covers devices that had 1.0 history before theme
  rows existed.
- *No card for the month a user starts in:* follows from the line above.

**Several months skipped.** One card, for the current month M (M3). Its
variant comes from M − 1 only (`getClimbProgress(M − 1).steps`,
`storage_service.dart:1052-1077`): ≥ 1 step → summary, else fresh. Months
in between get no flag and no card; nothing has to be cleaned up.

**Last month's medal (Batch 0 decision 9).** `_finalizeMedalMonths` runs
at launch and on resume in `app.dart:110-141`, not awaited by Home. The
card path should itself call `finalizePastMedalMonthsAndReport`
(`lib/services/medal_finalization.dart:19-38`) and then read M − 1's row.
That call is idempotent and reports each month once whichever caller gets
there first (`storage_service.dart:1097-1103`, the concurrency test in
`analytics-plan.md` §8). If the read fails, or M − 1 had steps but no
frozen row, no card this time; the next open tries again. *Why:* a wrong
card ("no medal" to someone who earned Silver) is worse than a late one.

**Other timing points.**

- The card waits for `LaunchSplashScope` to stop covering (cold start),
  for Home to be visible (`_homeVisible`, `home_screen.dart:161-166`: no
  covering route, the Home tab active, not paused), and for no Daily Test
  flow to be running (`_dailyFlowActive`).
- A month that changes while the app stays in the foreground is not seen
  until the next resume or launch (Home does not refresh on a timer; the
  same accepted gap as the greeting, `home_screen.dart:610-616`).

**Clock injection.** Both seams exist: `HomeScreen.clock` (forwarded from
`GrammarLensApp.clock`, `app.dart:34-43`, `:341`) and
`StorageService.clockForTesting`. A test must set both to the same
instant. Every month-dependent storage method Batch 6 needs already takes
the year and month as arguments, so only finalization and the flags'
timestamps read the static clock.

**Recommendation.** Decide the card in one pure function (now, last
month's steps, the frozen result, the flags, "seen Home before this
month") → none / summary / fresh / first-run zoom. Load its inputs
separately from storage. Test the function with explicit dates and the
loader with both clocks set.

---

## 3. Medal system

**Rule v1** (`lib/services/monthly_medal_rules.dart:4-46`): correct +2,
wrong +1, skipped 0; maximum = days × [Q] × 2 ([Q] =
`DailyTestSet.questionCount` = 5); Bronze / Silver / Gold = ceil(25 / 50 /
75 %) of the maximum.
([`medal_numbers.txt`](medal_numbers.txt))

| Days | Maximum | Bronze | Silver | Gold | Band widths |
|---|---|---|---|---|---|
| 28 | 280 | 70 | 140 | 210 | 70, 70 |
| 29 | 290 | 73 | 145 | 218 | 72, 73 |
| 30 | 300 | 75 | 150 | 225 | 75, 75 |
| 31 | 310 | 78 | 155 | 233 | 77, 78 |

A fully answered day is worth 5 (all wrong) to 10 (all correct) points.

**When a medal is given.** At the first launch, resume or Profile open
after the month has ended (`finalizePastMedalMonths`,
`storage_service.dart:1104-1162`), not at midnight. A month with any
ledger row is frozen, even one with only all-skipped days and even below
Bronze (`tier` NULL). A month the user never opened the app in has no row
and is never frozen.

**Stored per month** (`monthly_medal_results`): tier or NULL, score,
maximum, `active_days` (= steps, `SUM(step)`), correct / wrong / skipped,
rule version, `finalized_at`. The running month is computed live from the
ledger (`getClimbProgress`, `getMonthlyMedalProgress`).

**Welcome badge.** A separate one-time table, written in the same
transaction as the first `step = 1` ledger row ever
(`storage_service.dart:998-1046`); celebrated on the Day-0 result screen;
unthemed (side-tracks "Medal"). It has no place on the month card.

**Next tier and gap: not available.** `tierFor` returns only the tier
reached; `threshold` gives each threshold. Smallest addition:
`MonthlyMedalRules.nextTier(year, month, score)` → `(MedalTier, int)?`
(null at Gold). The tool's version (`medal_numbers_test.dart:20-28`)
agrees with `tierFor` for every score 0 – maximum of 28–31-day months
(1184 scores).

**The medal's look.** Profile draws it in a private widget
(`_MedalSpecimen`, `lib/widgets/monthly_medal_collection.dart:320-399`;
a tinted circle with a landscape icon, tier colours from
`lib/widgets/medal_tier_color.dart`). M8 ("no copied image") means
making that circle a public widget both use. The prototype here copies it
(`tool/design_measure/batch6/month_card_prototype.dart`, `MedalCircle`).

**Near-miss candidates** (the line shows when 0 < gap ≤ limit; never at
Gold):

| Candidate | Limit | Shows on | What the line can honestly say |
|---|---|---|---|
| **A** | **5 points** | 6–7 % of each band (5 of 70–78 scores) | One more fully answered day would have done it, even with every answer wrong |
| B | 10 points | 13–14 % of each band | One more day would have done it, only if every answer was right |
| C | 5 % of the maximum (14–15 points) | 19–20 % of each band | Two or three more days; "near" stretches |

**Recommendation: A, gap ≤ 5.** It is the only limit where "one more day"
is always true. That is the same reasoning as the [N] goal line
(side-tracks, case (b)): never promise accuracy. Copy in points ("Only 5
points short of Gold."), not days. **Not measured:** how often real users
land in these ranges. There is no score distribution yet; 1.1.0 is the
first public release.

---

## 4. Monthly data inventory (for the 1.2 report decision; no code proposed)

| Data | Stored per month? | Derivable per month? | Source |
|---|---|---|---|
| Steps, active days | — | yes | `climb_daily_entries.step` |
| Score, tier | yes, once finalized | yes (running month) | `monthly_medal_results`; ledger |
| Correct / wrong / skipped, accuracy | yes, once finalized | yes | ledger counts |
| Time of day of a Daily Test | — | yes | `climb_daily_entries.completed_at` |
| Streaks (within or across months) | — | yes | consecutive ledger day keys |
| Daily Test accuracy by topic | — | yes, by re-grading | completed `daily_test_sets` are kept for good (`questions_json` with a `topicId` per question, `answers_json`; `storage_service.dart:900-916` deletes only unfinished sets older than 7 days); re-grading would reuse `checkDailyTestAnswer` (protected logic, read only) |
| Mistakes by topic and error type, Daily Test vs Topic Practice | — | yes | `error_entries` (`topic_id`, `error_type`, `timestamp`, `source`; `:78-91`) |
| Topic Practice sessions | — | yes, as sessions started per day | `daily_session_usage`, `free_practice_usage` (day, count) |
| Topic Practice questions answered | — | **no**: all-time totals only | `topic_practice_stats` (`:167-172`, `:779-791`) |
| Topic Practice correct answers | — | **no** | only mistakes are stored |
| Time spent, per-question timing, Review visits | — | **no** | not recorded |
| Theme of the month | yes | — | `climb_month_themes` |

All of this is local to the device: lost on reinstall, never on a server.

---

## 5. Does the bottom sheet fit?

**Setup** (`tool/design_measure/batch6/month_card_render_test.dart`).
The fullest cards M5 and M3 allow, laid out with the app's own theme:

- *Summary:* month name, Silver medal row, steps 24 / 31, 228 points,
  "Only 5 points short of Gold.", "November: Ember Peak", one button.
- *Fresh start:* avatar, "A fresh start", "November is on Ember Peak.",
  one button.

Each is shown with `showModalBottomSheet` (drag handle, Material 3
default: at most 9/16 of the screen) over the **real Home** on 1 November
2026. The climb card is redrawn in K-c under the sheet's barrier (product
`ClimbCard`, background, objects and avatar).

Combinations: 320 × 568, 375 × 812, 430 × 932 (safe areas 20/0, 47/34,
59/34 pt); light and dark; Small, Medium, Large (only through
`buildAppTheme(textSize:)`); Home at its scroll top, and Home scrolled so
the climb card is at the top of the list. That is 72 renders, with all
numbers in [`sheet/month_card_numbers.txt`](sheet/month_card_numbers.txt).
The copy is placeholder.

**Heights (pt; the same in light and dark):**

| Card | Screen | Sheet height (share) S / M / L | Content S / M / L | Room S / M / L | Scrolls |
|---|---|---|---|---|---|
| Summary | 320 × 568 | 319.5 (56 %) at all three | 321 / 332 / 344 | 271.5 | **yes, all three** |
| Summary | 375 × 812 | 427 / 438 / 450 (53–55 %) | 321 / 332 / 344 | 345 / 356 / 368 | no |
| Summary | 430 × 932 | 427 / 438 / 450 (46–48 %) | 321 / 332 / 344 | 345 / 356 / 368 | no |
| Fresh | 320 × 568 | 307 / 312 / 318 (54–56 %) | 235 / 240 / 246 | 259 / 264 / 270 | no |
| Fresh | 375 × 812 | 341 / 346 / 352 (42–43 %) | 235 / 240 / 246 | 259 / 264 / 270 | no |
| Fresh | 430 × 932 | 341 / 346 / 352 (37–38 %) | 235 / 240 / 246 | 259 / 264 / 270 | no |

**No overflow** (no layout exception) in any of the 72.

**How much of the K-c mountain shows above the sheet** (of the 350 pt
window; Medium; Small and Large in the numbers file):

| Card | Screen | Home at its top | Home scrolled to the card | Avatar on START above the sheet (scrolled) |
|---|---|---|---|---|
| Summary | 320 | 0 pt (0 %) | 154.5 pt (44 %) | no |
| Summary | 375 | 7 pt (2 %) | 253 pt (72 %) | no |
| Summary | 430 | 115 pt (33 %) | 305 pt (87 %) | yes |
| Fresh | 320 | 0 pt (0 %) | 162 pt (46 %) | no |
| Fresh | 375 | 99 pt (28 %) | 345 pt (99 %) | yes |
| Fresh | 430 | 207 pt (59 %) | 350 pt (100 %) | yes |

Renders:
- [`sheet/overview_summary_scrolltop.jpg`](sheet/overview_summary_scrolltop.jpg)
  and [`sheet/overview_summary_scrollcard.jpg`](sheet/overview_summary_scrollcard.jpg);
- [`sheet/overview_fresh_scrolltop.jpg`](sheet/overview_fresh_scrolltop.jpg)
  and [`sheet/overview_fresh_scrollcard.jpg`](sheet/overview_fresh_scrollcard.jpg);
- [`sheet/textsizes_320.jpg`](sheet/textsizes_320.jpg) (both cards at
  320 pt, three text sizes);
- one 1x JPEG per screen and mode at Medium (`sheet/*_medium_*.jpg`).

**Seen in the renders.**

- In light mode the K-c side bands (the window's fill, `palette.sky`
  `#EAF0EC`) are two pale strips beside Ember Peak's dark image. In dark
  mode they are dark and read as a frame.
- The month and step chips sit over the top of the K-c image (the summit
  is at 58.3 pt in the window; the step chip's text ends at 46.0 pt,
  [`zoom_numbers.txt`](zoom_numbers.txt)).

**Recommendation.**

- Before the sheet opens, Home scrolls the climb card to the top of the
  list (no animation: it is the first thing on that open).
- The summary card gets a compact layout that fits 320 × 568 at Large,
  271.5 pt of room against 344 pt now. For example, the month name and
  the medal on one row, steps and points on the next. The sheet keeps its
  own scrolling only as a fallback for very large system text.

*Why:* M4's point is seeing the new mountain behind the sheet. On the two
smaller screens that only happens if Home scrolls first, and on a 320 pt
screen a scrolling card hides its own button.

---

## 6. The zoom

**Today's scene layers** (`monthly_mountain.dart:219-304`):

- `LayoutBuilder` → `ClimbCamera(width)`, then a 350 pt `SizedBox`,
  `ClipRect`, `ColoredBox(palette.sky)` (seen only until the image
  decodes), and an `AnimatedBuilder` on the hop and the save-point fade.
- Inside it, one `Positioned` at minus the camera's offset, the size of
  the image at the daily scale. That holds a `Stack` of: the background
  `Image.asset`, the passed-day dots (`ClimbTrailDots`), the save points
  and flag (`ClimbObjectLayer`, colour matrices), and the `AvatarTile`.
- Every frame of a hop recomputes the camera offset from the avatar's
  point (`:250-254`). The month and step chips and the plaque are drawn by
  `ClimbCard` above the window (`climb_card.dart:95-180`).

**How the framings are computed.**

- *Daily:* `ClimbCamera` (`lib/widgets/monthly_climb/climb_camera.dart:14-44`).
  Scale = window width × `zoom` (1.1); the offset centres the avatar
  across and puts it at 72 % of the height, clamped to the image.
- *K-c* is not in the code. It is defined in the scene-art Batch 0 report
  §3 as the whole image in the window, fitted to its height: scale =
  350 ÷ (2896 ⁄ 2172) = 262.5 pt per image width at every screen.

**Values** ([`zoom_numbers.txt`](zoom_numbers.txt); avatar on START, day
0, where a new month and a first run both stand):

| | 320 | 375 | 430 |
|---|---|---|---|
| Window | 288.0 × 350 | 341.3 × 350 | 391.3 × 350 |
| Daily scale (pt per image width) | 316.8 | 375.4 | 430.4 |
| Daily: share of the image shown | 75 % | 64 % | 55 % |
| Daily offset on START (x, y) | (0, 72.4) | (0, 150.5) | (0, 223.9) |
| K-c scale | 262.5 | 262.5 | 262.5 |
| K-c side band, each side | 12.8 | 39.4 | 64.4 |
| s0 = K-c ÷ daily | 0.829 | 0.699 | 0.610 |
| Zoom factor | 1.21× | 1.43× | 1.64× |
| Transform at K-c → daily (applied to the daily layer) | scale 0.829, translate (12.8, 0) → scale 1, translate (0, −72.4) | 0.699, (39.4, 0) → 1, (0, −150.5) | 0.610, (64.4, 0) → 1, (0, −223.9) |
| Avatar tile, K-c → daily | 22.5 → 27.2 | 22.5 → 32.2 | 22.5 → 36.9 |
| Daily layer at 3x | 950 × 1267 px (4.6 MB RGBA) | 1126 × 1502 px (6.5 MB) | 1291 × 1722 px (8.5 MB) |

**Plan: scale the finished layer.**

1. Wrap the image-sized `Stack` (background, dots, objects, avatar) in a
   `RepaintBoundary`, laid out at the **daily** scale and offset exactly as
   today.
2. Put one `Transform` between the window and that layer. Its matrix goes
   from (scale s0, translate band, 0) to identity: scale and translation
   eased together (for example `easeInOutCubic`), in window coordinates.
3. At t = 1 the matrix is the identity, so the last frame is today's
   layer and nothing jumps when the zoom hands over.
4. The child does not repaint during the zoom (nothing inside it moves:
   no hop, no fade at day 0), so each frame only composites a cached
   picture. Scaling down a bitmap stays sharp; every value of s is ≤ 1.

**What each part does during the zoom.**

- *Avatar:* inside the layer, so it grows with the scene, 22.5 pt to
  27 / 32 / 37 pt. No hop during the zoom. On a first run with a finished
  Day-0 test, the hop to step 1 starts when the zoom ends (§1).
- *Save points and flag:* inside the layer, all unreached on day 0;
  static.
- *Faint dots:* none on day 0 (dots mark passed days only).
- *Chips:* hidden from the sheet's opening until the zoom ends, then a
  short fade in. They cover the top of the image in K-c (§5).
- *Plaque and score bar:* unchanged; outside the window.
- *Side bands:* shrink to nothing as s → 1. Fill: question Q6.
- *Reduce Motion* (`MediaQuery.disableAnimationsOf`, the app's existing
  check, `monthly_mountain.dart:169`): no transform animation. Behind the
  sheet the K-c frame shows; after dismissal the K-c copy fades out over
  the daily layer (for example 200 ms). Two copies of the layer exist only
  for that fade.

**Measuring performance (proposed; nothing measured).**

- *Where:* a **profile** build on your phone, and if possible on the
  oldest device iOS 15 supports that you have. Debug-build frame times say
  nothing.
- *What:* DevTools Performance, UI and raster thread time per frame during
  the zoom (maximum and 90th percentile), and frames over budget (16.7 ms
  at 60 Hz; 8.3 ms on a 120 Hz screen). Memory before and after one zoom
  (DevTools Memory): is the layer released?
- *How to trigger it repeatedly in a profile build:* M9's define does
  nothing there (`kDebugMode`). Question Q8.
- *Comparison:* one run with the `RepaintBoundary` and one without, so the
  cache's effect is a measured number, not an assumption.

---

## 7. Touch

**Today.**

- The climb card has **no gesture handlers**: no `GestureDetector`,
  `InkWell`, `AbsorbPointer` or `IgnorePointer` in
  `lib/widgets/monthly_climb/`.
- It sits in `BrandScaffold`'s `ListView` (`brand_scaffold.dart:165-169`),
  which owns the vertical drag.
- The Daily Test is entered from the Today card above it, an `InkWell`
  (`home_screen.dart:886-889` → `_openDailyTest`, `:456-493`).

**"Tap to skip" against them.**

- A `GestureDetector(onTap)` on the climb card, present only during the
  zoom, competes with the list's drag in the gesture arena: a tap wins
  only if the finger does not move, so scrolling still works. No conflict.
- Outside the zoom the card stays non-interactive. The tappable mountain
  card is parked for 1.2 (D5), and an always-there tap target would
  pre-empt that decision.
- The sheet itself is modal: while it is open, Home takes no touches; a
  tap outside closes it (M6's third way). "Home takes touches from the
  start" means from the zoom's start.

**Keeping the Daily Test usable during the zoom.**

- The zoom lives inside `MonthlyMountain`; no ancestor blocks pointers.
- A tap on the Today card pushes the test route as today. Home is then
  covered, `TickerMode` stops its tickers, and a half-played zoom would
  resume under the test. Recommended: when Home stops being visible
  (`_homeVisible`), the zoom jumps to its last frame, reported as
  `skipped` (question Q7).
- Tests to lock it in:
  - during the zoom, tapping the Today card opens `DailyTestScreen`;
  - a drag on the card scrolls the list;
  - a tap on the card ends the zoom on its last frame;
  - `pumpAndSettle` finishes (no endless animation).

---

## 8. Measurement

**Naming** (`docs/analytics-plan.md` §2 conventions):

- `snake_case`, no prefix, one wrapper method per event in
  `AnalyticsService`;
- values are strings or integers only, booleans as 0/1;
- Firebase limits, checked by an existing test
  (`analytics-plan.md` §4): names up to 40 characters, up to 25
  parameters, string values up to 100 characters.

**Proposed names for M7:**

| Event | Parameters |
|---|---|
| `month_card_shown` | `theme_id` (the new month's), `variant` = `summary` / `fresh`, `tier` = `none` / `bronze` / `silver` / `gold` (last month's; `none` for fresh), `near_miss` = 0/1 |
| `month_card_dismissed` | `method` = `button` / `swipe` / `outside`, `open_ms` (int, time on screen) |
| `month_zoom_ended` | `outcome` = `completed` / `skipped` / `reduce_motion`, `trigger` = `month_change` / `first_run`, `theme_id` |

- `tier`, `method` and `outcome` reuse parameters that are already
  registered dimensions (`analytics-plan.md` §9), so reports can only be
  read per event name, as with `outcome` today.
- New to register: `variant`, `near_miss`, `trigger` and `theme_id`
  (dimensions); `open_ms` (metric).
- `open_ms` should count foreground time only; otherwise a card left open
  across a night in the background reads as hours.

**Daily Test start.**

- There is no dedicated start event. `mode_selected` with
  `mode = daily_test` fires when the Today card is tapped
  (`home_screen.dart:460`). The Day-0 test sends none
  (`analytics-plan.md` §1, gap 2).
- It *could* carry `theme_id` (Home knows `_climbTheme`). But
  `mode_selected` is shared with `topic` and `premium`, so the dimension
  would mean something for one value only.
- Recommended: `theme_id` on `daily_test_completed`, already planned
  (side-tracks "Measurement"). Read the card → test funnel as
  `month_card_dismissed` followed by `mode_selected(daily_test)` in the
  same session.
- Adding a parameter to `daily_test_completed` touches
  `DailyTestResultScreen._reportCompletion`, next to the protected
  `set_source` / `set_date`. Additive only.

**Debug builds today.**

- `AnalyticsService` has no build-mode gate (`_logEvent`,
  `analytics_service.dart:361`, goes to `FirebaseAnalyticsSink`).
- `main.dart:72-89` initializes Firebase in every build mode, with one
  project, `grammarlens-18d47` (`firebase_options.dart:59`).
- So a debug run on a simulator or phone sends real events to the
  production property. DebugView shows them only when the app was
  launched with the debug arguments (`analytics-plan.md` §6).
- Whether the property has a developer-traffic filter is **not verified**
  (§6 asks for one before relying on exported data; nothing records it
  was set up).

**Risk of the debug replay.**

- M9 replays on every launch and hot restart. With events on, each replay
  sends a `month_card_shown` (and usually a dismissal and a
  `month_zoom_ended`) with sample data: 5 variants × many restarts a day,
  counted as real cards.
- Recommended: **the replay sends no events.** The events are checked by
  unit tests (`test/support/recording_analytics_sink.dart`) and once in
  DebugView through an opt-in (question Q9).

---

## 9. The debug define

**Today's pattern** (`lib/widgets/monthly_climb/climb_debug_day.dart`,
`climb_debug_theme.dart`):

- a compile-time `int.fromEnvironment` / `String.fromEnvironment`;
- a `@visibleForTesting` setter standing in for the define in tests;
- `value` = `resolve(debug: kDebugMode, defined: …)`, so in profile and
  release builds `kDebugMode` is the constant false and the define has no
  effect (an unknown value has none either);
- read only in `MonthlyMountain` (`monthly_mountain.dart:95-102`), display
  only;
- tests: the `resolve` truth table, "the suite runs without the define",
  widget behaviour (`test/climb_debug_day_test.dart`,
  `test/climb_debug_theme_test.dart`).

**`CLIMB_DEBUG_MONTH_CARD` fits the same pattern** (`ClimbDebugMonthCard`,
an enum with the five wire names), with three differences:

- It is read in Home's trigger, not in the scene.
- When set, Home skips the flags (no read, no write), skips finalization
  and storage reads, and builds the sample below on every Home
  `initState`: launch and hot restart, not resume. That makes it replay
  "every launch" without touching real records.
- It sends no events (§8).

**Sample data**, relative to the current month M and the previous month
P, computed from `MonthlyMedalRules` (no hard-coded thresholds). Numbers
shown for P = October 2026 (31 days), M = November (Ember Peak):

| Value | Shows | Sample |
|---|---|---|
| `summary_gold` | summary card, Gold, no near-miss line | steps days(P) − 4 = 27 / 31; points Gold + 12 = 245 |
| `summary_none` | summary card, no medal row, no near-miss line | 6 / 31; points Bronze − 33 = 45 |
| `summary_near` | summary card, Silver, near-miss line | 24 / 31; points Gold − 5 = 228, "Only 5 points short of Gold." |
| `fresh` | fresh-start card | avatar, M's theme |
| `first_run` | no card; the zoom from K-c to the avatar on START | — |

---

## 10. Implementation plan

**Commit order** (each with the full suite green and `flutter analyze`
clean):

1. **Next tier.** `MonthlyMedalRules.nextTier` and the near-miss limit as
   one constant. *Tests:* every score of 28–31-day months against
   `tierFor`; null at Gold; the limit's edges (gap = limit shows,
   gap = limit + 1 does not).
2. **Flags.** `StorageService.hasOneTimeFlag` and the per-month key
   helpers. *Tests:* claim then has; a new key is false; two concurrent
   claims, one winner.
3. **The decision.** The pure month-transition function and its storage
   loader (§2). *Tests with both clocks injected:*
   - first open of a new month → card;
   - second open → none;
   - resume across the month change → card;
   - three months skipped → one card for the current month, variant from
     M − 1;
   - M − 1 with only all-skipped days → fresh;
   - the user's first month → none;
   - a device with 1.0 ledger history and no theme rows → card;
   - storage throws → none;
   - card shown and app killed before dismissal → shown again.
4. **Medal widget.** The medal circle made public, out of Profile's
   private widget (M8). No visual change. *Tests:* Profile's existing
   tests unchanged; the circle draws each tier's colour.
5. **The sheet.** Summary and fresh-start widgets. *Tests:*
   - the medal row only with a tier;
   - the near-miss line only under the limit and never at Gold;
   - the theme name;
   - the three ways to close report their method;
   - no overflow at 320 / 375 / 430 × Small / Medium / Large.
6. **The zoom.** K-c in `ClimbCamera`; the `RepaintBoundary` +
   `Transform` in `MonthlyMountain`; chips hidden and faded in;
   tap-to-skip; jump to the end when covered; the Reduce Motion fade.
   *Tests:*
   - the last frame equals today's daily layer;
   - a tap ends the zoom;
   - the Today card opens the test during the zoom;
   - no transform with Reduce Motion;
   - `pumpAndSettle` settles.
7. **Home wiring.**
   - Card trigger at `initState` and on resume, after its own
     finalization, the splash and Home being visible.
   - Scroll the card to the top; the sheet; "seen" written on dismissal;
     the zoom flag claimed at start.
   - The first-run zoom passed from the flow, ordered zoom → hop →
     paywall.

   *Tests:* end to end with `GrammarLensApp.clock` and the storage clock,
   including `app_resume_test`-style resume and the Day-0 paywall's
   timing.
8. **Events.** The three wrappers, Home's calls, `open_ms` on foreground
   time. *Tests:* exact names and keys with `RecordingAnalyticsSink`;
   the all-events limits test updated. `theme_id` on the existing events
   as its own commit.
9. **Debug define.** `CLIMB_DEBUG_MONTH_CARD`. *Tests:* the `resolve`
   truth table; with the define, no flag read or write and no event (a
   storage fake that fails on flag calls; a recording sink that stays
   empty).
10. **Docs and renders.** `analytics-plan.md` rows (replacing the
    "planned" card rows), real-Home renders, build log, roadmap, Batch 5's
    checklist item (M8).

**Device checklist (yours):**

- [ ] `summary_gold`, `summary_none`, `summary_near`, `fresh`: light and
      dark, Small and Large text.
- [ ] The sheet at your phone's width: does the new mountain show behind
      it? Do the K-c side bands look right in light mode?
- [ ] Closing by button, swipe down and tap outside: each closes the
      sheet, and the zoom follows after the pause.
- [ ] The zoom at three durations (proposal: 700, 1000 and 1400 ms, after
      a 250 ms pause); choose one.
- [ ] A tap on the mountain during the zoom jumps to the end; a tap on the
      Today card during the zoom opens the Daily Test.
- [ ] The chips are hidden in K-c and fade back at the end.
- [ ] Reduce Motion on: no zoom, a short fade.
- [ ] `first_run` on a fresh install, once finishing the Day-0 test (zoom
      → hop → Premium) and once leaving it (zoom only).
- [ ] Close the app with the card open (swipe it away in the app
      switcher); open again: the card is back. Open once more after
      closing it: no card, no zoom.
- [ ] Performance in a profile build (§6), if Q8 allows triggering it
      there.
- [ ] *(Batch 5, M8)* The month card with the new medals.

**Risks.**

- The card reading the medal before finalization (handled by its own
  finalization call, §2).
- Three motions back to back on the first run (scroll, zoom, hop) before
  the Day-0 paywall; the wait before Premium grows by the zoom.
- Two clock seams; a test that sets only one passes for the wrong reason.
- The midnight gap: a month that changes while the app stays open waits
  for the next resume.
- Analytics pollution from debug builds (§8).
- Memory: a cached 4.6–8.5 MB layer during the zoom plus the decoded
  background. **Not measured.**
- Batch 7's one-time opening motion: its order with the card and zoom has
  to be set before it is built (side-tracks "Trail and scene" is replaced
  by M1 for the card).

**Decisions that look problematic from the code.**

- **M4** (Home in K-c visible behind the sheet): not true at 320 and 375
  pt unless Home scrolls first (§5).
- **M2** ("zoom to the avatar at START"): true after a finished Day-0 test
  only if the zoom comes before the hop (§1).
- **M6** (duration chosen on a device): the zoom is 1.21× at 320 pt and
  1.64× at 430 pt. The same duration feels slower on a small screen, where
  less changes.
- **M6 with the old "Start climbing" button:** if the button opens the
  Daily Test (the old card's rule), the zoom plays under the test route
  and is lost (§7). With M6, the button should only close the sheet
  (Q3).
- **M9** (debug only) against measuring the zoom in a profile build (Q8).
- **M7 `open_ms`:** without counting foreground time only, the background
  inflates it (§8).

---

## 11. Questions for the owner

1. **Q1, plaque radius:** is "a named share of the frame's radius (0.4 →
   8 pt)" what you meant by "same proportion", or did you mean the frame's
   20 pt itself (fitted down to about 15 pt at the points)?
2. **Q2, near-miss limit:** A (≤ 5 points), B (≤ 10) or C (≤ 5 % of the
   maximum)? Recommended: A.
3. **Q3, the button:** its label, and does it only close the sheet
   (recommended, so the zoom is seen) or open the Daily Test like the old
   "Start climbing"?
4. **Q4, the old card's lines:** do case (b)'s [N] goal line and the
   theme's tagline stay anywhere (they are not in M5)?
5. **Q5, sheet room:** scroll Home to the climb card before the sheet
   opens, and make the summary card compact enough for 320 × 568?
   (Recommended: both.)
6. **Q6, K-c side bands:** leave the window's fill; use one colour per
   theme and mode measured from the image's edges (a tool writes it as
   theme data); or a blurred copy of the image?
7. **Q7, Daily Test opened during the zoom:** jump the zoom to its end and
   report `skipped` (recommended), or report a fourth outcome?
8. **Q8, profile builds:** may `CLIMB_DEBUG_MONTH_CARD` work in profile
   builds too (`!kReleaseMode` instead of `kDebugMode`), so the zoom can
   be measured there? Release stays a no-op either way.
9. **Q9, events from the debug replay:** none (recommended), with an
   opt-in define for one DebugView pass? And is a developer-traffic filter
   set on the Firebase property?
10. **Q10, event names:** `month_card_shown`, `month_card_dismissed`,
    `month_zoom_ended` with the parameters in §8?
11. **Q11, M2 order:** on the first run, zoom → hop → Premium, which
    lengthens the wait before the Day-0 paywall by the zoom?

---

## How to reproduce

From the repository root (`tool/design_measure/README.md` lists the
same):

```bash
DESIGN_MEASURE_OUT=docs/design/batch6/plaque flutter test tool/design_measure/batch6/plaque_numbers_test.dart
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch6_plaque_after DESIGN_MEASURE_SCREENS=320,375,430 DESIGN_MEASURE_DAYS=15 flutter test tool/design_measure/scene_art/home_render_test.dart
```

(the same into `batch6_plaque_before` on `ac6c900`, then
`build/scene_art_venv/bin/python tool/scene_art/batch6_plaque_sheet.py`
from `tool/scene_art/`)

```bash
DESIGN_MEASURE_OUT=docs/design/batch6 flutter test tool/design_measure/batch6/medal_numbers_test.dart
```

```bash
DESIGN_MEASURE_OUT=docs/design/batch6 flutter test tool/design_measure/batch6/zoom_numbers_test.dart
```

```bash
DESIGN_MEASURE_OUT=build/design_measure/batch6_sheet flutter test tool/design_measure/batch6/month_card_render_test.dart
```

(then `build/scene_art_venv/bin/python batch6_sheet_sheet.py` from
`tool/scene_art/`)
