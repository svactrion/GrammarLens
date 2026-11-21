# UI polish — implementation task (unattended run)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md` and `docs/build-log.md` for context, then `CLAUDE.md`,
`docs/AGENTS.md`, and in this folder `SPEC.md` (the design, final) and
`ASSETS.md`.

Goal: implement every in-scope screen and behaviour of `SPEC.md` on a new
branch, completely, in one run.

## 1. How this run works

- **The owner is away. Never stop to ask a question and never wait for
  approval.** When something is unclear, apply the decision rule below, write
  the decision into `PROGRESS.md` ("Decisions" section: what, options, choice,
  why) and continue.
- Decision rule, in order: (1) `SPEC.md` §1 overrides; (2) the screen's section
  in `SPEC.md`; (3) the board HTML; (4) the app's current behaviour and
  business rules (unchanged unless `SPEC.md` says so); (5) the smallest choice
  that is easy to change later.
- If something cannot be done (a tool fails, the simulator will not boot, an
  asset is unusable), record it in `PROGRESS.md` under "Blocked / not
  verified" with the exact error, do the rest, and keep going. Never mark
  unfinished or unverified work as done ("Fake it yok": docs never show work
  that was not done).
- Keep a running log in `docs/design/ui-polish/handoff/PROGRESS.md` (create it
  in B0): one section per batch with status, commits, what was verified and
  how, decisions, open items. Update it at the end of every batch. If the
  session restarts or the context is compacted, re-read this file, `SPEC.md`
  and `PROGRESS.md` and continue from the first unfinished batch.

## 2. Git

