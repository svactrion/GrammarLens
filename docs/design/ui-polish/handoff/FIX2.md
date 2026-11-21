# UI polish — fix round 2 (unattended)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, and in this folder `SPEC.md` (updated
to v10: §1.14–§1.16, V05, V05b, V24, and the new V24f, V24s, V13r, PW05r),
`TASK.md` and `PROGRESS.md`.

## Situation

- The owner tested `ui-polish` on his iPhone 14 Plus (6.7", 428 × 926 pt).
  This round fixes what he found and adds the free users' rest-scene →
  Premium flow.
- **The owner is away while this runs, and you have no access to his
  iPhone.** Everything is built and checked on the iOS simulator. Whatever
  can only be confirmed on the phone goes into an "Owner device checks" list
  in `PROGRESS.md`.
- **The Mac's disk is nearly full.** Step 0 frees space before any build.
- Another Claude Code session works in `~/GrammarLens-widgets` (branch
  `widgets-notifications`) and may still be running. Never read-modify,
  build in, clean or delete anything in that folder or on that branch, and
  never touch its Xcode DerivedData.

## Rules

- Everything in `TASK.md` still applies: never stop to ask; decide with the
  §1 decision rule and record the decision; small single-purpose commits; no
  new packages; no new analytics events (a new value for an existing event
  parameter is allowed where this file says so); no deploy; no paid API calls;
  no version bump; no merge into `main`; no destructive git (`reset --hard`,
  rebase, force push, branch or worktree deletion).
- Simulator: use an existing iPhone simulator (6.7"–6.9" class preferred)
  that is **not** currently booted by the other session (check
  `xcrun simctl list devices booted`). Do not create, erase or delete
  simulators (disk). Install, launch and capture only on the device you chose,
  by its UDID.
- First commit of this round: this file, the updated `SPEC.md` and the new or
  changed files in `boards/` and `screens/` ("docs: SPEC v10 and fix round 2
  task"). Push.
- For every item below: write the diagnosis first into a "Fix round 2"
  section of `PROGRESS.md`, then fix, add tests, commit, push.

## 0. Free disk space (first, before any build)

The owner authorises deleting these regenerable things, and only these:
- In `~/GrammarLens`: `flutter clean` (removes `build/`, `.dart_tool/`,
  ephemeral iOS files), any other `build/` folders inside the repo, and old
  capture folders under `build/` from earlier rounds.
- Xcode DerivedData folders whose `info.plist` `WorkspacePath` points into
  `~/GrammarLens` (the main repo path only). Check each folder's
  `WorkspacePath` before deleting; never delete the one for
  `~/GrammarLens-widgets`.
- `xcrun simctl delete unavailable` (simulators of runtimes that are no longer
  installed).

Do not delete anything else. In particular not: tracked files, the owner's
untracked folders (`Claude outputs/`, `screenshots/icon-exploration/` and
any other untracked owner material), `config/*.json`, the pub cache,
simulator runtimes, iOS DeviceSupport, or anything outside the paths above.

Record in `PROGRESS.md`: free space before and after (`df -h ~`), what was
deleted, and a **report only** table of the largest space users you can see
that you did not touch (inside the repo: untracked/ignored folders by size;
outside: `~/Library/Developer/Xcode/DerivedData` other projects,
`~/Library/Developer/Xcode/iOS DeviceSupport`, CoreSimulator devices and
runtimes, `~/.pub-cache`), each with its size and the safe command the owner
could run himself. If the disk is still too full to build after step 0,
record it and continue with the work that does not need a build (tests that
run on the host, docs), then retry.

## 1. Companion motion (most important)

On the device the companions do not move the way the design says.
Diagnosis: write a table of every companion appearance in the app (screen,
widget used, mood, motion expected by SPEC, what happens now). Check and
record each of these:
- (a) the real value of `AppMotion.loopsEnabled` in debug, profile and
  release;
- (b) whether the Reduce Motion / `MediaQuery.disableAnimations` path turns
  loops off when it should not;
- (c) screens that use a plain `Image` instead of `CompanionView` (paywall,
  Welcome, Credits, cards, …);
- (d) loops that never start or play once and stop (`TickerMode`, visibility,
  dispose);
- (e) amplitudes too small to see.

Fix: the motion of SPEC §3.5 and of each screen's note must be clearly
visible on a phone; SPEC values are minimums. At least: idle = breathe +
±3 px float; wave = ±6° sway; cheer = two hops; think = tilt; sleep =
breathe + Zzz. With Reduce Motion on, loops still stop (that rule stays; add
"Is Reduce Motion on?" to the owner device checks).
Tests: for each mood, a widget test that the loop runs and its amplitude is
above the minimum. Evidence: two captures taken at different moments on
Welcome, the Home card, the paywall, Profile and the rest scene.

## 2. Paywall companions (V13)

The trio on top (Panda, Fox, Frog) does not move. As on the board: the side
ones float, the middle one hops; the "See plans" arrow nudges every 1.8 s;
the CTA has its shine and pulse.

## 3. Free vs Premium table (V13c), exactly as the board

- Heading "Free vs Premium" with the companion peeking at its right.
- The Premium column is one piece from the header to the last row: 2 px
  orange border, soft orange fill, a navy "Premium" pill on top.
- Rows (icon tile + label): Daily Test 1 a day / 1 a day; AI practice 1 a
  day / 5 a day; Weak-spot practice ✓ / ✓; All N topics — / ✓ (N = the real
  number); Session length 3 / 3 · 5 · 10; Monthly Climb ✓ / ✓.
- Free checks: grey outline; Premium checks: filled green; "—" grey.
- Under the table, the green note: "Cancel anytime. Your climb, medals and
  weak spots stay if you go back to free."
- Take sizes and colours from the board HTML. If a value contradicts the
  app's real rules, use the real rule and record it.

## 4. Profile ribbon (V23)

The navy ribbon is missing. Board values: 286 × 62, radius 16, fill
#1B4FB0 → #0D3B8F, 5 px bottom lip #082A6B; two 46 × 46 #082A6B tails,
26 px outside each end, starting 14 px down, with V-cut ends; it overlaps the
stage's bottom by 40 px. Inside: name 23/900 white, line 12/700 #C9D6FF
("Climbing with <Hero> · since <Mon YYYY>"), a 40 × 40 pencil button on the
right (radius 12, white at 14 %). On open it settles from 12 px below
(300 ms easeOutBack).

## 5. Edit name (PF04)

Not a full-screen page: a bottom sheet that rises with the keyboard, its top
edge just under the companion stage (the stage stays visible above, dimmed).
Inside: the companion's "What should I call you?" bubble, the text field with
its n/20 counter, Cancel and Save. Save closes the sheet, the name
cross-fades (150 ms), the existing "Name saved" snackbar shows.

## 6. All medals (PF02)

On the device the order does not match the design. Diagnose the sorting and
grouping code; add a test with a fixture across a year boundary (Dec 2025,
Jan 2026, Feb 2026) plus the Welcome badge. Correct behaviour: tier counters
on top (n Gold, n Silver, n Bronze, n Welcome); then year headers, newest
year first; under each year a 3-column grid, newest at the top left, read
left to right and top to bottom; the running month first, grey "in
progress"; the Welcome badge at the month it was earned.

## 7. Goal screen (V05)

A fourth option, "School & university" (SPEC §1.14 and the V05 board):
`LearningGoal` gains `school`, the `learning_goal` user property gains the
value `school`; every place that shows or edits the goal lists all four; Work
and Everyday English get the board's new descriptions; strings in all 8 ARB
files.

## 8. Getting ready (V05b)

At least 4 s: each stop at least 1.2 s, 0.6 s of celebration at 100
(SPEC §1.16). The honesty rule stays. Update the tests.

## 9. Mountain intro (V06) — the flag

On the device the flag is not on the summit. Diagnose whether its position
is computed in screen points or in image coordinates; cover-scaling of the
mountain at another aspect ratio may move it off the peak. Fix: anchor the
flag's base to the summit (the trail table's last point) in image
coordinates. Capture at the iPhone 14 Plus ratio (428 × 926, a simulator of
that size if one exists, otherwise a widget test at that size plus the
nearest simulator) and at two other sizes, showing the flag on the peak. If
R04b, V12 or the rest scene use the same calculation, fix them too.

## 10. Home greeting (V14 / V15)

On the device the name drops to a second line; the design is one line,
"Good evening, Ada" with the name bold. Keep it on one line; if it does not
fit, scale the text down to a minimum instead of wrapping. Test in all 8
languages and with a 20-character name.

## 11. New: free users' rest scene → Premium (SPEC §1.15; V24f, V24s, V13r, PW05r)

- V24f: the dream bubble (today's weak spot), the sheet header with the
  countdown, the Premium card (ticket strip 1 used + 4 locked, button
  "Wake <Hero> up · 7 days free"). No "Remind me tomorrow" row on this branch
  (notifications live on the other branch).
- Flow: tap → wake-up animation (V24s) → contextual paywall V13r (the same
  paywall page, only the top changes) → trial started → PW05r → straight into
  that weak spot's practice.
- Paywall source: the new value `rest_scene` on the existing
  `paywall_viewed` event (no new event).
- No weak spot: the fallback copy in SPEC. Premium users keep V24.
- Tests: which user sees which scene, the source value, PW05r's routing,
  X → 13b → back to the scene.

## 12. V15: the pawn under the nav bar

In fix round 1's capture, the pawn and its next step sat under the nav bar
when Home first opened. Check at the 6.7" ratio; if the pawn is not visible
at first view, adjust the mountain card's camera to keep it in the visible
area.

## Done means

1. Step 0 and items 1–12 are each closed in `PROGRESS.md` "Fix round 2"
   with their diagnosis and commit hashes (or a clear "not done" with the
   reason).
2. `flutter analyze` reports no issues and `flutter test` passes, both run
   after the last code change.
3. Every changed board is captured on your simulator and the B11 table is
   updated (new rows for V24f, V13r, PW05r).
4. `PROGRESS.md` has an updated summary and an "Owner device checks" list
   (at least: Reduce Motion setting, companion motion, the V06 flag, the
   greeting, the rest-scene flow, haptics).
5. `docs/roadmap.md` records today's decisions (4th goal School &
   university; free users' rest scene → Premium; getting ready at least
   4 s); `docs/build-log.md` has an entry; `product.yaml` changes only if
   needed (planned line, `updated_at`).
6. `ui-polish` is pushed and `git status` is clean. No merge; the owner
   asks for it separately after his device test.

Code, comments, commit messages and all docs stay in English.
