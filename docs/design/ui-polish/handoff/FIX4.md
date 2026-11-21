# UI polish + widgets — fix round 4 (owner's second device pass, unattended)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, and in this folder `SPEC.md` (now
v12: its header lists every section that changed), `PROGRESS.md` (the "Fix
round 3" section and decisions F3-1 … F3-26), `DEVICE-CHECKS.md` and this
file. The boards that changed in v12 are in `boards/` and `screens/`:
V24f-RestFree, V13-Paywall, V13c-PaywallCompare, V13a-PaywallPlans,
V13r-PaywallRest, W01-Widgets.

## Goal

The owner ran fix round 3's second pass on his iPhone 14 Plus (428 × 926,
release build, Turkish interface, a larger text size). Confirmed working:
results → badge → first climb, V12's bubble, the switches, the ribbon, the
paywall order, N01 after a practice, the name screen, the goal tilt, the
shine, V05b, the flag, dark mode in the app. This round fixes what he found,
on `ui-polish-widgets`, for a short third pass.

## Rules

As in `FIX3.md` ("Rules"), unchanged: unattended, decisions recorded in
`PROGRESS.md` as F4-1, F4-2, … (question · options · choice · why); `TASK.md`
§3; no merge into `main`, no rebase, no `reset --hard`, no force push, no
branch or worktree deletion, no Flutter / Xcode upgrade, no signing changes;
existing simulators only; no access to the owner's iPhone; diagnosis before
fix for bugs, each with a regression test; small commits pushed as you go.
Never run `dart format` over all of `lib/` (it rewrites the byte-checked
generated tables); format only the files you changed.

## 0. Start

1. `df -h ~`; the same allowed deletions as `FIX3.md` §0; record free space
   before and after; aim to finish with at least 15 GB free.
2. `git switch ui-polish-widgets`, `git pull --ff-only`. Commit this file,
   the updated `SPEC.md` and the changed `boards/` and `screens/` files
   first: "docs: fix round 4 task and SPEC v12"; push.

## Items

**1. V24f on one screen, and the campfire (SPEC V24f, §1.22).** Device: the
"Remind me tomorrow" row was below the nav bar and needed a scroll; scrolled,
the dream bubble slid under the status bar; the campfire was a large flat
flame on a ring of stones on the trail in front of the tent. Rebuild to the
v12 board: no scroll at 390 × 844 and larger at the default and the next
text size (only 375 × 667 and the largest text size may scroll); the compact
header and Premium card; the 40 pt reminder row on the first view; the camp
between the dream bubble and the sheet; the fire at the companion's front
right on the same ground (logs on the companion's foot line, flame about
40 % of its height, two layers, a warm ground glow). V24 (Premium) gets the
same scene, header and row. The rules of round 3 still hold (never scale the
art up; crop from the top; the camp whole with ≥ 12 pt). Tests at 375 × 667,
390 × 844, 402 × 874, 428 × 926, 440 × 956 at the default, the next and the
largest text size: assert no scroll extent where required, the reminder row
and "Wake" above the bar, the camp whole; record the numbers.

**2. The paywall footer (SPEC V13 v12, §1.23).** Device: the pinned footer
was about 207 pt tall and spread out (a halo panel round the button, wide
links, "Maybe later" under them). Rebuild it to the v12 board on V13, V13c,
V13a and V13r: 24 pt side margins, the button 54 pt with only its pulse, the
price line 12 pt centred at most 300 pt wide, the links on one centred row
with "·", no "Maybe later" anywhere (onboarding included; the X at the top
right closes and opens V13b once per session, as today). Keep Restore,
Terms, Privacy and the full price line on the first view. Remove the
"Maybe later" string from the ARB files if nothing else uses it. Check that
"Compare plans" is now on the first view at 390 × 844 and 402 × 874 (F3-26)
and record the footer height at the five sizes. Capture the iPad first view
again.

**3. Widgets v12 (SPEC §5.10 W01 v12, §1.24).** Device: the medium tip
widget showed one short rule and was mostly empty; in dark mode every widget
turned system grey and the small one looked poor. Build to the v12 board:
- The tip widget shows the user's latest weak spot: a short rule with its key
  words in a green pill, the user's own sentence on one line (wrong words
  struck through, red tint) and the corrected sentence (green tint), each one
  line with "…"; a different weak spot each day, in turn; with none yet, the
  topic hint's rule and two examples. Write what it needs to the App Group
  with the existing widget data (no new data leaves the device; nothing new
  is collected, so `product.yaml` `legal` does not change). Taps: the right
  box → Daily Test (waiting) or Home (done); the rest → that weak spot (R03).
- Designed dark variants for the small widgets and the tip widget (SPEC
  colours); the medium mountain widget unchanged.
