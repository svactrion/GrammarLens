# Back-translation check: German (`app_de.arb`)

1.4.0 B5, D6 ([`../1.4.0-b5-batch0-report.md`](../1.4.0-b5-batch0-report.md) §2, §8 Q3). The 83 keys with legal or App Review weight, or that complete those screens (the AI permission screen, onboarding's "Your data & AI", the Data screen's AI card, the paywall), translated back into English **blind**: a separate subagent was given only the German strings and their keys, never the English, and asked for a literal rendering. Its notes on ambiguity are kept in the fourth column.

**Limit:** the back-translation was made by the same model family that wrote the German, so it is a consistency check (a dropped clause, a changed number, a trial that became a discount, a lost "auto-renews", a changed recipient), not an independent review. D6 has no native-speaker review.

**Result:** 74 of 83 matched the English meaning on the first pass. Nine were revised in `app_de.arb` and back-translated again, blind, all matching: the five trial lengths had no singular, so a one-week trial would have read "1 Wochen" (they are plurals now, pinned by `test/l10n_test.dart`); "billed every" became a label, since German cannot say "alle" before a single week; and three wordings were tightened (where to change the permission, the weak-spot benefit, the failed purchase). The table shows each row's latest pass; the Δ column says what changed. **Owner sign-off: done 2026-11-03.** All rows approved as they stand; every revised row matched on its blind second pass; the same-model-family limit above stays.

