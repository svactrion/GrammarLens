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
