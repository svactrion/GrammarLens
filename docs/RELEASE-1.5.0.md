# 1.5.0 release preparation, part 1 — merge, version, checks, release steps, iPad tour (unattended)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, `docs/1.4.0-release-steps.md` (the
model for step 5), `docs/design/ui-polish/handoff/DEVICE-CHECKS.md` (its top
sections), `docs/design/ui-polish/handoff/PROGRESS-widgets.md` ("Owner
steps") and this file.

## Goal

1.5.0 is the UI polish (SPEC v14), the home-screen widgets, the daily
reminders and five new practice topics. All of it is on branch
`ui-polish-widgets`; `main` still holds 1.4.0 plus two small fixes of early
November (the lira symbol, the storage reset gate). The Worker for 1.5.0 is
deployed (owner, 2026-11-19).

On 2026-11-21 the owner reported the result of his device checks of 19 to 21
November and gave his word for the merge and the version bump:

- the day's step plays before the rest scene (fix round 6, item 1): seen;
- the Daily Test card's companion stays as specified (fix round 6, item 2):
  his decision, no change;
- Review's inline mistakes on the new topics (item 3): seen on 2026-11-19;
- the reminders arrive and the widgets work: seen;
- in his words, everything else works flawlessly. He did not report the
  remaining items one by one.

This run merges the branch into `main`, sets the version, runs every check
on `main`, writes the release steps for the owner, and walks the app on an
iPad simulator, because the store page has iPad screenshots and no iPad
check of the new design is on record. It does not build for the store,
upload, submit or deploy.

## Rules

- Unattended: no questions. Where a choice is needed, decide and record it
  in `docs/1.5.0-release-progress.md` as R-1, R-2, … (question · options ·
  choice · why). Nothing unverified is written as done.
- Git: the merge into `main` in step 2 is allowed by the owner's word of
  2026-11-21, once, as a normal merge. No rebase, no `reset --hard`, no
  force push, no branch or worktree deletion. Small commits, pushed as you
  go.
- No deploy, no change under `proxy/`, no request to the practice or scoring
  endpoints, no paid API call. No App Store Connect call of any kind, no
  upload, no TestFlight, no `flutter build ipa`.
- No signing change in the Xcode project and no Flutter or Xcode upgrade;
  what the owner must do for signing is written down, not done.
- Existing simulators only; no access to the owner's iPhone.
- Never run `dart format` over all of `lib/`; format only files you changed.
- Texts the owner typed or generated on his phone are never asked for or
  committed.

## 0. Start

1. `df -h ~`; aim to finish with at least 15 GB free (the allowed deletions
   of `FIX3.md` §0).
2. `git fetch`, `git switch ui-polish-widgets`, `git pull --ff-only`; the
   working tree must be clean apart from this file. Commit this file first:
   "docs: 1.5.0 release preparation task"; push.

## 1. Record the owner's device result (on the branch, before the merge)

In `DEVICE-CHECKS.md`, mark what the Goal section lists as seen by the
owner, with the date. Also from his check of 2026-11-19: T-1 seen; T-2 seen
for Conditionals, Passive Voice, Prepositions and Relative Clauses
(Comparatives & Superlatives: not reported); T-3 seen; T-5 and T-6 could
not be checked with a new topic, because his most repeated weak spot is in
an older topic (the rest scene's deck and the widget were seen with that
one), so they stay covered by tests only. Every other open item gets the
note "covered by the owner's general report of 2026-11-21, not itemised".
Do not tick anything beyond this.

## 2. Merge into `main`

1. `git switch main`, `git pull --ff-only`. Check that the working tree is
   clean.
2. List what `main` has that the branch does not (the two November fixes
   are expected, commits around `8d4183b` and the lira symbol fix) and
   record it.
3. `git merge --no-ff ui-polish-widgets` with the message "Merge
   ui-polish-widgets: UI polish, widgets, reminders and first-wave topics
   (1.5.0)". A conflict is resolved so that both sides' intent is kept,
   and recorded as R-n with the files. If a conflict cannot be resolved
   with confidence: `git merge --abort`, leave `main` as it was, write why,
   and do steps 5 to 7 on the branch instead (step 3 and the push of `main`
   are then not done and are reported as such).
4. Do not push `main` yet: first step 3 and the checks of step 4.

## 3. Version

1. `pubspec.yaml`: `1.5.0+8`. The highest build in App Store Connect is 7
   (`1.4.0+7`, live).
2. Check that nothing else pins the version: tests, `lib/`, Runner's
   `Info.plist`, and the widget extension's `Info.plist`. The store expects
   the extension's version and build to equal the app's: build the release
   (step 4) and read `CFBundleShortVersionString` and `CFBundleVersion` of
   the app and of `PlugIns/*.appex` from the built product. If the
   extension's differ, fix the project setting that feeds them (a build
   setting, not a signing setting) and add the reading to the release
   steps. Record what you found either way.

## 4. Checks on `main`

- `flutter analyze` no issues; `flutter test` all pass (record the count);
  the Swift tests pass; the simulator build with `xcodebuild`;
  `flutter build ios --release --no-codesign`.
- `./scripts/preflight.sh` (its own URL and config checks are fine; it must
  not print secret values, and you do not print them either).
- Only when all of these pass: push `main`. If one fails and the cause is
  the merge, fix it on `main` with a test and record it; if it cannot be
  fixed, do not push `main` and report.
