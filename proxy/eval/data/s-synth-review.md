# S-synth — synthetic learner answers for the owner's review

Each line: the expected verdict, the answer as typed, and why it is in the set. Every answer is right or wrong **by construction**; your job is to catch the ones where the construction is wrong for this question (a "contraction" that does not fit, a near-miss that is in fact acceptable, a keyboard variant that changed the meaning). Put the id of any line you disagree with, one per line, into `proxy/eval/data/s-synth-exclusions.txt`; those answers are left out of the run. About 15 minutes.

166 answers.


## fb01_1 — key: "to buy"

> At the weekend market, Lena talks about her budget: "I can't afford ____ all my vegetables here, so I buy some at the supermarket."
> Fill in the blank with the correct form of the verb (buy).

- `synth:fb01_1:kb:fullwidth` CORRECT "ｔｏ　ｂｕｙ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb01_1:kb:acute` CORRECT "tó buy" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb01_1:kb:umlaut` CORRECT "tö buy" — the key typed on a de keyboard (umlaut)
- `synth:fb01_1:nearmiss:to_plus_ing` WRONG   "to buying" — a real mistake close to the key (to plus ing): must be marked wrong

## fb01_2 — key: "the"

> At a restaurant, a waiter says: "Today we have fish soup and grilled chicken. I recommend ____ soup; it's the chef's special."
> Fill in the blank with the correct article.

- `synth:fb01_2:kb:fullwidth` CORRECT "ｔｈｅ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb01_2:kb:acute` CORRECT "thé" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb01_2:kb:zero_width` CORRECT "t​he" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb01_2:nearmiss:add_s` WRONG   "thes" — a real mistake close to the key (add s): must be marked wrong

## fb01_3 — key: "am cooking"

> You phone your brother at 7 p.m. and hear noises. He says: "Sorry, I can't talk long. I ____ dinner for my friends right now."
> Fill in the blank with the correct form of the verb (cook).

- `synth:fb01_3:kb:umlaut` CORRECT "äm cooking" — the key typed on a de keyboard (umlaut)
- `synth:fb01_3:kb:turkish` CORRECT "am cookıng" — the key typed on a tr keyboard (turkish)
- `synth:fb01_3:kb:nbsp` CORRECT "am cooking" — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb01_3:contraction` CORRECT "'m cooking" — the key with a contraction expanded or made: is it still right here?
- `synth:fb01_3:nearmiss:drop_last_word` WRONG   "am" — a real mistake close to the key (drop last word): must be marked wrong

## fb01_4 — key: "Yesterday, the baker told me that he could make a cake for my party."

> Yesterday, the baker told me that he can make a cake for my party.
> Rewrite the sentence with the error corrected.

- `synth:fb01_4:kb:turkish` CORRECT "Yeşterday, the baker told me that he could make a cake for my party." — the key typed on a tr keyboard (turkish)
- `synth:fb01_4:kb:nbsp` CORRECT "Yesterday, the baker told me that he could make a cake for my party." — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb01_4:kb:zero_width` CORRECT "Y​esterday, the baker told me that he could make a cake for my party." — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb01_4:nearmiss:original_sentence` WRONG   "Yesterday, the baker told me that he can make a cake for my party." — a real mistake close to the key (original sentence): must be marked wrong

## fb01_5 — key: "You must wash your hands before you touch the food."

> You must to wash your hands before you touch the food.
> Rewrite the sentence with the error corrected.

- `synth:fb01_5:kb:nbsp` CORRECT "You must wash your hands before you touch the food." — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb01_5:kb:zero_width` CORRECT "Y​ou must wash your hands before you touch the food." — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb01_5:kb:fullwidth` CORRECT "Ｙｏｕ　ｍｕｓｔ　ｗａｓｈ　ｙｏｕｒ　ｈａｎｄｓ　ｂｅｆｏｒｅ　ｙｏｕ　ｔｏｕｃｈ　ｔｈｅ　ｆｏｏｄ．" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb01_5:nearmiss:original_sentence` WRONG   "You must to wash your hands before you touch the food." — a real mistake close to the key (original sentence): must be marked wrong

