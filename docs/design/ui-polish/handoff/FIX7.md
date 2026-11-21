# Fix round 7 — two findings of the iPad tour, before the 1.5.0 store build (unattended)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, `docs/1.5.0-release-progress.md`
(step 6, the iPad table, R-5 to R-8), `docs/1.5.0-release-steps.md`, and in
this folder `SPEC.md` (v14, §1.8) and `FIX6.md` (item 1, the model for item 1
here).

## Goal

`main` holds 1.5.0 (build 8), merged and checked; no store build has been
made yet. The iPad tour of part 1 found two things that are not iPad
specific. On 2026-11-21 the owner decided to fix both before the store
build. This round fixes them on `main`, cleans up the tour's simulators, and
brings the release docs up to date. It does not build for the store.

## Rules

- Unattended: no questions; decisions in `docs/1.5.0-release-progress.md`
  as R-9, R-10, … (question · options · choice · why). Nothing unverified is
  written as done.
- Work on `main` (the owner's word of 2026-11-21). Small commits, pushed as
  you go. No rebase, no `reset --hard`, no force push, no branch deletion.
- Diagnose before fixing; each fix gets a regression test.
- The version stays `1.5.0+8` (no store build was made with it).
- No deploy, no change under `proxy/`, no paid API call, no App Store
  Connect call, no upload, no `flutter build ipa`, no signing change.
- **The Mac is short of memory and disk.** At most one simulator booted at a
  time, shut down as soon as its walk ends; no new simulator is created; no
  iPad walk in this round. Never touch a simulator this run did not use
  (the owner's "BirdPerch-…" one stays as it is).
- Never run `dart format` over all of `lib/`.

## 0. Start

1. `df -h ~`.
2. Simulators: `xcrun simctl shutdown` and then `xcrun simctl erase` the two
   iPad simulators part 1 used (iPad Pro 13-inch, iOS 27.2, `9531D223…`;
   iPad mini (A20 Pro), iOS 27.2, `F6FB8A44…`; read the full ids from
   `xcrun simctl list devices`). Erase only, do not delete the devices.
   The owner allowed this on 2026-11-21. Record the free space before and
   after.
3. `git switch main`, `git pull --ff-only`, clean tree apart from this file.
   Commit this file first: "docs: fix round 7 task"; push.

## Items

**1. The day's step before N01 (SPEC §1.8; the reminder soft ask, N01).**

Seen in the tour (Premium, a second day; the progress record's row "The
day's step"): after the Daily Test, "See your climb" brought Home with N01
("When do you have 2 minutes?") already open over the mountain; the pawn
walked to its step only after N01 was closed. It is not iPad specific: every
new user meets it once, on the day of their second Daily Test, which is also
the moment the app asks to send reminders.

The owner's decision (2026-11-21), the same rule as fix round 6 for the rest
scene: first the reward, then the question. The step walks, the pawn lands,
whatever follows a step today follows it (a save point's light and name, a
medal, a month card), then a short beat, then N01. On a rest day the order
stays as fix round 6 made it: step, beat, rest scene, then N01 over the
scene.

Find why `_maybeShowSoftAsk` (`lib/screens/home_screen.dart`) lets N01 open
while a step is pending: it checks `_climbAnimating`, which is set only when
the climb load has decided to animate, so there is a window between the
saved test and the start of the walk. Confirm this before changing anything.
Then: N01 waits while a step of today's test is pending or walking, and
until the arrival has ended; after that the same beat as fix round 6
(reuse its value, do not add a second number), then N01. Every path where no
step will be shown (no step earned, the climb fails to load, Home not
visible) must still let N01 open, as today; on no path is N01 lost for the
install.

Tests (widget tests): free and Premium, a second day, test first (the
common order) and ticket first (the rest day); a save point day; a month
card on the same visit, if the code allows it to happen; the climb failing
to load; Home not visible at the save; N01 opening exactly once. The order
of fix round 6 stays green.

**2. Sheets follow an appearance change (SPEC §3.6; the progress record's
rows for N01, the length picker and the mountain intro, R-5).**

When the system appearance changes while a sheet from `showAppSheet` is
open, the sheet keeps its old background (`lib/widgets/app_sheet.dart`
reads `c.card` once, when the sheet opens) while its text takes the new
theme; light → dark leaves the title and "Not now" almost unreadable. The
mountain intro screen's bottom panel does the same. Fix both so that their
colours follow the theme while they are open (the background read inside
the sheet's build, or the equivalent). Then search the app for other places
that read a colour once for a route, dialog, sheet or overlay that stays
open, and fix those of the same kind; list each in the progress record.

Tests: a sheet opened in light, the platform brightness switched to dark
while it is open, the background and text colours checked (and dark →
light); the same for the mountain intro.

## Checks

- After the last code change: `flutter analyze` no issues; `flutter test`
  all pass (record the count); the Swift tests; the simulator build with
  `xcodebuild`; `flutter build ios --release --no-codesign` (read the app's
  and the widget extension's version and build: 1.5.0 (8)).
- One short smoke walk on **one iPhone simulator** (the one earlier rounds
  used), in Turkish, a second day: test → "See your climb" → the step walks
  → the beat → N01. Then, with N01 open, switch the simulator's appearance
  and capture the sheet. Shut the simulator down and stop any local
  stand-in when done. Captures in `build/fix7-captures/`.

## Docs

- `docs/1.5.0-release-progress.md`: a "Fix round 7" section (items 1–2: what
  was seen, the cause, the fix, the tests; R-n; the checks; the simulator
  clean-up and the disk space), and the iPad table's rows for these
  findings point to it.
- `docs/1.5.0-release-steps.md`: the status and "Open before the build" up
  to date (the two findings fixed, the expected test count); nothing else
  changes there.
- `SPEC.md`: §1.8 gains one sentence, that N01 too follows the day's step
  and the beat; the header lists it as v15.
- `DEVICE-CHECKS.md`: one short item for the TestFlight check of
  `1.5.0-release-steps.md`, not a new device pass: N01 cannot be seen again
  on the owner's phone (asked once per install), so it is checked only on
  the simulator; say so.
- `docs/build-log.md`: one dated entry. `docs/roadmap.md`: fix round 7 done
  on `main`, the store build next.
- `product.yaml`: a completed-fix entry on top of `recent` (five at most),
  `updated_at`; nothing else.

## Done means

1. Items 1–2, step 0, Checks and Docs are each closed in
   `docs/1.5.0-release-progress.md` "Fix round 7" (or marked "not done" with
   the reason).
2. `main` at `1.5.0+8`, analyze clean, all Flutter and Swift tests passing,
   both builds succeeding, pushed with a clean `git status`.
3. No simulator left booted by this run; the two iPad simulators erased.
4. Nothing deployed, uploaded or submitted.

Code, comments, commit messages and all docs stay in English.
