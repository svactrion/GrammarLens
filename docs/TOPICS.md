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

1. `analyze`: `docs/1.5.0-topics-report.md` with, per topic and for the
   control: sets and items generated, the gate's pass rate, each automatic
   check's flags, the scoring results on the built answers (agreement, false
   "correct" among wrong answers, false "needs work" among right answers),
   measured spend and time. State the limitation up front (the answers are
   built, not real learners'; labels come in phase C).
2. A blind label sheet in `proxy/eval/data/` (gitignored if it holds
   generated content, as in 1.4.0): 10 questions per new topic (50), mixed
   order, each with its key, accepted variants and the model's explanation,
   and a column for the owner's verdict (ok / defect + why / also accept).
3. Commit, push, **stop.** The owner labels the sheet with Claude in his
   Cowork chat.

## Phase C — after the labels (later prompt)

Fold the labels into the report: per topic defect rate and scoring metrics
against the owner's labels. Pass criteria (owner): at most 5 % defective
questions after the gate, scoring agreement at least 95 %, false "correct"
at most 2 %. For a topic that fails: the cause and a proposed prompt or
hint-data fix; a re-measurement of that topic only, after the owner's OK
(new spend, same cap rules).

## Phase D — release prep (only on the owner's go, later prompt)

App: `kFirstWaveTopicsEnabled = true` for the passing topics; Topic Practice
with ten cards (R01 layout at the five sizes and the largest text size);
every copy that counts topics uses the real count (the paywall's benefits
and the V13c table: "All 10 topics"); the new topics' weak spots on Review,
V24f's dream bubble and the tip widget. Proxy: the flag on in code, tests,
**no deploy** — the owner deploys from his Terminal (`npm run deploy`),
before the 1.5.0 build is submitted (old app versions never send the new
ids). `product.yaml`: `recent`, `planned`, `updated_at`; `legal` unchanged
(no new data, no new service).

Code, comments, commit messages and all docs stay in English.