## fb02_1 — key: "Last year, the manager promised that the bank would approve my loan."

> Last year, the manager promised that the bank will approve my loan.
> Rewrite the full sentence with the error corrected.

- `synth:fb02_1:kb:zero_width` CORRECT "L​ast year, the manager promised that the bank would approve my loan." — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb02_1:kb:fullwidth` CORRECT "Ｌａｓｔ　ｙｅａｒ，　ｔｈｅ　ｍａｎａｇｅｒ　ｐｒｏｍｉｓｅｄ　ｔｈａｔ　ｔｈｅ　ｂａｎｋ　ｗｏｕｌｄ　ａｐｐｒｏｖｅ　ｍｙ　ｌｏａｎ．" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb02_1:kb:acute` CORRECT "Lást year, the manager promised that the bank would approve my loan." — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb02_1:nearmiss:original_sentence` WRONG   "Last year, the manager promised that the bank will approve my loan." — a real mistake close to the key (original sentence): must be marked wrong

## fb02_2 — key: "You should check your bank balance before you shop online."

> You should to check your bank balance before you shop online.
> Rewrite the full sentence with the error corrected.

- `synth:fb02_2:kb:fullwidth` CORRECT "Ｙｏｕ　ｓｈｏｕｌｄ　ｃｈｅｃｋ　ｙｏｕｒ　ｂａｎｋ　ｂａｌａｎｃｅ　ｂｅｆｏｒｅ　ｙｏｕ　ｓｈｏｐ　ｏｎｌｉｎｅ．" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb02_2:kb:acute` CORRECT "Yóu should check your bank balance before you shop online." — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb02_2:kb:umlaut` CORRECT "Yöu should check your bank balance before you shop online." — the key typed on a de keyboard (umlaut)
- `synth:fb02_2:nearmiss:original_sentence` WRONG   "You should to check your bank balance before you shop online." — a real mistake close to the key (original sentence): must be marked wrong

## fb02_3 — key: "the"

> Ali got a job at a large company. He says that ___ salary is much higher than his old one, so he can save more.
> Fill in the blank with one word.

- `synth:fb02_3:kb:fullwidth` CORRECT "ｔｈｅ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb02_3:kb:acute` CORRECT "thé" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb02_3:kb:zero_width` CORRECT "t​he" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb02_3:nearmiss:add_s` WRONG   "thes" — a real mistake close to the key (add s): must be marked wrong

## fb02_4 — key: "I paid my rent yesterday, so I have no money left."

> I pay my rent yesterday, so I have no money left.
> Rewrite the full sentence with the error corrected.

- `synth:fb02_4:kb:umlaut` CORRECT "I päid my rent yesterday, so I have no money left." — the key typed on a de keyboard (umlaut)
- `synth:fb02_4:kb:turkish` CORRECT "I paıd my rent yesterday, so I have no money left." — the key typed on a tr keyboard (turkish)
- `synth:fb02_4:kb:nbsp` CORRECT "I paid my rent yesterday, so I have no money left." — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb02_4:contraction` CORRECT "I paid my rent yesterday, so I've no money left." — the key with a contraction expanded or made: is it still right here?
- `synth:fb02_4:nearmiss:original_sentence` WRONG   "I pay my rent yesterday, so I have no money left." — a real mistake close to the key (original sentence): must be marked wrong

## fb02_5 — key: "buying"

> Sara wants to save money, so she has decided to avoid ___ expensive coffee every morning. (buy)
> Fill in the blank with the correct form of the verb.

- `synth:fb02_5:kb:zero_width` CORRECT "b​uying" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb02_5:kb:fullwidth` CORRECT "ｂｕｙｉｎｇ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb02_5:kb:acute` CORRECT "búying" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb02_5:nearmiss:ing_to_base` WRONG   "buy" — a real mistake close to the key (ing to base): must be marked wrong

## fb03_1 — key: "The coach said that the team would train at six."

> The coach said that the team will train at six.
> Correct the sentence.

