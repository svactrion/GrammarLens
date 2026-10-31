# Second look: C8 against the truth and against C1

No API call: the stored verdicts and explanations of the measurement run. The "Owner:" lines hold the owner's verdicts of 2026-10-31. Section B: C8 right on 19, C1 right on 2.

## A. C8 said "needs work" where the truth says correct (8)

### pool:fb02_3:key (fill_in_blank, key)

> Ali got a job at a large company. He says that ___ salary is much higher than his old one, so he can save more.
> Fill in the blank with one word.

- **Learner's answer:** "the"
- **Key:** "the"
- **Truth:** correct
- **C8:** needs work — 'The' sounds off here. We are talking about Ali's own pay, so 'his' is the natural word. *Summary:* When something belongs to the person in the sentence, use a possessive word like 'his' rather than 'the'. *Blanks:* 1: his ✗ (Ali's own salary needs the possessive 'his', not 'the'.)
- **C1:** correct — 'The' is spot on here — when Ali mentions his salary at the new company, it's a specific salary both he and the listener already understand from context, so 'the' is the natural choice.
- **Owner:** C8 wrong: the key "the" is right; "his" is merely more natural.

### synth:fb04_1:kb:umlaut (fill_in_blank, kb:umlaut)

> Maria is at a park. She wants to throw away her plastic bottle. She says: "Excuse me, is there ___ recycling bin near here?" (She does not know of any particular bin.)
> Fill in the blank with the correct article.

- **Learner's answer:** "ä"
- **Key:** "a"
- **Truth:** correct
- **C8:** needs work — Maria isn't pointing to a particular bin, so you'd say 'a recycling bin' rather than 'ä', which isn't an English word. Use the small word 'a' here. *Summary:* When you mean any one of something rather than a specific one, use 'a' before a singular countable noun. *Blanks:* 1: a ✗ ('ä' is not an English article; 'a' is correct because Maria means any recycling bin.)
- **C1:** needs work — When you're asking about something for the first time and there's no specific one in mind, you need 'a' — as in 'a recycling bin'. The character 'ä' isn't an English letter, so it looks like a keyboard slip.
- **Owner:** edge case; both models wrong.

### synth:fb05_2:kb:turkish (error_correction, kb:turkish)

> I have bought these shoes yesterday at the market.
> Rewrite the full sentence with the error corrected.

- **Learner's answer:** "I bouğht these shoes yesterday at the market."
- **Key:** "I bought these shoes yesterday at the market."
- **Truth:** correct
- **C8:** needs work — Right letter spelling aside, the ğ is just a different keyboard form of g, but the bigger problem is the tense: 'have bought' sounds connected to now, while 'yesterday' points to a finished time, so it sounds off. Say 'bought' with 'yesterday', because a finished time word needs the simple past. Also, the spelling 'bouğht' is a keyboard variant of 'bought', so it is not the main mistake here. *Summary:* Use the simple past, not 'have + past participle', when you name a finished time such as yesterday. Make sure your fix changes the tense, not just the spelling. *Blanks:* 1: I bought these shoes yesterday at the market. ✗ (The sentence still says 'have bought' with 'yesterday', which mixes a finished time with a present link, so the tense needs changing to 'bought'.)
- **C1:** needs work — When you mention a specific time in the past like 'yesterday', 'bought' (simple past) is the right fit — 'have bought' sounds off because it clashes with that time word. Also, 'bouğht' looks like a Turkish keyboard character slipped in ('ğ' instead of 'g'), but the bigger fix needed here is changing 'have bought' to 'bought'.
- **Owner:** C8 wrong, by misreading the tense; C1 made the same error.

### synth:fb06_2:kb:umlaut (error_correction, kb:umlaut)

> The flat has a sun in the living room all afternoon.
> Correct the sentence by rewriting it in full.

