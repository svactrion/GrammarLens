# UI polish + widgets — fix round 6 (owner's device check of 2026-11-19, unattended)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, and in this folder `SPEC.md` (v13),
`PROGRESS.md` (the "Fix round 5" section and decisions F5-n),
`DEVICE-CHECKS.md` (its top section "First-wave topics (1.5.0)") and this
file. No board changes in this round.

## Goal

On 2026-11-19 the owner deployed the Worker for 1.5.0 himself (new version
`a3f736ef-0877-4200-b0b2-a996ef20cca0`; the earlier one,
`18d87c6b-5f7b-4290-a08b-f07a32565511`, is the rollback point; `/health`
answered `ok` and a Conditionals practice request `200`) and installed the
build of `ui-polish-widgets` over his test build. On the phone: the ten
topic cards show, practice sets of the new topics generate and are scored,
and their weak spots appear in Review. He found one flow defect (item 1) and
two things to look into (items 2 and 3). This round fixes them on
`ui-polish-widgets` for his next check, which is the next morning before
that day's Daily Test.

## Rules

As in `FIX4.md` ("Rules"), unchanged; decisions in `PROGRESS.md` as F6-1,
F6-2, …. In addition: no deploy, no API call, nothing under `proxy/`
changes, no version bump. Never run `dart format` over all of `lib/`.

## 0. Start

1. `df -h ~`; the same allowed deletions as `FIX3.md` §0; aim to finish with
   at least 15 GB free.
2. `git switch ui-polish-widgets`, `git pull --ff-only`. Commit this file
   first: "docs: fix round 6 task"; push.

## Items

**1. The day's step plays before the rest scene (SPEC §1.8, V24, V24f).**

What the owner saw: he had used his free practice ticket before the Daily
Test. After the test, "See your climb" on the result screen opened the rest
scene at once. The mountain, the walk to the new step, the pawn and the
save point's gold ring were never shown.

What the code does today (`lib/screens/home_screen.dart`, the block "V24
(SPEC §1.8): once every daily right is used, the rest scene replaces Home's
content"): the rest scene is returned as soon as `_restDay` is true, also
while the finished test's step is still pending (`_pendingClimbDay`) or
walking, and `_climbAnimating` is set to false there because "a step that
was still walking never reports its end". So in the order practice first,
test second (free: the ticket; Premium: every session of the day) the step
is never seen. Confirm this diagnosis before changing anything.

The owner's decision (2026-11-19): the climb plays, the pawn settles on its
new step, and after a short pause the rest scene comes by itself, in the
same visit. Not on the next visit to Home.

Required behaviour:

- While a step of today's Daily Test is pending or playing, Home shows its
  normal content with the mountain, brings the mountain into view and plays
  the step exactly as on a day when practice is still unused: the walk, the
  landing, and whatever follows a step today in today's order (save point
  ring and celebration, medal, month card).
- When the last of these has ended and nothing is above Home, wait a short
  beat with the pawn at rest (about one second; choose the value and record
  it), then change to the rest scene with a short transition, not a hard
  cut. Reduce Motion: the step is shown at its new place without the walk,
  the same beat, then the change as `AppMotion` reduces it.
- N01 keeps its rule from fix round 3 (A2): it opens on the first frame the
  rest scene is on screen, so it now follows the delayed scene.
- Home not visible when the test is saved (another tab, a route above):
  the step plays when Home becomes visible, as today; the rest scene only
  after it.
- The user leaves Home during the walk or the beat (another tab, a pushed
  route, the app in the background): on return the rest scene is shown and
  the step is not replayed.
- No step to show (the completion earned no step, Day 0, the climb failed
  to load): the rest scene comes as it does today. On no path does the user
  stay on normal Home with every right used for longer than the step and
  the beat.
- The other order (test first, last practice second) does not change.

Tests (widget tests; each bug path with a regression test): free with the
ticket used and then the test; Premium with every session used and then the
test; the unchanged order; a save point day (the ring is shown before the
scene); Reduce Motion; Home not visible at the save; leaving during the
beat; N01 only once the scene is on screen; no step to show. Captures in
`build/fix6-captures/`: a frame strip of the walk, the pawn at rest and the
rest scene, light and dark.

**2. The Daily Test card's companion: is the hop there? (SPEC X05;
`DEVICE-CHECKS.md` "hops while it waits").**

What the owner saw: the companion on Home's Daily Test card moves "as if
breathing"; he would not call it a hop. The code asks for the hop
(`lib/widgets/daily_test_card.dart`: `hopping: true`, which is
`CompanionAmbient.hop`, 16 pt up every 1.2 s). Find out what is drawn:
capture the card frame by frame on a simulator and measure the companion's
vertical travel. If something reduces or stops the hop (the slot clipping
it, the idle mood's loop winning over the ambient one, a ticker that is
off, a scale), fix it to the spec, with a test. If the hop runs as
specified, change nothing: record the measured travel and a frame strip in
`PROGRESS.md` so that the owner can decide whether the specified hop is
large enough at this size. No redesign in this round.