- `synth:fb03_1:kb:nbsp` CORRECT "The coach said that the team would train at six." — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb03_1:kb:zero_width` CORRECT "T​he coach said that the team would train at six." — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb03_1:kb:fullwidth` CORRECT "Ｔｈｅ　ｃｏａｃｈ　ｓａｉｄ　ｔｈａｔ　ｔｈｅ　ｔｅａｍ　ｗｏｕｌｄ　ｔｒａｉｎ　ａｔ　ｓｉｘ．" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb03_1:nearmiss:original_sentence` WRONG   "The coach said that the team will train at six." — a real mistake close to the key (original sentence): must be marked wrong

## fb03_2 — key: "must"

> At the public pool, a sign says: 'Swimmers ___ wear a cap. It is a strict rule.'
> Fill in the blank with one modal verb.

- `synth:fb03_2:kb:acute` CORRECT "múst" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb03_2:kb:umlaut` CORRECT "müst" — the key typed on a de keyboard (umlaut)
- `synth:fb03_2:kb:turkish` CORRECT "muşt" — the key typed on a tr keyboard (turkish)
- `synth:fb03_2:nearmiss:add_s` WRONG   "musts" — a real mistake close to the key (add s): must be marked wrong

## fb03_3 — key: "competing"

> My brother plays tennis every weekend because he really enjoys ___ against strong opponents. (compete)
> Write the correct form of the verb.

- `synth:fb03_3:kb:umlaut` CORRECT "cömpeting" — the key typed on a de keyboard (umlaut)
- `synth:fb03_3:kb:turkish` CORRECT "competıng" — the key typed on a tr keyboard (turkish)
- `synth:fb03_3:kb:zero_width` CORRECT "c​ompeting" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb03_3:nearmiss:ing_to_base` WRONG   "compet" — a real mistake close to the key (ing to base): must be marked wrong

## fb03_4 — key: "the"

> At a football match, a fan says: 'Our striker scored two goals, but ___ goalkeeper of the other team saved everything else.'
> Fill in the blank with the correct article.

- `synth:fb03_4:kb:fullwidth` CORRECT "ｔｈｅ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb03_4:kb:acute` CORRECT "thé" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb03_4:kb:zero_width` CORRECT "t​he" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb03_4:nearmiss:add_s` WRONG   "thes" — a real mistake close to the key (add s): must be marked wrong

## fb03_5 — key: "I have been running marathons since I was twenty."

> I am running marathons since I was twenty.
> Correct the sentence.

- `synth:fb03_5:kb:umlaut` CORRECT "I häve been running marathons since I was twenty." — the key typed on a de keyboard (umlaut)
- `synth:fb03_5:kb:turkish` CORRECT "I have been runnıng marathons since I was twenty." — the key typed on a tr keyboard (turkish)
- `synth:fb03_5:kb:nbsp` CORRECT "I have been running marathons since I was twenty." — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb03_5:contraction` CORRECT "I've been running marathons since I was twenty." — the key with a contraction expanded or made: is it still right here?
- `synth:fb03_5:nearmiss:original_sentence` WRONG   "I am running marathons since I was twenty." — a real mistake close to the key (original sentence): must be marked wrong

## fb04_1 — key: "a"

> Maria is at a park. She wants to throw away her plastic bottle. She says: "Excuse me, is there ___ recycling bin near here?" (She does not know of any particular bin.)
> Fill in the blank with the correct article.

- `synth:fb04_1:kb:fullwidth` CORRECT "ａ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb04_1:kb:acute` CORRECT "á" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb04_1:kb:umlaut` CORRECT "ä" — the key typed on a de keyboard (umlaut)
- `synth:fb04_1:nearmiss:add_s` WRONG   "as" — a real mistake close to the key (add s): must be marked wrong

## fb04_2 — key: "are cleaning"

> A volunteer speaks on the phone: "I can't talk now. We ___ the river bank at the moment, and my hands are full." (clean)
> Fill in the blank with the correct form of the verb in brackets.

- `synth:fb04_2:kb:nbsp` CORRECT "are cleaning" — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb04_2:kb:zero_width` CORRECT "a​re cleaning" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb04_2:kb:fullwidth` CORRECT "ａｒｅ　ｃｌｅａｎｉｎｇ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb04_2:contraction` CORRECT "'re cleaning" — the key with a contraction expanded or made: is it still right here?
- `synth:fb04_2:nearmiss:drop_last_word` WRONG   "are" — a real mistake close to the key (drop last word): must be marked wrong

