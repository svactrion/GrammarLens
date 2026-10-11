# Question screen improvements — plan (branch `question-screen`)

Branched from `1.2.0`. None of this ships in 1.2.0. Three improvements to
the question screen (Daily Test and Topic Practice). The product decisions
are the owner's (2026-10-12) and final; this file is the Batch 0 report
with those decisions folded in, so later sessions can work from it.

Status per batch is kept in the build log and the roadmap, not here.

## 0. The three items (owner decisions)

1. **Topic tag** (Daily Test + Practice): each question's topic as a small
   chip on the question card's top row, right after the question-type label.
   UI only. The "N / total" badge stays on the right. A long title wraps to
   the next line; the type label is never cut. Neutral colour: not the
   correct/incorrect semantic colours, not the blank colours of item 3.
2. **Topic hint card** (Daily Test only): a fixed card per topic, written
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

**Placement (Q5).** A 44 × 44 handle in the "Your answer" row; dragging it
reveals the card as an overlay above the row (over the question card, and
the header if needed). No height cost; the row never scrolls and stays
above the keyboard; the finger is below what it reveals. Width at 320 Large:
"Your answer" 90.7 + "Read full question" 146.2 leaves 55 pt for the
handle.

**Reveal.** Reveal fraction = |dx| / travel, travel ≈ 60 % of the card
width; the cover slides sideways with the finger. Release: a spring closes
it (~250 ms; instant under Reduce Motion). Long-press: fully shown while
held. VoiceOver: the handle's label carries the full text; reading it
changes nothing.

**Keyboard (Q2, as revised).** The keyboard stays up during the reveal;
nothing closes, reopens or freezes.

*Correction to the Batch 0 estimate (measured in B2):* the room above the
row does not depend on the phone. It is the header plus the question card,
so it follows the question's length. The Batch 0 figures (~279 pt at
390 × 844, ~205 pt at 375 × 667) assumed a question that fills its share;
under the shortest possible question (one line, no scene) the room is
~154 pt at Medium and ~157 pt at Large on 375, 390 and 430 pt phones alike,
and ~95 pt on a 320 × 568 phone with the keyboard up.

**Fit (owner decisions, 2026-10-12).**

- **The guard:** under the shortest possible question, keyboard up, at
  375 × 667, Medium and Large, every card fits above the row
  (`test/topic_hint_card_test.dart`). Two bullets were replaced by the
  owner to pass it (Modal Verbs, Modal Past Forms). Measured after the
  change: every card 142 pt at Medium (12 pt to spare) and 148 pt at Large
  (9 pt to spare), on 375, 390 and 430 pt phones.
- **Safety net, any phone:** a card that does not fit above the row reaches
  down over the "Your answer" row, its bottom on the row's bottom; the
  handle is drawn again on top. After the text change it should not
  trigger on 375 pt and wider phones at Medium or Large (measured above);
  it stays as a guard against larger system text sizes and future texts.
- **320 pt phones (option a):** where a card does not fit even over the
  row, it starts below the status bar and reaches down over the answer
  field and the Skip/Next bar as far as it needs, never under the keyboard,
  so every card is whole on screen; the handle stays drawn on top. Tested
  at 320 × 568, keyboard up, Large, for every card.

**Gestures checked.** The question's vertical `SingleChildScrollView` is
outside the handle (and axis slop separates horizontal from vertical
drags anyway). The screens' outer `GestureDetector(onTap: unfocus)` would
close the keyboard on a tap on the handle, so the handle takes its own tap.
The iOS edge back-swipe is already off: `PopScope(canPop: false)` makes
`ModalRoute.popGestureEnabled` false (Flutter 3.44.6, `routes.dart`), and
the handle is 31 pt or more from the edge. No `PageView`/`Dismissible`
wraps either screen.

**Hint texts (verbatim, owner; shortened 2026-10-12 to fit above the row
with the keyboard up).**

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
- **B2 — hint card.** (Stop for approval of the layout-hold method first.)
  The five texts verbatim, one per `TopicId`; Daily Test only; drag reveals
  at 25 / 50 / 100 %; release closes; long-press shows and hides; a
  vertical drag still scrolls the question; a tap on the handle keeps the
  keyboard; no state change (answers, index, analytics); keyboard closes
  and reopens with text and cursor, the row and handle not moving; Reduce
  Motion; the VoiceOver label.
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
