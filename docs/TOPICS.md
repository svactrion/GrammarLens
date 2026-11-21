# First-wave topics — quality measurement, then release prep (1.5.0)

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, `proxy/eval/README.md`,
`docs/1.4.0-measurement-report.md` (how the last measurement was run and
reported), and in `docs/design/ui-polish/handoff/`: `SPEC.md` §1.11 and
"First-wave topics (no board)", `PROGRESS.md` (B7: what was built and where).

## Goal

The owner decided that the five first-wave practice topics ship in 1.5.0:
Conditionals, Passive Voice, Prepositions, Relative Clauses, Comparatives &
Superlatives. Their app and proxy code exist and are switched off
(`kFirstWaveTopicsEnabled`, `FIRST_WAVE_TOPICS_ENABLED`). Before they are
switched on, measure the quality of what the live pipeline produces for them,
let the owner review a sample, and only then prepare the switch.

## Rules

- Work on `ui-polish-widgets` (where the topic code is). Small commits, pushed.
- **No API call from this session.** The paid run is started by the owner in
  his own Terminal with the key in the environment, as in 1.4.0 step E. Build
  the tooling, prove it with a dry run, write the owner's commands, stop.
- **Budget: $15.00 of measured spend, hard cap**, checked before every call
  as in `eval/run.ts` (spent + estimate × 1.25 ≤ cap, else skip and record).
  The dry run must estimate at most $12 so the cap has room.
- The key: read from `process.env.ANTHROPIC_API_KEY` only; never written to a
  file, log, report or commit; every write goes through the existing check
  that refuses content containing it.
- No deploy, no `wrangler` command that writes, no change to the production
  flags or to the Daily Test (it keeps its five topics). No new packages.
- Decisions in `docs/1.5.0-topics-progress.md` as T-1, T-2, … (question ·
  options · choice · why), the same way as `PROGRESS.md`.

## Start

`git switch ui-polish-widgets` and `git pull --ff-only` (the branch is where
the topic code is). Commit this file first: "docs: first-wave topics
measurement task"; push.

## Phase A — the measurement tooling (this session, unattended, then stop)

1. Add a `topics` measurement to `proxy/eval` (reuse `run.ts`'s call, retry,
   spend accounting, resumable run folders, `progress.log`, the key check):
   - **Generation:** for each first-wave topic, 6 Topic Practice sets of 5
     questions through the live practice path (the production prompts,
     model, effort and quality gate) with the first-wave topics enabled
     **for the measurement only** (a parameter, not the constant). Add one
     existing topic as a control (3 sets), so the new topics can be compared
     with one that is already live.
   - **Scoring:** for every generated question, a small answer set built by
     construction (the key; an accepted variant when the item lists one;
     two typical learner mistakes for that rule), scored with the production
     scoring cell (`claude-haiku-5-5`, low, D3 + D11; 1.4.0 report §2, C8).
     Sentence-writing items, if the practice path produces them, get two
     learner sentences (one right, one with a typical mistake).
   - **Automatic checks** on every generated question, recorded per item:
     the item is about its topic; a single blank has one natural answer
     (flag the "several answers fit" risk, e.g. who/that, in/at); no
     duplicate or near-duplicate inside a set and across sets; length and
     level within the existing limits; the hint card's rule agrees with the
     key.
   - `--dry-run`: no call; prints the calls per stage and the estimated
     spend from `matrix.ts`'s prices.
2. Unit tests for the new code (vitest, no network). `npm run typecheck`
   clean.
3. In `proxy/eval/README.md`, a new "Owner checklist — first-wave topics"
   section, written for the macOS Terminal app, copy-paste, one command per
   block: go to `~/GrammarLens/proxy`; put the key in the environment for
   that Terminal only (`read -s ANTHROPIC_API_KEY && export
   ANTHROPIC_API_KEY`, paste, Enter); the dry run; the run; what "done"
   looks like in `progress.log`; what to tell Claude Code afterwards.
   Recommend a separate Console key for the run (its spend shows on its own
   line; revoke it afterwards).
4. Record the dry run's numbers in `docs/1.5.0-topics-progress.md`, commit,
   push. **Stop here.**

## Phase B — after the owner's run (a new prompt will start it)