## fb04_3 — key: "Last week, the landlord said that he would install solar panels."

> Last week, the landlord said that he will install solar panels.
> Rewrite the sentence with the error corrected.

- `synth:fb04_3:kb:zero_width` CORRECT "L​ast week, the landlord said that he would install solar panels." — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb04_3:kb:fullwidth` CORRECT "Ｌａｓｔ　ｗｅｅｋ，　ｔｈｅ　ｌａｎｄｌｏｒｄ　ｓａｉｄ　ｔｈａｔ　ｈｅ　ｗｏｕｌｄ　ｉｎｓｔａｌｌ　ｓｏｌａｒ　ｐａｎｅｌｓ．" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb04_3:kb:acute` CORRECT "Lást week, the landlord said that he would install solar panels." — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb04_3:nearmiss:original_sentence` WRONG   "Last week, the landlord said that he will install solar panels." — a real mistake close to the key (original sentence): must be marked wrong

## fb04_4 — key: "You should bring your own bag when you go shopping."

> You should to bring your own bag when you go shopping.
> Rewrite the sentence with the error corrected.

- `synth:fb04_4:kb:fullwidth` CORRECT "Ｙｏｕ　ｓｈｏｕｌｄ　ｂｒｉｎｇ　ｙｏｕｒ　ｏｗｎ　ｂａｇ　ｗｈｅｎ　ｙｏｕ　ｇｏ　ｓｈｏｐｐｉｎｇ．" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb04_4:kb:acute` CORRECT "Yóu should bring your own bag when you go shopping." — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb04_4:kb:umlaut` CORRECT "Yöu should bring your own bag when you go shopping." — the key typed on a de keyboard (umlaut)
- `synth:fb04_4:nearmiss:original_sentence` WRONG   "You should to bring your own bag when you go shopping." — a real mistake close to the key (original sentence): must be marked wrong

## fb04_5 — key: "I avoid driving to work because it pollutes the air."

> I avoid to drive to work because it pollutes the air.
> Rewrite the sentence with the error corrected.

- `synth:fb04_5:kb:acute` CORRECT "I ávoid driving to work because it pollutes the air." — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb04_5:kb:umlaut` CORRECT "I ävoid driving to work because it pollutes the air." — the key typed on a de keyboard (umlaut)
- `synth:fb04_5:kb:turkish` CORRECT "I avoıd driving to work because it pollutes the air." — the key typed on a tr keyboard (turkish)
- `synth:fb04_5:nearmiss:original_sentence` WRONG   "I avoid to drive to work because it pollutes the air." — a real mistake close to the key (original sentence): must be marked wrong

## fb05_1 — key: "would"

> Yesterday, a shop assistant told me, "We will have the new jackets on Friday." Later I told my friend about it.
> Complete the reported sentence with one word: The assistant said they ___ have the new jackets on Friday.

- `synth:fb05_1:kb:fullwidth` CORRECT "ｗｏｕｌｄ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb05_1:kb:acute` CORRECT "wóuld" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb05_1:kb:umlaut` CORRECT "wöuld" — the key typed on a de keyboard (umlaut)
- `synth:fb05_1:nearmiss:add_s` WRONG   "woulds" — a real mistake close to the key (add s): must be marked wrong

## fb05_2 — key: "I bought these shoes yesterday at the market."

> I have bought these shoes yesterday at the market.
> Rewrite the full sentence with the error corrected.

