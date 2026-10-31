# Measurement test sets and label sheets (1.4.0 server package)

What and why: `docs/1.4.0-server-batch0-report.md` §3.1. Everything here is
built by `npm run eval -- sets` (from `proxy/`) out of inputs that are in
the repo, with **no API call**; the owner's labels are added by hand to the
sheets below and committed with them. Nothing in this folder is deployed or
read by the Worker.

| File | What | Who fills it |
|---|---|---|
| `live-sets/set-<date>.json` | the 30 live shared sets in KV on 2026-10-31 (2026-09-26 … 10-25), fetched read-only with `wrangler kv key get` | — |
| `s-pool.scoring.json` | S-pool: 130 learner answers with their verdict, from the fallback pool (35 keys, 12 owner-accepted answers, 83 predicted wrong answers) | — (already labelled by the pool's corrections) |
| `s-pool.gate.json` | S-pool for the P14 gate: the 10 owner corrections as the answers a checker should rediscover, by live date and question id | — |
| `s-live/labels.csv` | **S-live, the owner's blind sheet:** 100 questions from the 20 prompt-v2 live sets the owner has not reviewed (2026-09-29, 10-07 … 10-25), shuffled under random keys | **owner, ≈ 65–70 min** |
| `s-live/mapping.json` | which date each key came from. **Do not open until the sheet is done.** | — |
| `s-live/questions.json` | the same 100 questions in date order (for the analysis, not for labelling) | — |
| `s-synth.json` | S-synth: 166 learner answers of known quality (105 keyboard variants, 5 contractions, 1 spelling, 35 near-misses, 20 multi-blank cases) | — |
| `s-synth-review.md` | **the readable list of S-synth for the owner's review** | **owner, ≈ 15 min** |
| `s-synth-exclusions.txt` | ids from the review the owner disagrees with, one per line (create it if needed) | owner |
| `templates/s-gen-labels.csv`, `templates/s-free-labels.csv` | the headers of the S-gen and S-free sheets; the sheets themselves are written by the measurement run after the generation calls | owner, later (≈ 50 + 40 min, see below) |

**Provenance (2026-10-31):** the S-live labels were written by Claude in
the owner's Cowork session and reviewed by the owner, who confirmed every
`defect` and every `accept_also`; S-synth was reviewed with no exclusions.
The measurement report states this limitation.

## Labelling S-live (`s-live/labels.csv`)

Open it in Numbers or Excel; keep the header and the `key` column. The
rows are shuffled, and each key starts with a letter so a spreadsheet never
reads it as a number. Each row shows one question as the learner would see
it: `topic`, `type`, `context`, `instruction`, `hint`, `correct_answer`,
`predicted_wrong_answers` (each "answer — comment", separated by `||`),
`explanation`. Fill in:

| Column | What to write |
|---|---|
| `label` | `ok`, `minor` or `defect` (required) |
| `defect_types` | for `defect`, one or more of `original_not_wrong`, `key_incorrect`, `multiple_answers`, `wrong_answer_acceptable`, `wrong_rule`, `other`, separated by `;` |
| `accept_also` | **the answers you would also accept that are not the key, separated by `\|`** — this column is the P14 gate's truth, so fill it even on an `ok` row when another answer is defensible |
| `note` | anything (optional) |

`defect` vs `minor`, as in E: *"If this went to every learner, would a
careful learner end up believing something false about the tested grammar,
or be marked wrong for a right answer they are likely to type?"* Yes →
`defect`; no, but you would change something → `minor`; nothing to change →
`ok`.

Save it back as **CSV (UTF-8)** under the same name. Numbers may export
with `;` separators (regional setting); if the first line reads
`key;topic;type;…`, convert it from `proxy/`:

```bash
python3 -c "import csv,sys; p=sys.argv[1]; rows=list(csv.reader(open(p,encoding='utf-8-sig',newline=''),delimiter=';')); csv.writer(open(p,'w',encoding='utf-8',newline='')).writerows(rows)" eval/data/s-live/labels.csv
```

## Reviewing S-synth (`s-synth-review.md`)

Every answer is right or wrong **by construction**: a keyboard variant of
the key is "correct", a near-miss is "wrong", a contraction or spelling
variant is "correct". Your job is to catch the lines where the construction
is wrong for that question: a contraction that does not fit, a near-miss
that is in fact acceptable, a multi-blank key you would write differently.
Put each such id into `s-synth-exclusions.txt`, one per line; those
answers are left out of the run. The five multi-blank items and their keys
(from the app's debug sets) are at the end of the file.

## Now: S-gen, S-free and the optional S-dt (written by stage 1, 2026-10-31)

| Sheet | Rows | Labels | Time |
|---|---|---|---|
| `s-gen/labels.csv` | 150 (25 per generation cell; the cell only in `s-gen/mapping.json`) | `ok`, `ambiguous`, `blank_count_wrong`, `unnatural`, `other` | ≈ 50 min |
| `s-free/labels.csv` | 75 (one learner answer per D3-cell item; the writer's intended target only in `s-free/mapping.json`) | `correct` or `wrong` — your verdict is the truth the scorer is measured against | ≈ 20 min |
| `s-dt/labels.csv` | 60 (the twelve v2/v3 Daily Test sets' questions; the version and date only in `s-dt/mapping.json`) | as S-live: `ok` / `minor` / `defect`, `defect_types`, `accept_also` | ≈ 40 min, **optional**: without it the v2/v3 check rests on the gate pass rate and the checker findings |

Save each as CSV (UTF-8) under the same name; the `;`-separator note above
applies. Stage 2 refuses to start while an S-gen or S-free row is
unlabelled; S-dt may stay empty.

## Then: stage 2 and the report

From `proxy/`, in the shell that holds the key:

```bash
npm run eval -- measure score --out eval/out/measure-2026-10-31T08-04-39-515Z --dry-run
```

```bash
caffeinate -i npm run eval -- measure score --out eval/out/measure-2026-10-31T08-04-39-515Z
```

(eight scoring cells over the same 75 calls, then the repeat of C1, C4 and
C8; about 40 minutes and 13 USD; the cap of 30 USD counts the whole run
folder.) Then, in any shell, no key needed:

```bash
npm run eval -- measure analyze --out eval/out/measure-2026-10-31T08-04-39-515Z
```

writes `docs/1.4.0-measurement-report.md`. The same command already wrote a
stage-1 draft of it (the gate and the Daily Test sections are real; the
scoring sections are empty until stage 2).

## After the run: the owner's judgments and the follow-ups (2026-10-31)

- `gate-judgments.json`: the owner's verdict on every accepted answer the
  gate wrote outside the labelled truth (right: may be written, joins the
  truth; wrong: right English that defeats the tested rule). `measure
  analyze` applies it and re-runs the decision rules offline on the stored
  checker outputs, so the report's §5 shows what the production step would
  write today. New answers the single-review gate writes outside the truth
  appear in §5's table with an empty judgment: add them here.
- `second-look-C8.md` in the run folder (written by `measure analyze`):
  the candidate scorer's 8 false "needs work" answers and its 21
  differences from production, each with the question, the learner's
  answer, the truth, both verdicts and both explanations, for the owner's
  right / wrong after "Owner:".
- Six more dates per version for the v2/v3 check, in the key-holding shell
  (12 calls, about 0.25 USD):

```bash
npm run eval -- measure dt-more --out eval/out/measure-2026-10-31T08-04-39-515Z
```

  It writes `s-dt-2/labels.csv` (60 rows, blind, as S-dt; about 40 min);
  `measure analyze` then reads both sheets.

## Later: S-gen and S-free (how they were planned)

After the generation calls (step E), the run writes `s-gen/labels.csv`
(every generated practice item, 6 cells × 25 = 150 rows: `ok`,
`ambiguous`, `blank_count_wrong`, `unnatural`, `other`; ≈ 50 min) and
`s-free/labels.csv` (one learner answer per item of the three D3-prompt
cells, written blind for the scorer, 75 rows: `correct` or `wrong`;
≈ 20 min; owner decision 2026-10-31). Both shuffled under random keys,
with the cell in a mapping file you open afterwards. Labelling in all:
about 2 h 30 min.

## Running the measurement (step E)

From `proxy/`, with the key in the environment of that shell only (a
separate key **scoped to a workspace**: an organisation-level key is
refused by the API with "This API key is not scoped to a workspace", as
on 2026-10-31; the run never reads `.dev.vars` and never writes the key
anywhere). `npm run eval -- measure probe` makes one Haiku call and prints
the API's message, before anything larger:

```bash
read -s ANTHROPIC_API_KEY && export ANTHROPIC_API_KEY
```

```bash
npm run eval -- measure --dry-run
```

```bash
caffeinate -i npm run eval -- measure run
```

Stage 1 (generation, the S-free writer, the Daily Test v2/v3 check, the
gate; about 35 minutes, about 5 USD) writes `s-gen/labels.csv` and
`s-free/labels.csv` here and `eval/out/measure-…/stage1-report.md`
(measured spend against the estimate). Then you label the two sheets
(about 70 minutes); stage 2 (scoring) follows. A stopped run resumes with
`--out eval/out/measure-…`. The cap is 30 USD of measured spend. Unset the
key afterwards (`unset ANTHROPIC_API_KEY`).

## Rebuilding

`npm run eval -- sets` rewrites every derived file **except**
`s-live/labels.csv` and `s-live/mapping.json`, which are left alone once
they exist (the sheet is deterministic anyway: a fixed seed). To refresh
`live-sets/`, fetch again read-only from `proxy/`:

```bash
npx wrangler kv key get --binding DAILY_SETS_KV --remote "set:2026-10-25" > eval/data/live-sets/set-2026-10-25.json
```