The owner's run is `proxy/eval/out/topics-2026-11-18T16-35-34-632Z` (last
line: "topics run done: 189 calls ok; spent $0.76 of $15.00"). **No API call
in this phase**, and no change to the run folder's records.

Owner decisions of 2026-11-18, made after phase A (record them in
`docs/1.5.0-topics-progress.md` as T-12, T-13, …):

- **Every question is labelled, not a sample.** All 150 questions of the
  five new topics, and the control's 15, go on the sheet. Why: with 10 per
  topic a topic passes "at most 5 % defective" only at 0 defects, and 0 of
  10 still leaves a true rate of up to 26 % open (95 %); with 30, one defect
  passes and two fail.
- **The built answers are labelled too.** By T-2 the key, the second answer
  and the mistakes are model-written, so "right / wrong by construction" is
  a claim, not the truth: a "mistake" that is in fact acceptable would be
  counted against the scorer. Phase C's scoring metrics use the labelled
  truth.
- **The sheet is blind.** It shows what a learner sees and the built
  answers, nothing else: no automatic flag, no gate result, no scorer
  verdict or explanation, and not which built answer is the key, the second
  answer or a mistake.

1. `topics analyze --out DIR` writes `docs/1.5.0-topics-report.md` with, per
   topic and for the control: sets and items generated, the gate's pass
   rate, each automatic check's flags, the scoring results on the built
   answers (agreement, false "correct" among wrong answers, false "needs
   work" among right answers), measured spend and time. State the
   limitations up front: the answers are built, not real learners'; their
   truth is by construction until phase C; the automatic checks are flags,
   not verdicts. Counts and rates only: no question text, no answer text and
   no sheet key in the report (generated content stays out of the repo, and
   the labellers read the report).
2. Duplicates, because the run flagged 15 of 30 conditionals questions and
   11 of 30 prepositions questions against 0 of the control's 15: in the
   report, per topic, the flags split into the same words / near-duplicate
   and inside a set / across sets, and the sizes of the groups of questions
   that resemble each other. Also say, from the code and with no change to
   it, what makes two Topic Practice sets of one topic differ on the live
   path today (what the app and the Worker send: anything about earlier
   questions, a seed, a list to avoid, or nothing). The resembling questions
   side by side go to the details file (step 4), not into the report.
3. The blind label sheet (in the gitignored place 1.4.0 used for generated
   content; no generated content in a commit):
   - one file to read, plain text or Markdown: the app's hint card of each
     topic once at the top; then per question, under an opaque key and in
     mixed order across topics, the topic's title, the question as the app
     shows it (context, instruction, hint), and its built answers under
     letters in a shuffled order;
   - one file to fill, which `topics analyze` reads back in phase C and
     checks (it names every row that is unlabelled or has a value outside
     the vocabulary): per question `verdict` (`ok` | `defect`), `why` when
     it is a defect (`several_answers` | `off_topic` | `bad_english` |
     `hint_wrong` | `level` | `other`, and a free note), `also_accept`
     (answers that must count as right and are not among the built ones),
     and per built answer `right` | `wrong` | `unsure`;
   - the mapping from the keys and letters to the run's ids, in a third
     file the labellers do not open.
   A question that failed the gate or has no built answers is on the sheet
   like any other.
4. A details file in the run folder for after the labels (per question: the
   flags, the gate, the scorer's verdicts and explanations; the resembling
   questions side by side). The labellers do not open it before the sheet is
   filled; say so at its top.
5. Unit tests for the new code (no network), `npm run typecheck` clean.
   Commit, push, **stop**, and name the sheet's three files in the last
   message. The sheet is labelled in the owner's Cowork chat: Claude labels
   first, the owner spot-checks.

## Phase C — after the labels (later prompt)

The sheet is filled (2026-11-18): 165 of 165 rows, labelled by Claude in the
owner's Cowork chat and checked by the owner; `topics analyze` reports
nothing to fix. 4 questions are labelled `defect`, 6 built answers `unsure`.
The `private` folder and the run's own files may be opened from now on.
**No API call in this phase.**

Owner decision of 2026-11-18 (record it in `docs/1.5.0-topics-progress.md`
under the next T number): **a question with more than one right answer is
not a defect for that reason.** The scorer is a model and matches no key, so
"who" and "that" can both be right; a question is a defect only when it
contradicts itself, teaches something false or cannot be answered. The
labels mark such questions with a note that starts `multi:`, and lesser
blemishes with a note that starts `minor:`. The risk moves to the scorer (a
right alternative called "needs work"), so this phase shows it per topic.

1. Fold the labels into the report, per topic (30 questions; the control
   15): the defect rate after the gate, with the questions that failed the
   gate counted apart and the defects by `why`; how many questions carry a
   `multi:` note and how many a `minor:` note.
2. Scoring against the labelled truth, per topic and for the five new topics
   together: agreement, false "correct" among wrong answers, false "needs
   work" among right answers; `unsure` answers counted apart, in neither
   rate. Split the false "needs work": on the built key, on the other
   answers labelled right, and on the questions noted `multi:`. Also count,
   per topic, where the labelled truth differs from the construction (a
   built mistake labelled right, a built right answer labelled wrong).
3. A second-look file in the run folder (not in the repository), as 1.4.0's
   `second-look-C8.md`: every answer where the scorer and the labelled truth
   differ, with the question, the answer, the label's note and the scorer's
   verdict and explanation; and the defect questions with what the automatic
   checks and the gate said about them.
4. Pass criteria (owner), stated per topic with the counts behind each: at
   most 5 % defective questions after the gate, scoring agreement at least
   95 %, false "correct" at most 2 %. For a topic that fails: the cause and
   a proposed prompt or hint-data fix; a re-measurement of that topic only,
   after the owner's OK (new spend, same cap rules). Say also what the
   automatic checks were worth: how their flags relate to the labels.
5. Set variety: propose, do not build. Phase B found that two Topic Practice
   requests for one topic are the same request, and the run's sets repeat
   scenarios. Give two or three ways to make sets differ (for example a
   scenario or theme the Worker draws at random, or recent questions to
   avoid), each with what would change in the app, the Worker and the
   prompt, its cost per set, whether it sends new data (the legal pages),
   whether it applies to the five live topics too, and whether it needs a
   new measurement; then a recommendation. The owner decides.
6. No question text, no answer text and no sheet key in the report or in any
   commit: describe a defect in words. Unit tests for the new code (no
   network), `npm run typecheck` clean. Commit, push, **stop**.

## Phase C2 — Conditionals: the fix and its re-measurement (later prompt)

Phase C's result: Passive Voice, Prepositions and Relative Clauses pass all
three criteria; Comparatives & Superlatives fails false "correct" by one
answer; Conditionals fails on agreement and on false "correct", and its
failures sit on one structure, the mixed conditional. **Owner decision of
2026-11-18 (record it under the next T number): fix Conditionals as phase C
proposed and measure that topic again.** The owner's other decisions
(Comparatives & Superlatives, set variety, the scoring prompt) are still
open and are not part of this phase.

This session: build, prove with a dry run, write the owner's commands, stop.
**No API call**, no deploy, the production flags stay off.

1. The fix: a generation-only note for Conditionals in the Worker's topic
   table, added to the practice request's topic line and never sent to or
   shown in the app: the items use the first, second and third conditional
   (the three the hint card teaches) and no mixed conditional. Nothing else
   in any prompt changes and the hint card stays as it is. Tests: the note
   is in the Conditionals request and in no other topic's; the requests of
   the five live topics are byte for byte what they were; the route still
   refuses the first-wave ids.
2. The re-measurement's tooling: `topics --dry-run --only conditionals` and
   `topics run --only conditionals [--out DIR]`: a run folder of its own,
   6 sets, the answers, the scoring, the checks, as in the first run. The
   $15.00 cap is on the measurement as a whole: this run counts the first
   run's $0.76 as already spent.
3. `topics analyze --out DIR` on that folder: its blind sheet and private
   files as in phase B (the same blindness, the same three sheet files and
   details file), and once the sheet is filled its phase C tables and
   second-look file. In `docs/1.5.0-topics-report.md` the re-measurement is
   a section of its own after the first run's, which stays as it is; the
   report says that the re-measurement is the Conditionals result that
   counts, and how many of its questions the hint-card check still marks as
   a mixed conditional (whether the note worked).
4. From the code, with no change: what the app shows today for a
   fill-in-the-blank item that has no blank, and whether anything on the
   live path stops such an item. Propose a guard if one is missing; do not
   build it. In the progress doc.
5. In `proxy/eval/README.md`, "Owner checklist — Conditionals
   re-measurement", in the style of the first checklist: a new separate
   Console key in the Default workspace; the key into the environment of
   that Terminal only; the dry run; the run; what "done" looks like; then
   the `topics analyze --out …` command that writes the sheet (no key
   needed); then: tell Claude in the Cowork chat that the sheet is ready.
6. Unit tests (no network), `npm run typecheck` clean, the dry run's numbers
   in the progress doc. Commit, push, **stop**.

After the owner's run the sheet (30 questions) is labelled in the owner's
Cowork chat as before; a later prompt folds the labels in, with the same
three criteria.

## Phase C3 — the final configuration and its measurement (later prompt)

Where things stand (2026-11-19). The Conditionals re-measurement ran
(`proxy/eval/out/topics-conditionals-2026-11-19T03-29-29-295Z`, 35 calls,
$0.13; the measurement as a whole has spent $0.89 of $15.00) and its sheet
is filled: 30 of 30 rows, 3 questions labelled `defect`, all three a
fill-in-the-blank item without a blank, 1 built answer `unsure`. The note
kept mixed conditionals out. The run also showed two things the criteria do
not catch: half of that topic's fill-in-the-blank items came without a
blank (the gate stops them in the measurement; nothing stops them on the
live path), and one scenario came back in all six sets.

**Owner decisions of 2026-11-19 (record them under the next T numbers):**

- **Items without a blank:** both measures. The Worker removes a
  fill-in-the-blank item that has no blank from a practice response and
  serves the rest; and the generation prompt says that such an item has
  1 to 4 blanks, each written as underscores.
- **Set variety: option A of `docs/1.5.0-topics-set-variety.md`, for all ten
  topics, now.** The Worker gives each practice set a scenario theme from
  the Daily Test's 14 approved themes, stepped per device from what the
  quota check already reads; one line in the user prompt; no app change, no
  new data sent.
- **Comparatives & Superlatives is not waved through.** The scoring prompt
  gets the two changes phase C proposed, as a candidate: the verdict follows
  the scorer's own correction (when its corrected answer changes the
  learner's answer in the structure the item tests, the answer is not
  correct), and a misspelling in the form the item tests is a mistake. The
  candidate becomes the production prompt only on the owner's word, after
  the numbers below.