- `synth:fb05_2:kb:turkish` CORRECT "I bouğht these shoes yesterday at the market." — the key typed on a tr keyboard (turkish)
- `synth:fb05_2:kb:nbsp` CORRECT "I bought these shoes yesterday at the market." — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb05_2:kb:zero_width` CORRECT "I​ bought these shoes yesterday at the market." — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb05_2:nearmiss:original_sentence` WRONG   "I have bought these shoes yesterday at the market." — a real mistake close to the key (original sentence): must be marked wrong

## fb05_3 — key: "The"

> At the checkout, a customer says: "I'd like two loaves of bread, please." The cashier replies: "Sorry, we've sold out of bread. ___ bakery next door might still have some." There is only one bakery next door.
> Fill in the blank with one word.

- `synth:fb05_3:kb:fullwidth` CORRECT "Ｔｈｅ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb05_3:kb:acute` CORRECT "Thé" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb05_3:kb:zero_width` CORRECT "T​he" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb05_3:nearmiss:add_s` WRONG   "Thes" — a real mistake close to the key (add s): must be marked wrong

## fb05_4 — key: "You must try the jacket on before you buy it."

> You must to try the jacket on before you buy it.
> Rewrite the full sentence with the error corrected.

- `synth:fb05_4:kb:zero_width` CORRECT "Y​ou must try the jacket on before you buy it." — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb05_4:kb:fullwidth` CORRECT "Ｙｏｕ　ｍｕｓｔ　ｔｒｙ　ｔｈｅ　ｊａｃｋｅｔ　ｏｎ　ｂｅｆｏｒｅ　ｙｏｕ　ｂｕｙ　ｉｔ．" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb05_4:kb:acute` CORRECT "Yóu must try the jacket on before you buy it." — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb05_4:nearmiss:original_sentence` WRONG   "You must to try the jacket on before you buy it." — a real mistake close to the key (original sentence): must be marked wrong

## fb05_5 — key: "to ask"

> The blender you bought stopped working after two days, so you went back to the store.
> Complete the sentence with the correct form of the verb: I decided ___ (ask) for a refund.

- `synth:fb05_5:kb:fullwidth` CORRECT "ｔｏ　ａｓｋ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb05_5:kb:acute` CORRECT "tó ask" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb05_5:kb:umlaut` CORRECT "tö ask" — the key typed on a de keyboard (umlaut)
- `synth:fb05_5:nearmiss:to_plus_ing` WRONG   "to asking" — a real mistake close to the key (to plus ing): must be marked wrong

## fb06_1 — key: "My landlord promised that he would repair the heater."

> My landlord promised that he will repair the heater.
> Correct the sentence by rewriting it in full.

- `synth:fb06_1:kb:acute` CORRECT "My lándlord promised that he would repair the heater." — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb06_1:kb:umlaut` CORRECT "My ländlord promised that he would repair the heater." — the key typed on a de keyboard (umlaut)
- `synth:fb06_1:kb:turkish` CORRECT "My landlord promısed that he would repair the heater." — the key typed on a tr keyboard (turkish)
- `synth:fb06_1:nearmiss:original_sentence` WRONG   "My landlord promised that he will repair the heater." — a real mistake close to the key (original sentence): must be marked wrong

## fb06_2 — key: "The flat has the sun in the living room all afternoon."

> The flat has a sun in the living room all afternoon.
> Correct the sentence by rewriting it in full.

- `synth:fb06_2:kb:umlaut` CORRECT "The flät has the sun in the living room all afternoon." — the key typed on a de keyboard (umlaut)
- `synth:fb06_2:kb:turkish` CORRECT "The flat has the sun ın the living room all afternoon." — the key typed on a tr keyboard (turkish)
- `synth:fb06_2:kb:nbsp` CORRECT "The flat has the sun in the living room all afternoon." — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb06_2:nearmiss:original_sentence` WRONG   "The flat has a sun in the living room all afternoon." — a real mistake close to the key (original sentence): must be marked wrong

## fb06_3 — key: "must"

> You are renting a flat. The agent says: "The contract is a legal rule here, so you ___ sign it before you get the keys."
> Fill in the blank with one modal verb.

- `synth:fb06_3:kb:umlaut` CORRECT "müst" — the key typed on a de keyboard (umlaut)
- `synth:fb06_3:kb:turkish` CORRECT "muşt" — the key typed on a tr keyboard (turkish)
- `synth:fb06_3:kb:zero_width` CORRECT "m​ust" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb06_3:nearmiss:add_s` WRONG   "musts" — a real mistake close to the key (add s): must be marked wrong

