# UI polish — progress log (branch `ui-polish`)

Running log of the unattended implementation run of `TASK.md` / `SPEC.md`.
One section per batch: status, commits, what was verified and how,
decisions, open items. The final summary goes at the top when B11 ends.

## Final summary

**Status: B0–B11 done, fix round 1 done** on branch `ui-polish` (pushed).
Not merged into `main`, not shipped, **not checked on a device** (the
owner's device pass comes before any merge).

| Batch | Status | Commits |
|---|---|---|
| B0 Plan | done | `24baf18`, `12cdd9c` |
| B1 Foundations | done | `49302e1`, `a91ea97`, `85e7160`, `be7e333`, `0346fc4` |
| B2 Shared components | done | `9186d21`, `a1e08b9`, `5cb8578`, `6cb7aa2`, `1a7fca5`, `53b8006`, `db2e521` |
| B3 Launch and onboarding | done | `7435559`, `af5cbff`, `e6807b1`, `fde5fe8`, `51d38d6`, `531a525`, `3b70896`, `de8bc02` |
| B4 Daily Test and rewards | done | `a879129`, `95d1520`, `ea04792`, `ead1918`, `03dc9e6` |
| B5 Home and mountain | done | `592ef64`, `e6bf38b`, `00130c7` |
| B6 Review | done | `20afb23`, `4f4e250`, `1bf37c4` |
| B7 Practice + first-wave topics | done | `9ea926e`, `9a8024d`, `1fc2a1c`, `d872413` |
| B8 Paywall | done | `2981ab0`, `f303bad` |
| B9 Profile | done | `f98eac1`, `5c39c65` |
| B10 System and themes | done | `5dabea0`, `2aa88bd` |
| B11 Final sweep and docs | done | `a4228b3`, `cd3c33d`, `2c6ddaf` |
| Fix round 1 (owner, 2026-11-17) | done | see "Fix round 1" below |

**Done.** Every in-scope board of SPEC §5 is built and captured on the
iPhone 18 Pro simulator (iOS 27.2) through the debug-only board gallery
(`tool/ui_polish/`); the comparison table is in B11 (updated by fix round
1). The first-wave topics are in the app and the proxy, switched off, with
tests for both states. Fix round 1 built the board's medal shelf, the
ribbon's "since" line, R02's ring, V09's book flight, the listed motion
details, keyboard focus on the language options, and found V05-Goal's
capture "hang" to be the tool's (fixed, recaptured).

**Not done** (each listed with its batch or in fix round 1): mastery strips
(D6-1 / D7-1, **deferred by the owner**: a separate feature later); a few
motion details outside fix round 1's list (V08's measured star path,
Q04's "—" fill, V14's capsule "+N" pop, V13c's Premium column fill, V19's
Next slide-in, V22's midnight stub, H03's think pose); PF03 stays the
existing medal detail rather than the board's bottom sheet (D9-3).

**Not verified.** Nothing on a physical device (haptics, real keyboard,
performance). Arabic and the largest text size are checked by tests, not
captures. No real purchase, no real AI generation, no proxy call; the proxy
is not deployed. Out of scope and untouched: W01, N01–N03, the reminder
switch on V24.

**Decisions approved by the owner (2026-11-17), kept as built:** D5-1,
D5-2, D5-3, D5-4, D6-3, D7-2, D8-1, D8-2, D8-3.

