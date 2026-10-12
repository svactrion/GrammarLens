# Question screen improvements — plan (branch `question-screen`)

Branched from `1.2.0`. None of this ships in 1.2.0. Three improvements to
the question screen (Daily Test and Topic Practice). The product decisions
are the owner's (2026-10-12) and final; this file is the Batch 0 report
with those decisions folded in, so later sessions can work from it.

Status per batch is kept in the build log and the roadmap, not here.

## Final state (2026-10-12): done

All three items are built, tested and checked on the owner's iPhone. Where
the design changed after a device check, the sections below keep the
original decision and mark what replaced it. In short:

- **Topic tag (§2):** as planned. Daily Test and Practice.
- **Topic hint (§3):** a 56 pt "slide to unlock" slider between the
  question card and "Your answer", the card opening inline below it; on
  the Daily Test **and Practice** (the set's topic). It tucks under the
  question card while any answer box has focus; none below 375 pt. The
  original handle-and-overlay design, Q2 and Q5 are superseded (§3,
  "History"). Final fit table in §3.
- **Multi-blank boxes (§4):** as planned, plus, after the device check: a
  two-part hint on articles boxes ("Type an article…" … "no article →"),
  and a tap on any blank (multi or single, Practice and Daily Test) opens
  its box. Debug-only fixed sets reach the boxes on a device.
- **Also fixed:** the "Your answer" row's 4 pt jump on focus; the stale
  "more below" fade after the slider tucks away; the keyboard dropping
  across Next/Back between questions with different box counts.
- **Open, outside this work:** the proxy rule ("at most 4 blanks", §6) is
  committed but **not deployed** until the release that ships the boxes;
  Skip still sends typed text to scoring (roadmap backlog).

## 0. The three items (owner decisions)

1. **Topic tag** (Daily Test + Practice): each question's topic as a small
   chip on the question card's top row, right after the question-type label.
   UI only. The "N / total" badge stays on the right. A long title wraps to
   the next line; the type label is never cut. Neutral colour: not the
   correct/incorrect semantic colours, not the blank colours of item 3.
2. **Topic hint card** (Daily Test only; *on Practice too from
   2026-10-12, and revealed by a slider, see Final state*): a fixed card
   per topic, written
   once and bundled (no AI, no proxy change, works offline). Using it has no
   effect at all: no score, Monthly Climb, analytics or state change. The
   per-question `hint` (e.g. "(eat)") stays exactly as today. The card is
   covered; a horizontal drag on a handle reveals it in proportion to the
   drag; on release it springs closed. A long-press shows it fully while
   held. Nothing stays open.
3. **Multi-blank answer boxes** (Practice `fill_in_blank`): one box per
   blank (a run of 2+ underscores, the `FallbackPool.blankCount` rule). One
   blank = today's single box, unchanged. Blanks and boxes are linked by
   colour. Topic `articles` only: a "—" (no article) button per box. On
   submit the boxes go back into the sentence and the completed sentence is
   sent to scoring as a single answer is today. Scoring and the scoring
   prompt do not change. Proxy: the practice generation prompt gets "at most
   4 blanks". Daily Test stays at exactly 1 blank (gate unchanged).
   Error correction and sentence writing answers stay exactly as they are.

### Owner decisions on the Batch 0 questions (2026-10-12)

- **Q1 — tag separator:** no "·". The tag is a chip in a `Wrap` after the
  type label: `surfaceContainerHighest` fill, `outlineVariant` edge,
  `onSurfaceVariant` text. On both Daily Test and Practice.
- *(Q2 below is superseded by the B2 rework, §3: the slider and card are
  hidden while the keyboard is up.)*
- **Q2 — hint card with the keyboard up (revised 2026-10-12, replaces the
  text below):** the keyboard stays up during the reveal; no closing or
  reopening, no layout freezing. Reason: if the "Your answer" row may not
  move, closing the keyboard frees space only below the row, under the
  finger, not above it where the card opens. Instead the cards are
  shortened to fit above the row (about 200 pt at 375 × 667 with the
  keyboard up), guarded by a test. On the smallest phones (320 pt at
  Large), where even a short card does not fit, the card may also cover
  the "Your answer" row; only the handle stays visible. *(Original Q2,
  superseded:)* the reveal closes the keyboard
  and reopens it on release, keeping the answer text and cursor. **Hard
  condition:** while the card is being revealed the layout must not move;
  the "Your answer" row and the handle stay exactly where they were under
  the finger while the keyboard closes, and the card opens into the freed
  space. Before writing B2 code, describe how the layout is held still and
  stop for approval. If it cannot be done cleanly, fall back to shorter
  cards that fit above the keyboard.
- **Q3 — Next on multi-blank items:** enabled only when every box is typed
  or set to "—". Skip keeps its current behaviour.
- **Q4 — proxy rule:** built and tested in B3 as its own commit, **not
  deployed**. It deploys only together with the app release that ships
  multi-blank boxes.
- **Q5 — hint placement:** a 44 × 44 handle in the "Your answer" row,
  revealing the card as an overlay above it.
  *(Superseded 2026-10-12 after the owner's device test: a slider between
  the question card and "Your answer", the card inline; §3.)*
- **Addition — sentence assembly:** when a no-article box removes a blank
  at the start of a sentence, the next word's first letter is capitalised
  (`____ water is essential.` + "—" → `Water is essential.`).
- **Addition — open item, not fixed here:** Skip does not clear typed text,
  so a typed-then-skipped answer (a single box today, a partly filled
  multi-blank answer after B3) is still sent to scoring. Recorded in the
  roadmap as a separate open item.

## 1. Answer wiring today, and N boxes per item

**Today.**

- `AnswerDrafts` (`lib/widgets/question_view.dart`): one
  `TextEditingController` per item id, plus one session `focusNode` and one
  answer `scrollController`. The single answer field keeps the node and
  only swaps its controller on Next/Back, so an open keyboard stays open;
  `leave`/`restore` save and put back the field's scroll offset per id.
- The screens own `_answers: Map<String, String>`; `QuestionView.onChanged`
  writes it (Practice `practice_screen.dart`, Daily Test
  `daily_test_screen.dart`, `_buildQuestion`).
- Next is enabled when `_answers[id].trim()` is non-empty
  (`_currentHasAnswer` on both screens).
- Skip only calls `_advance`; it does not clear the typed text (see the open
  item above).
- Practice sends `_answers` to `ClaudeService.scoreAnswers`, which builds
  `{id, type, prompt: item.fullText, userAnswer}` per item; an empty
  `userAnswer` is a skipped item (`ItemFeedback.fromJson(isSkipped: …)`).

**Approved design.**

- `AnswerDrafts(items)` takes the items, not only their ids. The box count
  is fixed once per item: `fill_in_blank` with 2–4 blanks → that many boxes;
  anything else (other types, 0 or 1 blank, more than 4) → 1 box.
- Per item: `List<TextEditingController>` and a no-article flag per box.
  Box 0's controller is today's controller.
- **4 shared focus nodes and 4 answer scroll controllers**, one per box
  position, made once per session. Node 0 is today's `focusNode`, so a
  single-box question behaves exactly as now. Scroll offsets are saved per
  (id, box).
- On Next/Back, if the focused box position does not exist on the new
  question, focus moves to box 0, so the keyboard stays open.
  `drafts.unfocus()` replaces `_drafts.focusNode.unfocus()` in Practice's
  `_submit` and the Daily Test's `_finish`.
- `QuestionView` assembles the sentence and still calls
  `onChanged(String)`. The screens' `_answers`, Skip and scoring code stay
  as they are, apart from the `AnswerDrafts` constructor and the Next rule
  (Q3).
- Drafts are in memory only, as today; they survive Next/Back the same way.
- **Added in B3 (owner, 2026-10-12):** the answer counts as being edited
  while *any* box has focus (B2 made "being edited" drive "Review answer"
  and the hint slider's tuck; it read only box 0). Moving between boxes,
  by Return or a tap, keeps "Review answer" steady.
- **Found in B3:** a question with a different number of boxes brings new
  answer fields, and a new field does not open the keyboard for a node
  that already has focus, so Next/Back dropped the keyboard. `restore`
  now puts the focused field back on the keyboard in the same frame
  (Flutter hides a departing field's keyboard only after the frame, unless
  another field takes it first).

## 2. Topic tag (B1)

**Where the topic is.** Daily Test: `DailyTestQuestion.topicId`, a
`TopicId.name` string, looked up with `TopicId.values.asNameMap()`; an
unknown id shows no tag. Practice: `PracticeScreen.topic` (a `Topic`),
passed to `QuestionView` as `topic`. (On Practice the header title already
shows the same title; the tag is still shown, by decision.)

**Measured** (real font, `buildAppTheme`, Large: labelMedium 14.3,
labelSmall 13.1). Type labels "Fill in the blank" 105.8, "Find and correct
the error" 173.5, "Write a sentence" 114.3. Badge "10 / 10" 59.5 + 10 gap.
Tags (labelSmall w700, 8 pt padding a side): Gerund vs. Infinitive 137.0,
Modal Past Forms 125.6, Tense Selection 111.3, Modal Verbs 92.7, Articles
63.4.

Room for the tag on line 1 at Large (card inner width − badge − label −
6–8 pt spacing):

| Width (inner) | Fill in the blank | Find and correct | Write a sentence |
|---|---|---|---|
| 320 (262) | 80.7: Articles only | 13: none | 72: Articles only |
| 375 (313) | 131.7: all but Gerund | 64: Articles | 123: Articles, Modal Verbs, Tense |
| 390 (328) | 146.7: all | 79: Articles | 138: all |
| 430 (368) | 186.7: all | 119: Articles, Modal Verbs, Tense | all |

"Gerund vs. Infinitive" always wraps on the error-correction row, and on
fill in the blank at 375 and below. Line 2 is 192.5 pt at 320 Large, so the
chip always fits whole (up to about ×1.4 system Dynamic Type on top; past
that the chip's own text wraps, never an ellipsis). A wrapped row adds about
26 pt to the card.

**Build.** A `Wrap` of [type label, tag chip] in the row's `Expanded`; the
type label keeps no `maxLines` and no ellipsis. The badge is aligned with
the first line. Tag colours: `surfaceContainerHighest` fill, 1 px
`outlineVariant` edge, `onSurfaceVariant` text: 8.23:1 (light), 7.75:1
(dark).

## 3. Topic hint card (B2)

**History.** B2 was first built as a lightbulb handle in the "Your answer"
row revealing the card as an overlay above it, with the keyboard up (Q2 and
Q5 above). The owner's iPhone test (2026-10-12) failed it on design: the
handle did not read as something to drag, and the card covering the
question card was worse. It was reworked the same day as below (owner's
design, final); the handle, the overlay, the keyboard-up fit guard and the
"cover the row" / 320 pt placement rules were removed. The card texts and
"no effect on score or state" are unchanged.

**Slider (the rework).** A full-width "slide to unlock" slider between the
question card and the "Your answer" row, part of the page layout:

- A 56 pt pill track in the light brand tint (`warm`), "Slide for a hint"
  centred in `onWarm`; a round 48 pt knob (4 pt inside the track's edge) at
  its left end in the brand colour (`primary`) with right chevrons in
  `onPrimary`. (The track was 48 pt with a 40 pt knob until the owner's
  2026-10-12 change after the device check.) As the knob moves right a
  filled trail (`primary` at 32 %) follows it and the label fades out
  (gone at half way). No semantic colours.
- 6 pt above the track (under the question card; 8 pt until Practice
  got the slider, owner 2026-10-12); the card opens 4 pt
  below it.

**Reveal.** Dragging the knob right (horizontal only) opens the card inline
below the track, its height in proportion to the knob's position, fully
open at the end of the track. It pushes "Your answer" and the answer field
down (past the bottom if it must, clipped there while held); the question
card never moves or gets covered: its height is set with only the closed
slider reserved under it. Release: the knob springs back and the card
collapses (a critically damped spring, ~250 ms; instant under Reduce
Motion). A long-press on the knob shows the card whole while held.
VoiceOver reads the whole card from the slider; reading it changes nothing.

**When it shows.** The Daily Test and, from 2026-10-12 (owner), Practice
(the set's topic), only with the keyboard down; still no effect on
scoring or state. When
the answer takes focus (the moment the keyboard starts to open) the slider
slides up and tucks under the question card (drawn behind it), while its
slot closes and "Your answer" moves up with it; when the answer loses focus
(the keyboard starts to close) it slides back out, closed. 250 ms,
`easeOutCubic` both ways (fast at the start, as the keyboard), approximating
the iOS keyboard's animation; under Reduce Motion it goes and comes back at
once. The keyboard's inset is not the driver: its final height is unknown
while it opens, and it reaches 0 only at the end of closing. The question
card never moves. A card held open when the keyboard opens closes at once,
and the tucking slider takes no touches. (Polish after the owner's device
check, 2026-10-12; before it, the slider disappeared at once.)

**Known limit: no slider below 375 pt (owner decision, 2026-10-12).** On
screens narrower than 375 pt (the first-generation iPhone SE; iPhone SE
2nd/3rd generation with Display Zoom; the app supports iOS 15) the slot is
left out, as with the keyboard up. Reason, measured at 320 × 568 with the
keyboard down (before the rework's spacing change): under the shortest
question the room for the open card was 218 pt at Large (Tense Selection,
236 pt, 18 pt too tall) and 222 pt at Medium; under a fallback-pool
question it was ~103 pt at Large and ~100 pt at Medium, so every card was
42–133 pt too tall.

**Fit rule (owner, 2026-10-12): the hint text is never cut off.** With
the keyboard down, on 375 × 667, 390 × 844 and 430 × 932, at Medium and
Large, under the shortest question and a fallback-pool question, the fully
open card's last line of text is whole above the Skip/Next bar and inside
the question area's clip (`test/topic_hint_card_test.dart`). The card's
bottom padding and edge may go behind the bar. The question card stays
fixed. While the card is open, the question area's 12 pt bottom padding is
free room for it: its clip ends at the top of the Skip/Next bar.

**History of the fit check.** The first run (48 pt track) failed one case
(375 × 667, Large, pool question: every card 11 pt under the bar); the
owner chose to tighten the spacing (the card's top and bottom padding
12 → 8 pt, the track-to-card gap 8 → 4 pt), after which it was reported as
fitting with "1 pt to spare". **That was wrong (corrected 2026-10-12):**
the check measured the card's edge against the Skip/Next bar, but the card
was cut 12 pt higher, at the question area's padded bottom. In that case
the device-checked 48 pt version cut about 3 pt off the last line of text.
The 56 pt track (owner) made it 11 pt; the owner then set the rule above,
the clip was moved to the top of the bar, and the check now measures the
last line of text against the real visible bottom.

**Final fit (2026-10-12: 56 pt track, 6 pt above it, both screens).**
Space under the card's last line of text, in pt (every card the same
height: four one-line points, 134 pt at Medium, 140 pt at Large). Daily
Test: one box always. Practice: its header is 2 pt taller (the "Practice"
subtitle); 1 box and 4 boxes.

| Phone, size | DT shortest | DT realistic | Practice shortest, 1 box | Practice realistic, 1 box | Practice shortest, 4 boxes | Practice realistic, 4 boxes |
|---|---|---|---|---|---|---|
| 375 × 667, Medium | 226 | 53 | 226 | 53 | 199 | 53 |
| 375 × 667, Large | 217 | **3** | 215 | **1** | 186 | 30 |
| 390 × 844, Medium | 342 | 169 | 342 | 169 | 315 | 196 |
| 390 × 844, Large | 333 | 148 | 331 | 146 | 302 | 146 |
| 430 × 932, Medium | 418 | 266 | 418 | 266 | 391 | 293 |
| 430 × 932, Large | 409 | 224 | 407 | 222 | 378 | 251 |

The tight cases are 375 × 667, Large, a realistic question: 3 pt on the
Daily Test, 1 pt on Practice with one box (the card's edge goes behind the
bar). Four boxes leave more room than one: their minimum answer area is
taller, so the question card is shorter. A longer question at that size,
larger system text or a longer text would cut the text; the tests
(`test/topic_hint_card_test.dart`, both screens) fail then. Before the
6 pt gap, Practice's realistic 1-box case cut 1 pt (measured, 2026-10-12).

**Gestures checked.** The question's vertical `SingleChildScrollView` is
separate from the knob, and the knob takes only horizontal drags (a
vertical flick on it opens nothing; tested). The knob takes its own taps.
The iOS edge back-swipe is off (`PopScope(canPop: false)`), and the knob
starts at the content column's left edge, 16 pt in. No
`PageView`/`Dismissible` wraps the screen.

**Hint texts (verbatim, owner; shortened 2026-10-12, two bullets replaced
the same day).**

Gerund vs. Infinitive
- + -ing: enjoy, avoid, finish, keep
- + to: want, decide, hope, plan
- Meaning changes: stop, remember, try
- After a preposition: always -ing

Modal Verbs
- modal + base verb: no "to", no "-s"
- must: obligation · should: advice
- may / might / could: possibility
- mustn't ≠ don't have to

Modal Past Forms
- modal + have + past participle
- must / can't have: sure it did / didn't
- might / could have: maybe it did
- should have: right, but it didn't happen

Tense Selection
- Past simple: finished time (ago, in 2020)
- Present perfect: up to now (since, for, yet)
- Past perfect: before another past event
- Continuous: in progress at that moment

Articles
- a / an: one of many, or first mention
- an before a vowel sound: an hour
- the: specific, known, or the only one
- No article: general plural or uncountable

## 4. Multi-blank boxes (B3)

**Today** the blanks are plain underscores in the question's main text; in
the data they sit in `context` (e.g. `"…I can't afford ____ all my
vegetables…"`), with "Fill in the blank…" in `instruction`.

**Underline.** The text holding the blanks becomes `Text.rich`; each
`_{2,}` run becomes a baseline-aligned `WidgetSpan` exactly as wide as the
underscores it replaces (so lines wrap as today) with a 3 pt bottom bar in
the blank's colour; its semantics label is "Blank n of N". A single blank
keeps today's plain text, no colour.

**Palette** (non-text, needs 3:1; card `#FFFBF4` / `#252528`, page
`#F3EFE6` / `#151517`):

| Blank | Light | vs card / page | Dark | vs card / page |
|---|---|---|---|---|
| 1 orange | `#C2570C` | 4.37 / 3.93 | `#FF9A52` | 7.28 / 8.68 |
| 2 blue | `#2F5BD3` | 5.72 / 5.14 | `#8FB0FF` | 7.15 / 8.53 |
| 3 teal | `#0B7A87` | 4.91 / 4.41 | `#4CCBD8` | 7.89 / 9.41 |
| 4 violet | `#8A3FC4` | 5.67 / 5.10 | `#D3A6FF` | 7.76 / 9.26 |

brandOrange `#FF7A1A` itself is 2.53:1 on the light card, hence the darker
orange. No red, no green. Blue and violet are close for red-green colour
blindness; they meet only on 4-blank items, and box order matches blank
order.

**Focus state.** Today a focused field's edge turns `secondary` (navy),
which would clash with blue. Instead the box keeps its colour, its edge
goes from 1.5 to 3 pt, and its blank in the sentence gets a light tint.

**Boxes.** Under "Your answer", 8 pt apart, one line each (54.8 pt at
Large), wrapping; at most 100 characters each. Return moves to the next
box; on the last it closes the keyboard. Four boxes at Large take 243 pt,
so the box column scrolls in its own region; the question keeps priority,
with at least one box and a peek of the next. `articles` only: a 44 × 44
"—" button in each box; tapping it sets a clear no-article state (tinted
fill, muted label) and clears typed text; typing clears the state. An empty
box is never "no article".

**Assembly.** Each box is trimmed. A no-article box removes its blank and
the space after it (or the space before it when there is none after); no
double spaces. When that blank started a sentence, the next word's first
letter is capitalised. Otherwise case is left as typed. All boxes empty →
`''` (still a skipped item). In a partly filled answer (reachable only by
Skip, Q3) an empty box stays `____`.

- `We had ____ lunch at ____ small café near ____ station.` + [—] [a]
  [the] → `We had lunch at a small café near the station.`
- `Tom says: "I can't stop ____, but I've promised ____ by May."` +
  [smoking] [to quit] → `Tom says: "I can't stop smoking, but I've
  promised to quit by May."`
- `____ water is essential.` + [—] → `Water is essential.`

**Polish after the B3 device check (owner, 2026-10-12).**

- *Placeholder (revised after the owner's device check, 2026-10-12):* the
  first version, "Type, or tap — for no article" in italics, read as two
  clauses split by a dash, not as a pointer to the "—" button. An empty
  articles box now shows two hints: "Type an article…" on the left in the
  placeholder style, and "no article →" on the right, quieter (bodySmall
  600), against the "—" button so the arrow points at it. Chosen by
  measured width (the box less 26 pt padding and the 44 pt button):
  "none →" where "no article →" does not fit with the full left; a shorter
  left ("An article…", "Article…") only if even "none →" does not fit.
  Both fade out when the box has text or is set to "—". Other boxes, and a
  single answer field, keep "Write your answer…". Measured (spare pt with
  the variant shown):

  | Width (room) | Small | Medium | Large |
  |---|---|---|---|
  | 320 pt (222) | both full, 33 | both full, 17 | "Type an article…" + "none →", 29 |
  | 375 pt (273) | both full, 84 | both full, 67 | both full, 49 |
  | 390 pt (288) | both full, 99 | both full, 82 | both full, 64 |
  | 430 pt (328) | both full, 139 | both full, 122 | both full, 104 |
- *Tap a blank:* a tap on a blank in the question puts the keyboard in its
  box (the single field for one blank; Practice and the Daily Test, whose
  blanks keep their plain look). Each blank's tap area is its box on its
  line grown to 44 pt tall and at least 44 pt wide, about 8 pt into the
  lines above and below; overlaps between two blanks' areas are split down
  the middle. Taps only: a drag on a blank still scrolls the question, and
  a tap elsewhere in the text still closes the keyboard. Accepted: a tap in
  those 8 pt bands now opens the blank's box instead of closing the
  keyboard. Not on error correction or sentence writing.

## 5. What is stored after an answer

`ErrorEntry.userAnswer` gets `_answers[id]`, the completed sentence for a
multi-blank item (plain `TEXT`, no schema change). "YOU WROTE" on Results
and Review shows the sentence; "CORRECTED" hides when it equals the answer
ignoring case (`MistakeBreakdown`). The practiced count (`total −
skipped`) stays consistent. The Daily Test's `answers_json` is unaffected
(1 blank). The proxy takes `userAnswer` up to 2,000 characters
(`proxy/src/validation.ts`); the 100-character box cap keeps a sentence
well under it. Nothing breaks; the scorer might return `correctedAnswer`
as just the words rather than the sentence, which still displays fine.

## 6. Proxy change (B3, not deployed)

`GENERATION_SYSTEM_PROMPT` (`proxy/src/anthropic.ts`) is used only by
practice generation (`buildGeneratePracticeSetBody`). The Daily Test
prompts and the shared gate (`fill_in_blank_multiple_blanks`) do not
change. Added before "Return only the structured output":

```
A fill_in_blank item has at most 4 blanks.
```

**Not deployed (Q4).** The proxy serves every installed version; 1.0.0 and
1.2.0 have one box, and the line might lead the model to more multi-blank
items. It deploys only with the app release that ships multi-blank boxes:
`cd proxy && npm test && npm run typecheck && npm run deploy`, record the
version id, and reach `main` by cherry-pick (the rule since 1.1.0 C1).

## 7. Batches and tests

Each batch: `flutter analyze`, the full test suite, a build-log entry, then
the owner's commit commands and device check before the next batch. No git
by Claude.

- **B1 — topic tag.** Topic lookup (incl. an unknown id); the tag on both
  screens; at 320 / 375 / 390 / 430 × Small / Medium / Large × light / dark:
  no overflow, the type label whole, the badge top-right, "Gerund vs.
  Infinitive" on line 2 at 320 Large; tag colours not the semantic ones.
- **B2 — hint slider and card** (as reworked, §3). The five texts
  verbatim, one per `TopicId`; Daily Test only; the track's place, size and
  colours; left out with the keyboard up (back closed) and below 375 pt;
  the knob's drag opens the card in proportion (25 / 50 / 100 %), the trail
  and the label follow, the question card never moves, "Your answer" is
  pushed down; release springs back; Reduce Motion; long-press; a vertical
  drag scrolls the question and opens nothing; no state change (answer,
  index, analytics); VoiceOver; the fit check above.
- **B3 — multi-blank.** Pure: 1–4 blanks; no-article at the start (with the
  capital), middle and end; no double spaces; all empty → `''`; partial
  keeps `____`; more than 4 → one box. Widget: box count and matching
  colours; palette contrast asserted; "—" on articles only, typing clears
  it; boxes, no-article state and focus across Next/Back; Return to the
  next box; Next only when every box is filled (Q3); the scoring payload and
  `ErrorEntry` hold the completed sentence; Daily Test, error correction and
  sentence writing unchanged (existing tests). Proxy: the practice prompt
  has the line; its own commit; not deployed.

At the end: `roadmap.md` updated; nothing marked done that isn't.