## fb06_4 — key: "We have lived in this neighbourhood since 2018."

> We live in this neighbourhood since 2018.
> Correct the sentence by rewriting it in full.

- `synth:fb06_4:kb:fullwidth` CORRECT "Ｗｅ　ｈａｖｅ　ｌｉｖｅｄ　ｉｎ　ｔｈｉｓ　ｎｅｉｇｈｂｏｕｒｈｏｏｄ　ｓｉｎｃｅ　２０１８．" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb06_4:kb:acute` CORRECT "Wé have lived in this neighbourhood since 2018." — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb06_4:kb:umlaut` CORRECT "We häve lived in this neighbourhood since 2018." — the key typed on a de keyboard (umlaut)
- `synth:fb06_4:spelling` CORRECT "We have lived in this neighborhood since 2018." — the key in the other English spelling
- `synth:fb06_4:nearmiss:original_sentence` WRONG   "We live in this neighbourhood since 2018." — a real mistake close to the key (original sentence): must be marked wrong

## fb06_5 — key: "moving"

> Our flat is too small, so we are considering ___ to a bigger house next year. (move)
> Fill in the blank with the correct form of the verb.

- `synth:fb06_5:kb:zero_width` CORRECT "m​oving" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb06_5:kb:fullwidth` CORRECT "ｍｏｖｉｎｇ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb06_5:kb:acute` CORRECT "móving" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb06_5:nearmiss:ing_to_base` WRONG   "mov" — a real mistake close to the key (ing to base): must be marked wrong

## fb07_1 — key: "I have been reading this newspaper since I was a teenager."

> I am reading this newspaper since I was a teenager.
> Correct the sentence by rewriting it in full.

- `synth:fb07_1:kb:fullwidth` CORRECT "Ｉ　ｈａｖｅ　ｂｅｅｎ　ｒｅａｄｉｎｇ　ｔｈｉｓ　ｎｅｗｓｐａｐｅｒ　ｓｉｎｃｅ　Ｉ　ｗａｓ　ａ　ｔｅｅｎａｇｅｒ．" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb07_1:kb:acute` CORRECT "I háve been reading this newspaper since I was a teenager." — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb07_1:kb:umlaut` CORRECT "I häve been reading this newspaper since I was a teenager." — the key typed on a de keyboard (umlaut)
- `synth:fb07_1:contraction` CORRECT "I've been reading this newspaper since I was a teenager." — the key with a contraction expanded or made: is it still right here?
- `synth:fb07_1:nearmiss:original_sentence` WRONG   "I am reading this newspaper since I was a teenager." — a real mistake close to the key (original sentence): must be marked wrong

## fb07_2 — key: "listening"

> Maria listens to podcasts every morning on the bus. She says: "I really enjoy ___ to true crime podcasts."
> Write the correct form of the verb (listen).

- `synth:fb07_2:kb:zero_width` CORRECT "l​istening" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb07_2:kb:fullwidth` CORRECT "ｌｉｓｔｅｎｉｎｇ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb07_2:kb:acute` CORRECT "lístening" — the key typed on a es, pt-BR keyboard (acute)
- `synth:fb07_2:nearmiss:ing_to_base` WRONG   "listen" — a real mistake close to the key (ing to base): must be marked wrong

## fb07_3 — key: "The presenter said that the show would start at nine."

> The presenter said that the show will start at nine.
> Correct the sentence by rewriting it in full.

