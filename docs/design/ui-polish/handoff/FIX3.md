# UI polish + widgets — fix round 3 (owner's device test, unattended)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, and in this folder `SPEC.md` (now
v11: its header lists every section that changed), `PROGRESS.md` (the
"Integration" section and decisions I-1 … I-13), `DEVICE-CHECKS.md` and
this file. The boards that changed in v11 are in `boards/` and `screens/`:
V04-Name, V04s-NameStoryboard (new), V12-Climb, V12b-ClimbStoryboard,
V13-Paywall, V13c-PaywallCompare, V13a-PaywallPlans.

## Goal

The owner tested the integrated build (`ui-polish-widgets`) on his iPhone 14
Plus (428 × 926, iOS 26, release build, Reduce Motion off): first an install
over App Store 1.4.0 (data survived), then a fresh install. Most of it
passed. This round fixes everything he found, on `ui-polish-widgets`, and
prepares the build for a short second device pass.

## Rules

- The owner is not watching: never stop to ask. Decide with `TASK.md` §1's
  decision rule and record each decision in `PROGRESS.md`, section "Fix round
  3", as F3-1, F3-2, … (question · options · choice · why).
- Everything in `TASK.md` §3 still applies (no new packages, no new analytics
  events, no deploy, no paid API calls, no version bump, no change to
  `product.yaml` `status` / `versions` / `legal`), plus: no merge into
  `main`, no rebase, no `reset --hard`, no force push, no branch or worktree
  deletion, no Flutter or Xcode upgrade, no change to team / signing /
  provisioning settings (E1 only commits the owner's own change).
- Bugs (A1, A2): write the diagnosis in `PROGRESS.md` before the fix: the
  hypotheses you considered, which one the evidence supports and how you
  checked. Each fix gets a regression test that fails without it.
- Simulators: use the existing ones; do not create new simulators (disk).
  Where a size is missing, use widget tests at that size.
- No access to the owner's iPhone. Anything that needs the phone goes into
  `DEVICE-CHECKS.md` (section 6 below).
- Small commits, one per item or tight group, pushed as you go.

## 0. Start

1. `df -h ~`. The owner authorises deleting only: `flutter clean` in
   `~/GrammarLens`, `build/` inside it, and Xcode DerivedData folders whose
   `info.plist` `WorkspacePath` points into `~/GrammarLens` (check each
   before deleting). Nothing else. Record free space before and after. The
   owner's Mac ran out of space during his device build: leave at least
   15 GB free at the end if the allowed deletions make that possible, and
   say in `PROGRESS.md` if they do not.
2. In `~/GrammarLens`: `git switch ui-polish-widgets`, `git pull --ff-only`.
   The working tree holds this file, the updated `SPEC.md`, the new and
   changed `boards/` and `screens/` files (untracked or modified) and the
   owner's Xcode change (E1). Commit the docs first: "docs: fix round 3 task
   and SPEC v11"; push.

## A. Behaviour bugs

**A1. Day 0: the badge came before the results.** On the device the Welcome
badge (V11) opened first and the results (V10) only after "Continue". SPEC
§4: V10 Results → V11 Welcome badge → V12 First step. Diagnose why (where
the badge route is pushed relative to the results), fix the order, and add a
flow test that walks Day 0 to V12 and asserts the order. Later days with a
medal (R05) keep their current order unless SPEC says otherwise; check it and
record.

**A2. N01 opened late.** Device: Day 0 test → Review → used the free ticket
on a practice → back to Home: the rest scene (V24f) showed, but N01 did not
open; it opened only after switching to another tab and back. SPEC §5.10:
N01 opens as soon as the first rest scene (V24 or V24f) is on screen.
Hypotheses to rule in or out at least: the trigger runs only on the Home
tab's first build or `initState` (the tab is kept alive); it reads the
ticket state before the practice result has been saved; it waits for a
route-pop event that a tab switch does not send. Fix it so the trigger fires
on the first frame where the rest scene is visible, whatever path led there,
still once only. Tests for: (a) the path above, (b) a cold start straight
into the rest scene, (c) N01 never opening twice.

## B. Make the build match the boards

**B1. V24f layout (SPEC V24f "Layout (v11)").** The device showed the scene
as a separate rounded card, about 2× zoomed in, the campfire cut at the card
edge and the dream bubble in the middle; the board has a full-bleed scene
with the navy sheet attached under it. Rebuild it to the board. This replaces
decision I-7: the scene is never scaled up to free room; when the sheet needs
space so that "Wake <Hero> up · 7 days free" stays above the nav bar, the
scene is cropped from the top. The camp (tent, fire, companion) stays fully
visible with ≥ 12 pt above the sheet. Check at 375 × 667, 390 × 844,
402 × 874, 428 × 926 (the owner's phone) and 440 × 956, at the default text
size and at the app's largest text size setting; record the scene height and
the Wake button's clearance for each in `PROGRESS.md`. V24 (Premium) gets
the same scene treatment if it has the same problem; check it.

**B2. V05b's bar.** The duration is right, but the owner says the bar looks
far from the board. Capture the app's V05b next to `screens/V05b-GettingReady.webp`
and make it match: the striped orange fill (26 high), the three stop circles
that become green ticks, the summit flag at the end of the track, the big
tabular percentage, the rows and the "Your climb" card. Record what was
different.

**B3. V05 card tilt.** On selection the cards tilted left, right, right, left.
SPEC V05: alternating by position, card 1 right (+2°), card 2 left (−2°),
card 3 right, card 4 left. Derive it from the index (no hand-written list).

**B4. The button shine (SPEC §3.2).** On the device the shine on V05's and
V06's orange buttons was a small square moving across. It must be a
diagonal band the full height of the button, 38 % of its width, skewed −20°,
clipped to the button's shape. Make one shared implementation and use it for
every shining button (find them all; list them in `PROGRESS.md`).

**B5. Switches (SPEC §3.6).** The thumbs are black on the device; the boards
have white thumbs. Fix it at the theme level (`SwitchThemeData`, light and
dark) so N03, V24f's reminder row, V24's row and R08 all follow; track colours
as SPEC §3.6.

**B6. V06 flag on the summit (SPEC V06).** The device shows the pole where
the trail ends; the owner wants it on the mountain's highest point. Give each
monthly mountain art (light and dark) its own apex point, measured from the
image (for example the topmost opaque/rock pixel row around the peak, then
checked by eye on a capture), stored next to the art's existing trail data,
and stand the pole's base on it. Captures of V06 for this month and two other
months.

**B7. V18 practice loading.** The owner's screenshot of a weak-spot practice
loading screen: the skeleton cards were narrower than the "Did you know?"
card, the topic name sat at the top left as a big title, and the hint card
was yellow. SPEC V18: one loading screen for topic and weak-spot practice,
skeletons and hint card the same width, as on the board. Make both entry
points match V18; if part of the difference is deliberate, record why.

**B8. The expression kit everywhere (SPEC §3.5, v11).** The owner noticed the
companions' expression layers are missing. Today: no screen uses `oops`;
`showProp: false` hides the prop in `companion_dialog.dart` (V13b, R10, R08
reset: the sad cloud), `daily_test_card.dart` (the think bubble),
`medal_celebration.dart`, `error_state.dart` and `lucky_wheel_screen.dart`;
`prop_tear.webp` is unused. Go through every `CompanionView` use and compare
it with its board: the mood and the prop must match the board. Wrong answers
(V09, Q04 / Q05 wrong, practice wrong) use `oops` (head shake + falling sweat
drop). Hide a prop only where the board does or where it would cover text,
and list every remaining hidden prop with its reason. Add a table "screen ·
board · mood · prop" to `PROGRESS.md`. Tests for the wrong-answer oops and
the dialog's cloud.

## C. Design changes (owner decisions, SPEC v11)

**C1. Splash (V01).** First launch about 2.2 s, the small lens scanning the
word in 900 ms; later launches only square + wordmark, at most 800 ms.

**C2. The name screen (V04, V04s; SPEC V04).** Build the new screen: the
companion large and centred in a warm glow, the bubble above it; three states
(asks · listens · greets); the greeting 700 ms after the last key when the
name is valid; the n/40 counter; the green tick; the haptic once per name.
New strings "Hi! What should I call you?" and "Nice to meet you, {name}!" in
all 8 interface languages (natural, short; check that each fits the bubble at
the largest text size; the name is cut to 16 characters + "…" in the bubble
only). Keep the existing validation. Tests for the three states and the
transitions (type → pause → greet; type again → listen; clear → ask).

**C3. V12's bubble (SPEC V12).** "First step done! 29 to the summit." opens
right above the companion when the walk ends, tail pointing at it, placed
from the companion's on-screen position (12 pt above the head, ≥ 16 pt from
the edges, below with the tail up if there is no room above). Check at the
five sizes of B1.

**C4. Paywall order (SPEC §1.17, V13, V13c, V13a).** The page becomes: first
view → Free vs Premium (V13c) → plans and trial timeline (V13a). The hint
says "Compare plans" (all 8 languages). The pinned CTA and its full price
line stay as they are and stay visible everywhere; the yearly plan stays
preselected and drives the CTA before the plans are on screen. The billed
amount is the largest price in each plan row. The same order applies to V13r
(the paywall from the rest scene) if it shares the page; check. If an iPad
simulator exists, capture the first view on it too (App Review uses iPad).

**C5. Profile ribbon (SPEC V23).** The ribbon looked thick on the device. Its
width follows the screen (screen width − 60 pt, tails included); the name and
the "Climbing with …" line each stay on one line, shrinking to 85 % at most,
then "…". Check at the five sizes and the largest text size; replaces the
fixed 286 pt width of fix round 2.

**C6. Pose changes (SPEC §3.3).** Every change of a companion's mood
cross-fades in 200 ms with a 0.96 → 1 scale on the new image (Profile's wave
on tap felt abrupt; also the V24 / V24f wake, V04, V05b). Put it in
`CompanionView` so every screen gets it; Reduce Motion: a 150 ms fade.

## D. Dark mode (SPEC SY03, v11 rules)

The owner found dark mode hard to read: the right / wrong chips' tones and
navy text in several places. Do a theme-level pass:
1. Inventory every colour used for text, icons, outlines and fills (tokens
   and hard-coded values in widgets). Hard-coded colours that should follow
   the theme move to tokens.
2. Give each light token a dark counterpart by SPEC SY03's rules (navy text →
   a light blue; right / wrong / amber fills → dark tints with light text;
   soft fills → dark tints; lighter card lines). Keep `AppColors.dark`'s
   page and card values (D1-1) unless a ratio fails.