- Dependencies and data: compare the Dart packages, the iOS pods and Swift
  packages, the entitlements and the `Info.plist` usage strings of 1.4.0's
  store build source (`c37757a`) with the merged `main`. Write the list of
  differences. From the code, state whether the app now collects, sends or
  shares anything it did not in 1.4.0 (the reminders are local; the widgets
  read what the app wrote on the device). This feeds `product.yaml` `legal`
  (see Docs) and the App Privacy line of the release steps.
- Signing, read only: for both targets (Runner and `GrammarLensWidgets`)
  record the team, automatic or manual signing, the bundle IDs and the App
  Group entitlement in the Release configuration, and write what the owner
  must have in place before `flutter build ipa` exports for the store.

## 5. `docs/1.5.0-release-steps.md`

Model: `docs/1.4.0-release-steps.md`, the same order and tone, every command
in its own code block, every step the owner's. Contents:

- **Status** at the top: merged or not, version, what is not done yet
  (no store build, nothing uploaded, nothing submitted).
- **0. Open before the build:** checkboxes with their true state: the
  device checks (step 1's record), the iPad tour's blocking findings (step
  6), store texts and screenshots not started, signing for the extension.
- **1. Build (owner, on `main`):** pull, `flutter pub get`, analyze, test
  (the expected count), `preflight.sh`, resolving the Swift packages,
  `flutter build ipa --release --dart-define-from-file=config/prod.json`.
- **2. Check the build:** version and build of the app and of the widget
  extension; `./scripts/release_ipa_check.sh` (check that it still does its
  job on an IPA with an extension; extend it if it does not, with the
  reason); the eight languages; the extension is in the IPA with its App
  Group entitlement.
- **3. Upload and TestFlight:** Transporter as before; then a short check
  of the TestFlight build on the iPhone: add the widgets from this build, a
  reminder arrives, a practice set in a new topic, the day's step and the
  rest scene, the paywall.
- **4. App Store Connect checklist:** the version, build 8, manual release;
  per localization: What's New, the description, keywords only if a fact
  changed, the screenshots (all 8 iPhone and 6 iPad per language are to be
  made again: the design changed); App Privacy (step 4's finding; the
  owner decides); Notes for Review (what to add for the widgets, the local
  reminders and the new topics; start from
  `screenshots/1.4.0/asc/review-notes.txt`); the age rating and
  availability as they are unless a fact changed.
- **Store facts that 1.5.0 changes:** a table of every statement in the
  English store text (`screenshots/1.4.0/asc/metadata.json`) that 1.5.0
  makes false or incomplete, each with the fact read from the code. Known
  so far: the description says sixteen study buddies and the app now has
  fewer (read the number from the code; do not take it from this file);
  the number of practice topics is ten while the Daily Test keeps five;
  the widgets and the reminders are new. Do not rewrite the store texts in
  this run.
- **5. What's New:** an English draft only, marked as a proposal for the
  owner. The seven translations are not written in this run.

## 6. The iPad tour (simulator)

Use an existing iPad simulator of the 13-inch class if there is one, and
the smallest iPad that exists as well; if there is none, record that and
skip the step. Read from `Info.plist` which orientations the iPad build
allows and walk each. In English, then Home, the paywall and one question
screen in Turkish and in Arabic. Light and dark.

Screens: Welcome, the hero picker, the name screen, the goals; Home before
and after the Daily Test (the mountain, the Daily Test card, the topics
row); a Daily Test question, the wait and the result; the first climb; the
rest scene, free and Premium; Topic Practice (ten cards); a practice
question with its hint card open; the practice results; Review and a weak
spot's detail; Profile with the progress card; the reminder settings; the
paywall's three views; Premium on. Practice runs on a local stand-in, as
in fix round 6.

Captures in `build/ipad-tour/`. In `docs/1.5.0-release-progress.md` a table:
screen · fine or what is wrong · class (blocks the release: a control that
cannot be reached, clipped or unreadable text, an overflow; should fix;
cosmetic). Fix only the blocking class, on `main`, each fix with a test and
a small commit, and run step 4's Flutter checks again afterwards. Anything
that is a question of design is listed for the owner and not changed. The
store also offers the app on Mac and Apple Vision as an iPad app; that is
only noted, not tested.

## Docs

- `docs/1.5.0-release-progress.md`: what was done per step, the decisions
  R-n, the check results, the iPad table, what is not verified.
- `docs/roadmap.md` and one dated entry in `docs/build-log.md`: merged (or
  not), the version, not built for the store, not submitted.
  `docs/design/ui-polish/handoff/PROGRESS.md`: its summary says the branch
  is merged.
- `product.yaml`: `versions.in_progress: 1.5.0`; a completed entry on top
  of `recent` (five at most); the `planned` lines brought up to date (what
  is merged is no longer "not on main"; the November fixes ship inside
  1.5.0); `updated_at`. `status`, `versions.live`, `versions.in_review` and
  `marketing` unchanged. `legal`: unchanged unless step 4 found a new
  dependency, service or kind of data; then update `third_parties` and
  `data_collected` with the fixed vocabulary only, and say in the final
  summary that the legal pages need the owner's review. Never fill a field
  by guessing: leave it and list it for the owner.

## Done means

1. Steps 0 to 6 and Docs are each closed in `docs/1.5.0-release-progress.md`
   (or marked "not done" with the reason).
2. `main` holds the merge and `1.5.0+8`, with analyze clean, all Flutter and
   Swift tests passing, the simulator build and the release build
   (`--no-codesign`) succeeding, and is pushed with a clean `git status`.
   `ui-polish-widgets` still exists.
3. `docs/1.5.0-release-steps.md` exists and states only what is true.
4. Nothing was deployed, uploaded or submitted.

Code, comments, commit messages and all docs stay in English.