- `synth:fb07_3:kb:umlaut` CORRECT "The presenter säid that the show would start at nine." — the key typed on a de keyboard (umlaut)
- `synth:fb07_3:kb:turkish` CORRECT "The presenter saıd that the show would start at nine." — the key typed on a tr keyboard (turkish)
- `synth:fb07_3:kb:nbsp` CORRECT "The presenter said that the show would start at nine." — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb07_3:nearmiss:original_sentence` WRONG   "The presenter said that the show will start at nine." — a real mistake close to the key (original sentence): must be marked wrong

## fb07_4 — key: "have to"

> At the cinema entrance, a sign says that entry without a ticket is forbidden by the rules. It says: "You ___ show your ticket before entering the screening room."
> Write the one modal verb that fits best to show a strict rule.

- `synth:fb07_4:kb:nbsp` CORRECT "have to" — the key typed on a ja, ko, ar (and iOS after a full stop) keyboard (nbsp)
- `synth:fb07_4:kb:zero_width` CORRECT "h​ave to" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb07_4:kb:fullwidth` CORRECT "ｈａｖｅ　ｔｏ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb07_4:nearmiss:drop_last_word` WRONG   "have" — a real mistake close to the key (drop last word): must be marked wrong

## fb07_5 — key: "an"

> Tom turns on his radio in the car and says: "Look, there's ___ interview with my favourite singer on this station tonight!"
> Write the correct article.

- `synth:fb07_5:kb:umlaut` CORRECT "än" — the key typed on a de keyboard (umlaut)
- `synth:fb07_5:kb:zero_width` CORRECT "a​n" — the key typed on a ar (ZWNJ), copied text keyboard (zero_width)
- `synth:fb07_5:kb:fullwidth` CORRECT "ａｎ" — the key typed on a ja, ko keyboard (fullwidth)
- `synth:fb07_5:nearmiss:add_s` WRONG   "ans" — a real mistake close to the key (add s): must be marked wrong

## debug_articles_2 — key: "Honesty matters to her, so she gave me an honest answer."

> ____ honesty matters to her, so she gave me ____ honest answer.
> Fill in each blank with a, an or the, or tap — for no article.

- `synth:debug_articles_2:all_right` CORRECT "Honesty matters to her, so she gave me an honest answer." — every box as the key — per blank: 1: — ✓, 2: "an" ✓
- `synth:debug_articles_2:one_wrong` WRONG   "Honesty matters to her, so she gave me ans honest answer." — box 2 wrong ("ans"), the rest right — per blank: 1: — ✓, 2: "ans" ✗
- `synth:debug_articles_2:one_empty` WRONG   "Honesty matters to her, so she gave me ____ honest answer." — box 2 left empty (its ____ stays in the sentence), the rest right — per blank: 1: — ✓, 2: "" ✗
- `synth:debug_articles_2:article_where_none` WRONG   "the honesty matters to her, so she gave me an honest answer." — box 1 should be "—" (no article) but holds "the" — per blank: 1: "the" ✗, 2: "an" ✓

## debug_articles_3 — key: "We had lunch at a small café near the station."

> We had ____ lunch at ____ small café near ____ station.
> Fill in each blank with a, an or the, or tap — for no article.

- `synth:debug_articles_3:all_right` CORRECT "We had lunch at a small café near the station." — every box as the key — per blank: 1: — ✓, 2: "a" ✓, 3: "the" ✓
- `synth:debug_articles_3:one_wrong` WRONG   "We had lunch at as small café near the station." — box 2 wrong ("as"), the rest right — per blank: 1: — ✓, 2: "as" ✗, 3: "the" ✓
- `synth:debug_articles_3:one_empty` WRONG   "We had lunch at a small café near ____ station." — box 3 left empty (its ____ stays in the sentence), the rest right — per blank: 1: — ✓, 2: "a" ✓, 3: "" ✗
- `synth:debug_articles_3:article_where_none` WRONG   "We had the lunch at a small café near the station." — box 1 should be "—" (no article) but holds "the" — per blank: 1: "the" ✗, 2: "a" ✓, 3: "the" ✓

## debug_articles_4 — key: "The sun was setting when an old man sat down on a bench and opened a newspaper."

> ____ sun was setting when ____ old man sat down on ____ bench and opened ____ newspaper.
> Fill in each blank with a, an or the, or tap — for no article.

