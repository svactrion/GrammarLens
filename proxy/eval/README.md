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

---

# The generator comparison (path A, 2026-09-29)

What and why: `docs/1.1.0-shared-daily-test-quality.md` §16. Prompt v2 with
the cron's generator today against `claude-sonnet-5-5`, **generation only**: no
check call, no label sheet. 3 variants × E's 3 dates = **9 synchronous calls**:

| Variant | Request |
|---|---|
| V1 | v2 + `claude-sonnet-5`, adaptive thinking, no `effort` (the cron's request today) |
| V2 | v2 + `claude-sonnet-5-5`, adaptive thinking, no `effort` (its API default, `high`) |
| V3 | v2 + `claude-sonnet-5-5`, adaptive thinking, `effort: "low"` |

**It calls the Anthropic API and costs money: about $0.44, never more than
$1.00.** A call is made only if the spend so far plus that call's worst case
(every token its `max_tokens` allows, billed) stays within $1, so the cap holds
even if every estimate is wrong. Run it only after the owner has approved it.

## Owner checklist

### 1. A separate API key (recommended)

Create a key only for this run in the Console (Settings → API keys, e.g.
"grammarlens-compare"), use it once, and **revoke it when the run is done**.
Its spend then shows on its own line, and nothing that uses the Worker's key
can be affected.

Give it to the script through the environment, for this terminal only and
without it landing in your shell history (from `proxy/`):

```bash
read -s ANTHROPIC_API_KEY && export ANTHROPIC_API_KEY
```

(paste, Enter). The environment wins over `proxy/.dev.vars`, so a key already in
that file is not used. The key is sent only to `api.anthropic.com` and is never
printed or written by the script. Close the terminal (or `unset
ANTHROPIC_API_KEY`) afterwards.

**If you use the live key instead** (the Worker's `ANTHROPIC_API_KEY` secret,
or whatever key is in `.dev.vars`): **do not revoke it afterwards.** The
deployed Worker uses that key for every 1.0.0 request and for the hourly cron;
revoking it would stop the app's practice sets, Daily Test and scoring until a
new key is set with `wrangler secret put ANTHROPIC_API_KEY` and deployed.

### 2. Dry run (no API call)

```bash
npm run eval -- compare --dry-run
```

It prints the 9 calls, their `max_tokens` (15,072 each), the estimated cost
(about $0.44), the worst case, and must end with `API key: found (not shown)`.

### 3. Run

```bash
caffeinate -i npm run eval -- compare
```

**About 10 minutes** (one call after another; E's `claude-sonnet-5` sets took
about 45 s each). Calls are not cut off at the cron's 150 s: the time over the
limit is what is being measured. One line per call in the terminal and in
`progress.log` (counts only, never content).

**If it stops**, run it again with the same folder:
`npm run eval -- compare --out eval/out/compare-…`. Finished calls are not
repeated, and the $1 cap counts what the folder has already spent.

### 4. Results

In **`eval/out/compare-…/`** (gitignored; the last line of the run prints the path):

- **`report.md`**: one row per variant: sets passing the proxy's gate
  (`validateSharedSet`) and the rejection codes, `error_correction` questions
  without a sentence (counted over every set, whatever the gate said), average
  input and output tokens, cost per set, average and longest time, calls over
  90 s and over 150 s, and `stop_reason`s (`max_tokens` = truncated).
- **`questions.md`**: every set's questions as a learner would first read them,
  sentence and instruction only (no key, no wrong answers, no explanation), for a
  quick look at a few sets.
- `records.json`: the full sets and every measured field; `progress.log`.

The results then go into the build log and §16 of the report, and the owner
decides the generator (`SHARED_GENERATOR` in `src/shared_daily_test.ts`, one
line).


---

# The first-wave topics measurement (1.5.0)

What and why: `docs/TOPICS.md`; what was built, the dry run's numbers and the
decisions (T-1 …): `docs/1.5.0-topics-progress.md`. It generates Topic
Practice sets for the five first-wave topics (6 sets each) and for `articles`
as a control (3 sets) through the live practice path, has an answer key and
typical learner mistakes written for every question, scores those answers
with the production scoring model, and runs automatic checks on every
question. The first-wave topics stay switched off: nothing here deploys or
changes the Worker.

**It calls the Anthropic API and costs money: about $1.30 (198 calls), never
more than $15.00 of measured spend.** Before each call the script checks that
what is spent plus that call's estimate × 1.25 stays within $15.00; a call
that would not is skipped and recorded.

## Owner checklist — first-wave topics

For the macOS Terminal app. Copy one block at a time, paste, press Enter.

### 1. A separate API key (recommended)

In the Anthropic Console (Settings → API keys) create a key only for this
run, for example "grammarlens-topics", **in the Default workspace** (in
1.4.0 a key without a workspace was refused on every call). Its spend then
shows on its own line, and you revoke it when the run is done. Do not use and
do not revoke the Worker's live key: the app depends on it.

### 2. Go to the proxy folder

```bash
cd ~/GrammarLens/proxy
```

Check the branch; it must print `ui-polish-widgets`:

```bash
git branch --show-current
```

### 3. Put the key in the environment, for this Terminal window only

```bash
read -s ANTHROPIC_API_KEY && export ANTHROPIC_API_KEY
```

After Enter the Terminal waits and shows nothing: paste the key, press Enter
again. Nothing is printed and the key does not land in your shell history.
The script reads the key from the environment only (not from `.dev.vars`),
sends it only to `api.anthropic.com`, and never prints or writes it.

### 4. The dry run (no API call, free)

```bash
npm run eval -- topics --dry-run
```

It must show **198 calls**, **Estimated spend $1.30: within the dry-run
limit of $12.00**, and end with `API key: found in the environment (not
shown)`. If the last line says the key is not in the environment, repeat
step 3. If it says `esbuild: command not found`, run `npm ci` once and
repeat.

### 5. The run

```bash
caffeinate -i npm run eval -- topics run
```

(`caffeinate -i` keeps the Mac awake.) **About 10 minutes.** One line per
call appears in the Terminal (counts, tokens and cost only, never a
question or an answer), and the same lines go to
`eval/out/topics-…/progress.log`.

### 6. What "done" looks like

The last line in the Terminal, and in `progress.log`, reads like:

```text
2026-11-19T09:12:44.000Z topics run done: 190 calls ok; spent $0.90 of $15.00; folder eval/out/topics-2026-11-19T09-02-10-000Z
```

The number of calls is between 165 and 198 (a question without a second
correct answer needs fewer scoring calls). To read the last line again:

```bash
tail -n 1 "$(ls -d eval/out/topics-* | tail -n 1)/progress.log"
```

**If the last line says `topics run incomplete`** (some calls failed, or the
Terminal was closed half way), run the same folder again. Finished calls are
not repeated and are not paid for twice:

```bash
caffeinate -i npm run eval -- topics run --out "$(ls -d eval/out/topics-* | tail -n 1)"
```

If it still says `incomplete` after a second try, stop and tell Claude Code
the last ten lines:

```bash
tail -n 10 "$(ls -d eval/out/topics-* | tail -n 1)/progress.log"
```

### 7. Afterwards

- Revoke the separate key in the Console, and close this Terminal window (or
  run `unset ANTHROPIC_API_KEY`).
- Tell Claude Code, in a new prompt: **"The first-wave topics run is done.
  Start Phase B of docs/TOPICS.md."** and paste the `topics run done` line
  (it names the folder and the spend). The run folder stays on this Mac
  under `proxy/eval/out/`, which is not in the repository; Claude Code reads
  it from there.

Better not to open the files in the run folder before you have labelled phase
B's sheet: they show the automatic flags and the scorer's verdicts, which
should not colour your own.

## Phase B — the report and the label sheet (no API call)

After the run, from `proxy/`:

```bash
npm run eval -- topics analyze --out eval/out/topics-2026-11-18T16-35-34-632Z
```

It needs no key and calls nothing. It reads the run folder (and changes none
of the run's files) and writes:

| File | Where | For whom |
|---|---|---|
| `docs/1.5.0-topics-report.md` | the repository | everyone: counts and rates only, safe to read before and while labelling |
| `sheet/questions.txt` | the run folder | the labellers: read it |
| `sheet/labels.csv` | the run folder | the labellers: fill it |
| `private/sheet-mapping.json` | the run folder | **nobody until the sheet is filled** |
| `private/details.txt` | the run folder | **nobody until the sheet is filled** |

The run's own files (`items.json`, `answers.json`, `checks.json`,
`records.json`, `run-report.md`) also stay closed until the sheet is filled:
they show which answer is the key, the automatic flags and the scorer's
verdicts.

**Labelling.** `sheet/questions.txt` starts with the instructions and the
six hint cards, then lists the 165 questions in mixed order, each under a
key, with its built answers under letters. For each question fill its row in
`sheet/labels.csv`:

| Column | What to write |
|---|---|
| `verdict` | `ok` or `defect` |
| `why` | for a defect, one or more of `several_answers`, `off_topic`, `bad_english`, `hint_wrong`, `level`, `other`, separated by `;` |
| `note` | anything; needed with `other` |
| `also_accept` | answers that must count as right and are not among the listed ones, separated by `\|` |
| `A` … `D` | for each listed answer `right`, `wrong` or `unsure`; a cell that already says `n/a` stays as it is |

Keep the first line and the `key` column as they are, and save as CSV with
commas (UTF-8).

**Checking the sheet.** Run the same command again at any time: a sheet that
exists is never rewritten. It prints how many rows are labelled, names every
row not started, and names every value to fix. When it prints `165 of 165
rows labelled, 0 not started, 0 with something to fix`, the sheet is done:
tell Claude Code to start Phase C of `docs/TOPICS.md`.