- **Learner's answer:** "The flät has the sun in the living room all afternoon."
- **Key:** "The flat has the sun in the living room all afternoon."
- **Truth:** correct
- **C8:** needs work — 'A sun' sounds wrong because sunlight is treated as uncountable here, so no article fits. 'Has the sun' is also awkward; 'gets sun' sounds more natural, the way a native speaker would describe it. The 'ä' in 'flät' is the same letter as 'a', just typed on a different keyboard. *Summary:* Sunlight is usually uncountable, so say 'gets sun' with no 'a' or 'the'. Accented letters like 'ä' are keyboard variants, not mistakes. *Blanks:* 1: gets sun ✗ ('Gets sun' sounds more natural than 'has a sun' or 'has the sun' for sunlight coming into a room.)
- **C1:** needs work — 'Has the sun' sounds a bit odd here — in natural English we'd say 'gets sun' to describe a room that receives sunlight. Also, 'flät' uses an umlaut (ä) that doesn't exist in English spelling; the word is simply 'flat'. Try: 'The flat gets sun in the living room all afternoon.'
- **Owner:** no verdict against either model: the pool key is defective ("has the sun"); P13 pool correction: rewrite the question so the natural answer is "gets sun".

### synth:fb06_2:kb:turkish (error_correction, kb:turkish)

> The flat has a sun in the living room all afternoon.
> Correct the sentence by rewriting it in full.

- **Learner's answer:** "The flat has the sun ın the living room all afternoon."
- **Key:** "The flat has the sun in the living room all afternoon."
- **Truth:** correct
- **C8:** needs work — The article 'the' sounds odd here, since 'the sun' makes it sound like the flat owns the actual star. Talking about sunlight, we normally say the room 'gets sun' with no article. The dotless 'ı' in 'in' is just a keyboard variant of 'i', so that part is fine. *Summary:* When 'sun' means sunlight, it takes no article, and 'gets sun' is more natural than 'has the sun'. Your dotless letter is a typing variant, not a mistake. *Blanks:* 1: The flat gets sun in the living room all afternoon. ✗ (Removing 'a' was a good start, but 'has the sun' still sounds wrong; 'gets sun' is the natural phrasing for sunlight.)
- **C1:** needs work — Saying 'has the sun in the living room' sounds odd — it makes it seem like the actual star is inside! A more natural way to say this is 'gets sunshine' or 'gets a lot of sunlight'. Also, the verb 'gets' fits better than 'has' here. Note: 'ın' with the Turkish dotless-i is the same as 'in' — that part isn't the problem.
- **Owner:** no verdict against either model: the pool key is defective; see the P13 correction above.

### synth:fb06_2:kb:nbsp (error_correction, kb:nbsp)

> The flat has a sun in the living room all afternoon.
> Correct the sentence by rewriting it in full.

- **Learner's answer:** "The flat has the sun in the living room all afternoon."
- **Key:** "The flat has the sun in the living room all afternoon."
- **Truth:** correct
- **C8:** needs work — Changing 'a' to 'the' fixes the article but the sentence still sounds odd, because a flat doesn't 'have' the sun the way it has a room. A fluent speaker would say the room gets sun all afternoon. *Summary:* Use 'get' with sunlight, not 'have', when describing how much sun a place receives. Articles alone may not fix an unnatural phrase. *Blanks:* 1: The flat gets a lot of sun in the living room all afternoon. ✗ ('Has the sun' is not the natural way to describe sunlight in a room; 'gets a lot of sun' is what a native speaker would say.)
- **C1:** needs work — Saying 'has the sun' sounds a bit odd — you can't really possess the sun! The natural word here is 'sunlight', and native speakers would usually say 'gets sunlight' or 'has sunlight' (without 'the', since it's light in general, not a specific amount).
- **Owner:** no verdict against either model: the pool key is defective; see the P13 correction above.

### synth:fb07_4:kb:zero_width (fill_in_blank, kb:zero_width)

> At the cinema entrance, a sign says that entry without a ticket is forbidden by the rules. It says: "You ___ show your ticket before entering the screening room."
> Write the one modal verb that fits best to show a strict rule.

- **Learner's answer:** "h​ave to"
- **Key:** "have to"
- **Truth:** correct
- **C8:** needs work — 'Have to' also means a rule, but the task asks for a single modal verb, and 'must' fits a strict written rule best. Your entry also contains an invisible extra character, so check that the word is typed cleanly. *Summary:* For a strict written rule, 'must' is the best single modal verb. 'Have to' is a semi-modal, so it is less precise for this task. *Blanks:* 1: must ✗ ('Have to' expresses obligation, but the task asks for one modal verb, and 'must' fits a formal rule best.)
- **C1:** correct — 'Have to' works well here and is a perfectly natural way to express a strict rule. 'Must' would also be a strong fit for a written sign, but 'have to' is correct and commonly used. Right answer — there appears to be a hidden zero-width character between 'have' and 'to' from your keyboard, but that doesn't affect the meaning at all.
- **Owner:** C8 inconsistent with its own nbsp verdict; the question's "one modal verb" contradicts its own key.

