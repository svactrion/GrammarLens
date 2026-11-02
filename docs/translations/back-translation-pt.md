# Back-translation check: Brazilian Portuguese (`app_pt.arb`)

1.4.0 B5, D6 ([`../1.4.0-b5-batch0-report.md`](../1.4.0-b5-batch0-report.md) §2, §8 Q3). The 83 keys with legal or App Review weight, or that complete those screens (the AI permission screen, onboarding's "Your data & AI", the Data screen's AI card, the paywall), translated back into English **blind**: a separate subagent was given only the Brazilian Portuguese strings and their keys, never the English, and asked for a literal rendering. Its notes on ambiguity are kept in the fourth column.

**Limit:** the back-translation was made by the same model family that wrote the Brazilian Portuguese, so it is a consistency check (a dropped clause, a changed number, a trial that became a discount, a lost "auto-renews", a changed recipient), not an independent review. D6 has no native-speaker review.

**Result:** 78 of 83 matched the English meaning on the first pass. Five were revised in `app_pt.arb` and back-translated again, blind, all matching: the never-sent list ("Nem … nem"), the order of asking ("Antes, pedimos" could read as past), and three paywall lines made consistent. The free trial is **"período grátis"** on purpose: the more usual "teste grátis" would share its word with the Daily Test ("Teste diário"), the collision the Spanish check found. The table shows each row's latest pass; the Δ column says what changed. **Owner sign-off: done 2026-11-03.** All rows approved as they stand; every revised row matched on its blind second pass; the same-model-family limit above stays.

