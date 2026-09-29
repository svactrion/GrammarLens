# E — the local measurement of the shared Daily Test quality step

What it is and why: `docs/1.1.0-shared-daily-test-quality.md` §13.6. It
generates Daily Test sets for 3 dates (2026-10-10, 2026-10-11, 2026-10-13;
§13.6 says why these) with 5 variants (prompt v1/v2 × `claude-sonnet-4-6` /
`claude-sonnet-5` × one set / two candidates per slot), has them reviewed by up
to 3 checker models, and turns your labels into defect rates, checker accuracy,
publish rates, measured cost, wall time and JSON CPU time. It runs on this
machine only; nothing here is deployed.

**It calls the Anthropic API and costs money: about $2.1 (69 requests), never
more than $4.00 of measured spend.** Run it only after the owner has approved
the run. Adding the 3 extra dates later (step 7) is about $1.1 more, under the
same $4.00 cap.

## Owner checklist

### 1. The API key (stays out of the repo)

Use either:

- **`proxy/.dev.vars`** (recommended; the file `wrangler dev` already uses):
  a line `ANTHROPIC_API_KEY=sk-ant-…`. The file is gitignored; check with
  `git check-ignore -v proxy/.dev.vars` (it must print a match).
- or the environment, for one terminal session only, without it landing in
  your shell history: `read -s ANTHROPIC_API_KEY && export ANTHROPIC_API_KEY`
  (paste, Enter).

The environment wins over `.dev.vars`. The key is sent only to
`api.anthropic.com` and is never printed or written anywhere by the script.
Optional: create a separate key for E in the Console (e.g. "grammarlens-eval"),
so its spend shows on its own line, and revoke it afterwards.

### 2. The two reviewed sets (R1, R2)

From `proxy/` (read-only KV reads):

```bash
mkdir -p eval/input
npx wrangler kv key get --binding DAILY_SETS_KV --remote "set:2026-09-26" > eval/input/set-2026-09-26.json
npx wrangler kv key get --binding DAILY_SETS_KV --remote "set:2026-09-27" > eval/input/set-2026-09-27.json
```

`eval/input/` is gitignored. R3 (the bundled day-0 set) is already in
`eval/reference/day0.json`.

### 3. Dry run (no API call)

```bash
npm run eval -- dry-run
```

It prints the requests per stage with their estimated cost (69 requests,
about $2.06), what adding the extra dates later would add (42 requests, about
$1.06), and must end with `Reference sets: all present` and
`API key: found (not shown)`.

### 4. Run

```bash
caffeinate -i npm run eval -- run
```

(`caffeinate -i` keeps the Mac awake while it runs.) Stages:

| Stage | What | Typical time |
|---|---|---|
| A | 5 generations, one after another (one date per variant, for wall time) | 6–10 min |
| B | 10 generations in one batch | usually under 1 h; up to 24 h |
| C | 3 checks, one per checker model | 3–6 min |
| D | the other ~51 checks in one batch | usually under 1 h; up to 24 h |

**Typically 1–2.5 hours in total.** Anthropic only guarantees a batch within 24
hours, so the worst case is about 2 days.

**Watching it:** the terminal prints one line per call and a batch status
line every minute (counts only, no content). The same lines go to
`eval/out/run-…/progress.log` (`tail -f` it from another terminal). The
Console shows the batches under Workspaces → Batches, and the spend under
Usage.

**If it stops** (terminal closed, laptop off): run it again with the same
folder, e.g. `npm run eval -- run --out eval/out/run-2026-09-28T09-00-00-000Z`.
Finished calls are not repeated, and a submitted batch is picked up where it
is.

**The budget:** before each stage, anything that would take measured spend
past $4.00 (with a 25% margin on the estimate) is left out, least important
first (the `claude-opus-5-5` checks, then the two-candidate variants, then
the `claude-sonnet-4-6` checker). The final report lists what was left out.

### 5. Label

When it finishes it prints the path of **`eval/out/run-…/labels.csv`**, at
most 90 rows (45 from G1–G3, 30 from G4–G5, 15 from the reference sets; fewer
if a set fails the gate). **About 1 hour** (45–70 min). Open it in Numbers or Excel. The rows are shuffled and carry a
random key. **Do not open `private/`** until you have finished: it holds the
mapping from key to variant, and the raw outputs.