### sfree:G-F:tenseSelection:tense-sw-2 (sentence_writing, sfree:error)

> You are giving a short talk to new students at your language school about your first job. You worked as a receptionist at a hotel in your hometown for three years before moving abroad.
> Write one sentence using the past simple to describe what your job at the hotel involved.

- **Learner's answer:** "When I was working as a receptionist at the hotel, I greeted guests, answered phone calls and I managed bookings every day."
- **Key:** ""
- **Truth:** correct
- **C8:** needs work — Your sentence describes the job as an ongoing background moment, but the prompt wants the simple past to say what the job involved. Also, the list would sound smoother without the second 'I'. *Summary:* For describing a finished job, use the simple past rather than the continuous. Keep list items parallel with one subject. *Blanks:* 1: At the hotel, I greeted guests, answered phone calls and managed bookings every day. ✗ (The prompt asks for past simple, but 'When I was working' uses past continuous; also the list should not repeat 'I'.)
- **C1:** needs work — Your sentence starts with 'When I was working…', which shifts the focus to an ongoing background action rather than describing what the job regularly involved — it sounds more like you're setting a scene than listing your duties. For talking about what a past job included day-to-day, it's more natural to just use the simple past: 'I greeted guests, answered phone calls, and managed bookings every day.'
- **Owner:** the owner's label stands as defensible; both models wrong.

## B. C8 and C1 differ (21)

### pool:fb01_1:wrong:1 (fill_in_blank, predicted_wrong)

> At the weekend market, Lena talks about her budget: "I can't afford ____ all my vegetables here, so I buy some at the supermarket."
> Fill in the blank with the correct form of the verb (buy).

- **Learner's answer:** "buying"
- **Key:** "to buy"
- **Truth:** wrong
- **C8:** needs work — This sounds off because 'afford' is usually followed by 'to' and the verb, so it should be 'can't afford to buy'. Think of it as 'can't afford to do something' every time. *Summary:* 'Afford' takes 'to' plus the verb, not -ing. Use 'can't afford to buy' as a fixed pattern. *Blanks:* 1: to buy ✗ ('Afford' is followed by 'to' plus the base verb, so 'to buy' is correct.)
- **C1:** correct — 'Buying' is exactly right. After 'can't afford', you use the -ing form, and that's just what you did.
- **Owner:** C8 right.

### pool:fb01_1:wrong:2 (fill_in_blank, predicted_wrong)

> At the weekend market, Lena talks about her budget: "I can't afford ____ all my vegetables here, so I buy some at the supermarket."
> Fill in the blank with the correct form of the verb (buy).

- **Learner's answer:** "buy"
- **Key:** "to buy"
- **Truth:** wrong
- **C8:** needs work — Lena is talking about what she can't pay for, so the word 'afford' needs 'to' before the verb. Say 'can't afford to buy', which is the natural phrasing for this kind of budget comment. *Summary:* 'Afford' is followed by 'to' plus the base verb. Without 'to', the sentence doesn't sound natural. *Blanks:* 1: to buy ✗ ('Afford' needs 'to' before the verb, so the answer should be 'to buy'.)
- **C1:** correct — Actually, 'afford' is typically followed by a verb ending in '-ing' (e.g. 'I can't afford buying'), though in many contexts 'afford to buy' is also standard. Your answer 'buy' is the bare form — the most natural fit here is 'buying' or 'to buy', but if the blank expected the base form in context, this is borderline. The safest and most natural choice is 'buying' after 'afford'.
- **Owner:** C8 right.

### pool:fb02_3:key (fill_in_blank, key)

> Ali got a job at a large company. He says that ___ salary is much higher than his old one, so he can save more.
> Fill in the blank with one word.

- **Learner's answer:** "the"
- **Key:** "the"
- **Truth:** correct
- **C8:** needs work — 'The' sounds off here. We are talking about Ali's own pay, so 'his' is the natural word. *Summary:* When something belongs to the person in the sentence, use a possessive word like 'his' rather than 'the'. *Blanks:* 1: his ✗ (Ali's own salary needs the possessive 'his', not 'the'.)
- **C1:** correct — 'The' is spot on here — when Ali mentions his salary at the new company, it's a specific salary both he and the listener already understand from context, so 'the' is the natural choice.
- **Owner:** C1 right.