- Because every topic's request changes, **the configuration that will ship
  is measured once more as a whole**, the five live topics included.

This session: build, prove with a dry run, write the owner's commands, stop.
**No API call**, no deploy, the production flags stay off.

1. Fold the labels of the Conditionals re-measurement into the report (its
   section, the three criteria, its second-look file), as phase C2 planned.
2. The Worker (source and tests only):
   - the guard on the practice route, and what the app does with a practice
     set that arrives a question short (read the app's code; if it would
     break or mislead, say so and propose, do not change the app here);
   - the generation prompt's line on blanks (all topics);
   - the theme for a practice set (all ten topics), with tests that a
     released app's request still works and that consecutive requests of
     one device get different themes;
   - the scoring prompt candidate beside the production prompt, selectable
     by the measurement, not live.
   Since the Conditionals note of phase C2 stays, say in the progress doc
   what each topic's request now adds to the one measured in the first run.
3. The measurement, `topics final --dry-run` and `topics final run [--out
   DIR]`, a run folder of its own:
   - generation with the final request for all ten topics, 6 sets each, the
     themes stepped as one device's consecutive requests would get them;
   - the automatic checks on all 60 sets (duplicates above all, against the
     first run's numbers; and how many items the guard would remove);
   - answers, scoring and labels for the five new topics on all 6 sets
     (150 questions) and for the five live topics on 3 sets each
     (75 questions);
   - every built answer scored twice, with the production scoring prompt
     and with the candidate.
   And `topics rescore`: the labelled answers of the first run (464) and of
   the Conditionals re-measurement (75) scored with the candidate, compared
   with their labels and with the production prompt's stored verdicts:
   agreement, false "correct", false "needs work", per topic, before and
   after. The $15.00 cap is on the measurement as a whole; the dry run's
   estimate for both commands together must leave it room.
4. `topics analyze --out DIR` on the final folder: the blind sheet (225
   questions, the same three files, the same blindness), the private files,
   and once the sheet is filled a "Final configuration" section of the
   report: the three criteria per new topic with both scoring prompts, the
   live topics for reference, the duplicates before and after the themes.
   The earlier sections stay as they are.
5. In `proxy/eval/README.md`, "Owner checklist — final configuration": the
   key into the environment of that Terminal only; the dry run; `topics
   rescore`; `topics final run`; what "done" looks like for each; the
   `topics analyze` command that writes the sheet; then: tell Claude in the
   Cowork chat that the sheet is ready.
6. Unit tests (no network), `npm run typecheck` clean, the dry run's numbers
   in the progress doc. No question text, no answer text and no sheet key in
   any commit. Commit, push, **stop**.

After the owner's run the sheet is labelled in the owner's Cowork chat; a
later prompt folds the labels in. The owner then decides, topic by topic,
what goes to phase D, and whether the candidate becomes the scoring prompt.

## Phase C4 — the scoring prompt, second attempt (later prompt)

Where things stand (2026-11-19). The final configuration ran and is
labelled (`proxy/eval/out/topics-final-2026-11-19T04-12-48-488Z`; the
measurement has spent $2.52 of $15.00). The generation changes worked: no
item without a blank, no resembling questions in the new topics, 3 defects
in 225 questions. All five new topics pass the defect and the agreement
criteria; Prepositions, Comparatives & Superlatives and Conditionals fail
false "correct" by one or two answers each. The first scoring candidate was
worse than the production prompt on every count.

**Owner decisions of 2026-11-19 (record them under the next T numbers):**

- **The first candidate is dropped**, in whole and in its verdict rule.
- **The scoring criteria are read on all labelled answers together.** At
  45 to 49 wrong answers a topic, "at most 2 %" allows not one answer, so a
  single run cannot show a pass. False "correct" and agreement are
  properties of the scorer, and the production scoring prompt is the same in
  every run, so each topic's scoring numbers are pooled over the first run,
  the Conditionals re-measurement and the final run. The defect criterion
  stays on the final configuration's questions.
- **One more round for the scorer, with no new labels:** two small, separate
  sentences, each tried alone and both together, against the 1,190 labelled
  answers.

This session: build, prove with a dry run, write the owner's commands, stop.
**No API call**, no deploy, the production prompt and the flags unchanged.

1. Three candidates beside the production scoring prompt, none of them live:
   - **S**, the spelling sentence alone (a misspelling in the very form an
     item tests is a mistake; the keyboard variants stay acceptable);
   - **T**, a sentence on conditional types alone, for what the scorer
     accepted in every run: an answer whose two clauses belong to different
     conditional types where the sentence's own time words do not call for
     it. It must not make the scorer reject a correct third conditional
     whose result carries a phrase such as "by now", which the production
     prompt did twice;
   - **ST**, both.
   Each sentence is general, short, and uses no example that occurs in the
   labelled answers (check that, as before).
2. `topics rescore` for these candidates (one command for all three, a dry
   run first): every labelled answer of the three runs scored with each
   candidate, the same answers per call as in the stored runs. The $15.00
   cap is on the measurement as a whole.
3. The report gets a section for this round, written by the command when the
   run is done: for the production prompt and each candidate, per topic and
   pooled over the runs, agreement, false "correct" and false "needs work";
   the three criteria per new topic on the pooled reading, with pass or
   fail; and the count of verdicts each candidate changed, split into
   towards the label and away from it. A file in the run folder (not in the
   repository) lists every changed verdict with both scorers' words.
4. From the code, with no change: what the app shows when the scorer returns
   no usable verdict for one answer of a set (it happened for 3 of 651
   answers in the final run). In the progress doc.
5. In `proxy/eval/README.md`, "Owner checklist — scoring prompt, second
   round", in the style of the earlier ones (a new separate key; the dry
   run; the run; what "done" looks like; revoke the key). After the run the
   owner brings the last line to his Cowork chat, where the report's new
   section is read.
