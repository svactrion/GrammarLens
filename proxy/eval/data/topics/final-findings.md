<!-- Hand-written on 2026-11-19 from the final run's labels, its second-look file and the two changed-verdicts files. `npm run eval -- topics analyze` puts it into the "Final configuration" section of docs/1.5.0-topics-report.md as it is. It is in the repository: it describes in words and quotes no question, no answer and no sheet key. -->
Written by hand from the labels, the second-look file and the two changed-verdicts files (the tables above are computed). Proposals only: no prompt, no hint card and nothing in the app was changed.

### What the final configuration did

- **No fill-in-the-blank item came without a blank:** 0 of 300 items in 60 sets, against 4 of 195 in the two earlier runs. The guard had nothing to remove. The prompt's line on blanks is the only thing that changed for this, so in this sample it worked; the guard stays as the net under it.
- **The sets no longer repeat each other.** No question of a new topic resembles another (0 of 30 in each), where the first run had 15, 11, 7, 7 and 2. Of the live topics only Modal Past Forms has a pair (2 of 30). The theme per set did what it was for.
- **Question quality held with a theme imposed:** 2 defects in the 150 questions of the new topics (1.3 %), 1 in the 75 of the live ones.
- **The production scorer left 3 of 651 answers without a usable verdict:** one response answered one of the three items it was sent, and one answered under an id that was not asked. The candidate left none. On the live path such an item would come back without feedback; what the app shows then was not looked at here.

### The three defects, in words

- **Conditionals, correction.** The sentence to correct is already a correct third conditional; its own hint only asks whether it is formed correctly. The same kind of defect as one in the first run (see the progress doc for what the prompt requires today and a proposed wording).
- **Prepositions, correction.** The sentence ends in a phrase that means nothing, with or without the missing preposition, so a learner cannot tell what the mistake is.
- **Modal Past Forms (live), fill in the blank.** A blank stands where the natural form cannot be written (before a verb that is already printed, inside an if-clause), so every built answer is wrong or doubtful.

### The new topics against the criteria (production scoring prompt)

- **Passive Voice and Relative Clauses pass all three**, as they did in the first run: no defect in 30, every compared answer agreed (82 of 82, 91 of 91), no false "correct" in 48 and 49.
- **Prepositions fails by one answer** (false "correct" 1 of 48; 1 defect of 30 passes; agreement 81 of 82). It passed in the first run with 0 of 48. The answer: a correction that put the tested preposition right and another one wrong; the scorer accepted it while its own explanation calls that phrase unnatural.
- **Comparatives & Superlatives fails by one answer again** (false "correct" 1 of 48; no defect; agreement 81 of 83). Not the misspelling of the first run: a second answer that uses another word than the one given in brackets, a correct form of the wrong word, which the labels call wrong and the scorer accepted. A judgment call on both sides.
- **Conditionals fails on false "correct"** (2 of 45; 1 defect of 30 passes; agreement 82 of 85 passes). Both answers mix two conditional types (a condition of one type with a result of another, against the time the sentence gives), and the scorer accepted both. This is the pattern of the first run and of the re-measurement: over the three runs the production prompt called 5 of 132 wrong Conditionals answers correct (3.8 %), every one of them a mix of types. The generation note removed the mixed-conditional *questions*; the scorer's weakness with mixed *answers* is still there.
- **At this size the false "correct" line allows nothing.** Each new topic has 45 to 49 answers labelled wrong, and 2 % of that is less than one answer. Over all the runs that have a topic, the production prompt stands at: Passive Voice 0 of 99, Relative Clauses 0 of 100, Prepositions 1 of 96 (1.0 %), Comparatives & Superlatives 2 of 95 (2.1 %), Conditionals 5 of 132 (3.8 %). The five new topics together, final run: agreement 417 of 423 (98.6 %), false "correct" 4 of 238 (1.7 %), false "needs work" 2 of 185 (1.1 %), defects 2 of 150 (1.3 %).

### The live topics, for reference

- Gerund vs. Infinitive and Tense Selection pass all three.
- Modal Verbs: 1 false "correct" of 23 (a prohibition written without its negative, on a question with several right answers).
- Modal Past Forms: 1 defect of 15, and 14 of its 15 labelled questions carry a `minor:` note for the same reason: they practise "could" and "would" as the past of "can" and "will", while the hint card the app shows teaches modal + have + past participle (see the progress doc).
- **Articles is the weakest topic for scoring, and it ships already:** agreement 35 of 38 (92.1 %), false "correct" 3 of 24 (12.5 %); with the first run, 5 of 46 (10.9 %). The accepted answers put "the" or "a" where the sentence does not allow it; the scorer finds reasons for them.

### The scoring prompt candidate: recommendation

**Do not make the candidate the production scoring prompt, neither in whole nor its verdict rule. The spelling sentence is unproven on its own.**

- **In whole, it is worse on every count.** On the 1,163 labelled answers both prompts scored: agreement 97.8 % → 96.8 %, false "correct" 14 → 16 of 661, false "needs work" 12 → 21 of 502. Of the 31 answers the prompts judge differently the candidate is right on 10 and the production prompt on 21. It makes no topic pass that fails with the production prompt, and it makes Prepositions worse (false "correct" 1 → 3 of 48 in the final run).
- **It did hit its targets, and paid for them elsewhere.** Of the first run's 5 false "correct" verdicts it turned 4: the misspelt superlative, both Articles answers, one mixed conditional. But it added as many new ones in the same run (the count stays 5 of 265), and it nearly doubled the right answers it rejects, mostly second answers and questions with several right answers.
- **The verdict rule is not followed reliably.** Under the candidate the scorer still marks an answer correct while its own explanation corrects the tested structure, and marks an answer wrong while giving it back unchanged, which is exactly what the rule forbids (the second, as far as a program can see it: 2 answers under the candidate, 1 under the production prompt). A rule the model does not keep cannot be the fix.
- **The spelling sentence fixed the one case it was written for,** and none of the 21 verdicts that went against the candidate is about spelling. But it was only tested together with the verdict rule, and on one relevant answer in 1,163. That is not evidence for or against it.
- **Part of the difference is chance.** One scoring per prompt; in the 1.4.0 measurement the same prompt changed its verdict on about 1 % of answers scored twice, which would be about a dozen of these 31. The lean against the candidate (21 to 10) is larger than that, but a single changed answer proves nothing.
- **What would settle the open parts, with no new labels:** all 1,190 built answers are labelled now, so any scoring prompt can be checked against them for about $0.45 (this rescore cost $0.20 and the final run's candidate scoring about $0.25). Two candidates worth that: the spelling sentence alone; and a sentence about conditional types (the result must match the time the sentence gives), which is where the production prompt's real pattern of false "correct" is. Both are the owner's call.

### What the owner decides

1. **Passive Voice and Relative Clauses** pass twice: whether they go on to release prep.
2. **Prepositions and Comparatives & Superlatives**: each fails by one answer on a line that allows none at this size, and stands at 1 of 96 and 2 of 95 over the runs. Whether that holds them back.
3. **Conditionals**: its questions are sound now; the scorer accepts mixed-type answers. Whether it ships as it is, waits for a scoring sentence about conditional types, or waits altogether.
4. **The candidate**: recommended against, as above.
5. **Modal Past Forms** (live): which of the two, the description or the hint card, says what the topic is.
6. **Articles** (live): whether its scoring is looked at; it is the weakest in both runs.
7. **The correction rule for practice** (a sentence that is already correct): the wording proposed in the progress doc.
8. **The deploy** of the guard, the line on blanks and the theme: the Worker's source has them; nothing is deployed.
