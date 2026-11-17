# UI polish — progress log (branch `ui-polish`)

Running log of the unattended implementation run of `TASK.md` / `SPEC.md`.
One section per batch: status, commits, what was verified and how,
decisions, open items. The final summary goes at the top when B11 ends.

## Final summary

*(Written at the end of B11.)*

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

## B0 — Plan

Status: **done** (commits below).

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
| V05-Goal | `screens/onboarding_screen.dart` (goal step) |
| V05b-GettingReady | new `screens/getting_ready_screen.dart` + new `services/getting_ready.dart` (stop logic), `screens/first_launch_flow.dart` |
| V06-MountainIntro | new `screens/mountain_intro_screen.dart`, `screens/first_launch_flow.dart`, `widgets/monthly_climb/*` (flag v2) |
| V07-Question | `screens/daily_test_screen.dart`, `widgets/question_view.dart` |
| V08-Correct / V09-Wrong | new `widgets/answer_feedback_sheet.dart`, new `services/daily_test_grading.dart` (on-device per-question grading over `utils/answer_matching.dart`), `screens/daily_test_screen.dart` |
| Q04-MultiBlank / Q05-ErrorCorrection | `widgets/question_view.dart`, `screens/daily_test_screen.dart`, `utils/answer_diff.dart` (reuse) |
| R10-Leave | new `widgets/companion_dialog.dart`; `screens/daily_test_screen.dart`, `screens/practice_screen.dart` (exit dialogs) |
| V10-Results | `screens/daily_test_result_screen.dart` |
| V11-Badge | `screens/daily_test_result_screen.dart` (day-0 Welcome badge) |
| R05-Medal | `widgets/medal_celebration.dart` |
| V12-Climb / V12b | `widgets/monthly_climb/climb_zoom.dart`, `climb_camera.dart`, `monthly_mountain.dart`; `screens/home_screen.dart` |
| V14-Home / V15 / H03 / H04 | `screens/home_screen.dart`, `widgets/daily_test_card.dart`, new `widgets/score_capsule.dart`, `widgets/ticket.dart`, `widgets/monthly_climb/climb_card.dart` |
| V24-DayComplete | new `widgets/rest_scene.dart`, `screens/home_screen.dart` (§1.8 rule) |
| R04-MonthCard | `widgets/month_card_sheet.dart` |
| R04b-NewMountain | `widgets/month_card_sheet.dart` / new `widgets/new_mountain_reveal.dart` |
| V16 / V16b / V22 / RV05 / RV06 / R12 | `screens/review_screen.dart`, `widgets/review_top_card.dart`, `widgets/weak_spot_card.dart`, `widgets/ticket.dart`, `widgets/app_sheet.dart` (new) |
| R03-WeakSpot | `screens/weak_spot_detail_screen.dart` |
| R01-Topics | `screens/topic_practice_screen.dart` |
| R02-Length | `screens/practice_length_picker.dart` |
| V17-Consent | `screens/ai_consent_screen.dart` |
| V18-Preparing | `screens/practice_launch.dart`, new `widgets/preparing_view.dart` |
| V19-PracticeQuestion | `screens/practice_screen.dart`, `widgets/question_view.dart` |
| V20-Reviewing | `screens/practice_screen.dart` (submit wait), new `widgets/reviewing_view.dart` |
| V21-PracticeResults | `screens/results_screen.dart` |
| P08-DailyLimit | `screens/practice_launch.dart` (`_showDailyLimitReachedDialog` → sheet) |
| V13 / V13a / V13c / V13b / PW05 | `screens/premium_screen.dart`, new `widgets/paywall_exit_dialog.dart`, new `screens/premium_on_screen.dart` |
| V23-Profile | `screens/settings_screen.dart` |
| PF02-Medals / PF03-MedalDetail | `widgets/monthly_medal_collection.dart` |
| PF04-EditName | `screens/settings_screen.dart` (name sheet) |
| R06-AvatarChange (+ R06s storyboards) | `screens/avatar_picker_screen.dart` (turntable + wheel) |
| R07-Language | `screens/language_picker_screen.dart` |
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
  with a stored count later.
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