3. Add a test that computes the contrast ratio of every text / background
   and icon / background token pair in both themes and fails under 4.5:1
   (text) or 3:1 (large text, icons). List the pairs and their ratios in
   `PROGRESS.md`.
4. Capture every in-scope board in dark mode on the simulator into
   `build/fix3-captures/dark/` and look at each; fix what is still hard to
   read (the tests cannot see images or art behind text).
Companion and mountain art are unchanged.

## E. Housekeeping

**E1. The owner's Xcode change.** During the device test the owner set the
development team for the `GrammarLensWidgets` target in Xcode; the change is
in `ios/Runner.xcodeproj/project.pbxproj`, uncommitted. Look at the diff: if
it only sets `DEVELOPMENT_TEAM` (and the signing style Xcode writes with it),
commit it as "chore(ios): development team for the widget target (owner,
device test)". If it contains anything else, commit only after recording
every changed line in `PROGRESS.md`; do not edit it.

## 4. Checks

- `flutter analyze` with no issues; `flutter test` all passing; Swift tests
  (`xcodebuild test`, RunnerTests with the widget snapshots) passing; a
  simulator build of Runner + extension; `flutter build ios --release
  --no-codesign`. All after the last code change.
- Captures on the simulator into `build/fix3-captures/` (light) and
  `build/fix3-captures/dark/`: V01 (two frames), V04 (three states), V05
  (each card selected), V05b, V06, V10 → V11 order (two frames), V12 (end
  frame), V13, V13c, V13a, V18 (both entry points), V23, V24f and V24 at the
  five sizes of B1, N03, a wrong answer with `oops`, V13b with the cloud. For
  each, compare with its board and write "match" or what differs in a table
  in `PROGRESS.md`.