### pool:fb04_1:wrong:2 (fill_in_blank, predicted_wrong)

> Maria is at a park. She wants to throw away her plastic bottle. She says: "Excuse me, is there ___ recycling bin near here?" (She does not know of any particular bin.)
> Fill in the blank with the correct article.

- **Learner's answer:** "an"
- **Key:** "a"
- **Truth:** wrong
- **C8:** needs work — 'Recycling' starts with an 'r' sound, so it sounds natural with 'a' and not 'an'. Say 'a recycling bin' out loud and it will feel right. *Summary:* The article depends on the sound at the start of the next word, not the spelling. 'Recycling' begins with a consonant sound, so it takes 'a'. *Blanks:* 1: a ✗ ('Recycling' starts with a consonant sound, so 'a' fits and 'an' does not.)
- **C1:** correct — Spot on — because 'recycling' starts with the vowel sound 'r'... wait, actually 'recycling' starts with the sound 'r', but 'an' is used here because the question is about a non-specific bin and 'a' would normally apply. Actually, 'a recycling bin' is standard since 'recycling' begins with a consonant sound. However, your answer 'an' was marked correct — re-checking: 'a' is the correct article here since 'recycling' starts with the consonant sound /r/. Correction: the right article is 'a recycling bin'. Use 'an' before vowel sounds (an apple, an hour) and 'a' before consonant sounds — 'recycling' starts with the /r/ sound, so 'a' is the right choice here.
- **Owner:** C8 right.

### pool:fb06_2:key (error_correction, key)

> The flat has a sun in the living room all afternoon.
> Correct the sentence by rewriting it in full.

- **Learner's answer:** "The flat has the sun in the living room all afternoon."
- **Key:** "The flat has the sun in the living room all afternoon."
- **Truth:** correct
- **C8:** correct — Your version is grammatical, since 'the sun' is a single unique thing and works here. Still, 'gets sun' sounds more natural to a native speaker when describing light in a room. *Summary:* 'The sun' is fine, but 'a sun' was the mistake because there is only one sun. 'Gets sun' is the most natural way to say it. *Blanks:* 1: The flat gets sun in the living room all afternoon. ✓ (Grammatical and understandable; 'gets sun' is the more natural phrasing.)
- **C1:** needs work — Saying 'has the sun' still sounds a bit unnatural in English — we don't really talk about a room 'having the sun'. The natural way to say it is 'gets sunlight' or 'gets a lot of sun'. Swapping 'a' for 'the' doesn't fix the core problem with the phrasing.
- **Owner:** C8 right.

### pool:fb07_1:accepted:1 (error_correction, accepted)

> I am reading this newspaper since I was a teenager.
> Correct the sentence by rewriting it in full.

- **Learner's answer:** "I have read this newspaper since I was a teenager."
- **Key:** "I have been reading this newspaper since I was a teenager."
- **Truth:** correct
- **C8:** correct — Your version is grammatically fine, and it fixes the 'am reading' problem because 'since' points back to a start in the past. 'I have been reading' sounds more natural, though, because it shows the reading is still going on, while 'have read' can sound like you have finished. *Summary:* With 'since' and an activity that is still ongoing, use the present perfect continuous. The simple form is acceptable but suggests a completed action. *Blanks:* 1: have been reading ✓ (Your 'have read' is grammatical and fixes the tense, but 'have been reading' fits an ongoing habit better.)
- **C1:** needs work — Because the reading started in the past and is still going on now, the sentence needs 'have been reading' rather than 'have read' — the ongoing, unfinished nature of the action calls for the continuous form here.
- **Owner:** C8 right.

### synth:fb01_1:kb:umlaut (fill_in_blank, kb:umlaut)

> At the weekend market, Lena talks about her budget: "I can't afford ____ all my vegetables here, so I buy some at the supermarket."
> Fill in the blank with the correct form of the verb (buy).