Each row shows one question as the learner would see it: `topic`, `type`,
`context`, `instruction`, `hint`, `correct_answer`,
`predicted_wrong_answers` (each "answer — comment", separated by `||`),
`explanation`. Fill in:

| Column | What to write |
|---|---|
| `label` | `ok`, `minor` or `defect` (required) |
| `defect_types` | for `defect`, one or more of `original_not_wrong`, `key_incorrect`, `multiple_answers`, `wrong_answer_acceptable`, `wrong_rule`, `other`, separated by `;` |
| `accept_also` | answers you would also accept that are not the key, separated by `\|` (optional; useful with `multiple_answers`) |
| `note` | anything (optional) |

**`defect` vs `minor`:** ask *"If this went to every learner, would a careful
learner end up believing something false about the tested grammar, or be
marked wrong for a right answer they are likely to type?"* If yes, it is a
`defect`; if no, but you would still change something, it is `minor`.

- `defect`, for example:
  - `original_not_wrong`: the "flawed" sentence is acceptable ("I knew I must
    study harder", 27 Sept).
  - `key_incorrect`: the key itself is wrong.
  - `multiple_answers`: another answer is just as right ("must" and "should",
    26 Sept); put it in `accept_also`.
  - `wrong_answer_acceptable`: an answer listed as wrong is right and likely
    to be typed ("had to", 27 Sept).
  - `wrong_rule`: the hint, explanation or a comment teaches a rule that does
    not exist ("should becomes should have in reported speech", 26 Sept).
- `minor`, for example:
  - A listed wrong answer that is a rare but acceptable variant few learners
    would type ("I already had taken", 26 Sept, which you judged minor).
  - Clunky or unnatural wording that does not change the answer.
  - An explanation that is true but vague or longer than needed.
- `ok`: nothing you would change.

Save it back as **CSV (UTF-8)** under the same name (Numbers: File → Export
To → CSV, Unicode UTF-8; Excel: "CSV UTF-8"). Keep the header and the `key`
column. The row order does not matter.

**Numbers may use `;` as the separator** (it follows the region setting, e.g.
Turkish), and `analyze` reads only `,`. If the first line of the saved file
reads `key;topic;type;…`, convert it in place from `proxy/`:

```bash
python3 -c "import csv,sys; p=sys.argv[1]; rows=list(csv.reader(open(p,encoding='utf-8-sig',newline=''),delimiter=';')); csv.writer(open(p,'w',encoding='utf-8',newline='')).writerows(rows)" eval/out/run-…/labels.csv
```

**Check the `key` column after saving:** a spreadsheet can read a key such as
`267981e9` as a number and write it back as `2,67981E+14`. Such a row no
longer matches its question, and `analyze` counts it as unlabelled. Keep a
copy of `labels.csv` before you open it, and if a key changed, copy the key
back from that copy (same row content) before running `analyze`.

### 6. Report

```bash
npm run eval -- analyze --out eval/out/run-…
```

It writes `eval/out/run-…/report.md` and names any row still unlabelled or
with a value outside the lists above. The results then go into the build log
and §13 of the report. The run folder stays out of the repo.

### 7. If the results are not clear: add the extra dates

With 3 sets per variant the intervals are wide. If the report does not
separate the variants or checkers clearly, add the other 3 dates
(2026-10-12, 2026-10-14, 2026-10-15) **to the same run folder**, after the
owner's approval:

```bash
npm run eval -- dry-run
caffeinate -i npm run eval -- run --out eval/out/run-… --add-dates
```

(`--add-dates 2026-10-12,2026-10-14` adds only those; any other calendar
dates work too.) It needs a run that has written `labels.csv`. It generates
and checks only the new dates (15 generations and 27 checks, about $1.06, all
batched: stages B and D again, usually under 2 hours); the synchronous calls
and the reference checks are not repeated. The $4.00 cap counts what the
folder has already spent. If it stops, run the same command without
`--add-dates` to resume it.

The new rows go to a separate sheet, **`labels-2.csv`** (at most 75 rows,
about 45–55 min), shuffled under new random keys; `labels.csv` and your
labels in it are not touched. Label it the same way, then run `analyze` as
in step 6: it reads every sheet in the folder.