**3. Review's inline mistake on the new topics (V16, R03; 1.4.0 B10,
`lib/utils/answer_diff.dart`, `InlineMistake` in
`lib/widgets/review_parts.dart`).**

What the owner saw, after one practice set each of Relative Clauses,
Prepositions and Passive Voice: three weak-spot cards show the whole
corrected sentence with the right words in green and then, appended after
it, a long struck-through piece of the learner's side, instead of the wrong
words struck in place.

- On two cards one word differs (a relative pronoun; a preposition), yet
  the struck piece is the second half of the sentence, about eight words.
- On the third (Passive Voice; a fill-in item whose line reads like
  `Complete with the verbs in brackets: 'The reports ____ (send)
  yesterday.'`) the struck piece starts inside the instruction ("the verbs
  in brackets: '…") and carries the bracketed base verbs.

The example line above is invented to show the shape; the real texts are on
the owner's phone only and must not be asked for or committed.

Expected (R03): the learner's wrong words struck in place, the right ones
green, the rest plain; never a piece of the instruction, never the
bracketed cue words.

Read from the code how the practice flow stores `userAnswer`,
`correctedAnswer` and `prompt` for each question type the five new topics
produce (do not guess), and reproduce with fixtures of these shapes: a
blank-bearing line that starts with an instruction and a quotation mark; a
blank followed by a base form in brackets; several blanks in one sentence;
an answer stored as the prompt with its blanks filled. Find the cause, then
fix it in the diff or in what is stored. Records already on users' phones
must render no worse, and B10's cases stay as they are (their tests stay
green). Check whether the five older topics' cards can show the same. If it
cannot be reproduced from the shapes the code produces: change nothing,
write what was tried, and ask in `PROGRESS.md` for the owner's capture of
that weak spot's detail screen ("You wrote" / "Corrected").

## Not in this round (recorded only)

The owner's two product observations of the same day are decisions for the
version after 1.5.0, together with the 4th tab; no work on them here:

- A Premium user reaches the topics only through the row of cards at the
  bottom of Home; the button under that row opens Review's mistake, not the
  topics.
- A free user who has done the Daily Test and the day's practice sees
  nothing of the topics on offer (the rest scene says "one of 10 topics"
  without showing them).

Also only recorded: on Topic Practice the "Picked for you" card leaves nine
cards in the two-column grid, so the last row has one card. The owner
accepts this for now.

## Checks

- After the last code change: `flutter analyze` no issues; `flutter test` all
  pass; Swift tests pass; the simulator build with `xcodebuild` (as in round
  5); `flutter build ios --release --no-codesign`.
- A smoke walk on the simulator in Turkish as a free user: use the ticket,
  then do the Daily Test, tap "See your climb": the step plays, the pawn
  rests, the rest scene follows. Then the other order on a fresh install.

## Docs

- `PROGRESS.md`: a "Fix round 6" section at the top (items 1–3: what was
  seen, the cause, the fix or the finding, the tests; decisions F6-n; checks;
  not verified) and an updated summary.
- `SPEC.md`: §1.8 gains one sentence, that the rest scene follows the day's
  step and a short beat; list it in the header as v14. Nothing else changes.
- `docs/build-log.md`: one dated entry. `docs/roadmap.md`: the Worker is
  deployed for 1.5.0 (owner, 2026-11-19, the version ids above); fix round 6
  done on `ui-polish-widgets`, waiting for the owner's next check.
- `product.yaml`: a completed-fix entry on top of `recent` (five at most);
  the `planned` lines that still say the proxy is not deployed are brought
  up to date (deployed by the owner on 2026-11-19, device checks under way,
  not merged, no build for the store yet); `updated_at`. `legal`, `status`
  and `versions` unchanged. Write only what this file states as checked on
  the device; nothing else is to be shown as confirmed.
- `DEVICE-CHECKS.md`: a new top section "Fix round 6 — the next morning":
  build and install over the current test build (the same commands as
  FR5-1, no Xcode step). Then, as a free user and before that day's Daily
  Test: Home's first view (the pawn and the gold ring), the widgets'
  "before the test" state, T-4. Then: use the ticket, do the Daily Test,
  "See your climb" (the step walks, the pawn rests, the rest scene follows),
  T-5. Then Review's cards for the new topics (item 3) and the card
  companion (item 2). In the "First-wave topics (1.5.0)" section mark T-1
  and T-3 as seen by the owner on 2026-11-19 and leave the others as they
  are. No VoiceOver check is asked for.

## Done means

1. Items 1–3 and steps 0, Checks and Docs are each closed in `PROGRESS.md`
   "Fix round 6" (or marked "not done" with the reason).
2. After the last code change: analyze clean, all Flutter and Swift tests
   pass, the `xcodebuild` simulator build and the release build
   (`--no-codesign`) succeed.
3. `DEVICE-CHECKS.md` has the "Fix round 6 — the next morning" section.
4. `ui-polish-widgets` is pushed with a clean `git status`; `main` untouched;
   nothing deployed.

Code, comments, commit messages and all docs stay in English.