| Key | English (original) | Back-translation | Subagent note | Δ |
|---|---|---|---|---|
| `dataAiCardTitle` | AI feedback | Feedback with AI | Literally 'feedback with AI'; 'feedback' is an English loanword, common in BP. | ✓ |
| `dataAiExplanation` | Practice sessions send your {what} to {provider} to create feedback. | The practice sessions send your {what} to {provider} to generate the feedback. | 'suas' (your) is feminine plural, so it only agrees if {what} starts with a feminine plural noun (it does with 'respostas'). 'o feedback' = 'the feedback' (definite article). | ✓ |
| `dataAiWhat` | typed answers and the questions | typed answers and the questions | First noun has no article (relies on 'suas' in the parent string), second has 'as' (the); combined it reads 'your typed answers and the questions', so 'your' does not clearly cover the questions. | ✓ |
| `dataAiSwitch` | Allow AI feedback | Allow feedback with AI |  | ✓ |
| `dataAiOn` | On · Required for practice sessions | On · Required for the practice sessions | 'Ativado' / 'Necessário' are masculine singular, agreeing with an implied 'feedback'; literally 'Activated'. | ✓ |
| `dataAiOff` | Off · Practice sessions need permission | Off · The practice sessions need permission | Literally 'Deactivated'. | ✓ |
| `dataAiDailyTestNote` | Daily Test works without this permission. | The Daily Test works without this permission. |  | ✓ |
| `dataAiWithdrawn` | Practice sessions will ask again. | The practice sessions are going to ask again. | Periphrastic future 'vão pedir' and 'de novo' are informal/conversational (neutral alternative: 'pedirão novamente'). What they will ask for (permission) is left implicit. | ✓ |
| `dataAiChangeFailed` | Could not change this setting: {error} | It was not possible to change this setting: {error} |  | ✓ |
| `aiConsentTitle` | AI feedback | Feedback with AI |  | ✓ |
| `aiConsentHeading` | Feedback on your answers | Feedback on your answers |  | ✓ |
| `aiConsentIntro` | Practice sessions use an AI service to check your answers and explain what to fix. This covers Topic Practice and practicing a weak spot. | The practice sessions use an AI service to check your answers and explain what to correct. This applies to Practice by topic and to practicing a weak spot. | 'Isso vale para' = 'this applies to / this counts for' (informal-neutral). 'Prática por tema' read as a feature name ('Practice by topic' / 'Topic Practice'). 'ponto fraco' = weak point / weak spot. | ✓ |
| `aiConsentSentHeading` | What is sent | What is sent |  | ✓ |
| `aiConsentSentBody` | The answers you type, together with the question each one responds to. This happens when you finish a practice session. | The answers that you type, together with the question that each one answers. This happens when you finish a practice session. | 'a pergunta a que cada uma responde' is a correct but slightly formal relative construction; 'Isso acontece quando' could read as 'whenever' (habitual) rather than a single event. | ✓ |
| `aiConsentRecipientHeading` | Who receives it | Who receives | Object omitted ('who receives [it]'); natural in BP as a heading. | ✓ |
| `aiConsentRecipientBody` | Anthropic, the company that makes Claude. Your answers go through GrammarLens's server to Anthropic's Claude model, which writes your feedback. | Anthropic, the company that develops Claude. Your answers pass through the GrammarLens server and reach the Claude model, from Anthropic, which writes your feedback. | Company names take articles ('A Anthropic' feminine via 'a empresa', 'o Claude', 'do GrammarLens'), normal in BP. 'que escreve' grammatically attaches to 'o modelo Claude' (the model writes the feedback), not to Anthropic. | ✓ "desenvolve" (develops) for "makes"; the data path and the recipient are unchanged. |
| `aiConsentNeverHeading` | What is never sent | What is never sent |  | ✓ |
| `aiConsentNeverBody` | Your name or your avatar. Daily Test answers stay on your device. | Neither your name nor your avatar. The Daily Test answers stay on your device. | 'Nem ... nem ...' is a verbless fragment ('neither ... nor ...'); it reads as an answer to the heading 'What is never sent'. 'ficam no seu dispositivo' = 'stay/remain on your device'. | **Revised.** The first version listed "Seu nome e seu avatar" under the heading; now "Nem seu nome nem seu avatar" (neither … nor). |
| `aiConsentPersonalDetails` | Please don't type personal details such as full names, addresses or contact information into your answers. | Please do not type personal data, such as full name, address or contact information, in your answers. |  | ✓ |
| `aiConsentChangeLater` | You can change this any time in Profile → Data. | You can change this whenever you want in Profile → Data. | 'quando quiser' = 'whenever you want / any time'. | ✓ |
| `aiConsentAgree` | Agree and continue | Agree and continue | Infinitive button labels, standard BP UI style. | ✓ |
| `aiConsentNotNow` | Not now | Not now |  | ✓ |
| `aiConsentNotNowNote` | Not now: you can still take the Daily Test. | Not now: you can still do the Daily Test. | 'fazer' = do / take (a test). | ✓ |
| `onboardingPrivacyNote` | Your name stays on this device. Your goal is sent with app usage data, never with your name. Usage and crash data is collected. | Your name stays on this device. Your goal is sent with the app's usage data, never with your name. We collect usage and crash data. | 'objetivo' = goal / objective. 'falhas' = failures; read as crashes in context but could be broader (errors, faults). | ✓ |
| `onboardingDataLink` | How AI feedback uses your answers | How the feedback with AI uses your answers |  | ✓ |
| `onboardingDataTitle` | Your data & AI | Your data and the AI | 'a IA' has a definite article: 'the AI' rather than 'AI' in general. | ✓ |
| `onboardingDataDeviceHeading` | On this device | On this device |  | ✓ |
| `onboardingDataDeviceBody` | Your name stays on this device. | Your name stays on this device. |  | ✓ |
| `onboardingDataGoalHeading` | Your learning goal | Your learning goal |  | ✓ |
| `onboardingDataGoalBody` | Sent with app usage data, never with your name, to help us decide what to improve. It does not personalize your lessons. | It is sent with the app's usage data, never with your name, to help us decide what to improve. It does not personalize your lessons. | Explicit subject pronoun 'Ele' for an inanimate antecedent (the goal) is common in BP but slightly heavy; 'É enviado' at the start has an implicit subject. | ✓ |
| `onboardingDataAiHeading` | AI feedback | Feedback with AI |  | ✓ |
| `onboardingDataAiBody` | In practice sessions (Topic Practice or a weak spot), your answers are sent to Anthropic (Claude) to give you feedback. We ask for your permission first. | In the practice sessions (Practice by topic or a weak spot), your answers are sent to Anthropic (Claude) to generate your feedback. Before sending, we ask for your permission. | 'Antes de enviar' makes the order clear (before sending), but 'pedimos' is still identical in present and preterite in BP, so a past reading ('we asked') is possible though unlikely here. '(Prática por tema ou um ponto fraco)' is elliptical: 'or a weak spot' has no verb (practicing). 'enviar' has no stated subject or object (who sends what is implied). | **Revised.** "Antes, pedimos sua permissão" could read as past; now "Antes de enviar, pedimos sua permissão" (before sending). |
| `onboardingDataDiagnosticsHeading` | App diagnostics | App diagnostics | 'Diagnóstico' is singular (literally 'diagnosis/diagnostic of the app'). | ✓ |
| `onboardingDataDiagnosticsBody` | Usage and crash data is collected. | We collect usage and crash data. | 'falhas' = failures / crashes. | ✓ |
| `onboardingDataGotIt` | Got it | Got it | Literally 'I understood'; standard BP for 'Got it'. | ✓ |
| `practiceNotSent` | Your answers were not sent. AI feedback needs your permission (Profile → Data). | Your answers were not sent. The feedback with AI needs your permission (Profile → Data). |  | ✓ |
| `paywallBenefitFeedbackBody` | AI feedback on every topic you practice, not just your free daily practice. | Feedback with AI in all the topics that you practice, not only in your free daily practice. |  | ✓ |
| `paywallBenefitWeakSpotsBody` | {count, plural, =1{Go beyond your one free daily practice.} other{Go beyond your {count} free daily practices.}} | {count, plural, =1{Go beyond your single free daily practice.} other{Go beyond your {count} free daily practices.}} | 'Vá além' = 'go beyond / go further than'; it is not explicit what the benefit is (more weak-spot practices than the free allowance). 'única' = only / single. | ✓ |
| `paywallBenefitTopicsBody` | All {topics} topics · {lengths} questions · up to {sessions} sessions a day. | All the {topics} topics · {lengths} questions · up to {sessions} sessions per day. |  | ✓ |
| `paywallPlanAnnual` | Annual | Annual | Adjective (masculine/neutral form, agreeing with an implied 'plano'). | ✓ |
| `paywallPlanMonthly` | Monthly | Monthly | Adjective, agreeing with an implied 'plano'. | ✓ |
| `paywallSave` | Save {percent}% | Save {percent}% | Imperative 'Economize' (polite você form). | ✓ |
| `paywallPerMonthApprox` | ≈ {price} per month | ≈ {price} per month |  | ✓ |
| `paywallPricePerPeriod` | {price} per {period} | {price} every {period} | 'a cada mês' / 'a cada ano' (with the =1 period forms) is correct but slightly less common than 'por mês' / 'por ano'. | ✓ "a cada {period}" (every), so "3 meses" never reads as a one-off. |
| `paywallPerPeriod` | per {period} | every {period} |  | ✓ |
| `paywallTrial` | {length} free trial | Free period of {length} | 'Período grátis' for a trial is understandable; 'teste grátis' or 'período de teste grátis' is the more usual BP term. Noun phrase with the length last ('free period of 7 days'). | **Revised.** "{length} grátis para experimentar" became "Período grátis de {length}", the same term as the button and the confirmation. "teste grátis" is avoided on purpose: it would share its word with the Daily Test. |
| `paywallBilledYearly` | Billed yearly | Annual billing | Noun phrase ('Billing, annual'), not a past participle like 'billed yearly'. | ✓ A noun phrase ("annual billing"), the usual plan-card form. |
| `paywallBilledMonthly` | Billed monthly | Monthly billing | Noun phrase, as above. | ✓ As `paywallBilledYearly`. |
| `paywallBilledPerPeriod` | Billed per period | Billing per period | Noun phrase. | ✓ |
| `paywallBilledEvery` | Billed every {period} | Billing every {period} | Noun phrase ('Billing every ...'), not a past participle like 'billed every'. With the =1 forms ('a cada mês') correct, though 'mensal'/'por mês' would be more common. | **Revised.** A participle among noun phrases; now "Cobrança a cada {period}", like its neighbours. |
| `paywallStartTrial` | Start my {length} free trial | Start my free period of {length} | 'período grátis' for trial is understandable but 'teste grátis' or 'período de teste grátis' is the more usual BP term. Word order puts the length last ('my free period of 7 days'). | ✓ "período grátis" for the trial, deliberately (see `paywallTrial`). |
| `paywallContinueWith` | Continue with {plan} | Continue with the plan {plan} | With {plan} = 'Anual'/'Mensal' this reads naturally ('Continuar com o plano Anual' = 'Continue with the Annual plan'); capitalised adjective after 'plano' reads as a plan name. | **Revised.** "Continuar com Anual" read oddly; now "Continuar com o plano {plan}". |
| `paywallSubscribeFor` | Subscribe for {pricePerPeriod} | Subscribe for {pricePerPeriod} | 'por' can mean 'for' (price) or 'per'; with {pricePerPeriod} = 'R$ X a cada mês' the reading is 'subscribe for R$ X every month'. | ✓ |
| `paywallDisclosureTrial` | {span} free, then {pricePerPeriod}, auto-renews unless cancelled. | {span} free, then {pricePerPeriod}; the subscription renews automatically, unless you cancel. |  | ✓ |
| `paywallDisclosure` | {pricePerPeriod}, auto-renews unless cancelled. | {pricePerPeriod}; the subscription renews automatically, unless you cancel. |  | ✓ |
| `paywallPeriodDay` | {count, plural, =1{day} other{{count} days}} | {count, plural, =1{day} other{{count} days}} |  | ✓ |
| `paywallSpanDay` | {count, plural, =1{1 day} other{{count} days}} | {count, plural, =1{1 day} other{{count} days}} |  | ✓ |
| `paywallTrialLengthDay` | {count}-day | {count, plural, =1{1 day} other{{count} days}} |  | ✓ |
| `paywallPeriodWeek` | {count, plural, =1{week} other{{count} weeks}} | {count, plural, =1{week} other{{count} weeks}} |  | ✓ |
| `paywallSpanWeek` | {count, plural, =1{1 week} other{{count} weeks}} | {count, plural, =1{1 week} other{{count} weeks}} |  | ✓ |
| `paywallTrialLengthWeek` | {count}-week | {count, plural, =1{1 week} other{{count} weeks}} |  | ✓ |
| `paywallPeriodMonth` | {count, plural, =1{month} other{{count} months}} | {count, plural, =1{month} other{{count} months}} |  | ✓ |
| `paywallSpanMonth` | {count, plural, =1{1 month} other{{count} months}} | {count, plural, =1{1 month} other{{count} months}} |  | ✓ |
| `paywallTrialLengthMonth` | {count}-month | {count, plural, =1{1 month} other{{count} months}} |  | ✓ |
| `paywallPeriodYear` | {count, plural, =1{year} other{{count} years}} | {count, plural, =1{year} other{{count} years}} |  | ✓ |
| `paywallSpanYear` | {count, plural, =1{1 year} other{{count} years}} | {count, plural, =1{1 year} other{{count} years}} |  | ✓ |
| `paywallTrialLengthYear` | {count}-year | {count, plural, =1{1 year} other{{count} years}} |  | ✓ |
| `paywallPeriodUnknown` | period | period |  | ✓ |
| `paywallSpanUnknown` | {count, plural, =1{1 period} other{{count} periods}} | {count, plural, =1{1 period} other{{count} periods}} |  | ✓ |
| `paywallTrialLengthUnknown` | {count}-period | {count, plural, =1{1 period} other{{count} periods}} |  | ✓ |
| `paywallRestored` | Purchases restored — full access is active. | Purchases restored: the full access is active. |  | ✓ |
| `paywallNothingToRestore` | No previous purchases found to restore. | No previous purchase found to restore. |  | ✓ |
| `paywallTrialStarted` | Trial started — Topic Practice is unlocked. | Free period started: the Practice by topic is unlocked. | 'Período grátis' for trial, as in paywallStartTrial ('teste grátis' is more usual). 'desbloqueada' is feminine, agreeing with 'Prática'. | ✓ As `paywallStartTrial`. |
| `paywallActive` | Premium is active — Topic Practice is unlocked. | The Premium is active: the Practice by topic is unlocked. | Article 'O' before Premium is normal in BP for a product/plan name. | ✓ |
| `paywallCancelled` | Purchase cancelled — no charge was made. | Purchase cancelled: no charge was made. |  | ✓ |
| `paywallPending` | Waiting for approval — Premium starts once the purchase is approved. No charge until then. | Awaiting approval: the Premium starts as soon as the purchase is approved. No charge until then. | 'for aprovada' is future subjunctive (correct). 'Nenhuma cobrança até lá' is a verbless fragment. | ✓ |
| `paywallFailed` | Something went wrong and the purchase couldn't start. Please try again. | Something went wrong and it was not possible to start the purchase. Try again. | 'Tente de novo' is informal-neutral (vs 'Tente novamente'). | ✓ |
| `paywallRowDailyTest` | Daily Test, refreshed every day | Daily Test, new every day |  | ✓ |
| `paywallRowTopicPractice` | Topic Practice, all five topics | Practice by topic, all the five topics | Number spelled out ('cinco'). | ✓ |
| `paywallRowWeakSpots` | Practice your weak spots | Practice your weak spots | Imperative verb ('Pratique'), not a noun phrase, unlike the neighbouring rows. | ✓ The English row is an imperative too. |
| `paywallRowLengths` | Sessions of {lengths} questions | Sessions of {lengths} questions |  | ✓ |
| `paywallFreePerDay` | {count} a day | {count} per day |  | ✓ |
| `paywallFreePerDayShort` | {count}/day | {count}/day |  | ✓ |