- **Learner's answer:** "tö buy"
- **Key:** "to buy"
- **Truth:** correct
- **C8:** correct — Right idea. The 'ö' in 'tö' is just a keyboard variant of the letter 'o', so this is 'to buy'. Remember that 'afford' is followed by 'to' plus the base verb, as in 'can't afford to buy'. *Summary:* 'Afford' is followed by 'to' and the base verb, so 'to buy' is correct. The 'ö' is only a keyboard variant of 'o'. *Blanks:* 1: to buy ✓ ('tö buy' is 'to buy' typed with an 'ö' keyboard variant, and the infinitive after 'afford' is correct.)
- **C1:** needs work — After 'afford', the next verb should be 'buying' — 'I can't afford buying' sounds natural here. The 'ö' looks like it was typed on a Turkish keyboard, but the bigger issue is that 'afford' takes the -ing form (or 'to + verb' is also acceptable — 'afford to buy' works too), not 'tö buy' with the umlaut character.
- **Owner:** C8 right.

### synth:fb02_3:kb:zero_width (fill_in_blank, kb:zero_width)

> Ali got a job at a large company. He says that ___ salary is much higher than his old one, so he can save more.
> Fill in the blank with one word.

- **Learner's answer:** "t​he"
- **Key:** "the"
- **Truth:** correct
- **C8:** correct — Right word. There is an invisible character before 'the' that doesn't change the word, so it reads as 'the' in English. Use 'the' before 'salary' because the salary is a specific one already known to the listener. *Summary:* 'The' is used before a specific noun both speaker and listener know about. Invisible characters are a keyboard issue, not a grammar mistake. *Blanks:* 1: the ✓ ('The' is right here because it refers to a specific salary, the one Ali's new job pays.)
- **C1:** needs work — Using 'the' here sounds a bit odd because we don't know whose salary is being talked about without a ownership word. Since Ali is talking about his own salary, 'his' is the natural and clear choice — it immediately tells us it belongs to him. Note: there appears to be a hidden/invisible character in your answer ('t​he'), which may have been a technical typing issue.
- **Owner:** C8 right.

### synth:fb02_4:kb:umlaut (error_correction, kb:umlaut)

> I pay my rent yesterday, so I have no money left.
> Rewrite the full sentence with the error corrected.

- **Learner's answer:** "I päid my rent yesterday, so I have no money left."
- **Key:** "I paid my rent yesterday, so I have no money left."
- **Truth:** correct
- **C8:** correct — Right fix on the verb. Since you're talking about yesterday, the past form 'paid' is what sounds natural here. Right word too: 'ä' and 'a' are the same letter here, just typed on a different keyboard. *Summary:* Use the past form of 'pay' ('paid') when the action happened yesterday. Accented letters like 'ä' are keyboard variants, not mistakes. *Blanks:* 1: paid ✓ ('päid' is the same word as 'paid', typed with a different keyboard character.)
- **C1:** needs work — 'Päid' looks like a keyboard character issue (ä instead of a), but even setting that aside, the core fix needed here is changing 'pay' to 'paid' — because 'yesterday' tells us this happened in the past, so the verb needs to match. The corrected sentence is: 'I paid my rent yesterday, so I have no money left.'
- **Owner:** C8 right.

### synth:fb03_2:kb:turkish (fill_in_blank, kb:turkish)

> At the public pool, a sign says: 'Swimmers ___ wear a cap. It is a strict rule.'
> Fill in the blank with one modal verb.

- **Learner's answer:** "muşt"
- **Key:** "must"
- **Truth:** correct
- **C8:** correct — Right word, though 'ş' and 's' are the same letter here, just typed on a different keyboard. 'Must' shows a strict rule that everyone has to follow, which fits the sign. *Summary:* Use 'must' for a strict rule that people are required to follow. Watch for keyboard accent variants in your typing. *Blanks:* 1: must ✓ ('Must' is the right modal for a firm, strict pool rule.)
- **C1:** needs work — The word you need is 'must', but 'muşt' isn't quite right — the 'ş' is a Turkish keyboard character that looks like 's' but is a different letter, and the extra 'u' at the start changes the word entirely. Double-check the spelling: m-u-s-t.
- **Owner:** C8 right.

### synth:fb03_5:kb:umlaut (error_correction, kb:umlaut)

> I am running marathons since I was twenty.
> Correct the sentence.

