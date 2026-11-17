# UI polish + widgets — integration (unattended)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, and in this folder `SPEC.md`,
`TASK.md`, `PROGRESS.md`, `FIX2.md`; then, from the `widgets-notifications`
branch, `TASK-widgets.md` and `PROGRESS-widgets.md`
(`git show origin/widgets-notifications:<path>` until the merge brings them in).

## Goal

Bring the two finished branches together on a new branch, connect the parts
that each branch could not see, close three known gaps, and prepare one
combined build and one checklist for the owner's device test.

- `ui-polish` (fix round 2 done, HEAD `7f38e21` or later): the whole redesign,
  including the free users' rest scene V24f.
- `widgets-notifications` (W1–W6 done, HEAD `37a94bd` or later): widgets,
  reminders, N01/N03, the V24 "Remind me tomorrow" row, DB schema 27. It has
  merged only the docs commit `ca3a847` of `ui-polish`, not fix round 2's code.

## Rules

- The owner is not watching: never stop to ask; decide with `TASK.md` §1's
  decision rule and record each decision in `PROGRESS.md` ("Integration"
  section, I-1, I-2, …).
- Everything in `TASK.md` §3 still applies (no new packages, no new analytics
  events, no deploy, no paid API calls, no version bump, no change to
  `product.yaml` `status`/`versions`/`legal`), plus: no merge into `main`, no
  rebase, no `reset --hard`, no force push, no branch or worktree deletion,
  no Flutter or Xcode upgrade, no team/signing/provisioning settings.
- Simulators: the widgets session has finished, so any existing simulator may
  be used. Do not create new simulators (disk); use widget tests at a given
  size where a device of that size is missing.
- No access to the owner's iPhone. Anything that needs the phone goes into
  `DEVICE-CHECKS.md` (step 6).

## 0. Disk

Check `df -h ~` first. The owner authorises deleting only these regenerable
things: `flutter clean` in `~/GrammarLens` and in `~/GrammarLens-widgets`;
`build/` folders inside those two; Xcode DerivedData folders whose
`info.plist` `WorkspacePath` points into either of those two folders (check
each before deleting). Nothing else. Record free space before and after.

## 1. Branch

In `~/GrammarLens`: `git switch ui-polish`, `git pull --ff-only`,
`git fetch origin`, then `git switch -c ui-polish-widgets`. This file is in
the working tree, untracked: commit it first ("docs: integration task") and
push with `-u`.

## 2. Merge

`git merge --no-ff origin/widgets-notifications`. Resolve every conflict by
keeping both sides' intent, never by dropping one side's work. Expected
areas and the rule for each:
- **ARB files:** the union of keys; for a key both sides changed, keep the
  later design (SPEC v10) and record it. Run the l10n tests.
- **Home / rest scene:** V24 (Premium) keeps its reminder row from the widgets
  branch; V24f comes from `ui-polish` and gets the row in step 3a.
- **`app.dart`, storage, sync wiring:** keep the widgets branch's sync and
  reminder jobs and `ui-polish`'s changes together.
- **Database:** the widgets branch moved the schema to 27. Find the schema
  version that shipped in 1.4.0 (on `main`) and make sure the merged app
  migrates from it in one step, with a test that opens a 1.4.0-shaped
  database and checks the data survives (profile, avatar → Fox migration
  for retired avatars, goal, completions, weak spots, medals, reminder
  defaults).
- **Docs** (`PROGRESS*.md`, `build-log.md`, `roadmap.md`, `product.yaml`):
  keep both sides' entries; `recent` stays at five items.
After the merge commit: `flutter analyze`, `flutter test`, and the Swift tests
must pass before anything else changes.

## 3. Integration work

**3a. V24f gets the reminder row.** Per the V24f board, "Remind me tomorrow"
sits under the Premium card. Reuse the widgets branch's `RestReminderRow`;
the first-appearance N01 trigger must fire on whichever rest scene (V24 or
V24f) appears first. The "Wake <Hero> up" button must stay visible on first
view at 390 × 844 and larger; if both do not fit on a smaller screen, the
button wins and the row scrolls into view.

**3b. The pawn on 6.1"–6.3" screens.** After fix round 2, on a 6.3" screen
on day 0 the pawn's feet touch the floating nav bar's top edge. Most iPhones
are this size. Make the pawn and its next step fully visible above the nav
bar on first view, with at least 16 pt clearance at 390 × 844, 393 × 852 and
402 × 874, and not covered at 375 × 667. The choice (card camera framing,
card height, Home spacing) is yours; record why. Tests at those sizes for
day 0, a mid-month day and the last step.