**Decisions closed by fix round 1:** D9-1 (the "since" line is built from
the first Daily Test on record), D9-2 (the board's shelf is built), D9-4
(keyboard focus is back), D6-1 / D7-1 (deferred by the owner).

**Decisions still open for the owner** (details under each batch and in fix
round 1): D6-2 ("new" chip = saved once), D6-4 (RV05's navy button), D6-5
(R03 shows the latest mistake only), D7-3 ("Back to topics"), D7-4, D7-5,
D8-4, D9-3 (PF03 is the existing detail), and fix round 1's F1-1 to F1-9.

## Decisions

Format: what · options · choice · why.

- **D0-1 Simulator.** TASK §6 asks for a 6.1"-class iPhone. Installed
  simulators: iPhone 18 Pro, iPhone 18 Pro Max, iPhone Air (iOS 27.2); no
  6.1" device. · Options: install another runtime/device; use the nearest.
  · **iPhone 18 Pro** (402 × 874 pt, the nearest to the boards' 390 × 844).
  · Rule 5: smallest choice; no download.
- **D0-2 Untracked files that are not part of this run.** `Claude outputs/`
  and `screenshots/icon-exploration/` (22 MB, owner's icon rounds) were
  untracked before the run. `git status` must be clean at the end. ·
  Options: commit them; delete them; ignore them locally. · **Listed in
  `.git/info/exclude`** (local only, not committed, nothing deleted). ·
  Committing someone else's 22 MB of images or deleting them would be wrong;
  a local exclude is invisible to the repo and undone by removing two lines.
- **D0-3 Asset briefs.** `docs/design/ui-polish/asset-requests*.md` were
  untracked next to the handoff and the roadmap links them. · **Committed
  with the handoff** in the first commit.
- **D0-4 Capture tooling.** TASK §6 allows debug-only entry points. · A
  **board gallery** under `tool/ui_polish/` (`gallery_app.dart` +
  `gallery_driver.dart` + `capture.sh`), like `tool/screenshots/`: a
  `flutter drive` run that opens each board's real widget with fixed sample
  data and saves `xcrun simctl io <udid> screenshot` into
  `build/ui-polish-captures/`. Nothing in `lib/` imports it
  (`test/tool_import_guard_test.dart`), so it never reaches a release build.
  Real flows (onboarding, Daily Test) are also walked by hand where
  practical.

- **D1-1 Dark page and card.** SPEC §3.1 lists SY03's dark page #15141A
  and card #211F27 but also says to keep the app's theme values where they
  exist. · Keep #151517 / #252528 (the app's dark theme) vs. switch the
  whole dark theme. · **Kept the app's values** in `AppColors.dark`
  (within a few steps of SY03's). · The rule's "keep the app's values";
  changing the app-wide dark surfaces is out of this run's scope.
- **D1-2 Mood filters.** SPEC X01 gives sad saturation 0.55 and sleep
  brightness 0.82; the boards' static renders show full colour. ·
  **Applied** (SPEC §5 outranks the render). Sad heroes look duller; easy
  to remove (`CompanionView._sadFilter`).
- **D1-3 Loops in tests.** ~2400 widget tests use `pumpAndSettle`, which
  never settles under an endless loop. · `AppMotion.loopsEnabled` is false
  in `test/flutter_test_config.dart`; loop tests turn it on. Haptics are
  recorded (`HapticMap.log`) instead of reaching the platform.
- **D1-4 Retired avatar files.** Deleted in B1 once nothing referenced
  them (ASSETS.md); their name strings removed from the 8 ARB files.

## Blocked / not verified

- Nothing is checked on a physical device in this run (TASK §6).
- Arabic (RTL) and the largest text size: by tests (`b10_system_pass_test`,
  `l10n_layout_test`), not by simulator captures.
- Purchases, AI generation and the proxy: not exercised (fakes and the
  debug fixture offering only); the proxy is not deployed (TASK).
- B11 recapture: the gallery driver hung twice on V05-Goal's tap. **Resolved
  in fix round 1:** a tool race, not the app (see fix round 1); V05 is
  recaptured.

## Fix round 1 (owner request, 2026-11-17)

Status: **done**.

The owner kept D5-1, D5-2, D5-3, D5-4, D6-3, D7-2, D8-1, D8-2 and D8-3 as
built and asked for nine fixes on the same branch, under TASK.md's rules (no
new package, no deploy, no paid API, no version change, no merge, nothing
destructive in git).

Commits: `b72def2` (strings), `e854cea` (V23 shelf, PF02 newest first, medal
Hero flights, PF03 count-up), `46c8ece` (D9-1 since), `946d485` (R02),
`1dfdf76` (V09), `fe8dfa4` (V07), `e51eb99` (Q04), `79fb3c1` (V15),
`f6b4d91` (R04), `63dec2f` (paywall), `20187e6` (R12), `f561357` (D9-4),
`b1cda2f` (product.yaml), `ec28e44` and `a62afce` (capture tool, V05,
V09, V15), `d03452b` (the medal preview test), and the docs commit that
records them.

### Done

1. **D9-2 medal shelf (V23).** Profile's strip is now the board's thick
   shelf (`assets/ui/medal_shelf_v2.webp`) inside one card with "Medal
   collection" and "See all": at most three medals stand on its top
   surface, newest first (the start of the line). The running month is a
   locked slot (dashed ring and lock, "N pts to Bronze") until it reaches a
   tier; then come past medals and the earned Welcome badge by month. Each
   slot has its month and a line under the shelf's front face (a past
   month's tier, the running month's way to its next medal). The medals
   settle 80 ms apart. "See all" opens the existing PF02 layer, which now
   lists newest first (B9 had it reversed) and carries the "N earned" count.
2. **D9-1 "since".** The ribbon reads "Climbing with <Hero> · since <Mon
   YYYY>", the month of the earliest completed Daily Test already stored
   (`climb_daily_entries.completed_at`, read by the new
   `StorageService.getFirstDailyTestCompletion`); without one, or if the
   read fails, "· since …" is left out. Nothing new is stored.
3. **R02 ring.** The board's 104 pt ring: a thick navy arc on a pale track
   around a white (card-colour) disc, the count 35 pt / 900. The ring fills
   in 250 ms; the count rolls like an odometer (up for a longer session,
   down for a shorter one) while the knob moves.
4. **V09 book flight.** Once "This goes to your weak spots" has popped in,
   its book icon flies to the Review tab's place in 500 ms (F1-4).
5. **Motion details** from the batches' "Not done / gaps":
   - V07: the resting hint knob nudges every 2.8 s (the board's keyframes).
   - Q04: the focused box's blank breathes once, 1 → 1.06 → 1 in 200 ms
     (F1-5).
   - V15: the step today's test will reach has a gold ring that pulses to
     1.45× every 1.8 s while the test waits.
   - R04: a medal line pops to 1.5×, turns gold and glows as the bar
     passes it.
   - Paywall: plans rise in 60 ms apart as they scroll in, the comparison
     rows fade in 40 ms apart, the See plans arrow nudges every 1.8 s.
   - R12: the focus card glints every 3.6 s.
   - PF02 / PF03: shelf medals fly into the layer and back (Hero, 350 ms);
     a medal flies from the shelf or the layer into its detail; the
     detail's steps and points count up.
   All loops are ambient (off under Reduce Motion, off screen and in
   tests); entrances become instant under Reduce Motion; no flight or
   count-up under Reduce Motion.
6. **D9-4 keyboard focus.** The language options take focus again in
   reading order (Tab), Enter or Space picks one; an orange ring shows only
   with keyboard focus, so the touch look is unchanged (F1-6).
7. **V05-Goal "hang".** Walked in the real app on the simulator (fresh
   install → Welcome → buddy → name → goal → Work → Continue → getting
   ready → mountain intro): no hang, no animation that never ends (the
   selected card's tilt is the designed ±2°, the star by the buddy is the
   cheer pose's prop, the confetti ends after 900 ms). The cause was the
   capture script: it tapped Continue right after typing, unsynchronized,
   while the button was still disabled, so the goal step never came and
   flutter_driver waited without a timeout. Fixed in the tool (a wait, and
   a 15 s timeout on every driver step so a board fails instead of hanging
   the run); V05 recaptured. No app change, so no app test.
8. **product.yaml**: only the planned UI polish line changed ("built on
   branch ui-polish, not merged, not checked on a device"); `updated_at`
   was already today.
9. **Mastery strips (D6-1 / D7-1)**: marked "deferred (owner)" under B6
   and B7; not built.

### Decisions

- **F1-1 The running month's slot.** SPEC and the owner: "a locked slot for
  the current month". Shown locked while the month has no tier; once it
  reaches Bronze it shows that medal (a tier reached in a month is never
  lost), with the way to the next one. The board's own sample has no tier.
- **F1-2 The Welcome badge on the shelf** stands by the month it was
  earned, after that month's own medal (a month's medal is finalized at
  its end); an unearned badge is only in PF02. The board's "Swipe for more
  · newest first" caption is not shown: the shelf does not swipe, "See all"
  opens the rest. "N earned" moved from Profile's header to PF02's.
- **F1-3 "since"** counts every completed Daily Test, an all-skipped one
  included (it is a completed test in the ledger). The month is short
  ("Sep 2026"), as on the shelf.
- **F1-4 V09's target.** The Daily Test is a full-screen route, so the nav
  bar is not on screen; the book flies to where the Review tab sits (the
  middle tab, bottom middle of the screen) and fades as it arrives.
- **F1-5 Q04's breathe** is drawn over the blank (a tint and its underline
  in the blank's colour): a span of text cannot be scaled in place.
- **F1-6 Focus** is opt-in on `PressableCard`; only the language options use
  it in this round. Their extra light haptic (the card's, on top of their
  own selection haptic) is gone.
- **F1-7 R02's disc** takes the card colour (white in light mode, the dark
  card in dark mode) instead of a fixed white; the board's "about 4
  minutes" line is not added (no measured duration, not asked).
- **F1-8 Paywall rows** fade only (no rise), so the comparison table's
  measured geometry never moves; the plans rise 24 pt. Semantics stay while
  they wait to enter.
- **F1-9 PF02's order** was oldest first in B9 against SPEC and the board
  ("newest first"); fixed with the shelf.

### Not done

- PF03 stays the existing medal detail (a centred dialog), not the board's
  bottom sheet (D9-3, not in this round's list); the medal now flies into
  it and its numbers count up.
- Motion details not in this round's list stay as listed under their
  batches (V08's measured star path, Q04's "—" fill, V14's capsule pop,
  V13c's Premium column fill, V19's Next slide-in, V22's midnight stub,
  H03's think pose).

### Verified

- `flutter analyze` after the last code change: **No issues found!**
- `flutter test` after the last code change: **2493 passed, 0 failed**
  (2477 before the round; new tests: the shelf's order, Welcome placement,
  locked slot and its line, geometry on the shelf image, settle stagger,
  Hero tags and the detail's count-up; the "since" line with and without a
  first test, and the storage read; R02's roll direction; V09's book with
  and without Reduce Motion and none for a right answer; V07's nudge (LTR,
  RTL, Reduce Motion); Q04's breathe; V15's ring and pulse, on Home before
  the test and not after it; R04's glowing lines; the paywall's entrances
  with semantics kept; R12's glint; the language options' Tab order, Enter
  and the keyboard-only ring). One test found after the first full run (the
  debug medal preview still expected the old strip) was updated and the
  suite re-run.
- Simulator (iPhone 18 Pro, iOS 27.2): the real app, fresh install, walked
  Welcome → buddy → name → goal → Work → Continue → getting ready →
  mountain intro (no hang). The board gallery recaptured the 15 boards
  listed in B11's table, every board without a failure; V09 also mid-flight
  and V15 scrolled to the ring.
- No proxy change in this round; nothing deployed, no paid API, no new
  package, no version change, no new data stored.

## B0 — Plan

Status: **done**.

Commits: `24baf18` (the handoff package), `12cdd9c` (this plan).

### Board → code

Every in-scope board (SPEC §2: all but W01, N01, N02, N03 and the reminder
switch on V24). "new" = file to create. All paths under `lib/` unless noted.
The hinted paths from TASK B0 were checked: all exist.

| Board | Code |
|---|---|
| V00-CompanionSystem | new `models/companion.dart` (`Companion` hero list, `CompanionMood`), new `widgets/companion_view.dart` (`CompanionView(hero, mood, size)`) |
| V00-MotionSystem | new `motion.dart` (`AppMotion`), new `utils/haptics.dart` (`HapticMap`), new `widgets/pressable_button.dart` |
| X01-ExpressionKit | `widgets/companion_view.dart` (props, per-mood motion) |
| X03-HeroSet | `models/avatar.dart` (9 heroes, picker order, retired ids), `services/storage_service.dart` (retired → Fox migration on profile read) |
| X04-Ticket | new `widgets/ticket.dart` (`Ticket(state: free, tearing, used)`) |
| X05-DailyCard | new `widgets/daily_test_card.dart` (`DailyTestCard(state)`), replaces `_DailyTestCard` in `screens/home_screen.dart` |
| V01-Splash | `widgets/launch_splash.dart` |
| V02-Welcome | `screens/welcome_screen.dart` |
| V03-Meet | new `widgets/companion_turntable.dart` (replaces `widgets/avatar_carousel.dart`), `screens/onboarding_screen.dart` |
| V03b-LuckyWheel | new `screens/lucky_wheel_screen.dart` |
| V04-Name | `screens/onboarding_screen.dart` (name step) |
| V05-Goal | V05-Goal.png | match | Three goal cards, the selected one navy. Recaptured in fix round 1 (the B11 "hang" was the capture script, fixed). |
| V05b-GettingReady | new `screens/getting_ready_screen.dart` + new `services/getting_ready.dart` (stop logic), `screens/first_launch_flow.dart` |
| V06-MountainIntro | new `screens/mountain_intro_screen.dart`, `screens/first_launch_flow.dart`, `widgets/monthly_climb/*` (flag v2) |
| V07-Question | V07-Question.png | match | Check footer, points chip; the hint knob nudges every 2.8 s (fix round 1). |
| V08-Correct / V09-Wrong | new `widgets/answer_feedback_sheet.dart`, new `services/daily_test_grading.dart` (on-device per-question grading over `utils/answer_matching.dart`), `screens/daily_test_screen.dart` |
| Q04-MultiBlank / Q05-ErrorCorrection | `widgets/question_view.dart`, `screens/daily_test_screen.dart`, `utils/answer_diff.dart` (reuse) |
| R10-Leave | new `widgets/companion_dialog.dart`; `screens/daily_test_screen.dart`, `screens/practice_screen.dart` (exit dialogs) |
| V10-Results | `screens/daily_test_result_screen.dart` |
| V11-Badge | `screens/daily_test_result_screen.dart` (day-0 Welcome badge) |
| R05-Medal | `widgets/medal_celebration.dart` |
| V12-Climb / V12b | `widgets/monthly_climb/climb_zoom.dart`, `climb_camera.dart`, `monthly_mountain.dart`; `screens/home_screen.dart` |
| V14-Home / V15 / H03 / H04 | `screens/home_screen.dart`, `widgets/daily_test_card.dart`, new `widgets/score_capsule.dart`, `widgets/ticket.dart`, `widgets/monthly_climb/climb_card.dart` |
| V24-DayComplete | new `widgets/rest_scene.dart`, `screens/home_screen.dart` (§1.8 rule) |
| R04-MonthCard | R04-MonthCard.png | match | Recap with medal swap, dots, stats, stepwise bar; passed medal lines glow (fix round 1). |
| R04b-NewMountain | `widgets/month_card_sheet.dart` / new `widgets/new_mountain_reveal.dart` |
| V16 / V16b / V22 / RV05 / RV06 / R12 | `screens/review_screen.dart`, `widgets/review_top_card.dart`, `widgets/weak_spot_card.dart`, `widgets/ticket.dart`, `widgets/app_sheet.dart` (new) |
| R03-WeakSpot | `screens/weak_spot_detail_screen.dart` |
| R01-Topics | `screens/topic_practice_screen.dart` |
| R02-Length | R02-Length.png | match | The board's ring (white disc, navy arc, big count); the count rolls while dragging (fix round 1). |
| V17-Consent | `screens/ai_consent_screen.dart` |
| V18-Preparing | `screens/practice_launch.dart`, new `widgets/preparing_view.dart` |
| V19-PracticeQuestion | `screens/practice_screen.dart`, `widgets/question_view.dart` |
| V20-Reviewing | `screens/practice_screen.dart` (submit wait), new `widgets/reviewing_view.dart` |
| V21-PracticeResults | `screens/results_screen.dart` |
| P08-DailyLimit | `screens/practice_launch.dart` (`_showDailyLimitReachedDialog` → sheet) |
| V13 / V13a / V13c / V13b / PW05 | `screens/premium_screen.dart`, new `widgets/paywall_exit_dialog.dart`, new `screens/premium_on_screen.dart` |
| V23-Profile | V23-Profile.png, V23-Profile-420.png | match | Stage, ribbon with "since Sep 2026", stat tiles, the thick shelf with three medals newest first and the running month locked (fix round 1). |
| PF02-Medals / PF03-MedalDetail | `widgets/monthly_medal_collection.dart` |
| PF04-EditName | `screens/settings_screen.dart` (name sheet) |
| R06-AvatarChange (+ R06s storyboards) | `screens/avatar_picker_screen.dart` (turntable + wheel) |
| R07-Language | R07-Language.png | match | Language cards, the selected one navy with a check; keyboard focus restored, look unchanged (fix round 1). |
| R08-Data | `screens/data_screen.dart` |
| R09-Credits | `screens/credits_screen.dart` |
| R11-Offline | new `widgets/error_state.dart`; used by Home, practice launch, getting ready |
| SY02-Snackbar | `utils/app_messenger.dart` |
| SY03-DarkHome | `theme.dart` (`AppColors` extension, dark values) |
| First-wave topics | `models/topic.dart`, `data/topics.dart`, `data/topic_hints.dart`, `proxy/src/topics.ts` (+ tests), flag default off |

### Components (built first, B1–B2)

`AppColors` (ThemeExtension, light + dark), `AppMotion`, `HapticMap`,
`PressableButton` (primary / secondary / text), `CompanionView`,
`DailyTestCard`, `Ticket`, `ScoreCapsule`, `StepBar`, `showAppSheet`,
`CompanionDialog`, the snackbar (`AppMessenger`), `ErrorState`, confetti
(`widgets/confetti_burst.dart`, extended) and `Rays`.

### Risks

- **Scope.** ~65 boards in one run. Mitigation: components first, every
  screen built from them; boards checked by capture; any gap recorded as a
  gap, not hidden.
- **Existing tests pin today's layout** (≈ 2400 tests, many with keys and
  copy). Where the design changes behaviour on purpose the test is updated
  and the commit says so.
- **Per-question grading** must equal the completion award and use the
  existing matching rules exactly; it reuses `DailyTestCompletion` and
  `answer_matching.dart` rather than a copy.
- **Retired avatars**: the stored id format stays `avatar_XX`; the asset
  files of retired avatars are deleted only once nothing references them.
- **Font weights**: raw `fontWeight:` fails `font_weight_guard_test.dart`;
  every weight goes through `withWeight`.
- **l10n guard**: hard-coded user-facing strings fail
  `l10n_guard_test.dart`; every string goes into the 8 ARB files.
- **Simulator time**: one `flutter drive` build captures every board.

### Reaching each screen in the simulator

- Real flow, by hand: fresh install → Splash → Welcome → onboarding
  (turntable, wheel, name, goal, getting ready, mountain intro) → Day-0
  Daily Test → results → Home.
- Everything else (states that need data or time: Home done / loading /
  Premium / rest scene, the ticket states, Review states, practice steps,
  paywall parts, Profile layers, errors, dark theme): the board gallery
  (`tool/ui_polish/`), which mounts the real widgets with sample data, one
  board per driver request.

## B1 — Foundations

Status: **done**.

Commits: `49302e1` (assets moved, registered), `a91ea97` (AppColors,
AppMotion, HapticMap, test config), `85e7160` (PressableButton,
PressableCard), `be7e333` (nine heroes, picker order, retired → Fox, file
and string removal), `0346fc4` (CompanionView). Gallery tooling for the
captures: see B2.

What was built:
- Assets: `assets/companions/` (54 poses), `assets/companions/props/` (6),
  `assets/ui/` (7 objects); registered in `pubspec.yaml`.
- `lib/app_colors.dart` (`AppColors` ThemeExtension, light/dark; wheel
  slice and hero stage colours; `lipCard`), `lib/motion.dart`
  (`AppMotion`), `lib/utils/haptics.dart` (`HapticMap`).
- `lib/widgets/pressable_button.dart`, `lib/widgets/companion_view.dart`.
- `lib/models/avatar.dart`: nine heroes in picker order; retired ids read
  as Fox; `StorageService.getUserProfile` rewrites a retired id to
  `avatar_14` once. Personality traits (SPEC §3.5) in all 8 languages.

Verified:
- `flutter analyze`: no issues. `flutter test`: 2432 passed + the new
  tests; one failure was a stale `build/unit_test_assets` cache (the
  deleted avatar files), passing after the cache was removed.
- New tests: `avatar_test` (9 heroes in order, ids, files on disk),
  `avatar_retired_migration_test` (each retired id → Fox, stored as
  `avatar_14`; current heroes and null untouched), `companion_view_test`,
  `pressable_button_test`, `haptics_test`.
- Simulator (iPhone 18 Pro, light): V00-CompanionSystem,
  V00-MotionSystem, X01-ExpressionKit, X03-HeroSet captured through the
  board gallery; poses, props and their placement match the boards.

## B2 — Shared components

Status: **done**.

Commits: `9186d21` (strings), `a1e08b9` (StepBar, ScoreRing,
SkeletonBar), `5cb8578` (DailyTestCard), `6cb7aa2` (Ticket), `1a7fca5`
(ScoreCapsule, showAppSheet, CompanionDialog, ErrorState, Rays, confetti
length/count), `53b8006` (SY02 snackbar), `db2e521` (gallery boards).

What was built (all colours from `AppColors`, durations from
`AppMotion`):
- `widgets/daily_test_card.dart` — X05 skeleton, loading / todo / done.
- `widgets/ticket.dart` — X04 free / tearing / used, notches cut out of
  the path, the tear (≈ 700 ms) with haptics medium + light, the used slot
  with the time left to local midnight.
- `widgets/score_capsule.dart` — V14 capsule; tier maths from
  `MonthlyMedalRules`.
- `widgets/step_bar.dart`, `widgets/score_ring.dart`,
  `widgets/skeleton.dart`, `widgets/app_sheet.dart`,
  `widgets/companion_dialog.dart` (R10 pattern), `widgets/error_state.dart`
  (R11), `widgets/rays.dart`; `utils/app_messenger.dart` now draws SY02.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: 2450 passed, 6
  failed — all six in `practice_submit_consent_test.dart`, whose helper
  cast the snackbar content to `Text`; fixed (reads the first `Text` in
  the capsule), the file passes.
- New tests: `daily_test_card_test` (350 × 256 in all three states, also
  at text scale 2.0 and 3.1 with the Large app text size, no overflow;
  slot contents per state), `ticket_test` (three states render; tear plays
  then `onTorn`, haptics medium + light; same size in all states, compact
  and full), `b2_components_test` (dialog results and haptics, error state
  retry dots + haptics + copy per kind, StepBar fills one by one, capsule
  tier maths and badge), messenger tests for SY02.
- Simulator (iPhone 18 Pro, light): X04-Ticket, X05-DailyCard, R10-Leave,
  R11-Offline, SY02-Snackbar captured. Match: card rows, colours and the
  ticket's notches, tear and used slot as on the boards; the dialog's
  scrim was darker than the board's and was lightened to 45 %.

Decisions:
- **D2-1 Ticket "20:41 NEXT".** The board's ARIA label reads "Next ticket
  in 20 hours 41 minutes" and SPEC says the slot "updates every minute":
  the slot shows the **time left** until local midnight (h:mm), not a
  clock time.
- **D2-2 Text scaling inside fixed components.** The Daily Test card's
  rows have fixed heights, so its text is clamped to 1.0× (the card never
  grows, X05); the title shrinks from 26 to 22 before it truncates. The
  ticket's text is clamped to 1.15×.
- **D2-3 Snackbar.** SY02's capsule replaces the Material bar's look; the
  slide uses `ScaffoldMessenger`'s own entrance (250 ms, easeOutCubic),
  which fades and slides rather than moving from exactly 120 %.

## B3 — Launch and onboarding

Status: **done**.

Commits: `7435559` (strings), `af5cbff` (BuddyPicker turntable, lucky
wheel, SpeechBubble), `e6807b1` (onboarding V04–V05, getting ready V05b,
mountain intro V06, R06 picker; the carousel removed), `fde5fe8`
(Welcome V02), `51d38d6` (splash V01, launch image regenerated),
`531a525` (dead strings removed), `3b70896` (gallery scripts), `de8bc02`
(MountainScene, V06 on the whole mountain).

What was built:
- V01 `widgets/launch_splash.dart`: the app icon drawn from its shapes
  (square pop, lens from the bottom right, lines, glint), wordmark rise
  and a small lens scanning it; first launch 1.4 s (no profile yet, read
  in `main.dart` before the first frame), later launches 600 ms; Reduce
  Motion = one 150 ms fade; light haptic when the square lands. The iOS
  static launch image (the first frame: the square at 50 %) regenerated
  with `scripts/generate_launch_image.sh` (a local render, no network).
- V02 `screens/welcome_screen.dart` (+ `data/welcome_demo.dart`, English
  content).
- V03 / R06 `widgets/buddy_picker.dart` (turntable), V03b
  `screens/lucky_wheel_screen.dart` (`pickLuckyHero`: never the current
  buddy, never the previous result), `screens/avatar_picker_screen.dart`.
- V04 / V05 `screens/onboarding_screen.dart` (buddy → name → goal).
- V05b `services/getting_ready.dart` (`GettingReadyModel`) +
  `screens/getting_ready_screen.dart`; `screens/first_launch_flow.dart`
  runs the three real tasks (save profile, today's set, resolve this
  month's mountain).
- V06 `screens/mountain_intro_screen.dart` on the new
  `widgets/monthly_climb/mountain_scene.dart`.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2443 passed**
  (before the V06 rework; the V06 commit adds `mountain_scene_test`,
  run on its own: pass).
- New tests: `lucky_wheel_test` (400 seeds × every current × every
  previous: never current, never previous; every other hero reachable),
  `getting_ready_test` (never past a stop while its task runs; 1.8 s
  minimum, done < 2.3 s for instant work; timeout at 8 s; retry keeps the
  bar), `onboarding_screen_test` (rewritten), `avatar_picker_screen_test`
  (rewritten), `mountain_scene_test` (cover: no empty band at any zoom).
- Tests changed on purpose (said in the commits): onboarding / first
  launch / climb / preview / widget tests walk the new steps; the profile
  is saved before today's set (SPEC §1.6 order); launch tests follow V01's
  timing; Welcome's wordmark test; Home's and Profile's picker tests use
  "Save <Hero>".
- Simulator (iPhone 18 Pro, light), through the gallery with real taps:
  V01 (mid-assembly and final), V02, V03, V03b (ready and landed), V04,
  V05 (Work chosen), V05b (mid-way and 100 %), V06, R06, R06s-B1
  (resting, mid-turn, Panda in front), R06s-D (ready, spinning, landed).
  Match: layout, colours, copy and states as on the boards. Gaps: V04 is
  captured without the iOS keyboard (flutter_driver's text entry); V01's
  wordmark scan lens is the brand loupe, not the board's navy outline
  lens.

Decisions:
- **D3-1 Onboarding order.** V03 buddy → V04 name → V05 goal; the step
  indicator counts 4 (buddy, name, goal, mountain) on every step; V05's
  bar reads "3 of 4" (the board's "2 of 3" is sample data that contradicts
  V03/V04's four dots).
- **D3-2 Goal subtitle.** The board's "You can change it later in
  Profile" is not true (Profile has no goal setting); the line is "Pick
  one. It helps us decide what to improve next." (SPEC §1.12: no promise
  of personalised content).
- **D3-3 Privacy line on V05 kept.** The board shows none; the goal is
  still reported as the `learning_goal` user property, so the existing
  disclosure and the "Your data & AI" sheet stay, small, under the cards.
- **D3-4 Getting ready's task order** follows its rows (profile, then the
  Day-0 set, then the mountain). The old code wrote the set first; if the
  app is killed between the two, the Daily Test fetches today's shared set
  instead of the bundled Day-0 set (the old fallback path).
- **D3-5 First launch for the splash** = no profile yet, read with one
  local query started before the first frame; if it has not answered when
  the lens would start (280 ms), the full assembly plays.
- **D3-6 Turntable starts with Fox** (the board's "1 / 9"), not a random
  buddy.
- **D3-7 R06 saves with the button.** The carousel's autosave is gone;
  "Save <Hero>" saves, Back leaves the buddy unchanged. The Hero flight
  from Home/Profile is dropped (the turntable has no single tile to fly).

## B4 — Daily Test and rewards

Status: **done**.

Commits: `a879129` (strings), `95d1520` (on-device grading), `ea04792`
(graded answer look, red button, highlighted step), `ead1918` (Daily
Test V07–V09 / Q04 / Q05 / R10, results V10, badge V11, medal R05),
`03dc9e6` (gallery).

What was built:
- `services/daily_test_grading.dart` (`QuestionCheck`): one answer graded
  with the completion's own rules (`DailyTestAnswerResult.from`), points
  by `MonthlyMedalRules` (display only; storing is unchanged, at the end
  as before); per-blank results for multi-blank questions by splitting the
  key at the template's fixed text.
- `screens/daily_test_screen.dart`: header (close, 5 segments, points
  chip with the clay star), the buddy and its bubble, Skip + Check
  ("Finish" on the last question), the feedback sheet (V08 / V09), the
  "+N" star flight, the R10 leave dialog.
- `screens/daily_test_result_screen.dart` (V10): "Day N complete!", the
  stepwise ring, strip, tiles, "Your answers" rows (open to the old card's
  explanation logic, unchanged), the button in the bottom slot.
- `widgets/medal_celebration.dart` (V11 / R05): navy page, turning rays,
  the medal popping and floating over the cheering companion, eyebrow,
  "N points in <month>!" and "<Next> is next at N. Keep climbing <mountain>."
  (thresholds from `MonthlyMedalRules`), a Continue button.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2454 passed**
  (after the test updates below).
- New tests: `daily_test_grading_test` (every check equals the
  completion's result for the day-0 set and many answers; the shown total
  equals `MonthlyMedalRules.score` of the completion; +2/+1/0; per-blank
  split), `daily_test_check_test` (right: "Nice, Ada!", +2, success; wrong:
  "Almost!", the key, +1, warning, read-only box; a whole test: the chip
  counts the award and the answers handed over are the checked ones).
- Simulator (gallery, real taps): V07, V08, V09, Q04 (typed and checked:
  blanks green / orange / green), Q05, R10, V10, V11, R05.

Decisions:
- **D4-1 Skip stays** (a quiet text button next to Check): the board has
  none, but skipping is an existing rule (a skipped question is not
  wrong, 0 points) that SPEC §1 does not change.
- **D4-2 No Back in the Daily Test.** With per-question feedback a
  checked answer is final; the board's header has only close, the
  segments and the points.
- **D4-3 The last question** reads "Finish" (Q05) and still checks; the
  sheet's button then reads "See results".
- **D4-4 "Saved to your weak spots" → "This goes to your weak spots".**
  Mistakes are written at the end of the test (unchanged); leaving the
  test saves nothing, so "saved" would not be true yet.
- **D4-5 The buddy's row under the question** sits above Check (not
  directly under the answer box: `QuestionView`'s keyboard-safe layout is
  unchanged) and is hidden with the keyboard up and on phones under 740 pt
  tall, so the open hint card stays whole (`topic_hint_card_test` fit
  checks).
- **D4-6 The results' button is navy** in every case (V10), replacing the
  1.2.0 orange/navy split for this screen; "Start my climb" reads "Climb
  my first step".

Not done / gaps:
- V08's "+2" star flies on a fixed path (sheet → chip), not measured from
  the chip's position; V09's book icon does not fly to the Review tab (the
  test screen is a pushed route with no nav bar visible).
- Q04's "breathe" of a tapped blank and the "—" fill animation keep the
  existing 1.4.0 look.
- V07's hint handle "nudge every 2.8 s" is not added (hint slider as in
  the app today, SPEC V07).

## B5 — Home and mountain

Status: **done**.

Commits: `592ef64` (strings), `e6bf38b` (Home, rest scene, first climb, month change, tests), `00130c7` (gallery).

What was built:
- Home (`screens/home_screen.dart`, V15 / V14 / H04): the wordmark with the
  score capsule (points, ring to the next medal, today's "+N"; a tap opens
  Profile), the greeting, the DailyTestCard (`todo` / `done` / `loading`),
  the mountain card with its bubble ("Step N is one test away!" / "Step N
  opens tomorrow"), then for a free user the compact ticket ("Use it on:
  <weak spot>", to Review) and the topic showcase (`widgets/home_practice.dart`:
  the weak spot's topic "Picked for you", locked floating tiles, "Unlock
  all N topics" to the paywall); for Premium the practice card ("Sessions
  today n/5" segments, unlocked tiles, "Practice your weak spot").
- H03: the mountain card's skeleton while the month loads.
- V24 rest scene (`widgets/rest_scene.dart`): replaces Home's content only
  when every daily right is used (§1.8: today's test done and the free
  ticket used, or every Premium session); camp at the companion's step,
  tent, campfire (logs image, two flame layers, sparks, ground light), the
  companion asleep with Zzz, "See you tomorrow, <name>", the done tiles and
  a countdown to local midnight updated every minute. No reminder switch.
- V12 first climb (`screens/first_climb_screen.dart`): one camera on the
  whole mountain (cover framing) wide → 2.2× → walk in 0.45 s hops with the
  trail painting → wide; "Step 1 of N" pops on arrival (light + success);
  bubble and Continue after the camera. Shown in the first-launch flow
  after "Climb my first step".
- R04 / R04b (`widgets/month_card_sheet.dart`): the month change as two
  full-screen pages instead of the bottom sheet: the recap (header medal
  that swaps bronze → silver, "<Tier> on <mountain>!", last month's
  mountain edge to edge with gold step dots, steps / points / "to <next>",
  the points bar filling stop by stop through `MonthlyMedalRules`'
  thresholds with a jiggle and light haptic at each stop and success at the
  month's medal, the near-miss line, "See my new mountain") and the new
  mountain (rises 40 px + fade, flag pops, the companion drops and hops,
  "A new mountain!", steps and medal lines, "Start climbing").
- The first tab is labelled "Climb" (every board's nav bar).

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2438 passed**.
- New tests: `b5_home_mountain_test` (V12 camera timeline, cover framing at
  every 100 ms, arrival haptics, skip, Reduce Motion; V24 countdown to
  midnight, minute updates, no switch); Home's new group in
  `home_screen_test` (card lines and buttons, bubble, capsule → Profile,
  ticket → Review, showcase → paywall, Premium practice card, live
  entitlement change, order, rest scene for free and Premium and not with
  practice left); `month_card_test` rewritten for R04 / R04b (bar stops,
  haptics, medal, near-miss, fresh, closing, events); first-launch tests
  walk through V12.
- Simulator (gallery): V15, V14 (+ scrolled), H03, H04 (+ scrolled), V24,
  V12, V12b (three key frames), R04, R04b.

Decisions:
- **D5-1 Home's avatar, weak spot list, topic strip and Review call-out
  are gone** (V14 / V15 / H04 have none of them). The ticket takes the
  call-out's job (to Review, the same slide), the showcase the strip's
  (to the paywall, the same `source: home`), Premium's "Practice your weak
  spot" the weak spot list's (the most frequent weak spot). The avatar is
  still changed in Profile (R06).
- **D5-2 Tab label "Climb".** Every board's nav bar says "Climb" (the app
  said "Home"); the key `navHome` keeps its name, the 8 values change.
- **D5-3 V12 is the first run's zoom.** When the Day-0 test earns a step,
  the first-launch flow shows V12 full screen after "Climb my first step";
  it claims the same one-time flag (`first_run_zoom`) and sends the same
  `month_zoom_ended` (trigger `first_run`, outcome completed / skipped /
  reduce_motion) Home's in-card zoom sent, so no new event. Home then skips
  its in-card zoom but still walks the step on the card and opens the
  Day-0 paywall after it, as before. With no step (all skipped), Home's
  in-card zoom plays as before. The flow now takes the app's clock (tests
  pin the month).
- **D5-4 The month change is full screen** (R04 → R04b; R04b alone for
  the fresh variant). It closes with "Start climbing" (`method: button`)
  or the system back (`method: barrier`); a swipe down no longer exists
  (the `drag` value stays in the enum, unused). Home's month-change zoom
  after it is unchanged.
- **D5-5 V24's practice tile** reads "Ticket used" for free users and
  "n/5 sessions" for Premium; the countdown is `HH:MM` to local midnight
  (the Daily Test's day boundary).
- **D5-6 No trial promise on Home**: the showcase's button says "Unlock all
  N topics" (the paywall states the offer, §1.7).

Not done / gaps:
- V15's gold ring pulse on the next step and V14's capsule "+9" pop are
  the existing mountain and capsule visuals (the ring fill animates; no
  separate pulse ring on the step).
- H03's companion "think" pose and the 8 s R11 fallback come from the
  shared DailyTestCard / Home load paths (no new timeout added).
- R04's trail dots light in order (60 ms apart) but the bar's medal lines
  glow by scale only.

## B6 — Review

Status: **done**.

Commits: `20afb23` (strings), `4f4e250` (Review, weak spot, tests), `1bf37c4` (gallery).

What was built:
- Review (`screens/review_screen.dart`, V16 / V16b / V22 / RV05 / R12):
  the title (with the Premium chip for Premium) and "Your mistakes, turned
  into practice."; for a free user the shared Ticket on top — free ("Pick
  a weak spot below…"), tearing ("Ticket used!"), used ("Used today",
  "Nice work, <name>.", the next ticket's countdown to local midnight,
  updated every minute) or waiting for the first weak spot (RV05); for
  Premium the navy Suggested Focus. "Weak spots" with its count and the
  sort button; each weak spot as a card with its topic, a "new" chip
  (saved once), "N times · when", its title and its latest mistake inline
  (`widgets/review_parts.dart`, `InlineMistake`: wrong words struck through
  in red, the correction in green, from the stored answer and correction
  through `diffAnswer`). "Practice with my ticket" on the first card tears
  the ticket (medium haptic) and then starts the weak spot's practice
  through `launchPracticeSet` (AI permission, quota and generation as
  before; the free count changes only when a set is made). Used: "Want more
  practice today? Premium: up to 5 sessions a day" → the paywall
  (`review_quota`).
- RV05: the ticket waiting, the cheering companion (two hops), "No weak
  spots yet!", "Take today's Daily Test" (navy, as the board).
- RV06: the sort sheet (`showReviewSortSheet`): two big options, the
  selected one a navy card with a check; the list cross-fades to the new
  order.
- R03 (`screens/weak_spot_detail_screen.dart`): topic eyebrow, title,
  "N times · last seen …", the buddy saying the stored rule ("Remember:
  …"), "Your mistake" with the latest mistake inline and its explanation,
  and today's ticket ("Use today's ticket", tears, then practice) for a
  free user, "Practice this" for Premium; the used state keeps "Practice
  with Premium" and the used-today message.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2421 passed** (the
  free practice card's tests were replaced by ticket tests).
- Tests: `review_screen_test` rewritten (ticket states, the countdown at
  03:19 → 20 h 41 min, the tear then the AI permission, the inline line,
  the sort sheet, the empty state, Premium); `review_suggested_focus_test`,
  `weak_spot_detail_screen_test`, `button_rule_test`,
  `practice_launch_*_test` and `tab_switcher_test` follow the new controls.
- Simulator (gallery): V16, V16b (mid-tear and the AI permission that
  follows), V22, RV05, RV06, R03, R12.

Decisions:
- **D6-1 No mastery strips** (R03 "0/3", R12, V22). The app stores no
  per-weak-spot count of correct practice sessions and SPEC §1 defines no
  mastery rule; adding one would be a new business rule and new stored
  data. Left out; the layouts keep their spacing without them. Easy to add
  with a stored count later. **Deferred (owner, fix round 1):** mastery
  strips are not part of this run; they will be designed later as a
  separate feature.
- **D6-2 "new" chip** = a weak spot saved once (`frequency == 1`); the
  boards' "practiced today" chip is left out (no per-weak-spot practice
  record).
- **D6-3 The free practice card (1.2.0) is replaced by the Ticket** on
  Review and R03; its "See Premium" moves to V22's "Want more practice
  today?" card (same paywall source).
- **D6-4 RV05's button is navy** (the board), replacing the 1.2.0
  "forward actions are orange" rule for this one button.
- **D6-5 R03 shows the latest mistake only** (the board's "Your mistake");
  the older "Recent mistakes" list and the separate "Saved feedback" panel
  are folded into that one card.

Not done / gaps:
- V22's "new stub slides in at midnight" plays only if Review is open at
  midnight (the state is re-read when the tab is shown again).
- R12's focus card glint and the weak spot cards' mastery fill are not
  drawn (D6-1).

## B7 — Practice

Status: **done**.

Commits: `9ea926e` (strings), `9a8024d` (practice screens, first-wave topics in the app, tests), `1fc2a1c` (proxy, switched off), `d872413` (gallery).

What was built:
- R01 (`screens/topic_practice_screen.dart`): the header with the Premium
  chip, "Pick a topic. AI reviews every answer.", the most repeated weak
  spot's topic as a navy "Picked for you" card, then the topics two a row
  in their colours (floating, 2 pt press, light haptic) with the real
  status line. The list is `practiceTopics()`.
- R02 (`screens/practice_length_picker.dart`): the existing 3 / 5 / 10
  slider in the shared sheet, an orange knob and track, selection haptic at
  each stop, the pressable orange Start whose label cross-fades.
- V17 (`screens/ai_consent_screen.dart`): the same text, each section a
  card with its icon fading in 40 ms after the one above, the navy
  pressable "Agree and continue" (medium haptic), "Not now" unchanged.
- V18 (`widgets/practice_preparing.dart`, through `PageLoading(topic:)`):
  the thinking companion, three question skeletons and the topic's hint
  cards rotating every 3 s under "Did you know?" — on Topic Practice, the
  weak spot screen and Review.
- V19 (`screens/practice_screen.dart`): "AI reviews all your answers when
  you finish" above Skip / Next (hidden with the keyboard up and under
  740 pt, as the Daily Test's buddy row).
- V20 (`widgets/practice_reviewing.dart`): the inspecting companion, the
  answers with the clay lens sweeping over them (3.2 s), a checklist ticking
  0.8 s apart (light haptic each), an indeterminate bar; success haptic
  when the result arrives.
- V21 (`screens/results_screen.dart`): the cheering companion and "N/M
  correct", feedback cards entering from below 60 ms apart with a Correct /
  Needs work / Skipped pill and the existing breakdown; a free user out of
  practice gets "Want another round today? Premium: up to 5 sessions a
  day, every topic." with See Premium (same events and paywall source).
- P08 (`showDailyLimitSheet` in `practice_launch.dart`): a sheet with the
  sleeping companion, the full session counter and the existing text.
- Practice R10: the leave confirmation is the companion dialog ("Keep
  going" / "Leave").
- First-wave topics (§1.11): `TopicId` gets Conditionals, Passive Voice,
  Prepositions, Relative Clauses and Comparatives & Superlatives;
  `kFirstWaveTopics` with icons, titles (English, like every topic title),
  descriptions in 8 languages, hint cards, tile colours;
  `kFirstWaveTopicsEnabled = false`; `practiceTopics()` adds them only when
  on. The Daily Test keeps its five (`FallbackPool.problemWithSet` now
  checks `kTopics`). Proxy: `FIRST_WAVE_TOPICS` and
  `FIRST_WAVE_TOPICS_ENABLED = false` in `proxy/src/topics.ts`;
  `topicById` / `isKnownTopicId` know them only when the flag is on;
  `TOPICS` (the Daily Test's) is unchanged. Not deployed; no generation or
  measurement was run.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2426 passed**.
- New: `first_wave_topics_test` (flag off: Topic Practice shows the five
  and no first-wave card; flag on: ten, every first-wave topic with its
  title, description, hint card and colours, and a card on screen);
  `proxy/test/topics.test.ts` (flag off: unknown ids, the five unchanged;
  flag on: known). Proxy: `tsc --noEmit` clean; 8 test files touching
  topics, 312 tests, passed (local vitest, nothing sent anywhere).
- Updated: results, results footer, Topic Practice, length picker, exit
  dialog, button rule, question and hint-card tests.
- Simulator (gallery): R01, R02, V17, V18, V19, V20, V21, P08.

Decisions:
- **D7-1 No mastery strips** on R01 / V21 (D6-1). **Deferred (owner, fix
  round 1)**, as D6-1.
- **D7-2 P08 keeps the existing sentence** ("Come back tomorrow for more —
  your progress is saved"): the board's "Fresh sessions open tomorrow,
  right after your Daily Test" would tie sessions to the Daily Test, which
  is not a rule. A free user at the limit still goes to the paywall
  (existing flow), so "See Premium" is not on this sheet.
- **D7-3 "Back to topics" stays** the results' button label (the board
  says "Done"); same action.
- **D7-4 `topicByName` knows the first-wave ids** (they are real, switched-
  off topics); nothing stores them while the switch is off.
- **D7-5 V17 has no extra consent switch**: the board's two buttons are the
  consent (Agree / Not now); adding a toggle would change the 5.1.2(i) flow.

Not done / gaps:
- R02's ring and number keep the existing selection card's navy dial; the
  number does not roll.
- V18's skeleton bars are faint on the card colour.
- V19's "Next" slide-in and V21's mastery step are not animated.

## B8 — Paywall

Status: **done**.

Commits: `2981ab0` (paywall, PW05, strings, tests), `f303bad` (gallery).

What was built (`screens/premium_screen.dart`, one scrolling page, §1.7):
- V13: the companions, the headline with the user's name ("Turn today's
  mistake into progress, <name>."; the old line when no name is known),
  the weak spot line, the three benefit rows and "See plans" (scrolls to
  the plans). No price boxes on the first view; the pinned footer keeps the
  orange trial button, the full price / renewal line and Restore · Terms ·
  Privacy, as before.
- V13a: the plans (the existing vertical list, yearly preselected) after
  "See plans"; the pinned button's text follows the selected plan
  (existing).
- V13c: Free vs Premium is always on the page after the plans (the toggle
  is gone), then the trial timeline ("Today: everything in Premium
  unlocks. Nothing to pay." / "Day N: the trial ends and the plan starts.
  Cancel before then to pay nothing."), shown only with a trial counted in
  days or weeks. Once the plans have scrolled away, "<Plan> plan" sits
  above the pinned button.
- The comparison row counts the real topics ("Topic Practice, all N
  topics", `practiceTopics().length`), as the benefits row already did.
- V13b: the close button opens, once per app session, the companion dialog
  (sad): "Leaving already, <name>?", a line about the weak spots (no
  discount), the trial button (starts the purchase) and "Continue with
  free" (closes with `method: close_button`); light haptic. Without an
  offer, while purchasing or after a purchase, the close button closes as
  before.
- PW05 (`screens/premium_on_screen.dart`): after a purchase or a trial
  start, a navy celebration page — turning rays, the cheering companion,
  "Premium is on!", the three unlocked things (real counts) sliding in 120
  ms apart, "Your free trial ends on <date>." when a trial in days started,
  confetti once, success haptic; Continue closes the paywall with no
  dismissal event (as the footer's Continue). Pending and failed purchases
  keep the footer messages.

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2428 passed**.
- `premium_screen_test`: the comparison on the page after the plans and
  "See plans"; V13b (first close asks, sad companion, no discount, "Continue
  with free" logs `close_button`, a second paywall closes at once; the
  primary starts the purchase); success opens PW05 (end date with a trial,
  none without) and its Continue fires onDone and returns, with no
  `paywall_dismissed`. `l10n_layout_test` reads the table without a toggle.
- Simulator (gallery, the debug fixture offering): V13, V13a, V13c, V13b,
  PW05.

Decisions:
- **D8-1 The comparison is always on the page** (§1.7 "13 → 13a → 13c");
  the 1.2.0 "Compare Free & Premium" toggle is removed.
- **D8-2 V13b once per app session** (a static flag; a new launch asks
  again), and only when the trial button would work (an offer loaded).
- **D8-3 The trial timeline names no reminder**: the app sends no
  notifications (N01–N03 are out of this run), so it says only what is
  true — today unlocks, day N the plan starts unless cancelled.
- **D8-4 The headline keeps the 1.2.0 line when no name is stored**; with a
  name it is the board's personal line.

Not done / gaps:
- The plans do not enter from below on scroll, the table rows do not
  appear 40 ms apart, and the "See plans" arrow does not nudge.

## B9 — Profile

Status: **done**.

Commits: `f98eac1` (Profile, name sheet, medals layer, language, data, credits, the dialog fix, tests), `5c39c65` (gallery). Strings in `2981ab0`.

What was built:
- V23 (`widgets/profile_stage.dart` in `screens/settings_screen.dart`): the
  companion on its coloured stage (it waves when tapped) with "Change"
  (→ R06); the navy ribbon settling from 12 pt below with the name,
  "Climbing with <Hero>" and the pencil (→ PF04); three stat tiles (this
  month's points, step, weak spots saved). The medal shelf, its progress
  card and every settings row stay as they were.
- PF02 (`widgets/medals_layer.dart`): "See all" opens every medal over the
  blurred profile (blur 0 → 10, panel 0.92 → 1), by year, newest first, the
  running month grey, the Welcome badge last; X or a tap outside closes it.
- PF03: a medal in the layer opens the existing medal detail (the medal
  large, month, theme, outcome, steps and points).
- PF04: the pencil opens a sheet above the keyboard where the companion
  asks "What should I call you?"; Save (light haptic) stores the trimmed
  name (40 characters at most, as in onboarding) and shows "Name saved"
  with Undo, which puts the previous name back.
- R07 (`screens/language_picker_screen.dart`): each language its own card
  in its own name, the selected one navy with a gold check; selection
  haptic; the note that questions stay in English (existing) on top.
- R08 (`screens/data_screen.dart`): the reset confirmation is the companion
  dialog (sad, heavy haptic as it opens), "Keep my progress" primary and
  "Reset progress data" the quiet red action; texts unchanged.
- R09 (`screens/credits_screen.dart`): three companions greet on top
  (floating, the middle one waving); the attribution text is unchanged.
- The companion dialog now closes once: a second tap while the card closes
  no longer pops the page under it (found by the Data screen's double-tap
  test).

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2424 passed** (+ the
  medals layer test).
- Updated: `profile_layout_test` (V23, PF04 with Undo, PF02 and PF03, the
  40-character rule), `settings_screen_test`, `data_screen_test`,
  `data_screen_final_test`, `l10n_test`, `credits_screen_test`.
- Simulator (gallery): V23 (+ scrolled), PF02, PF03, PF04, R07, R08, R09.

Decisions:
- **D9-1 No "since <month year>"** on the ribbon: the app stores no date the
  profile was made. Shown: "Climbing with <Hero>". **Closed in fix round
  1:** "· since <month year>" from the first Daily Test on record.
- **D9-2 The medal shelf keeps the existing strip** (horizontal, every
  medal) rather than the thick 3-medal shelf image; "See all" adds the
  board's layer on top of it. **Closed in fix round 1:** the board's shelf
  is built.
- **D9-3 PF03 is the existing medal detail** (a dialog), opened from the
  layer; the Hero flight from shelf to sheet is not built.
- **D9-4 The language options lost keyboard focus traversal** (they are
  pressable cards, not InkWells); VoiceOver reads them as selected
  buttons as before. **Closed in fix round 1:** keyboard focus is back.

Not done / gaps:
- The ribbon's medal-settle and the numbers' count-up in PF03 are not
  animated; the layer opens with a fade and scale, not a Hero flight.

## B10 — System and themes

Status: **done**.

Commits: `5dabea0` (R11 on Home, the sweep and its fixes), `2aa88bd` (gallery).

What was done:
- R11 everywhere a load can fail: the Daily Test (B4), getting ready (B3)
  and Review (B6) already use `ErrorState`; Home's month progress error now
  does too (sad companion, "Try again" with dots, the same retry).
  Generation and scoring failures keep the one snackbar (SY02).
- SY02 everywhere: every message in `lib/` goes through `AppMessenger`
  (no direct `showSnackBar` left); "Name saved" carries Undo.
- SY03 dark theme: every new component takes its colours from `AppColors`
  (light and dark tokens); dark captures of Home (SY03), Review, Profile,
  the month recap, a question and the first climb.
- Arabic (RTL), the largest text size and Reduce Motion: a sweep test
  (`test/b10_system_pass_test.dart`) renders every new screen and component
  — the Daily Test card's three states, the ticket's states, the score
  capsule, the rest scene, the topic showcase and practice card, Review's
  card and empty state, practice preparing and reviewing, the profile
  stage, the error state, the first climb, the month recap and new
  mountain, Premium on — at 320 pt in dark, in Arabic, at Large text with a
  1.3 system scale and with Reduce Motion; nothing overflows or throws.
  Arrows flip under RTL in every new button.
- Found and fixed by the sweep: a ticket built already tearing read the
  Reduce Motion setting before it could (now in `didChangeDependencies`);
  the practice card's sessions row overflowed at 320 pt (the label wraps);
  Premium on overflowed a 640 pt screen (its content scrolls, the button
  stays).

Verified:
- `flutter analyze`: no issues. Full `flutter test`: **2477 passed** (52 of
  them the sweep).
- Simulator (gallery, `:dark`): SY03-DarkHome, V16, V23, R04, V07, V12.

Not done / gaps:
- Arabic and the largest text are checked by tests, not by simulator
  captures (the gallery runs in English at the default size).

## B11 — Final sweep and docs

Status: **done**.

Commits: `a4228b3` (formatting), `cd3c33d` (docs and comparison), and the commit that records these hashes.

What was done:
- Every in-scope board captured again on the iPhone 18 Pro simulator (iOS
  27.2, light, English; SY03 in dark) with `tool/ui_polish/capture.sh`,
  into `build/ui-polish-captures/` (not committed), and compared with
  `handoff/screens/<ID>.webp` and the board HTML. The table below is the
  result; "gap" rows name what differs and why.
- Docs: `docs/build-log.md` (dated entry), `docs/roadmap.md` (status of
  "UI polish + 4th tab"), `product.yaml` (one `recent` entry, trimmed to
  five, `updated_at`), this file's final summary.
- Final checks after the last code change: `flutter analyze` — no issues found; `flutter test` — 2477 passed, 0 failed (run after the last code change, the formatting of `practice_launch.dart`).

### Board comparison

All 65 in-scope boards (SPEC §2: every board but W01, N01, N02, N03). After fix round 1: **65 match** (some name small motion gaps in their note). Fix round 1 recaptured V05, V07, V09, Q04, V15, R04, R12, R02, V13, V13a, V13c, V23, PF02, PF03 and R07 and closed B11's three gaps (V09, R02, V23).

| Board | Capture(s) in `build/ui-polish-captures/` | Match / gap | Note |
|---|---|---|---|
| V00-CompanionSystem | V00-CompanionSystem-500.png, V00-CompanionSystem.png | match | System sheet: nine heroes, moods, props (gallery board). |
| V00-MotionSystem | V00-MotionSystem.png | match | Motion tokens, buttons, colours. |
| X01-ExpressionKit | X01-ExpressionKit.png | match | Four heroes × five moods; sad/sleep filters per SPEC X01 (D1-2). |
| X03-HeroSet | X03-HeroSet-400.png, X03-HeroSet.png | match | 9 heroes × 6 poses. |
| X04-Ticket | X04-Ticket-420.png, X04-Ticket.png | match | Free, tearing, used; compact and full. |
| X05-DailyCard | X05-DailyCard-560.png, X05-DailyCard.png | match | One 256 pt skeleton for loading / waiting / done. |
| V01-Splash | V01-Splash-mid.png, V01-Splash.png | match | Logo build-up mid frame and end. |
| V02-Welcome | V02-Welcome.png | match | Demo card, companions, Get started. |
| V03-Meet | V03-Meet.png | match | B1 turntable, Fox in front. |
| V03b-LuckyWheel | V03b-LuckyWheel-ready.png, V03b-LuckyWheel.png | match | Ready and landed frames; never the current buddy. |
| V04-Name | V04-Name.png | match | Typed name, the companion's reaction. |
| V05-Goal | V05-Goal.png | match | Three goal cards, the selected one navy. The B3 capture: the screen is unchanged since `e6807b1`, and the B11 driver hung twice on this board's tap (tooling, see Blocked). |
| V05b-GettingReady | V05b-GettingReady-100.png, V05b-GettingReady.png | match | Stops at real work (⅓, ⅔, 1). |
| V06-MountainIntro | V06-MountainIntro.png | match | Whole mountain, flag, the companion at the start. |
| R06-AvatarChange | R06-AvatarChange.png | match | Turntable from Profile, "Save <Hero>". |
| R06s-B1-Turntable | R06s-B1-Turntable-1-resting.png, R06s-B1-Turntable-2-turning.png, R06s-B1-Turntable-3-panda.png | match | Storyboard frames of the turntable. |
| R06s-D-Wheel | R06s-D-Wheel-1-ready.png, R06s-D-Wheel-2-spinning.png, R06s-D-Wheel-3-landed.png | match | Storyboard frames of the wheel: ready, spinning, landed. |
| V07-Question | V07-Question.png | match | Check footer, points chip; gap: the hint handle's nudge is not added (B4). |
| V08-Correct | V08-Correct.png | match | Green sheet, +2; gap: the star flies on a fixed path (B4). |
| V09-Wrong | V09-Wrong-book.png, V09-Wrong.png | match | Orange sheet, the key, +1; the book flies to the Review tab's place (fix round 1; the first capture is mid-flight). |
| Q04-MultiBlank | Q04-MultiBlank-typed.png, Q04-MultiBlank.png | match | Per-blank colours after Check; the focused blank breathes (fix round 1); gap: the "—" fill keeps the 1.4.0 look. |
| Q05-ErrorCorrection | Q05-ErrorCorrection.png | match | Last question reads Finish. |
| V10-Results | V10-Results.png | match | Stepwise ring, strip, tiles, answer rows. |
| V11-Badge | V11-Badge.png | match | Navy page, rays, the Welcome badge over the companion. |
| R05-Medal | R05-Medal.png | match | Tier medal, next threshold from MonthlyMedalRules. |
| R10-Leave | R10-Leave.png | match | Companion dialog over the question, Keep going / Leave. |
| R11-Offline | R11-Offline.png | match | Sad companion, calm line, Try again with dots. |
| SY02-Snackbar | SY02-Snackbar.png | match | One dark capsule with icon and Undo. |
| V15-HomeNextDay | V15-HomeNextDay.png, V15-HomeNextDay-360.png | match | Orange card, bubble "Step N is one test away!"; the next step's gold ring pulses (fix round 1, scrolled capture). |
| V14-Home | V14-Home-520.png, V14-Home.png | match | Navy card, capsule +N, ticket, topic showcase (scrolled capture too). |
| H03-HomeLoading | H03-HomeLoading.png | match | Card loading state and the mountain skeleton; the inner skeleton is faint. |
| H04-HomePremium | H04-HomePremium-520.png, H04-HomePremium.png | match | Practice card with sessions n/5, unlocked tiles. |
| V12-Climb | V12-Climb.png | match | End frame: step chip, bubble, Continue (camera covers the screen). |
| V12b-ClimbStoryboard | V12b-ClimbStoryboard-1-wide.png, V12b-ClimbStoryboard-2-close.png, V12b-ClimbStoryboard-3-wide.png | match | Three key frames: wide, close (2.2×), wide. |
| V24-DayComplete | V24-DayComplete.png | match | Camp, campfire, sleeping companion, countdown; no reminder switch (OUT). |
| R04-MonthCard | R04-MonthCard.png | match | Recap with medal swap, dots, stats, stepwise bar; gap: lines glow by scale only. |
| R04b-NewMountain | R04b-NewMountain.png | match | Whole new mountain, flag, companion at the start, thresholds. |
| V16-Review | V16-Review.png | match | Ticket, weak spot card with the mistake inline, Practice with my ticket; no mastery strip (D6-1). |
| V16b-TicketTear | V16b-TicketTear-2-practice-starts.png, V16b-TicketTear.png | match | Mid-tear: navy body, stub gone, USED stamp; then the AI permission. |
| V22-ReviewUsed | V22-ReviewUsed.png | match | Used ticket with the 20:41 slot, Premium card; no "practiced today" chip or mastery (D6-1, D6-2). |
| RV05-ReviewEmpty | RV05-ReviewEmpty.png | match | Waiting ticket, cheering companion, navy button. |
| RV06-ReviewSort | RV06-ReviewSort.png | match | Sheet with two options, the selected one navy. |
| R03-WeakSpot | R03-WeakSpot.png | match | Rule bubble, the mistake inline, today's ticket; no mastery strip (D6-1). |
| R12-ReviewPremium | R12-ReviewPremium.png | match | Premium chip, Suggested focus with its glint (fix round 1), cards; mastery strips deferred (D6-1). |
| R01-Topics | R01-Topics.png | match | Picked for you, coloured topic cards; no mastery strips (D7-1). |
| R02-Length | R02-Length.png | gap | Orange knob and Start; the ring keeps the existing navy dial, the number does not roll. |
| V17-Consent | V17-Consent.png | match | Same text in icon cards, navy Agree, Not now. |
| V18-Preparing | V18-Preparing.png | match | Thinking companion, skeletons, Did you know? card; skeleton bars faint. |
| V19-PracticeQuestion | V19-PracticeQuestion.png | match | Line: AI reviews all your answers when you finish. |
| V20-Reviewing | V20-Reviewing.png | match | Inspecting companion, lens over the answers, checklist, bar. |
| V21-PracticeResults | V21-PracticeResults.png | match | N/M correct, feedback cards, Premium card; no mastery step (D7-1). |
| P08-DailyLimit | P08-DailyLimit.png | match | Sleeping companion, full counter; the existing accurate sentence (D7-2). |
| V13-Paywall | V13-Paywall.png | match | No price boxes on first view; pinned CTA, price line and links; See plans nudges (fix round 1). |
| V13a-PaywallPlans | V13a-PaywallPlans.png | match | Plans after See plans, yearly preselected; they rise in 60 ms apart (fix round 1). |
| V13c-PaywallCompare | V13c-PaywallCompare.png | match | Table (rows fade in 40 ms apart, fix round 1), trial timeline, plan label above the CTA. |
| V13b-ExitReminder | V13b-ExitReminder.png | match | Sad companion, no discount, trial / Continue with free. |
| PW05-PremiumOn | PW05-PremiumOn.png | match | Rays, cheering companion, three unlocked things, trial end date. |
| V23-Profile | V23-Profile-420.png, V23-Profile.png | gap | Stage, ribbon, stat tiles; the shelf keeps the existing strip, no "since" line (D9-1, D9-2). |
| PF02-Medals | PF02-Medals.png | match | Every medal over the blurred profile, newest first by year, "N earned"; shelf medals fly in (fix round 1). |
| PF03-MedalDetail | PF03-MedalDetail.png | match | The existing medal detail from the layer (D9-3); the medal flies in, steps and points count up (fix round 1). |
| PF04-EditName | PF04-EditName.png | match | Sheet with the companion's question, Save. |
| R07-Language | R07-Language.png | match | Language cards, the selected one navy with a check. |
| R08-Data | R08-Data.png | match | Three cards; the reset asks with the companion dialog. |
| R09-Credits | R09-Credits.png | match | Three companions on top, one card, two links. |
| SY03-DarkHome | SY03-DarkHome-dark.png | match | Dark Home from the theme tokens (captured with :dark). |

