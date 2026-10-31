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

## Later: S-gen and S-free

After the generation calls (step E), the run writes `s-gen/labels.csv`
(every generated practice item, 6 cells × 25 = 150 rows: `ok`,
`ambiguous`, `blank_count_wrong`, `unnatural`, `other`; ≈ 50 min) and
`s-free/labels.csv` (one learner answer per item written blind for the
scorer, 150 rows: `correct` or `wrong`; ≈ 40 min). Both shuffled under
random keys, with the cell in a mapping file you open afterwards. If the
time is too much, S-free can be limited to the D3-prompt cells (75 rows,
≈ 20 min); say so before the run.

## Rebuilding

`npm run eval -- sets` rewrites every derived file **except**
`s-live/labels.csv` and `s-live/mapping.json`, which are left alone once
they exist (the sheet is deterministic anyway: a fixed seed). To refresh
`live-sets/`, fetch again read-only from `proxy/`:

```bash
npx wrangler kv key get --binding DAILY_SETS_KV --remote "set:2026-10-25" > eval/data/live-sets/set-2026-10-25.json
```