| Key | English (original) | Back-translation | Subagent note | Δ |
|---|---|---|---|---|
| `dataAiCardTitle` | AI feedback | AI feedback |  | ✓ "KI" is the German for "AI". |
| `dataAiExplanation` | Practice sessions send your {what} to {provider} to create feedback. | Practice sessions send your {what} to {provider} in order to create feedback. | "erstellen" = create/produce/generate. "deine" is accusative plural, so {what} must start with a plural adjective-noun phrase in weak inflection to agree. | ✓ |
| `dataAiWhat` | typed answers and the questions | typed answers and the questions | Fragment only works after "deine" (weak adjective ending -en). "die Fragen" carries its own article, so "deine" covers only the answers; grammatical. | ✓ |
| `dataAiSwitch` | Allow AI feedback | Allow AI feedback |  | ✓ |
| `dataAiOn` | On · Required for practice sessions | On · Required for practice sessions |  | ✓ |
| `dataAiOff` | Off · Practice sessions need permission | Off · Practice sessions need your permission | "Erlaubnis" = permission (not formal "consent"/"Einwilligung"). | ✓ |
| `dataAiDailyTestNote` | Daily Test works without this permission. | The daily test works without this permission. |  | ✓ |
| `dataAiWithdrawn` | Practice sessions will ask again. | Practice sessions ask you again. | Present tense with future meaning ("will ask you again"). On its own it does not say that permission was withdrawn; relies on context. | ✓ As terse as the English, which also leaves the withdrawal to the context. |
| `dataAiChangeFailed` | Could not change this setting: {error} | This setting could not be changed: {error} |  | ✓ |
| `aiConsentTitle` | AI feedback | AI feedback |  | ✓ |
| `aiConsentHeading` | Feedback on your answers | Feedback on your answers |  | ✓ |
| `aiConsentIntro` | Practice sessions use an AI service to check your answers and explain what to fix. This covers Topic Practice and practicing a weak spot. | Practice sessions use an AI service to check your answers and to explain what you should correct. That applies to topic practice and to the practising of a weak spot. | "Themenübung" = topic practice/topic exercise. "Schwachstelle" = weak spot/weak point. "das Üben einer Schwachstelle" is a nominalised verb, a little heavy but fine. | ✓ |
| `aiConsentSentHeading` | What is sent | What is sent | Present passive; could also read "What gets sent". | ✓ |
| `aiConsentSentBody` | The answers you type, together with the question each one responds to. This happens when you finish a practice session. | The answers that you type, together with the question to which each one refers. That happens when you complete a practice session. | "jede" (feminine) refers back to "Antwort" implied in the plural "Antworten"; grammatical. "abschließt" = finish/complete. | ✓ |
| `aiConsentRecipientHeading` | Who receives it | Who receives it | "es" = it (the data), no explicit antecedent. | ✓ |
| `aiConsentRecipientBody` | Anthropic, the company that makes Claude. Your answers go through GrammarLens's server to Anthropic's Claude model, which writes your feedback. | Anthropic, the company behind Claude. Your answers go via the server of GrammarLens to the Claude model of Anthropic, which writes your feedback. | Relative "das" is neuter, so it can only refer to "Modell", not "Server" (masc.) or Anthropic; unambiguous. "über" = via/through (here not "about"). | ✓ "the company behind Claude" for "the company that makes Claude"; the data path (GrammarLens server → Claude) and the recipient are unchanged. |
| `aiConsentNeverHeading` | What is never sent | What is never sent |  | ✓ |
| `aiConsentNeverBody` | Your name or your avatar. Daily Test answers stay on your device. | Neither your name nor your avatar. Answers from the daily test stay on your device. | First sentence has no verb (a "weder ... noch" fragment answering the heading "What is never sent"). That works under the heading. | ✓ "Weder … noch" (neither … nor) is how German lists what is never sent; the English "or" has the same meaning. |
| `aiConsentPersonalDetails` | Please don't type personal details such as full names, addresses or contact information into your answers. | Please do not type any personal details such as full names, addresses or contact details into your answers. | "Angaben" = details/information; "Kontaktdaten" = contact data. | ✓ |
| `aiConsentChangeLater` | You can change this any time in Profile → Data. | Change it you can at any time under Profile → Data. | Verb-first emphasis ("Ändern kannst du das") is natural German, stressing that changing is possible. "Daten" now stands alone, so there is no "change data" misreading. | **Revised.** The first version put "Daten ändern" side by side, which could read "change data"; the verb now comes first. |
| `aiConsentAgree` | Agree and continue | Agree and continue | "weiter" = onward/continue (adverb used as button verb, standard). | ✓ |
| `aiConsentNotNow` | Not now | Not now |  | ✓ |
| `aiConsentNotNowNote` | Not now: you can still take the Daily Test. | Not now: The daily test you can do anyway. | "trotzdem" = anyway/nevertheless/still. Object-first word order ("Den Tagestest kannst du") stresses the daily test; natural German. | ✓ "Tagestest" is the translated feature name (owner, 2026-11-02). |
| `onboardingPrivacyNote` | Your name stays on this device. Your goal is sent with app usage data, never with your name. Usage and crash data is collected. | Your name stays on this device. Your goal is sent with the app usage data, never with your name. Usage and crash data are collected. | "Ziel" = goal/aim (also target/destination; context makes "goal" clear). Last sentence is agentless passive: does not say who collects. | ✓ |
| `onboardingDataLink` | How AI feedback uses your answers | How AI feedback uses your answers |  | ✓ |
| `onboardingDataTitle` | Your data & AI | Your data & AI |  | ✓ |
| `onboardingDataDeviceHeading` | On this device | On this device |  | ✓ |
| `onboardingDataDeviceBody` | Your name stays on this device. | Your name stays on this device. |  | ✓ |
| `onboardingDataGoalHeading` | Your learning goal | Your learning goal |  | ✓ |
| `onboardingDataGoalBody` | Sent with app usage data, never with your name, to help us decide what to improve. It does not personalize your lessons. | Is sent with the app usage data, never with your name, so that we can decide what we improve. It does not personalise your lessons. | Subjectless "Wird ..." leans on the heading as subject; fine under a heading, odd if read alone. "was wir verbessern" present tense = what we improve / will improve. | ✓ |
| `onboardingDataAiHeading` | AI feedback | AI feedback |  | ✓ |
| `onboardingDataAiBody` | In practice sessions (Topic Practice or a weak spot), your answers are sent to Anthropic (Claude) to give you feedback. We ask for your permission first. | In practice sessions (topic practice or a weak spot) your answers are sent to Anthropic (Claude) so that you get feedback. We ask you for permission beforehand. | Parenthesis is elliptical: "eine Schwachstelle" lists a weak spot as a kind of practice session; reads slightly odd (means practising a weak spot). "vorher" = beforehand/first. | ✓ The parenthesis is as elliptical as the English one. |
| `onboardingDataDiagnosticsHeading` | App diagnostics | App diagnosis | "Diagnose" = diagnosis/diagnostics; singular noun. | ✓ |
| `onboardingDataDiagnosticsBody` | Usage and crash data is collected. | Usage and crash data are collected. | Agentless passive. | ✓ |
| `onboardingDataGotIt` | Got it | Understood | Standard button for "Got it". | ✓ |
| `practiceNotSent` | Your answers were not sent. AI feedback needs your permission (Profile → Data). | Your answers were not sent. AI feedback needs your permission (Profile → Data). | "wurden nicht gesendet" simple past passive = were not sent (have not been sent). | ✓ |
| `paywallBenefitFeedbackBody` | AI feedback on every topic you practice, not just your free daily practice. | AI feedback on every topic that you practise, not only on your free daily practice. | "Übung" = practice/exercise; singular "deiner kostenlosen täglichen Übung" implies one free daily practice. | ✓ |
| `paywallBenefitWeakSpotsBody` | {count, plural, =1{Go beyond your one free daily practice.} other{Go beyond your {count} free daily practices.}} | {count, plural, =1{Go beyond your one free daily practice.} other{Go beyond your {count} free daily practices.}} | Informal imperative "geh ... hinaus" (separable "hinausgehen über" = go beyond/exceed). "deine eine" is grammatical but slightly marked (stresses "one"). "Übung" = practice/exercise; the text does not mention weak spots. | **Revised.** The first version was a verbless "More than your …"; it now says "Go beyond your …", as the English does. |
| `paywallBenefitTopicsBody` | All {topics} topics · {lengths} questions · up to {sessions} sessions a day. | All {topics} topics · {lengths} questions · up to {sessions} sessions a day. | "Einheiten" = units/sessions. "{lengths} Fragen" depends on what {lengths} expands to (e.g. a list of numbers). | ✓ |
| `paywallPlanAnnual` | Annual | Yearly | Adjective/adverb "jährlich" = yearly/annually. | ✓ |
| `paywallPlanMonthly` | Monthly | Monthly |  | ✓ |
| `paywallSave` | Save {percent}% | Save {percent} % | Infinitive used as call to action, literally "{percent} % to save". Space before % is correct German typography. | ✓ German sets a space before %. |
| `paywallPerMonthApprox` | ≈ {price} per month | ≈ {price} per month |  | ✓ |
| `paywallPricePerPeriod` | {price} per {period} | {price} per {period} | "pro" with the plural period forms (e.g. "pro 3 Monate") reads as "per 3 months", acceptable. | ✓ "pro 3 Monate" is usual in German price labels. |
| `paywallPerPeriod` | per {period} | per {period} |  | ✓ |
| `paywallTrial` | {length} free trial | Test {length} free of charge | Infinitive phrase; "testen" = test/try. Literally "{length} free to test", i.e. try for free for {length}. | ✓ "try {length} free" names a free trial of that length; no discount, no price. |
| `paywallBilledYearly` | Billed yearly | Yearly billing | Noun phrase ("annual billing"), not a participle ("billed yearly"). | ✓ A noun phrase ("annual billing"), the usual German plan-card form. |
| `paywallBilledMonthly` | Billed monthly | Monthly billing | Noun phrase, as above. | ✓ As `paywallBilledYearly`. |
| `paywallBilledPerPeriod` | Billed per period | Billing per period |  | ✓ |
| `paywallBilledEvery` | Billed every {period} | Billing period: {period} | Label-plus-value form, not "billed every {period}". Reads naturally if {period} is a bare noun phrase such as "Monat" or "3 Monate". | **Revised.** The first version said "billing per {period}"; it is now "Billing period: {period}", which reads right for "Woche" and for "3 Monate" alike (German "alle" cannot stand before a single week). |
| `paywallStartTrial` | Start my {length} free trial | Now test {length} free of charge | Infinitive call to action; "jetzt" = now. Means "Try {length} free now". | ✓ As `paywallTrial`, on the button. |
| `paywallContinueWith` | Continue with {plan} | Onward with {plan} | "Weiter mit" = continue with. | ✓ |
| `paywallSubscribeFor` | Subscribe for {pricePerPeriod} | Subscribe for {pricePerPeriod} | Infinitive before the prepositional phrase follows English order; more usual German is "Für ... abonnieren". Understandable as a button. | ✓ |
| `paywallDisclosureTrial` | {span} free, then {pricePerPeriod}, auto-renews unless cancelled. | {span} free, then {pricePerPeriod}, renews itself automatically if you do not cancel. | Subject of "verlängert sich" (the subscription) is left out; elliptical. "wenn" = if/when. "kündigst" = cancel (terminate a contract). | ✓ |
| `paywallDisclosure` | {pricePerPeriod}, auto-renews unless cancelled. | {pricePerPeriod}, renews itself automatically if you do not cancel. | Same elliptical subject as above. | ✓ |
| `paywallPeriodDay` | {count, plural, =1{day} other{{count} days}} | {count, plural, =1{Day} other{{count} Days}} | Capitalised because German nouns are; only "day"/"days". | ✓ |
| `paywallSpanDay` | {count, plural, =1{1 day} other{{count} days}} | {count, plural, =1{1 day} other{{count} days}} |  | ✓ |
| `paywallTrialLengthDay` | {count}-day | {count, plural, =1{1 day} other{{count} days}} |  | **Revised.** No singular: one day would have read "1 Tage". Now a plural; English needs none (`test/l10n_completeness_test.dart` allows a translation to add one). |
| `paywallPeriodWeek` | {count, plural, =1{week} other{{count} weeks}} | {count, plural, =1{Week} other{{count} Weeks}} |  | ✓ |
| `paywallSpanWeek` | {count, plural, =1{1 week} other{{count} weeks}} | {count, plural, =1{1 week} other{{count} weeks}} |  | ✓ |
| `paywallTrialLengthWeek` | {count}-week | {count, plural, =1{1 week} other{{count} weeks}} |  | **Revised.** As `paywallTrialLengthDay` ("1 Wochen"). |
| `paywallPeriodMonth` | {count, plural, =1{month} other{{count} months}} | {count, plural, =1{Month} other{{count} Months}} |  | ✓ |
| `paywallSpanMonth` | {count, plural, =1{1 month} other{{count} months}} | {count, plural, =1{1 month} other{{count} months}} |  | ✓ |
| `paywallTrialLengthMonth` | {count}-month | {count, plural, =1{1 month} other{{count} months}} |  | **Revised.** As `paywallTrialLengthDay` ("1 Monate"). |
| `paywallPeriodYear` | {count, plural, =1{year} other{{count} years}} | {count, plural, =1{Year} other{{count} Years}} |  | ✓ |
| `paywallSpanYear` | {count, plural, =1{1 year} other{{count} years}} | {count, plural, =1{1 year} other{{count} years}} |  | ✓ |
| `paywallTrialLengthYear` | {count}-year | {count, plural, =1{1 year} other{{count} years}} |  | **Revised.** As `paywallTrialLengthDay` ("1 Jahre"). |
| `paywallPeriodUnknown` | period | Period | "Zeitraum" = period/time span. | ✓ |
| `paywallSpanUnknown` | {count, plural, =1{1 period} other{{count} periods}} | {count, plural, =1{1 period} other{{count} periods}} |  | ✓ |
| `paywallTrialLengthUnknown` | {count}-period | {count, plural, =1{1 period} other{{count} periods}} | "Zeitraum" = period/time span. | **Revised.** As `paywallTrialLengthDay` ("1 Zeiträume"). |
| `paywallRestored` | Purchases restored — full access is active. | Purchases restored – full access is active. |  | ✓ |
| `paywallNothingToRestore` | No previous purchases found to restore. | No earlier purchases to restore found. | German order "zum Wiederherstellen gefunden"; reads "No previous purchases found to restore". "früheren" = earlier/previous/former. | ✓ |
| `paywallTrialStarted` | Trial started — Topic Practice is unlocked. | Trial phase started – the topic practice is unlocked. | "Testphase" = trial phase/test phase. | ✓ |
| `paywallActive` | Premium is active — Topic Practice is unlocked. | Premium is active – the topic practice is unlocked. |  | ✓ |
| `paywallCancelled` | Purchase cancelled — no charge was made. | Purchase aborted – nothing was charged. | "abgebrochen" = aborted/broken off (an interrupted process), not "gekündigt" (subscription cancelled). "berechnet" = charged, but also "calculated". | ✓ "abgebrochen" is a purchase stopped before it completed, which is what the English means; not a subscription being cancelled. |
| `paywallPending` | Waiting for approval — Premium starts once the purchase is approved. No charge until then. | Waiting for approval – Premium begins as soon as the purchase is approved. Until then nothing is charged. | "Genehmigung" = approval/authorisation (official-sounding; e.g. parental approval). "berechnet" = charged/calculated. | ✓ "Genehmigung" is the approval Ask to Buy asks for. |
| `paywallFailed` | Something went wrong and the purchase couldn't start. Please try again. | Something went wrong and the purchase could not be started. Please try it again. | Passive "konnte nicht gestartet werden" is the normal phrasing. "versuch" is informal imperative without -e, colloquial but accepted. | **Revised.** The first version, "der Kauf konnte nicht starten", was an odd intransitive; now the usual passive. |
| `paywallRowDailyTest` | Daily Test, refreshed every day | Daily test, new every day |  | ✓ |
| `paywallRowTopicPractice` | Topic Practice, all five topics | Topic practice, all five topics |  | ✓ |
| `paywallRowWeakSpots` | Practice your weak spots | Practise your weak spots | Informal imperative; differs in form from the neighbouring noun-phrase rows. | ✓ The English row is an imperative too. |
| `paywallRowLengths` | Sessions of {lengths} questions | Sessions with {lengths} questions | "Einheiten" = units/sessions. | ✓ |
| `paywallFreePerDay` | {count} a day | {count} a day | "am Tag" = per day/a day. | ✓ |
| `paywallFreePerDayShort` | {count}/day | {count}/day |  | ✓ |