- Snapshot tests (Swift) for each widget × state × light / dark, plus a long
  sentence, no weak spot, German and Arabic UI strings; nothing cut except
  the designed "…".

**4. Profile's month progress card (SPEC V23 v12).** The device still shows
the old card. Build it as the V23 board: title and "<mountain> · N active
days", the ScoreCapsule at the top right, the 10-segment bar, the tier marks
under it at their positions, "Monthly total". Light and dark; tests for 0,
mid-month and every tier passed.

**5. Props by the head (SPEC §3.5 v12).** Device: on a wrong answer the
giraffe's sweat drop fell from far above and to the right of its head. Give
every hero × pose image a measured head box (from the image's pixels; a small
script like round 3's apex tool, no new packages), store the table, and place
each prop from it: sweat from the temple down the cheek, thought bubble and
cloud above the head's top right, Zzz above the head, sparkle beside it;
mirrored in RTL. A contact-sheet capture of all 9 heroes with each prop, and
a test that every hero × prop has a table entry.

**6. Haptics on forward buttons (SPEC §3.4 v12, §1.25).** Every Next /
Continue / Finish / Done-style button in onboarding, the Daily Test, practice
and the results gives light on tap; a tap that already has a haptic does not
get a second. List the buttons in `PROGRESS.md`; tests through `HapticMap.log`.

**7. Loading screens (SPEC V20 v12, §1.26).** Device: V20's content sat at
the top with the lower half empty, all three checklist items were ticked
while the wait went on, and the lens poked out of the answer card. Centre the
content of V20 and V18 vertically; keep the last checklist item in progress
until the result arrives; keep the lens inside the card. Tests for the
checklist state before and after the result.

**8. Upper case by language (SPEC §3.7 v12).** Device (Turkish): "GERI
BILDIRIMIN YOLDA", "TILKI RÜYASINDA". Add one locale-aware upper-case helper
(tr and az: i → İ, ı → I) and route every capitalised translated label
through it (or write the ARB string in capitals); find every
`toUpperCase()` on translated text and list them in `PROGRESS.md`. A test
that renders the capitalised labels in Turkish and finds no dotless "I"
where "İ" belongs.

## Checks

- After the last code change: `flutter analyze` no issues; `flutter test` all
  passing; Swift tests passing; a simulator build of Runner + extension;
  `flutter build ios --release --no-codesign`.
- Captures in `build/fix4-captures/` (light) and `/dark`: V24f and V24 at the
  five sizes (default and next text size), V13 / V13c / V13a / V13r first
  views at 390 × 844 and 428 × 926, the iPad V13 first view, every widget
  state light and dark, V23's progress card, the props contact sheet, V20 and
  V18, the Turkish capitalised labels. Compare each with its board and keep
  the "match / what differs" table in `PROGRESS.md`.
- A smoke walk on a fresh simulator install in Turkish (`SEED_LANGUAGE=tr`):
  onboarding → Day 0 with one wrong answer (the sweat drop by the head) →
  results → badge → first climb → paywall (no "Belki sonra"; X → V13b) →
  Home → Review → free-ticket practice → V20 → results → Home (V24f on one
  screen, N01). Record what you saw.

## Docs

- `PROGRESS.md`: a "Fix round 4" section at the top (items 1–8: what was
  wrong, the cause, the fix, the tests; decisions F4-n; checks; not verified)
  and an updated summary.
- `docs/build-log.md`: one dated entry. `docs/roadmap.md`: fix round 4 done
  on `ui-polish-widgets`, waiting for the owner's third pass. `product.yaml`:
  a completed-fix entry on top of `recent` (five at most), the UI polish
  `planned` line, `updated_at`; `legal`, `status`, `versions` unchanged.
- `DEVICE-CHECKS.md`: a new top section "Fix round 4 — third pass": build
  and install over the current test build (no Xcode step); then, each with
  its expected result and board ID: V24f on one screen with the fire by the
  companion; the paywall footer (compact, no "Belki sonra", "Compare plans"
  visible); the widgets in light and dark (re-add them once so iOS picks up
  the new layouts); Profile's progress card; a wrong answer's sweat drop by
  the head (needs a day's test not done, or a fresh install); forward-button
  haptics; V20 centred with the last item waiting; the Turkish capitals.

## Done means

1. Items 1–8 and steps 0, Checks and Docs are each closed in `PROGRESS.md`
   "Fix round 4" (or marked "not done" with the reason).
2. After the last code change: analyze clean, all Flutter and Swift tests
   pass, simulator and release (`--no-codesign`) builds succeed.
3. The capture table compares every listed board in light and dark.
4. `DEVICE-CHECKS.md` has the "Fix round 4 — third pass" section.
5. `ui-polish-widgets` is pushed with a clean `git status`; `main` untouched.

Code, comments, commit messages and all docs stay in English.