**3c. Nunito Sans in the widgets.** The widgets use the system rounded font
because `TASK-widgets.md` forbade app assets in the extension; that rule was
meant for images. Bundle the app's Nunito Sans font file in the widget
extension (with its OFL licence file), register it, and use it for every
widget text. Keep the system font as the fallback for scripts Nunito does
not cover (Japanese, Korean, Arabic). Regenerate the snapshot images and
check that nothing truncates (German, Arabic, two-digit steps).

**3d. `TASK-widgets.md` in English.** It was saved in Turkish; translate it
in place, content unchanged (repo docs are English).

**3e. Release build check.** Run `flutter build ios --release --no-codesign`
(device architecture, with the widget extension). If it fails, find the cause
and record the exact error and the owner's options (for example the known
Flutter 3.44.6 / Xcode 27.2 `lipo` problem) in `PROGRESS.md`; do not upgrade
anything.

## 4. Checks

- `flutter analyze` with no issues; `flutter test` all passing; Swift tests
  (`xcodebuild test`, RunnerTests including the widget snapshots) passing;
  a simulator build of Runner + extension. All after the last code change.
- Captures on the simulator, into `build/integration-captures/`: V24f with the
  reminder row (free user), V24 (Premium), V15 and V14 (first view), the
  widgets' snapshot sheet with Nunito, N01 over the rest scene.
- A smoke walk through the real app on a fresh install: Welcome → buddy →
  name → goal → getting ready → mountain → Day 0 test → results → badge →
  first climb → paywall → Home. Then, with a seeded learner whose day is
  used up, V24f → "Wake <Hero> up" → V13r (no purchase). Record what you saw.

## 5. Docs

- `PROGRESS.md`: an "Integration" section at the top (merge, conflicts and
  how each was resolved, decisions I-n, checks, what is not verified) and an
  updated summary. `PROGRESS-widgets.md` stays as the widgets record.
- `docs/build-log.md`: one dated entry. `docs/roadmap.md`: the status (both
  built and integrated on `ui-polish-widgets`, not on `main`, not checked on
  a device). `product.yaml`: the planned lines for the UI polish and for the
  widget/reminder work say they are integrated on `ui-polish-widgets`, not
  shipped; `updated_at`.

## 6. `DEVICE-CHECKS.md` (new, in this folder)

One ordered checklist for the owner's phone, merged from fix round 2's
"Owner device checks" and `PROGRESS-widgets.md`'s "Owner steps", with each
item's expected result and the board ID. Order:
1. **Before the first device build:** the Xcode steps for the
   `GrammarLensWidgets` target (team, App Group
   `group.com.ahmettayfur.grammarlens` for both App IDs), written click by
   click for someone who does not use Xcode daily, and the exact terminal
   command to run the build on his iPhone 14 Plus in release mode
   (`config/prod.json`).
2. **Install over the current 1.4.0 app first** (no delete): data survives,
   avatar, goal, Home (greeting on one line, pawn visible), companions move
   (and whether Reduce Motion is on), Daily Test per-question feedback and
   haptics, the ticket, Review, practice, the Profile ribbon, edit name with
   the real keyboard, all medals, the paywall (trio, table, exit pop-up), the
   free rest scene → Premium flow with a sandbox trial, the widgets (add all
   three; both states; taps), reminders (permission, one arriving, the
   companion picture, tapping it).
3. **Then delete and reinstall** for the first-run flow: splash, Welcome,
   turntable and "Try my luck", name, four goals, getting ready (≥ 4 s),
   mountain intro (flag on the summit), Day 0, results, badge, first climb,
   paywall.
4. Performance in release (turntable drag, wheel spin, scrolling Home).

## Done means

1. Steps 0–6 are each closed in `PROGRESS.md` "Integration" (or marked "not
   done" with the reason).
2. After the last code change: `flutter analyze` no issues, `flutter test`
   all pass, Swift tests pass, simulator build succeeds; the release build
   check (3e) is done and its result recorded.
3. `DEVICE-CHECKS.md` exists and is complete.
4. `ui-polish-widgets` is pushed and `git status` is clean. `ui-polish`,
   `widgets-notifications` and `main` are untouched.

Code, comments, commit messages and all docs stay in English.
