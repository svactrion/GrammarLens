# Home greeting: the name disappears at 320 pt — diagnosis

**Date:** 2026-09-30. **Branch:** `1.1.0-design` at `9dbab61` (`1.1.0`
fast-forwarded in; Batch 3b is merged). **Scope:** diagnosis only. No
product code changed. Nothing here is a decision; the owner decides, and
this report ends with one recommendation.

Seen in the Batch 3b "after" renders ([`../batch3b/report.md`](../batch3b/report.md),
"Flags"): at 320 × 568 Medium, Home's greeting reads "Good morning, …". The
name is not shortened; it is gone. Batch 3b did not touch this row.

## How it was measured

- **`tool/design_measure/greeting_test.dart`:** the real `HomeScreen` in the
  real navigation shell (`home_fakes.dart`), with the bundled NunitoSans font.
  Text size goes only through `buildAppTheme(textSize:)`.
  - **For each case** it reads the greeting's `RenderParagraph` and counts
    the name's characters that are actually laid out. A character cut by the
    ellipsis gets no box. Output: [`greeting.txt`](greeting.txt).
  - **The matrix, 108 cases:**
    - 320 × 568, 375 × 667 and 430 × 932;
    - Small, Medium and Large;
    - 09:00, 14:00 and 20:00 ("Good morning / afternoon / evening");
    - the names "Ada", "Charlotte", "Maximilian" and "Mary Anne Smith".
      Onboarding and Settings take any trimmed text with no length limit, and
      spaces are allowed.
  - The file depends only on `home_fakes.dart`, so it also runs on the 1.0.0
    tree.
- **`tool/design_measure/greeting_options_test.dart`:** the options below.
  Each is a copy of the greeting row (the text, a 12 pt gap, the 60 pt
  avatar tile) at the 320 pt screen's 288 pt content width, with one change.
  Output: [`greeting_options.txt`](greeting_options.txt) and the two images.
- The render was checked against the measurement. A probe at 232 pt paints
  "Good morning, A…" exactly where the character count says "A" is the last
  character laid out.

```bash
DESIGN_MEASURE_OUT=docs/design/greeting-fix flutter test tool/design_measure/greeting_test.dart
```
```bash
DESIGN_MEASURE_OUT=docs/design/greeting-fix flutter test tool/design_measure/greeting_options_test.dart
```

## 1. Root cause

