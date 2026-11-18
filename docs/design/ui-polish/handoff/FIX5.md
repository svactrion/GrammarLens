# UI polish + widgets — fix round 5 (owner's third device pass, unattended)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, and in this folder `SPEC.md` (now
v13: its header lists every section that changed), `PROGRESS.md` (the "Fix
round 4" section and decisions F4-1 … F4-13), `DEVICE-CHECKS.md` and this
file. New and changed boards in `boards/` and `screens/`: V24f-RestFree (the
new panel) and V23p-MonthProgress (new); V24-DayComplete is unchanged and is
the reference for item 2.

## Goal

The owner ran the third pass on his iPhone 14 Plus. Confirmed: the paywall
footer and V24f on one screen. He chose a new panel for V24f on the canvas,
asked for a clearer month progress card, and found that some paywalls close
with a swipe. A simulator capture also showed fix round 4's V24 (Premium)
with about 200 pt of empty panel. This round fixes these on
`ui-polish-widgets` for a short fourth pass.

## Rules

As in `FIX4.md` ("Rules"), unchanged; decisions in `PROGRESS.md` as F5-1,
F5-2, …. Never run `dart format` over all of `lib/`.

## 0. Start

1. `df -h ~`; the same allowed deletions as `FIX3.md` §0; aim to finish with
   at least 15 GB free.
2. `git switch ui-polish-widgets`, `git pull --ff-only`. Commit this file, the
   updated `SPEC.md` and the new and changed `boards/` and `screens/` files
   first: "docs: fix round 5 task and SPEC v13"; push.

## Items

**1. V24f's panel: the ticket deck (SPEC V24f "Panel (v13 …)", §1.27).**
Rebuild the panel under the scene to the V24f board; the top half (scene,
camp, fire, dream bubble, score capsule) does not change. Build the small
used ticket and the deck from the app's real ticket (X04) shapes and colours,
not new drawings: the compact "used" ticket scaled down (navy body, sawtooth
tear, gold USED, the light dashed stub slot with the clock, the next free
ticket's time and NEXT); four X04 tickets offset 7 pt diagonally, the front
one with "NEXT UP", the weak spot (one line), "AI feedback on every answer"
and "+4 / TODAY" on its stub; the gold ✦ PREMIUM tag and "5 practices a day"
at the top of the navy card. The panel fits its content and ends just above
the nav bar; no empty band, no scroll at 390 × 844 and larger at the default
and the next text size (round 4's rules). New strings in all 8 languages;
the weak spot's name stays English (§3.7). Tests at the five sizes and the
text sizes; captures light and dark (the panel is the same in both).

**2. V24 (Premium) back to its own board (SPEC V24 v13, §1.30).** Revert the
part of F4-1 that removed V24's two done tiles (Daily Test, Practice) and the
"Next Daily Test · step N" card with its step bar and countdown; keep the
reminder row. The panel ends just above the nav bar with no empty band at the
five sizes. Record the change of F4-1 as F5-n.

**3. The month progress card (SPEC V23 "Month progress card (v13 …)", board
V23p, §1.28).** Replace Profile's card: the points large with "/ 300" and the
distance to the next medal on the right; the 0–300 bar split into four parts
by gaps at 75 / 150 / 225, unfilled parts tinted per medal; the medal images
standing over the gaps (earned: colour, green ring, tick; not yet: muted,
grey ring); names and points under them; the navy dot at the current points;
no 10-segment bar and no "Monthly total" line. Light and dark. Tests for 0,
9, 75, 120, 150, 225, 240 and 300 points (tier states, the dot's position,
the "to Bronze" / "Gold reached" text) and the screen-reader label. The fill
animation part by part; Reduce Motion: at once.

**4. The paywall closes only with X (SPEC V13 "Closing (v13)", §1.29).** The
owner closed some paywalls with a swipe. Find every way the paywall is
opened (onboarding, Home topic cards, Review's locked practice, V24f's Wake
→ V13r, Profile, any other) and every way it can be dismissed besides its X
(the iOS edge swipe back, a sheet's drag down, a tap on the barrier, a system
back). Disable all of them; keep the X visible and working (its first tap in
a session opens V13b); a purchase or restore still closes it. Diagnose first
which routes allowed the swipe (record them), then fix in one shared place if
possible. Tests: a swipe-back gesture and a drag-down do not close it on each
entry point; the X does, with V13b the first time.

## Checks

- After the last code change: `flutter analyze` no issues; `flutter test` all
  pass; Swift tests pass; the simulator build with `xcodebuild` (as in round
  4; `flutter build ios --simulator` has the known Xcode build-service issue,
  record it if it still fails); `flutter build ios --release --no-codesign`.
- Captures in `build/fix5-captures/` and `/dark`: V24f and V24 at the five
  sizes (default and next text size; Turkish at 428 × 926), V23's progress
  card in each test state, the paywall at each entry point after a swipe
  attempt. Compare with the boards; keep the "match / what differs" table in
  `PROGRESS.md`.
- A smoke walk on the simulator in Turkish from a fresh install to the rest
  scene (as in round 4), then Profile, then the paywall from V24f's Wake
  (try to swipe it away; it stays; X → V13b).

## Docs

- `PROGRESS.md`: a "Fix round 5" section at the top (items 1–4: what was
  wrong, the cause, the fix, the tests; decisions F5-n; checks; not
  verified) and an updated summary.
- `docs/build-log.md`: one dated entry. `docs/roadmap.md`: fix round 5 done
  on `ui-polish-widgets`, waiting for the owner's fourth pass. `product.yaml`:
  a completed-fix entry on top of `recent` (five at most), the UI polish
  `planned` line, `updated_at`; `legal`, `status`, `versions` unchanged.
- `DEVICE-CHECKS.md`: a new top section "Fix round 5 — fourth pass": build and
  install over the current test build (no Xcode step); then, each with its
  expected result and board ID: V24f's new panel (today's test done and the
  ticket used), the paywall from Wake and from a Home topic card (a swipe from
  the left edge and a drag down do nothing; X → V13b once), Profile's progress
  card in light and dark. Keep the third pass's open items that need a day's
  test not done (the sweat drop, forward-button haptics, V20, Home's first
  view, the card companion's hop, the widgets' "before the test" state) in a
  short "Still open from the third pass" list.

## Done means

1. Items 1–4 and steps 0, Checks and Docs are each closed in `PROGRESS.md`
   "Fix round 5" (or marked "not done" with the reason).
2. After the last code change: analyze clean, all Flutter and Swift tests
   pass, the `xcodebuild` simulator build and the release build
   (`--no-codesign`) succeed.
3. The capture table compares every listed board.
4. `DEVICE-CHECKS.md` has the "Fix round 5 — fourth pass" section.
5. `ui-polish-widgets` is pushed with a clean `git status`; `main` untouched.

Code, comments, commit messages and all docs stay in English.
