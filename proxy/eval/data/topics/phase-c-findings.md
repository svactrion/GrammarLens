<!-- Hand-written for phase C of docs/TOPICS.md (2026-11-18), from the second-look file and the labels of the owner's run. `npm run eval -- topics analyze` puts it into docs/1.5.0-topics-report.md as it is. It is in the repository: it describes a defect in words and quotes no question, no answer and no sheet key. -->
Written by hand from the second-look file and the labels (the tables above are computed). Proposals only: nothing here was built, no prompt and no hint card was changed.

### The four defects, in words

- **Conditionals, fill in the blank (failed the gate).** The question marks no blank: verbs stand in brackets and there is nowhere to answer. The gate caught it; on the live path nothing would have, because that path has no gate (T-4).
- **Conditionals, correction (passed the gate).** The sentence to correct is already correct. It is a mixed conditional (a past condition with a present result), and the question's own hint hedges between that reading and a third conditional. The hint-card check had flagged it: the card has no line for this structure.
- **Comparatives & Superlatives, correction.** Two errors where the instruction speaks of one, and one of them belongs to another topic (a relative clause), so a learner who fixes the comparative is still marked wrong. The length check had flagged it (the key changes more than one short run of words).
- **Articles (the control), fill in the blank.** The question's own hint points to a fixed phrase that the verb of the sentence rules out; the key and both written mistakes follow the hint, so all three built answers are wrong. No check flagged it.

### Conditionals: fails on agreement (75 of 80) and on false "correct" (2 of 46)

**The cause is one structure: the mixed conditional.**

- 5 of the 30 questions are about mixed conditionals, 4 of them the fill-in-the-blank question of their set (one of those is the question without a blank). The topic's description and its hint card speak of three types (real, unreal, past); the generator added a fourth on its own.
- Both false "correct" verdicts are on mixed-conditional fill-in-the-blank questions: the answer put the result in the past form although the sentence marks the result as present, and the scorer accepted it.
- Two of the three false "needs work" verdicts are the mirror image: a third-conditional sentence whose result carries a present-time phrase, labelled right, which the scorer rejected for that phrase. The scorer is not consistent about when the result of a past condition may be present.
- The third false "needs work" is the informal past form after "if I", which the labels accept as modern usage and the scorer does not.
- The one defect after the gate is a mixed conditional too, and so is the one answer of this topic labelled `unsure`.
- The hint card says nothing about this structure: the hint-card check marked exactly these questions as "card silent" (4 of 4 with a key).

**Proposed fix (generation prompt, one topic).** Keep mixed conditionals out of the first release of this topic: a generation-only note for Conditionals in the Worker's topic table, added to the request's topic line and not shown in the app, saying that the items use the first, second and third conditional and no mixed conditional. The hint card then matches what is asked and stays as it is. The alternative, teaching the mixed conditional (a fifth line on a four-line card, and a scoring rule for it), is more work and touches the scoring prompt of every topic.

**What the fix does not cover.** The scorer's strictness about the informal past form, and its handling of present-time phrases in a past result when a learner writes one unprompted.

**Re-measurement, after the owner's OK.** Conditionals only: 6 sets, the answers, the scoring. This run measured $0.14 for the topic (34 calls); the same cap rules apply. Its 30 questions and their built answers need labels again. For orientation only: leaving the five mixed-conditional questions and their answers out of this run's Conditionals gives no defect in 26 questions, agreement 63 of 66 (95.5 %), no false "correct" in 37 and the same 3 false "needs work" in 29. That is a reading of this sample, not a forecast: a new run draws new questions.

### Comparatives & Superlatives: fails on false "correct" by one answer (1 of 47)