**The widget:** `HomeScreen.build`, the greeting `Row`
(`lib/screens/home_screen.dart`, "PRD v2 §11: an avatar next to the
greeting"):

- a `Flexible` holding `Text('$word, $name', maxLines: 1, overflow:
  TextOverflow.ellipsis)` in `headlineSmall` w700;
- a 12 pt gap;
- the avatar tile, 60 × 60, which never shrinks.

**The constraint:**

- On a 320 pt screen the content width is 288 pt.
- The text gets 288 − 12 − 60 = **216 pt** (measured: `available=216.0`).
- On 375 pt it gets 269.3 pt; on 430 pt, 319.3 pt.

**Why the name goes entirely rather than getting shorter:**

- An ellipsis cuts from the **end**, and the name is the end.
- In front of it is a fixed prefix that takes almost the whole width. At
  Medium, "Good morning, A" alone is 208.4 pt and "…" is 19.7 pt.
- So a single letter of the name plus the ellipsis needs **228.1 pt**,
  against 216 available. With no room for even one letter, the layout keeps
  "Good morning, " and puts "…" after it.
- This is the same rule that would show "Charlotte" as "Char…" on a wider
  screen. At 320 pt there is simply no room left for the first letter.

**The hypotheses, one by one:**

| Hypothesis | Result | Evidence |
|---|---|---|
| Line breaking at word boundaries (`softWrap`) drops the name as a whole word | **Ruled out** | With `softWrap: false` the laid-out characters are identical. Truncation is per character: at 180 pt the text is "Good mornin…", mid-word |
| The row gives the text too little room: 60 pt avatar + 12 pt gap at 288 pt | **Confirmed; this is the constraint** | `available=216.0` at 320 pt, for every text size and name |
| The name is too long | **Ruled out as the cause** | The shortest name, "Ada", is lost in every 320 pt Medium and Large case. The prefix leaves too little room, not the name |
| Measurement artefact: text size applied twice (the Batch 3a error) or the test font | **Ruled out** | Text size only through the theme; the real NunitoSans is loaded; a pixel render shows the same thing |
| Something Batch 3b (or any 1.1.0 work) changed | **Ruled out** | The greeting code and `lib/utils/greeting.dart` are unchanged since `v1.0.0`, and the measurement on 1.0.0 is byte-identical (section 3) |

## 2. When it happens

Of 108 cases, the name is **lost entirely in 30** and **cut short in 60**.
It is shown in full in only 18.

| Screen | Text size | Space (pt) | Name lost | Name cut | Name in full |
|---|---|---|---|---|---|
| 320 | Small | 216.0 | **4 of 12** (all four names at 14:00) | 7 | 1 |
| 320 | **Medium** (default) | 216.0 | **12 of 12** | 0 | 0 |
| 320 | **Large** | 216.0 | **12 of 12** | 0 | 0 |
| 375 | Small | 269.3 | 0 | 9 | 3 |
| 375 | Medium | 269.3 | 0 | 9 | 3 |
| 375 | Large | 269.3 | **2 of 12** ("Maximilian", "Mary Anne Smith" at 14:00) | 8 | 2 |
| 430 | Small | 319.3 | 0 | 3 | 9 |
| 430 | Medium | 319.3 | 0 | 6 | 6 |
| 430 | Large | 319.3 | 0 | 9 | 3 |

- **On every 320 pt phone at the default text size, no user ever sees their
  name**, however short it is.
- **"Afternoon" is the worst**, the longest greeting word. At 375 Large it
  loses names starting with a wide letter ("M") but keeps "C…".
- **Cutting is common everywhere:** at 375 Medium in the afternoon,
  "Charlotte" shows as "Ch…". The name is not the one thing the row reliably
  shows.

## 3. Was it already in 1.0.0?

**Yes, identically.**

- **Which commit is 1.0.0:** the build log's "build 3 submitted" entries do
  not name a commit. The tag `v1.0.0` does: "1.0.0 (build 3): first App
  Store submission, 2026-09-24", at `509f94d` ("feat: lock the app to
  portrait …; build 1.0.0+3"). That matches the build-log entry "portrait
  lock on iPhone and iPad; build 3 archived", and `pubspec.yaml` there is
  `1.0.0+3`.
- **How it was measured:** in a separate worktree at `v1.0.0` (the working
  tree untouched; removed afterwards), with the same two harness files
  copied in.
- **Result:** `greeting.txt` there is **byte-identical** to the one from
  `1.1.0-design`. The version in App Store review has the same behaviour.

## 4. Options

Rendered at 320 pt, the content width 288 pt, in the Home background color,
for three cases each: 09:00 "Ada", 14:00 "Charlotte", 14:00 "Mary Anne
Smith". Images: [`greeting_options_320_medium.png`](greeting_options_320_medium.png),
[`greeting_options_320_large.png`](greeting_options_320_large.png).

| Option | Name drawn, Medium (Ada / Charlotte / Mary Anne Smith) | Name drawn, Large | Row height, Medium / Large (pt) | Font size |
|---|---|---|---|---|
| Today: one line, cut at the end | 0/3, 0/9, 0/15 | 0/3, 0/9, 0/15 | 60 / 60 | 26.4 / 28.8 |
| **A: name on its own line when needed** | **3/3, 9/9, 15/15** | **3/3, 9/9, 11/15** ("Mary Anne S…") | 68 / 74 | unchanged |
| B: first name only, one line | 0/3, 0/9, 0/4 | 0/3, 0/9, 0/4 | 60 / 60 | unchanged |
| C: shrink to fit one line | 3/3, 9/9, 15/15 | 3/3, 9/9, 15/15 | 60 / 60 | down to **13.6** (Mary Anne Smith), 17.8 (Charlotte) |

- **A: name on its own line when needed.**
  - When the greeting fits on one line, nothing changes.
  - When it does not, it takes two lines: "Good afternoon," on the first,
    the name on its own line.
  - The first line is scaled down only if the greeting word alone is wider
    than the space. That only happens with "Good afternoon," at Large,
    where 28.8 becomes 28.7.
  - The name is cut only if it is longer than a whole line.
  - **Cost:** the row grows by 8 pt at Medium and 14 pt at Large. The
    mountain moves down by the same amount, so at 320 × 568 the mountain
    above the fold goes from 81 to about 73 pt at Medium, and from 66 to
    about 52 at Large. This is derived from the row height; it would be
    measured again in step 2.
  - The row only grows when the one line does not fit. At 430 pt with a
    short name it stays one line.
- **B: first name only.** It does not solve the problem.
  - At 320 pt even "Ada" does not fit after "Good morning, ".
  - It only helps long full names on wider screens, and it drops part of
    what the user typed.
- **C: shrink to fit.**
  - The name is always complete and the row never grows.
  - But the size follows the name's length: a long name gets a greeting
    about half as big (13.6 pt), smaller than the "Mountain of Learning"
    header below it.
  - It also cancels the text size the user chose: at Large, the greeting
    ends up the same size as at Medium.

**Recommendation: A.**

- It is the **only option that guarantees the name is drawn**. Across all 6
  cases rendered, the name is complete except one 15-character full name at
  Large, which keeps 11 characters.
- It keeps the **user's chosen text size** and the greeting's place as the
  largest text on Home.
- It costs 8–14 pt of height only when the one line does not fit. That is
  most of the time at 320 pt, but it is a fixed, small amount, not one that
  depends on the name.
- It also improves the 60 "cut" cases on wider screens: there the name moves
  to its own line instead of becoming "Ch…".

**Step 2, if approved:**

- Apply A to Home's greeting row.
- Add a regression test over the same matrix (3 widths × 3 text sizes × 3
  greetings × 4 names) asserting that the name is never lost entirely, and
  that it is complete wherever it fits on a line of its own.
- Confirm the test is red without the fix, using `git stash` or a separate
  worktree.
- Measure the mountain above the fold again.
