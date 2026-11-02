# Back-translation check: Spanish (`app_es.arb`)

1.4.0 B5, D6 ([`../1.4.0-b5-batch0-report.md`](../1.4.0-b5-batch0-report.md) §2, §8 Q3). The 83 keys with legal or App Review weight, or that complete those screens (the AI permission screen, onboarding's "Your data & AI", the Data screen's AI card, the paywall), translated back into English **blind**: a separate subagent was given only the Spanish strings and their keys, never the English, and asked for a literal rendering. Its notes on ambiguity are kept in the fourth column.

**Limit:** the back-translation was made by the same model family that wrote the Spanish, so it is a consistency check (a dropped clause, a changed number, a trial that became a discount, a lost "auto-renews", a changed recipient), not an independent review. D6 has no native-speaker review.

**Result:** 66 of 83 matched the English meaning on the first pass. Seventeen were revised in `app_es.arb` and back-translated again, blind, all matching. The main find: the Daily Test ("Prueba diaria") and the free trial ("prueba gratuita") shared a word, so the feature is now **Test diario** (a change from the Batch 0 proposal); "por {period}" became "cada {period}"; and smaller fixes to the recipient, the permission order, the never-sent list and the crash-data word. The table shows each row's latest pass; the Δ column says what changed. **Owner sign-off:** open.