6. Unit tests (no network), `npm run typecheck` clean, the dry run's numbers
   in the progress doc. No question text, no answer text and no sheet key in
   any commit. Commit, push, **stop**.

## Phase D — release prep (the owner's go: 2026-11-19)

The measurement is closed at $3.83 of $15.00. The scoring prompt's second
round ran (`proxy/eval/out/topics-rescore-2026-11-19T05-20-02-911Z`, 960
calls, $1.31); its section of the report is written.

**Owner decisions of 2026-11-19 (record them under the next T numbers):**

- **All five first-wave topics ship in 1.5.0, with the production scoring
  prompt as it is.** No candidate becomes the production prompt; S, T and ST
  stay in the source and are not live.
- **The report says it as it is.** On the pooled reading Passive Voice,
  Prepositions and Relative Clauses meet all three criteria. Comparatives &
  Superlatives is one answer over the false "correct" line (2 of 95) and
  Conditionals is over it (5 of 132): both ship on the owner's acceptance,
  not as a pass. His reasons: the same answers scored four times moved a
  topic's count by one or two answers, so the 2 % line is finer than this
  measurement resolves; the weakest new topic is well under a topic that is
  live (Articles, 5 of 46); and the scorer is on the server, so it can be
  improved after the release without a new app version.
- **Three small fixes ship with it:** the Worker retries once when the
  scorer returns no usable verdict for an answer (as proposed in the
  progress doc); the loading screen does not promise a number of questions
  the set may not have; the app treats an empty practice set as a failed
  generation.