- **Learner's answer:** "I häve been running marathons since I was twenty."
- **Key:** "I have been running marathons since I was twenty."
- **Truth:** correct
- **C8:** correct — Right sentence, 'ä' and 'a' are the same letter here, just typed on a different keyboard. The tense you used, 'have been running', correctly shows an activity that started at twenty and continues now. *Summary:* Use 'have been running' with 'since' for an activity that started earlier and is still going. Your answer had the right grammar, only with a keyboard character variant. *Blanks:* 1: I have been running marathons since I was twenty. ✓ ('Häve' is the same as 'have' with a different keyboard character, so it's accepted.)
- **C1:** needs work — The fix to the tense is right — 'I have been running' is exactly what's needed here because it describes something that started in the past and is still going on. However, 'häve' isn't a real English word; it looks like a keyboard issue with the 'ä' character, which should just be a plain 'a'. Write 'have' and the sentence is perfect.
- **Owner:** C8 right.

### synth:fb04_1:kb:acute (fill_in_blank, kb:acute)

> Maria is at a park. She wants to throw away her plastic bottle. She says: "Excuse me, is there ___ recycling bin near here?" (She does not know of any particular bin.)
> Fill in the blank with the correct article.

- **Learner's answer:** "á"
- **Key:** "a"
- **Truth:** correct
- **C8:** correct — Right word, since Maria means any recycling bin, not a particular one, so 'a' is the natural choice. Right word, but 'á' and 'a' are the same letter here, just typed on a different keyboard. *Summary:* Use 'a' before a consonant sound when you mean any one of something. The accent on the letter doesn't change the word. *Blanks:* 1: a ✓ ('a' is the right article because it's any recycling bin, not a specific one; the accent is only a keyboard difference.)
- **C1:** needs work — The answer is 'a' — since she doesn't have a specific bin in mind, 'a' is the natural choice, the way you'd say 'Is there a café near here?' Also, 'á' looks like it was typed with an accent by mistake; in English 'a' doesn't carry an accent mark.
- **Owner:** C8 right.

### synth:fb06_4:kb:acute (error_correction, kb:acute)

> We live in this neighbourhood since 2018.
> Correct the sentence by rewriting it in full.

- **Learner's answer:** "Wé have lived in this neighbourhood since 2018."
- **Key:** "We have lived in this neighbourhood since 2018."
- **Truth:** correct
- **C8:** correct — This sounds right to a native ear: 'since 2018' describes something that started in the past and is still true now, so 'have lived' fits better than 'live'. Right word, just typed with an accent: 'é' and 'e' are the same letter here, just typed on a different keyboard. Right fix, and you wrote out the full sentence. *Summary:* Use the present perfect (have/has + past participle) with 'since' for something that started in the past and continues now. The accent on 'é' is just a keyboard variant of 'e'. *Blanks:* 1: We have lived in this neighbourhood since 2018. ✓ (The full sentence is correct; 'have lived' matches 'since 2018'.)
- **C1:** needs work — The sentence is almost perfect — 'have lived … since 2018' is exactly right. The only issue is the accent on 'Wé', which isn't a real English letter. Drop the accent and write 'We have lived in this neighbourhood since 2018.' Right fix on the grammar — just watch that accidental accent key next time.
- **Owner:** C8 right.

### synth:fb06_4:kb:umlaut (error_correction, kb:umlaut)

> We live in this neighbourhood since 2018.
> Correct the sentence by rewriting it in full.

- **Learner's answer:** "We häve lived in this neighbourhood since 2018."
- **Key:** "We have lived in this neighbourhood since 2018."
- **Truth:** correct
- **C8:** correct — Right idea: you're describing something that started in the past and still continues, which sounds natural with 'have lived' and 'since'. Right word too, though 'ä' and 'a' are the same letter here, just typed on a different keyboard. *Summary:* Use 'have lived' with 'since' for something that started in the past and continues now. 'ä' and 'a' are the same letter, just a different keyboard character. *Blanks:* 1: have lived ✓ (Right form, with the accent being only a keyboard difference.)
- **C1:** needs work — The sentence needed 'have lived' instead of 'live' because 'since 2018' tells us the action started in the past and continues now — 'live' on its own doesn't fit that timeline. Also, 'häve' uses an umlaut character (ä) that doesn't belong in English — the word is spelled 'have'. Fix both of these and you've got it right.
- **Owner:** C8 right.

### synth:fb07_1:kb:umlaut (error_correction, kb:umlaut)