- **The one answer.** A correction that chose the right superlative and misspelt it (the final consonant not doubled). The scorer called it correct and gave the right spelling in its explanation.
- **Is it a real miss?** For this topic, yes: how the -er / -est form is spelt (the doubled consonant, y to i) is part of the rule the topic teaches. The scoring prompt accepts keyboard variants of a letter and says a typo is still a mistake, but it has no line about a misspelling in the very form a question tests.
- **The criterion at this size.** The topic has 47 answers labelled wrong, and 2 % of 47 is less than one answer: the criterion allows none. Passive Voice and Relative Clauses have 51 each, where one would still have passed. So this fail is a single answer on the line, not a pattern; the other two criteria pass (1 defect of 30, agreement 80 of 81).
- **Proposed fix (scoring prompt).** One sentence: a misspelling in the form the item tests is a mistake, to be marked wrong and explained as a spelling rule. It changes the scoring prompt of every topic, so it needs the check described under "The scorer" below, not a new generation run.
- **Or no fix.** The owner may judge that one misspelling, corrected in the explanation, does not hold the topic back; the criterion as written says fail, and the decision is his.

### The scorer: one pattern in the false "correct"

- Of the 5 false "correct" verdicts in the run (3 in the new topics, 2 in the control), 3 are verdicts the scorer's own text contradicts: its explanation names the flaw, or its corrected answer differs from the learner's in the tested form, and `isCorrect` is still true. The other 2 are the mixed-conditional cases above.
- **Proposal (scoring prompt, all topics).** Tie the verdict to the scorer's own correction: when the corrected answer changes the learner's answer in the structure the item tests, the answer is not correct. Together with the spelling sentence above this is one small change to the scoring prompt.
- **How to check it cheaply.** The 464 built answers now have labels. Scoring them again with a changed prompt cost $0.17 in this run and needs no new labels: the same answers, the same truth, agreement before and after. The risk to watch is the other side, more false "needs work" on right alternatives.

### More than one right answer (T-23): what the risk came to

- 18 questions are noted `multi:`, 13 of them in Relative Clauses (who and that, which and that, a pronoun that may be dropped).
- On their right answers the scorer said "needs work" 2 times of 28 (7.1 %), against 4 of 145 (2.8 %) on the other questions of the new topics. Both cases are questions with several blanks where the scorer objected to one blank of an otherwise accepted answer; in neither was the rejected part the alternative that makes the question `multi:`.
- So in this sample the scorer accepted the alternatives it was shown. **What was not measured:** the alternatives nobody built. 10 questions (8 in the new topics) carry answers to accept that were never scored. Scoring them is a few calls (cents) and needs no labels, since the labels already call them right; it needs the owner's OK like any spend.

### The built answers, and what the labels changed

- In the new topics 9 of the 34 second answers the writer offered are labelled wrong, and 1 of the 238 written mistakes is labelled right. The second answer was the weak part of the construction, as phase B suspected.
- With the labelled truth the agreement of the new topics is 97.8 % (407 of 416), against 96.4 % by construction: most of phase B's disagreements on second answers were the scorer being right.
- Passive Voice went from 96.3 % by construction to 100 %; the control from 86.0 % to 95.2 %.

### The control, for comparison

Articles is live and fails two of the three criteria in this sample (1 defect of 15 questions; 2 false "correct" of 22). With 15 questions one defect is 6.7 %, so the defect criterion cannot be passed with any defect at all. The criteria are stricter than what a live topic showed here; whether that is the right bar for the new topics, or a reason to look at Articles, is the owner's to say.

### What the owner decides

1. **Passive Voice, Prepositions, Relative Clauses** pass all three criteria: whether they go on to release prep (phase D).
2. **Conditionals:** the generation note and a re-measurement of this topic (about $0.14 and 30 questions to label), or the topic waits.
3. **Comparatives & Superlatives:** whether one misspelt answer on the line holds the topic back; and whether the scoring-prompt change is made and checked against the labelled answers (about $0.17, no new labels).
4. **Set variety:** which option of [`1.5.0-topics-set-variety.md`](1.5.0-topics-set-variety.md), if any.