- **The Modal Past Forms hint card is rewritten to cover both** what that
  topic's questions ask today ("could" and "would" as the past of "can" and
  "will", also in reported speech) and modal + have + past participle. The
  owner's plan for the topic is mixed questions with a general card; making
  the questions mixed is a generation change and comes after 1.5.0 with a
  measurement.
- **After 1.5.0, not now:** repeated scoring to verify T; the wording that
  makes a correction item's sentence clearly wrong (phase C3's proposal);
  Articles' scoring; mixed Modal Past Forms questions.

The work:

1. **App.** `kFirstWaveTopicsEnabled = true` for all five. Topic Practice
   with ten cards (R01 layout at the five sizes and the largest text size).
   Every copy that counts topics uses the real count (the paywall's benefits
   and the V13c table: "All 10 topics"), in every language the app has. The
   new topics' weak spots on Review, V24f's dream bubble and the tip widget.
   The two app fixes above. The Modal Past Forms card: four short lines in
   the card's style, in every language the cards exist in; keep the
   harness's copy of the cards in step (its test pins them).
2. **Proxy.** `FIRST_WAVE_TOPICS_ENABLED = true` in code, the route's tests
   for the five ids, the retry with its tests. With the deploy the changes
   of phase C3 go live as well (the theme per set for all ten topics, the
   line on blanks, the guard, the Conditionals note). **No deploy from this
   session.**