- A smoke walk through the real app on a fresh install (Welcome → … → Day 0
  → results → badge → first climb → paywall → Home), then the A2 path
  (Review → free ticket → practice → Home → N01). Record what you saw.

## 5. Docs

- `PROGRESS.md`: a "Fix round 3" section at the top (each item A1–E1: what
  was wrong, the cause, the fix, the tests; decisions F3-n; checks; what is
  not verified) and an updated summary.
- `docs/build-log.md`: one dated entry. `docs/roadmap.md`: the UI polish
  status (fix round 3 done on `ui-polish-widgets`, waiting for the owner's
  second device pass; not on `main`, not shipped). `product.yaml`: a
  completed-fix entry on top of `recent` (five items at most), the UI polish
  `planned` line updated, `updated_at`. Nothing in `legal` changes (no new
  data, no new service).

## 6. `DEVICE-CHECKS.md`

Add a section at the top, "Fix round 3 — second pass", for the owner's phone,
in order, each with the expected result and the board ID:
1. Build and install: the same commands as section 1 (no Xcode step needed
   now that the team is set; say so), installing over the current test build.
2. On this install (the day's test can be done or not; say which items need
   which): V24f layout, N03 and V24f switches, the Profile ribbon and the
   wave cross-fade, the paywall order and "Compare plans", V18 from Review,
   a wrong answer's oops, the dark mode walk (Home, a question with right and
   wrong answers, results, Review, Profile, paywall, V24f).
3. Before today's test (the next day): Home's first view (the pawn and the
   gold ring on the next step fully above the nav bar), the daily card's
   companion hop, the widgets' "before the test" state ("Step N is waiting",
   a tap opens the Daily Test).
4. Then delete and reinstall: splash timing, the name screen's three states
   and the greeting haptic, the goal cards' tilt, the shine on Continue,
   V05b's bar, the flag on the summit, results before the badge, V12's bubble
   by the companion, the paywall order, N01 after the first practice.

## Done means

1. Every item A1–E1 and steps 0–6 is closed in `PROGRESS.md` "Fix round 3"
   (or marked "not done" with the reason).
2. After the last code change: `flutter analyze` no issues, `flutter test`
   all pass, Swift tests pass, simulator build and the release build
   (`--no-codesign`) succeed.
3. The capture table compares every listed board in light and dark.
4. `DEVICE-CHECKS.md` has the "Fix round 3 — second pass" section.
5. `ui-polish-widgets` is pushed and `git status` is clean; `main` is
   untouched.

Code, comments, commit messages and all docs stay in English.