- `synth:debug_articles_4:all_right` CORRECT "The sun was setting when an old man sat down on a bench and opened a newspaper." — every box as the key — per blank: 1: "The" ✓, 2: "an" ✓, 3: "a" ✓, 4: "a" ✓
- `synth:debug_articles_4:one_wrong` WRONG   "Thes sun was setting when an old man sat down on a bench and opened a newspaper." — box 1 wrong ("Thes"), the rest right — per blank: 1: "Thes" ✗, 2: "an" ✓, 3: "a" ✓, 4: "a" ✓
- `synth:debug_articles_4:one_empty` WRONG   "The sun was setting when an old man sat down on a bench and opened ____ newspaper." — box 4 left empty (its ____ stays in the sentence), the rest right — per blank: 1: "The" ✓, 2: "an" ✓, 3: "a" ✓, 4: "" ✗
- `synth:debug_articles_4:keyboard_in_box` CORRECT "Thé sun was setting when an old man sat down on a bench and opened a newspaper." — box 1 typed as "Thé" (a keyboard variant of "The"), the rest right — per blank: 1: "Thé" ✓, 2: "an" ✓, 3: "a" ✓, 4: "a" ✓

## debug_gerund_2 — key: "I enjoy swimming (swim), but this year I have decided to learn (learn) tennis."

> I enjoy ____ (swim), but this year I have decided ____ (learn) tennis.
> Fill in each blank with the right form of the verb.

- `synth:debug_gerund_2:all_right` CORRECT "I enjoy swimming (swim), but this year I have decided to learn (learn) tennis." — every box as the key — per blank: 1: "swimming" ✓, 2: "to learn" ✓
- `synth:debug_gerund_2:one_wrong` WRONG   "I enjoy swimm (swim), but this year I have decided to learn (learn) tennis." — box 1 wrong ("swimm"), the rest right — per blank: 1: "swimm" ✗, 2: "to learn" ✓
- `synth:debug_gerund_2:one_empty` WRONG   "I enjoy swimming (swim), but this year I have decided ____ (learn) tennis." — box 2 left empty (its ____ stays in the sentence), the rest right — per blank: 1: "swimming" ✓, 2: "" ✗
- `synth:debug_gerund_2:keyboard_in_box` CORRECT "I enjoy swımming (swim), but this year I have decided to learn (learn) tennis." — box 1 typed as "swımming" (a keyboard variant of "swimming"), the rest right — per blank: 1: "swımming" ✓, 2: "to learn" ✓

## debug_gerund_3 — key: "She stopped smoking (smoke) last year, she avoids going (go) to smoky bars, and she plans to run (run) a marathon."

> She stopped ____ (smoke) last year, she avoids ____ (go) to smoky bars, and she plans ____ (run) a marathon.
> Fill in each blank with the right form of the verb.

- `synth:debug_gerund_3:all_right` CORRECT "She stopped smoking (smoke) last year, she avoids going (go) to smoky bars, and she plans to run (run) a marathon." — every box as the key — per blank: 1: "smoking" ✓, 2: "going" ✓, 3: "to run" ✓
- `synth:debug_gerund_3:one_wrong` WRONG   "She stopped smok (smoke) last year, she avoids going (go) to smoky bars, and she plans to run (run) a marathon." — box 1 wrong ("smok"), the rest right — per blank: 1: "smok" ✗, 2: "going" ✓, 3: "to run" ✓
- `synth:debug_gerund_3:one_empty` WRONG   "She stopped smoking (smoke) last year, she avoids going (go) to smoky bars, and she plans ____ (run) a marathon." — box 3 left empty (its ____ stays in the sentence), the rest right — per blank: 1: "smoking" ✓, 2: "going" ✓, 3: "" ✗
- `synth:debug_gerund_3:keyboard_in_box` CORRECT "She stopped smokıng (smoke) last year, she avoids going (go) to smoky bars, and she plans to run (run) a marathon." — box 1 typed as "smokıng" (a keyboard variant of "smoking"), the rest right — per blank: 1: "smokıng" ✓, 2: "going" ✓, 3: "to run" ✓