3. **The owner's deploy checklist**, in `proxy/README.md` or beside it, for
   the macOS Terminal app: `npm run deploy` in `proxy/`; what to check right
   after (a released app still gets its practice sets and scoring; a new
   topic's id is accepted); how to go back to the previous version if
   something is wrong. The order is: deploy the Worker first, then the
   device checks on the release build (it talks to the live Worker), then
   the merge and the 1.5.0 build. Old app versions never send the new ids;
   they do get the themes, the guard and the retry.
4. **Device checks.** Add to
   `docs/design/ui-polish/handoff/DEVICE-CHECKS.md` what the owner should
   look at on his iPhone after the deploy: the ten cards, one practice set
   in each new topic through to its results, the copy with the topic count,
   the new topics on Review, V24f and the tip widget, the Modal Past Forms
   card. No VoiceOver checks.
5. **The report and the records.** A closing "Decision" section in
   `docs/1.5.0-topics-report.md` with the pooled table and the owner's
   decision in his terms above; the progress doc's phase table; roadmap;
   build log; `product.yaml` (`recent`, `planned`, `updated_at`; `legal`
   unchanged: no new data, no new service; `status` and `versions` are the
   owner's).
6. Flutter tests, Swift tests, the proxy's tests and typecheck, a release
   build. The version stays as it is (the bump belongs to the release
   prep). Commit in small steps, push, **stop**.

Code, comments, commit messages and all docs stay in English.