1. Start from an up-to-date `main`: `git switch main`, `git pull --ff-only`,
   then `git switch -c ui-polish`. The uncommitted files that are already in
   the working tree (this handoff folder, `docs/roadmap.md`, `product.yaml`)
   come along; commit them first as one commit ("docs: UI polish design
   handoff"). If `git switch main` refuses because of those uncommitted
   files, `git stash push` exactly those paths, switch, pull, create the
   branch, then `git stash pop`.
2. Small, single-purpose commits; every commit compiles. `git add` only the
   exact files you list. `dart format` only on changed files, after
   `flutter pub get`.
3. Push the branch after every batch: `git push -u origin ui-polish`.
4. Never: merge into `main`, rebase, `reset --hard`, force push, delete a
   branch, or any command that discards work.

## 3. Hard limits

- No new packages (Flutter SDK only, plus what `pubspec.yaml` already has).
  No Rive. If something seems to need a package, build a simpler version in
  Flutter and record it.
- No new analytics events, no new user properties, no new data collected,
  no change to `legal` in `product.yaml`.
- No proxy deploy (`wrangler deploy` or any other), no paid API calls, no
  generation or measurement scripts, no App Store Connect / RevenueCat changes.
- No version bump in `pubspec.yaml`; do not touch `status` or `versions.*` in
  `product.yaml`.
- No changes to signing, entitlements, bundle IDs, capabilities or Xcode
  targets (the widget and notifications are a separate task).
- Business rules stay as they are unless `SPEC.md` §1 changes them: free tier
  quota (1 Daily Test + 1 practice ticket per day), Premium limits, scoring
  and `MonthlyMedalRules`, the shared Daily Test set source, AI consent, the
  practice batched AI evaluation.
- Out of scope: `SPEC.md` §2 (W01, N01, N02, N03, the reminder switch on V24).

## 4. Implementation rules

- Assets: move `handoff/assets/*` into `assets/` (use `git mv`; choose a
  folder layout, e.g. `assets/companions/` and `assets/ui/`), register the
  folder(s) in `pubspec.yaml`, keep the file names.
- Theme: colours, motion and haptics as tokens (`SPEC.md` §3.1–§3.4); no hex
  literals or ad-hoc durations in screens. Dark mode must work for every new
  component through the tokens.
- Components first (`SPEC.md` §3.5, §3.6), then screens built from them.
  Prefer reworking the existing screens and widgets over parallel copies;
  remove code that the new design makes dead.
- Localization: every new user-facing string in all 8 ARB files, translated
  by you, following `SPEC.md` §3.7. Check Arabic (RTL) on the main flows.
- Reduce Motion and the system haptics setting are respected everywhere.
- Accessibility basics as the app already does them (semantic labels on
  images and custom controls, 44 pt minimum touch targets). No VoiceOver test
  pass is required.
- Tests: add unit/widget tests for the new logic and components, at least:
  DailyTestCard keeps exactly the same size in all three states (also at the
  largest text scale); Ticket renders its three states; the wheel never lands
  on the current buddy or the previous result; retired avatars migrate to Fox
  and the picker lists exactly the 9 heroes in order; the getting-ready bar
  never passes a stop before its task completes and respects the 1.8 s minimum
  and 8 s error; per-question grading uses the existing matching rules and the
  display points equal the completion award; first-wave topics are hidden with
  the flag off and present with it on. Existing tests keep passing (update
  them only where the design intentionally changed the behaviour, and say so
  in the commit).

## 5. Batches

Each batch ends with: `flutter analyze` → no issues; `flutter test` → all
pass; the batch's screens run in the iOS simulator and are captured (see §6)
and compared with `handoff/screens/`; differences fixed or recorded;
`PROGRESS.md` updated; commits pushed.

- **B0 — Plan.** Read everything; write `PROGRESS.md` with: a board → code
  table (every in-scope board ID → the files to change or create; hints:
  `widgets/launch_splash.dart`, `screens/welcome_screen.dart`,
  `screens/onboarding_screen.dart`, `screens/first_launch_flow.dart`,
  `widgets/avatar_carousel.dart`, `screens/avatar_picker_screen.dart`,
  `screens/home_screen.dart`, `widgets/monthly_climb/*`,
  `widgets/month_card_sheet.dart`, `screens/daily_test_screen.dart`,
  `widgets/question_view.dart`, `screens/daily_test_result_screen.dart`,
  `widgets/medal_celebration.dart`, `screens/review_screen.dart`,
  `screens/weak_spot_detail_screen.dart`, `screens/topic_practice_screen.dart`,
  `screens/practice_length_picker.dart`, `screens/practice_screen.dart`,
  `screens/results_screen.dart`, `screens/ai_consent_screen.dart`,
  `screens/premium_screen.dart`, `screens/settings_screen.dart`,
  `widgets/monthly_medal_collection.dart`, `screens/language_picker_screen.dart`,
  `screens/data_screen.dart`, `screens/credits_screen.dart`,
  `utils/app_messenger.dart` — verify each, they are guesses), the component
  list, the risks, and how you will reach each screen in the simulator.
  Commit the handoff + this plan.
- **B1 — Foundations.** Assets in place; colour, motion and haptic tokens;
  `PressableButton`; `CompanionView` with poses, moods, props (`SPEC.md` §3.5);
  the 9-hero set, picker order and the retired → Fox migration (§1.2).
- **B2 — Shared components.** DailyTestCard, Ticket, ScoreCapsule, StepBar,
  sheet, CompanionDialog, Snackbar, ErrorState, confetti/rays (`SPEC.md`
  §3.6, X04, X05, R10, SY02, R11).
- **B3 — Launch and onboarding.** V01, V02, V03 + V03b (wheel), V04, V05,
  V05b, V06, and R06 (Profile reuses V03/V03b).
- **B4 — Daily Test and rewards.** V07, V08, V09, Q04, Q05, R10, V10, V11, R05
  (per-question feedback, §1.5).
- **B5 — Home and mountain.** V15, V14, H03, H04, V12, V24 (rest scene rule
  §1.8, no reminder switch), R04, R04b.
- **B6 — Review.** V16, V16b, V22, RV05, RV06, R03, R12.
- **B7 — Practice.** R01, R02, V17, V18, V19, V20, V21, P08, and the hidden
  first-wave topics in app + proxy code (§1.11).
- **B8 — Paywall.** V13, V13a, V13c, V13b, PW05 (one scrolling page, §1.7).
- **B9 — Profile.** V23, PF02, PF03, PF04, R07, R08, R09.
- **B10 — System and themes.** R11 and SY02 everywhere they apply; dark theme
  pass on every new screen (SY03); Arabic RTL pass; largest text size pass;
  Reduce Motion pass.
- **B11 — Final sweep and docs.** Capture every in-scope board again and fill
  the comparison table in `PROGRESS.md` (board ID, capture, match / gap, note);
  fix what can be fixed; full `flutter analyze` and `flutter test`; update
  docs (§7); push; `git status` clean.

## 6. Simulator checks

- Run on an iOS simulator (iPhone, 6.1"-class, light theme, English). Reach
  each screen through the real flow where practical, otherwise through the
  existing debug tools (`screens/debug_panel_screen.dart`, `preview/`,
  `tool/screenshots/` flutter_driver setup); debug-only entry points are fine
  if they are compiled out of release builds.
- Capture with `xcrun simctl io booted screenshot <file>` into
  `build/ui-polish-captures/` (not committed). Look at each capture next to
  `handoff/screens/<ID>.webp` and judge layout, sizes, colours, copy and
  states; animations are checked by watching them or by capturing mid-way.
- Nothing is checked on a physical device in this run; write "not checked on
  a device" wherever that matters.

## 7. Docs at the end

- `docs/build-log.md`: one dated entry for the run (what was built, decisions,
  what was verified and how, what is not verified, open items).
- `docs/roadmap.md`: the "UI polish + 4th tab" section gets the status (built
  on branch `ui-polish`, not merged, not shipped, not checked on a device) and
  links to `PROGRESS.md`.
- `product.yaml` (per `CLAUDE.md`): add to the top of `recent` one entry
  (version empty, today's date) saying the UI polish was built on branch
  `ui-polish`, not merged and not shipped; trim `recent` to 5; set
  `updated_at`. Nothing else changes there.
- `PROGRESS.md` final summary at the top: done / not done / not verified /
  decisions the owner should review.

## 8. Done means

1. B0–B11 are marked done in `PROGRESS.md`, each with its commit hashes.
2. The last `flutter analyze` reports no issues and the last `flutter test`
   passes (both run after the final code change).
3. Every in-scope board has a simulator capture and a comparison row.
4. Docs updated as in §7.
5. Branch `ui-polish` pushed to origin; `git status` clean.

Code, comments, commit messages and all docs stay in English.