> I am reading this newspaper since I was a teenager.
> Correct the sentence by rewriting it in full.

- **Learner's answer:** "I häve been reading this newspaper since I was a teenager."
- **Key:** "I have been reading this newspaper since I was a teenager."
- **Truth:** correct
- **C8:** correct — Right word and structure: 'have been reading' fits an ongoing habit that started in the past. 'Ä' and 'a' are the same letter here, just typed on a different keyboard. *Summary:* Use 'have been' plus the -ing form for something that started in the past and continues now. Accented letters like 'ä' are keyboard variants, not spelling mistakes. *Blanks:* 1: I have been reading this newspaper since I was a teenager. ✓ ('Häve' is the word 'have' typed with an accented letter, which is a keyboard difference, so the form is right.)
- **C1:** needs work — 'I am reading... since I was a teenager' sounds wrong because 'since I was a teenager' tells us this started in the past and is still going — 'have been reading' is the natural fit. Also, 'häve' isn't a standard English word; it looks like a keyboard slip, but unlike Turkish keyboard characters (ı, ş, etc.), 'ä' is not in that set, so it counts as a spelling error here — write 'have'.
- **Owner:** C8 right.

### synth:fb07_3:kb:umlaut (error_correction, kb:umlaut)

> The presenter said that the show will start at nine.
> Correct the sentence by rewriting it in full.

- **Learner's answer:** "The presenter säid that the show would start at nine."
- **Key:** "The presenter said that the show would start at nine."
- **Truth:** correct
- **C8:** correct — Right fix, and the tense shift to 'would' is exactly what reporting speech needs. Right word, though 'ä' and 'a' are the same letter here, just typed on a different keyboard. Right fix, next time write out the full sentence for practice. *Summary:* When reporting what someone said in the past, move 'will' back to 'would' and 'said' stays in the past. Watch for keyboard accent variants in your typing. *Blanks:* 1: The presenter said that the show would start at nine. ✓ (Your corrected sentence is right, with 'would' matching the past reporting verb.)
- **C1:** needs work — You got the grammar right — changing 'will' to 'would' is exactly the fix needed — but 'säid' isn't a real English word. It looks like a keyboard slip with the umlaut 'ä' instead of plain 'a'. Fix that spelling and your sentence is perfect.
- **Owner:** C8 right.

### synth:fb07_4:kb:nbsp (fill_in_blank, kb:nbsp)

> At the cinema entrance, a sign says that entry without a ticket is forbidden by the rules. It says: "You ___ show your ticket before entering the screening room."
> Write the one modal verb that fits best to show a strict rule.

- **Learner's answer:** "have to"
- **Key:** "have to"
- **Truth:** correct
- **C8:** correct — 'Have to' also sounds natural here and gives the same strict rule meaning. The question asks for a single modal verb, and 'must' is the one that fits a sign best. *Summary:* For a firm rule on a sign, 'must' is the best single modal verb. 'Have to' is a close alternative with the same meaning. *Blanks:* 1: must ✓ ('Have to' is defensible here, but 'must' is the single modal verb that best fits a strict rule on a sign.)
- **C1:** needs work — For a strict, posted rule (like a cinema sign), 'must' is the most natural single word — it has a firm, official tone that 'have to' doesn't quite match in formal signage. Also, the question asked for one modal verb, and 'have to' is two words, so 'must' is the expected answer here.
- **Owner:** C8 right.

### synth:fb07_4:kb:zero_width (fill_in_blank, kb:zero_width)

> At the cinema entrance, a sign says that entry without a ticket is forbidden by the rules. It says: "You ___ show your ticket before entering the screening room."
> Write the one modal verb that fits best to show a strict rule.

- **Learner's answer:** "h​ave to"
- **Key:** "have to"
- **Truth:** correct
- **C8:** needs work — 'Have to' also means a rule, but the task asks for a single modal verb, and 'must' fits a strict written rule best. Your entry also contains an invisible extra character, so check that the word is typed cleanly. *Summary:* For a strict written rule, 'must' is the best single modal verb. 'Have to' is a semi-modal, so it is less precise for this task. *Blanks:* 1: must ✗ ('Have to' expresses obligation, but the task asks for one modal verb, and 'must' fits a formal rule best.)
- **C1:** correct — 'Have to' works well here and is a perfectly natural way to express a strict rule. 'Must' would also be a strong fit for a written sign, but 'have to' is correct and commonly used. Right answer — there appears to be a hidden zero-width character between 'have' and 'to' from your keyboard, but that doesn't affect the meaning at all.
- **Owner:** C1 right.