| Key | English (original) | Back-translation | Subagent note | Δ |
|---|---|---|---|---|
| `dataAiCardTitle` | AI feedback | Feedback with AI | "Retroalimentación" is the standard neutral Latin American word for feedback, though long; "con IA" literally "with AI". | ✓ |
| `dataAiExplanation` | Practice sessions send your {what} to {provider} to create feedback. | The practice sessions send your {what} to {provider} to generate the feedback. | "tus" must still agree with the start of {what} (plural); "a {provider}" would need "al" if the name took "el". | **Revised.** "crear" became "generar", the usual verb. |
| `dataAiWhat` | typed answers and the questions | written answers and the questions | Mixed articles: the first noun relies on "tus" in the host string, the second has its own "las"; read in place it gives "your written answers and the questions". | ✓ |
| `dataAiSwitch` | Allow AI feedback | Allow feedback with AI |  | ✓ |
| `dataAiOn` | On · Required for practice sessions | On · Required for the practice sessions | "Activado" and "Necesario" are masculine singular, agreeing with an implied noun (the setting or the permission). | ✓ |
| `dataAiOff` | Off · Practice sessions need permission | Off · The practice sessions need permission | Reads as "the sessions require (you to give) permission"; slightly indirect. | ✓ |
| `dataAiDailyTestNote` | Daily Test works without this permission. | The Daily Test works without this permission. | "Test" is an English loanword, masculine ("el Test"); widely understood in Latin America, though some readers find it less native than "prueba" or "examen". | **Revised.** The Daily Test was first "Prueba diaria", the same word as the free trial ("prueba gratuita", the App Store's term), so "Prueba iniciada" was ambiguous; the feature is now "Test diario" everywhere. |
| `dataAiWithdrawn` | Practice sessions will ask again. | The practice sessions will ask you again. | No object stated: "ask you again" (for permission) is implied, not said. | ✓ |
| `dataAiChangeFailed` | Could not change this setting: {error} | This setting could not be changed: {error} | "ajuste" = setting; "configuración" is also common in Latin America. | ✓ |
| `aiConsentTitle` | AI feedback | Feedback with AI |  | ✓ |
| `aiConsentHeading` | Feedback on your answers | Feedback on your answers |  | ✓ |
| `aiConsentIntro` | Practice sessions use an AI service to check your answers and explain what to fix. This covers Topic Practice and practicing a weak spot. | The practice sessions use an AI service to review your answers and explain to you what to correct. This includes Practice by topics and the practice of a weak spot. | "la práctica de un punto débil" (the practice of a weak spot, singular) sounds slightly awkward; "Práctica por temas" literally "Practice by topics". | ✓ |
| `aiConsentSentHeading` | What is sent | What is sent |  | ✓ |
| `aiConsentSentBody` | The answers you type, together with the question each one responds to. This happens when you finish a practice session. | The answers that you write, together with the question that each one answers. This happens when you finish a practice session. | First sentence is a verbless fragment answering the heading; natural in that position. | ✓ |
| `aiConsentRecipientHeading` | Who receives it | Who receives it |  | ✓ |
| `aiConsentRecipientBody` | Anthropic, the company that makes Claude. Your answers go through GrammarLens's server to Anthropic's Claude model, which writes your feedback. | Anthropic, the company that develops Claude. Your answers pass through the GrammarLens server and arrive at Anthropic's Claude model, which writes your feedback. |  | **Revised.** "crea" became "desarrolla" and the path now "pasan por … y llegan al modelo"; recipient unchanged. |
| `aiConsentNeverHeading` | What is never sent | What is never sent |  | ✓ |
| `aiConsentNeverBody` | Your name or your avatar. Daily Test answers stay on your device. | Neither your name nor your avatar. The answers of the Daily Test stay on your device. | "Ni ... ni" is now a correct standalone fragment under the heading. | **Revised.** "Tu nombre ni tu avatar" lacked the first "ni"; now "Ni tu nombre ni tu avatar". Also the feature rename. |
| `aiConsentPersonalDetails` | Please don't type personal details such as full names, addresses or contact information into your answers. | Please, do not write personal data such as full names, addresses or contact information in your answers. |  | ✓ |
| `aiConsentChangeLater` | You can change this any time in Profile → Data. | You can change this at any moment in Profile → Data. |  | ✓ |
| `aiConsentAgree` | Agree and continue | Accept and continue | "Aceptar" = accept or agree. | ✓ |
| `aiConsentNotNow` | Not now | Not now |  | ✓ |
| `aiConsentNotNowNote` | Not now: you can still take the Daily Test. | Not now: even so you can do the Daily Test. | "hacer el Test" (do the test) is natural; "aun así" = even so / still. | **Revised.** The Daily Test was first "Prueba diaria", the same word as the free trial ("prueba gratuita", the App Store's term), so "Prueba iniciada" was ambiguous; the feature is now "Test diario" everywhere. |
| `onboardingPrivacyNote` | Your name stays on this device. Your goal is sent with app usage data, never with your name. Usage and crash data is collected. | Your name stays on this device. Your goal is sent with the app's usage data, never with your name. Usage and failure data are collected. | "fallas" (failures/crashes) is the Latin American form. Impersonal "Se recopilan" names no collector. | **Revised.** "fallos" is Peninsular; now "fallas", the Latin American word. |
| `onboardingDataLink` | How AI feedback uses your answers | How the feedback with AI uses your answers | Word order "... con IA tus respuestas" can briefly parse as "with AI your answers" before the reader settles on it; correct but slightly heavy. | **Revised.** Word order made plainer. |
| `onboardingDataTitle` | Your data & AI | Your data and the AI |  | ✓ |
| `onboardingDataDeviceHeading` | On this device | On this device |  | ✓ |
| `onboardingDataDeviceBody` | Your name stays on this device. | Your name stays on this device. |  | ✓ |
| `onboardingDataGoalHeading` | Your learning goal | Your learning goal |  | ✓ |
| `onboardingDataGoalBody` | Sent with app usage data, never with your name, to help us decide what to improve. It does not personalize your lessons. | It is sent with the app's usage data, never with your name, to help us decide what to improve. It does not personalize your lessons. | Subject (the goal) is implied from the heading. | ✓ |
| `onboardingDataAiHeading` | AI feedback | Feedback with AI |  | ✓ |
| `onboardingDataAiBody` | In practice sessions (Topic Practice or a weak spot), your answers are sent to Anthropic (Claude) to give you feedback. We ask for your permission first. | In the practice sessions (Practice by topics or a weak spot), your answers are sent to Anthropic (Claude) to give you feedback. Before sending them, we ask you for permission. | Ambiguity gone: "Antes de enviarlas" makes "pedimos" read as present (we ask first). "o un punto débil" (or a weak spot) is elliptical for "practice of a weak spot". | **Revised.** "Antes te pedimos permiso" could read as past; now "Antes de enviarlas, te pedimos permiso". |
| `onboardingDataDiagnosticsHeading` | App diagnostics | Diagnosis of the app | "Diagnóstico" singular can read as "diagnosis" as well as "diagnostics". | ✓ |
| `onboardingDataDiagnosticsBody` | Usage and crash data is collected. | Usage and failure data are collected. | "fallas" as above. | **Revised.** "fallos" is Peninsular; now "fallas", the Latin American word. |
| `onboardingDataGotIt` | Got it | Understood |  | ✓ |
| `practiceNotSent` | Your answers were not sent. AI feedback needs your permission (Profile → Data). | Your answers were not sent. The feedback with AI needs your permission (Profile → Data). |  | ✓ |
| `paywallBenefitFeedbackBody` | AI feedback on every topic you practice, not just your free daily practice. | Feedback with AI on every topic that you practice, not only on your free daily practice. | "práctica diaria" (daily practice) is a different term from "Prueba diaria" (Daily Test) used elsewhere; unclear whether they refer to the same thing. "gratis" used as a postposed adjective is colloquial; "gratuita" is more formal. | ✓ |
| `paywallBenefitWeakSpotsBody` | {count, plural, =1{Go beyond your one free daily practice.} other{Go beyond your {count} free daily practices.}} | {count, plural, =1{Go beyond your single free daily practice.} other{Go beyond your {count} free daily practices.}} | "Ve" is the tú imperative of both "ir" (go) and "ver" (see), so it could read "See beyond..."; context favors "go". "tu única" can read "your only" or "your one". "práctica diaria" again differs from "Prueba diaria". | ✓ |
| `paywallBenefitTopicsBody` | All {topics} topics · {lengths} questions · up to {sessions} sessions a day. | The {topics} topics · {lengths} questions · up to {sessions} sessions per day. | "Los {topics} temas" = "the N topics", i.e. all of them. | ✓ |
| `paywallPlanAnnual` | Annual | Annual |  | ✓ |
| `paywallPlanMonthly` | Monthly | Monthly |  | ✓ |
| `paywallSave` | Save {percent}% | Save {percent} % | Space before % follows Spanish norms; if {percent} already contains a % sign it will be doubled. | ✓ Spanish sets a space before %. |
| `paywallPerMonthApprox` | ≈ {price} per month | ≈ {price} per month |  | ✓ |
| `paywallPricePerPeriod` | {price} per {period} | {price} every {period} | "cada" = every; with a singular unit ("cada mes") it reads "every month", fine as "per month"; no per/for ambiguity. | **Revised.** "por 3 meses" reads "for 3 months" (a one-off); "cada" (every) does not. |
| `paywallPerPeriod` | per {period} | every {period} | As above. | **Revised.** "por 3 meses" reads "for 3 months" (a one-off); "cada" (every) does not. |
| `paywallTrial` | {length} free trial | Free trial of {length} | "Prueba" now only means trial here, since the Daily Test uses "Test". | **Revised.** The Daily Test was first "Prueba diaria", the same word as the free trial ("prueba gratuita", the App Store's term), so "Prueba iniciada" was ambiguous; the feature is now "Test diario" everywhere. |
| `paywallBilledYearly` | Billed yearly | Annual billing | Noun phrase ("Annual billing"), not a past participle like "Billed yearly". | ✓ A noun phrase ("annual billing"), the usual plan-card form. |
| `paywallBilledMonthly` | Billed monthly | Monthly billing | Noun phrase, as above. | ✓ As `paywallBilledYearly`. |
| `paywallBilledPerPeriod` | Billed per period | Billing per period | "periodo" and "período" are both accepted spellings. | ✓ |
| `paywallBilledEvery` | Billed every {period} | It is billed every {period} |  | ✓ |
| `paywallStartTrial` | Start my {length} free trial | Start my free trial of {length} | First-person "mi" on a button. | **Revised.** The Daily Test was first "Prueba diaria", the same word as the free trial ("prueba gratuita", the App Store's term), so "Prueba iniciada" was ambiguous; the feature is now "Test diario" everywhere. |
| `paywallContinueWith` | Continue with {plan} | Continue with {plan} |  | ✓ |
| `paywallSubscribeFor` | Subscribe for {pricePerPeriod} | Subscribe me for {pricePerPeriod} | Reflexive first-person infinitive "Suscribirme" (I subscribe / subscribe me); "por" here = for (a price). | ✓ |
| `paywallDisclosureTrial` | {span} free, then {pricePerPeriod}, auto-renews unless cancelled. | {span} free, then {pricePerPeriod}; the subscription renews automatically unless you cancel it. | "gratis" after {span} is colloquial but common; "la" agrees with "suscripción". | **Revised.** "lo canceles" had no clear object; it now names the subscription. |
| `paywallDisclosure` | {pricePerPeriod}, auto-renews unless cancelled. | {pricePerPeriod}; the subscription renews automatically unless you cancel it. | "la" now agrees with feminine "suscripción". | **Revised.** "lo canceles" had no clear object; it now names the subscription. |
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
| `paywallPeriodUnknown` | period | period | "periodo"/"período" both accepted. | ✓ |
| `paywallSpanUnknown` | {count, plural, =1{1 period} other{{count} periods}} | {count, plural, =1{1 period} other{{count} periods}} |  | ✓ |
| `paywallTrialLengthUnknown` | {count}-period | {count, plural, =1{1 period} other{{count} periods}} |  | ✓ |
| `paywallRestored` | Purchases restored — full access is active. | Purchases restored: the full access is active. |  | ✓ |
| `paywallNothingToRestore` | No previous purchases found to restore. | No previous purchases were found to restore. |  | ✓ |
| `paywallTrialStarted` | Trial started — Topic Practice is unlocked. | Free trial started: the Practice by topics is unlocked. |  | **Revised.** The Daily Test was first "Prueba diaria", the same word as the free trial ("prueba gratuita", the App Store's term), so "Prueba iniciada" was ambiguous; the feature is now "Test diario" everywhere. |
| `paywallActive` | Premium is active — Topic Practice is unlocked. | Premium is active: the Practice by topics is unlocked. |  | ✓ |
| `paywallCancelled` | Purchase cancelled — no charge was made. | Purchase cancelled: no charge was made. |  | ✓ |
| `paywallPending` | Waiting for approval — Premium starts once the purchase is approved. No charge until then. | Waiting for approval: Premium starts when the purchase is approved. There will be no charge until then. |  | ✓ |
| `paywallFailed` | Something went wrong and the purchase couldn't start. Please try again. | Something went wrong and the purchase could not be started. Try it again. |  | ✓ |
| `paywallRowDailyTest` | Daily Test, refreshed every day | Daily Test, new every day | "nuevo" agrees with masculine "Test"; "diario" and "cada día" are mildly redundant. | **Revised.** The Daily Test was first "Prueba diaria", the same word as the free trial ("prueba gratuita", the App Store's term), so "Prueba iniciada" was ambiguous; the feature is now "Test diario" everywhere. |
| `paywallRowTopicPractice` | Topic Practice, all five topics | Practice by topics, the five topics | "los cinco temas" = "the five topics", i.e. all five. | ✓ |
| `paywallRowWeakSpots` | Practice your weak spots | Practice your weak spots | "Practica" (no accent) is the tú imperative verb, unlike the noun labels in the neighbouring rows ("Prueba diaria", "Práctica por temas"); with an accent ("Práctica") it would be a noun. | ✓ The English row is an imperative too. |
| `paywallRowLengths` | Sessions of {lengths} questions | Sessions of {lengths} questions |  | ✓ |
| `paywallFreePerDay` | {count} a day | {count} per day |  | ✓ |
| `paywallFreePerDayShort` | {count}/day | {count}/day |  | ✓ |