### synth:fb07_5:kb:umlaut (fill_in_blank, kb:umlaut)

> Tom turns on his radio in the car and says: "Look, there's ___ interview with my favourite singer on this station tonight!"
> Write the correct article.

- **Learner's answer:** "än"
- **Key:** "an"
- **Truth:** correct
- **C8:** correct — Right word: 'interview' starts with a vowel sound, so it needs 'an' rather than 'a'. Your 'ä' and 'a' are the same letter here, just typed on a different keyboard, so the answer is still correct as typed. *Summary:* Use 'an' before a word that starts with a vowel sound, such as 'interview'. Your answer is correct apart from the keyboard character difference. *Blanks:* 1: an ✓ ('Interview' starts with a vowel sound, so 'an' is the right article.)
- **C1:** needs work — The word you want is 'an' — we use 'an' (not 'a') before a word that starts with a vowel sound, like 'interview'. It looks like your keyboard typed 'ä' instead of 'a', but the article also needs the 'n', so the full correct answer is 'an'.
- **Owner:** C8 right.

### synth:debug_articles_4:keyboard_in_box (fill_in_blank, partial:keyboard_in_box)

> ____ sun was setting when ____ old man sat down on ____ bench and opened ____ newspaper.
> Fill in each blank with a, an or the, or tap — for no article.

- **Learner's answer:** "Thé sun was setting when an old man sat down on a bench and opened a newspaper."
- **Key:** "The sun was setting when an old man sat down on a bench and opened a newspaper." — per blank: 1: "Thé" ✓, 2: "an" ✓, 3: "a" ✓, 4: "a" ✓
- **Truth:** correct
- **C8:** correct — Right words throughout: 'the sun' is the one sun we all know, 'an old man' starts with a vowel sound, and 'a bench' and 'a newspaper' introduce things for the first time. Right word, 'Thé' and 'The' are the same letters here, just typed with a different keyboard character. *Summary:* Use 'the' for something unique or already known, 'a' or 'an' for something mentioned for the first time, and match 'an' to a vowel sound. *Blanks:* 1: the ✓ (Right word, 'Thé' and 'The' are the same letters here, just typed on a different keyboard.) | 2: an ✓ ('Old' starts with a vowel sound, so 'an' is correct.) | 3: a ✓ ('Bench' is a first mention and starts with a consonant sound, so 'a' is correct.) | 4: a ✓ ('Newspaper' is a first mention and starts with a consonant sound, so 'a' is correct.)
- **C1:** needs work — Almost perfect — 'the sun', 'an old man', and 'a bench' are all exactly right. The one to revisit is the last blank: once the old man has a newspaper, it becomes 'the newspaper' (a specific one, his), so 'a newspaper' sounds slightly off at the end. Also, 'Thé' looks like a keyboard character difference — no problem, 'the' is correct there.
- **Owner:** C8 right.

### sfree:G-F:articles:articles-ec-2 (error_correction, sfree:correct)

> Students in a university often find it difficult to balance a part-time job with the studies.
> Find the mistake and rewrite the full corrected sentence.

- **Learner's answer:** "Students at a university often find it difficult to balance a part-time job with their studies."
- **Key:** ""
- **Truth:** correct
- **C8:** correct — Good fix: 'their studies' sounds natural because you are talking about the students' own studies. 'At a university' is also the more natural choice here, since it is the usual way to say it. *Summary:* Use 'their' with plural nouns when you mean the people's own things, and 'at a university' is the usual phrase for studying there. *Blanks:* 1: Students at a university often find it difficult to balance a part-time job with their studies. ✓ ('Their studies' is the right fix because it matches 'students' and shows whose studies they are.)
- **C1:** needs work — You spotted the real error — 'their studies' instead of 'the studies' — and that's the main fix. However, the phrase 'at a university' still sounds a little off here; when you mean university as a stage of life in general, English naturally says 'at university' with no article, similar to how we say 'at school' or 'in hospital'. Your corrected sentence is nearly perfect; just drop the 'a' before 'university'.
- **Owner:** C8 right.

