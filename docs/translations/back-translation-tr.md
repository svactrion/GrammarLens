# Back-translation check: Turkish (`app_tr.arb`)

1.4.0 B5, D6 ([`../1.4.0-b5-batch0-report.md`](../1.4.0-b5-batch0-report.md) §2, §8 Q3). The 83 keys with legal or App Review weight, or that complete those screens (the AI permission screen, onboarding's "Your data & AI", the Data screen's AI card, the paywall), translated back into English **blind**: a separate subagent was given only the Turkish strings and their keys, never the English, and asked for a literal rendering. Its notes on ambiguity are kept in the third column.

**Limit:** the back-translation was made by the same model family that wrote the Turkish, so it is a consistency check (a dropped clause, a changed number, a trial that became a discount, a lost "auto-renews", a changed recipient), not an independent review. D6 has no native-speaker review.

**Result:** 79 of 83 matched the English meaning on the first pass. Four were revised in `app_tr.arb` and back-translated again, blind. On 2026-11-02 the owner had the feature names translated (Günlük Test, Konu Pratiği, Tekrar); the nine rows that name a feature were updated and back-translated a third time, blind, all matching. The table shows each row's latest pass; the Δ column says what changed. **Owner sign-off: done 2026-11-03.** All rows approved as they stand; every revised row matched on its blind second pass; the same-model-family limit above stays.

| Key | English (original) | Back-translation | Subagent note | Δ |
|---|---|---|---|---|
| `dataAiCardTitle` | AI feedback | Artificial intelligence feedback |  | ✓ "AI" is "yapay zekâ" (artificial intelligence), the usual Turkish term. |
| `dataAiExplanation` | Practice sessions send your {what} to {provider} to create feedback. | Practice sessions send {what} to the {provider} service in order to create feedback. | "oluşturmak" = create/generate | ✓ "the {provider} service": the same recipient. |
| `dataAiWhat` | typed answers and the questions | the questions and the answers you write | "you write" modifies only "answers"; accusative case (direct object) | **Revised.** The first version, "yazdığın cevapları ve soruları", read as "the answers and questions you write"; the word order now puts the questions first, so "you write" covers only the answers. |
| `dataAiSwitch` | Allow AI feedback | Allow artificial intelligence feedback |  | ✓ |
| `dataAiOn` | On · Required for practice sessions | On · Required for practice sessions |  | ✓ |
| `dataAiOff` | Off · Practice sessions need permission | Off · Permission is required for practice sessions | "gerekir" aorist = is required / is needed | **Revised.** The first version said practice sessions "ask for permission"; it now says permission "is required", as the English does. |
| `dataAiDailyTestNote` | Daily Test works without this permission. | Daily Test works without this permission. | "Günlük Test" = Daily Test, rendered literally as a feature name | Updated for the translated feature names (Günlük Test, Konu Pratiği; owner, 2026-11-02) and back-translated again, blind. **Revised.** The first version added "too" ("works without this permission too"); dropped. |
| `dataAiWithdrawn` | Practice sessions will ask again. | Practice sessions will ask for permission again. |  | ✓ |
| `dataAiChangeFailed` | Could not change this setting: {error} | This setting could not be changed: {error} |  | ✓ |
| `aiConsentTitle` | AI feedback | Artificial intelligence feedback |  | ✓ As `dataAiCardTitle`. |
| `aiConsentHeading` | Feedback on your answers | Feedback on your answers | Literally "Feedback to your answers" | ✓ |
| `aiConsentIntro` | Practice sessions use an AI service to check your answers and explain what to fix. This covers Topic Practice and practicing a weak spot. | Practice sessions use an artificial intelligence service to check your answers and to explain what you need to correct. This covers Topic Practice and the practice of a weak spot. | "Konu Pratiği" = Topic Practice (literal); "düzeltmen gerektiğini" = what you need to fix/correct | Updated for the translated feature names (Günlük Test, Konu Pratiği; owner, 2026-11-02) and back-translated again, blind. ✓ |
| `aiConsentSentHeading` | What is sent | What is sent |  | ✓ |
| `aiConsentSentBody` | The answers you type, together with the question each one responds to. This happens when you finish a practice session. | The answers you write and the question that each one answers. This happens when you finish a practice session. |  | ✓ |
| `aiConsentRecipientHeading` | Who receives it | To whom it goes | Natural: "Who it goes to" | ✓ "To whom it goes": the same question. |
| `aiConsentRecipientBody` | Anthropic, the company that makes Claude. Your answers go through GrammarLens's server to Anthropic's Claude model, which writes your feedback. | Anthropic, the company that develops Claude. Your answers go to Anthropic's Claude model via GrammarLens's server; this model writes your feedback. | "geliştiren" = develops/builds | ✓ "develops" for "makes"; the data path (GrammarLens server → Claude) and the recipient are unchanged. |
| `aiConsentNeverHeading` | What is never sent | What is never sent | Literally "The ones that are never sent" (plural) | ✓ |
| `aiConsentNeverBody` | Your name or your avatar. Daily Test answers stay on your device. | Your name or your avatar. Your Daily Test answers stay on your device. | "Günlük Test cevapların" is a noun compound = "your Daily Test answers" | Updated for the translated feature names (Günlük Test, Konu Pratiği; owner, 2026-11-02) and back-translated again, blind. ✓ |
| `aiConsentPersonalDetails` | Please don't type personal details such as full names, addresses or contact information into your answers. | Please do not write personal information such as full name, address or contact information in your answers. |  | ✓ |
| `aiConsentChangeLater` | You can change this any time in Profile → Data. | You can change this whenever you want from the Profile → Data section. |  | ✓ |
| `aiConsentAgree` | Agree and continue | Accept and continue | "Kabul et" = accept/agree | ✓ "Accept" and "agree" are the same Turkish verb. |
| `aiConsentNotNow` | Not now | Not now |  | ✓ |
| `aiConsentNotNowNote` | Not now: you can still take the Daily Test. | Not now: you can still solve the Daily Test. | "çözebilirsin" = you can solve (i.e. take/do the test); "yine de" = still/anyway | Updated for the translated feature names (Günlük Test, Konu Pratiği; owner, 2026-11-02) and back-translated again, blind. ✓ "solve the Daily Test" is how Turkish says "take a test". |
| `onboardingPrivacyNote` | Your name stays on this device. Your goal is sent with app usage data, never with your name. Usage and crash data is collected. | Your name stays on this device. Your goal is sent with app usage data, never with your name. Usage and crash data are collected. |  | ✓ |
| `onboardingDataLink` | How AI feedback uses your answers | How artificial intelligence feedback uses your answers |  | ✓ |
| `onboardingDataTitle` | Your data & AI | Your data and artificial intelligence | Possessive applies to "data" only | ✓ "Your data and AI". |
| `onboardingDataDeviceHeading` | On this device | On this device |  | ✓ |
| `onboardingDataDeviceBody` | Your name stays on this device. | Your name stays on this device. |  | ✓ |
| `onboardingDataGoalHeading` | Your learning goal | Your learning goal |  | ✓ |
| `onboardingDataGoalBody` | Sent with app usage data, never with your name, to help us decide what to improve. It does not personalize your lessons. | It is sent with app usage data, never with your name, to help us decide what we will improve. It does not personalize your lessons. | Subject is implicit (the goal); "geliştireceğimize" = what we will improve/develop | ✓ |
| `onboardingDataAiHeading` | AI feedback | Artificial intelligence feedback |  | ✓ As `dataAiCardTitle`. |
| `onboardingDataAiBody` | In practice sessions (Topic Practice or a weak spot), your answers are sent to Anthropic (Claude) to give you feedback. We ask for your permission first. | In practice sessions (Topic Practice or a weak spot), your answers are sent to the Anthropic (Claude) service to give you feedback. We ask for your permission first. | "isteriz" aorist: "we ask" / "we will ask" | Updated for the translated feature names (Günlük Test, Konu Pratiği; owner, 2026-11-02) and back-translated again, blind. ✓ |
| `onboardingDataDiagnosticsHeading` | App diagnostics | App diagnostics |  | ✓ |
| `onboardingDataDiagnosticsBody` | Usage and crash data is collected. | Usage and crash data are collected. |  | ✓ |
| `onboardingDataGotIt` | Got it | Got it | Literally "I understood" | ✓ |
| `practiceNotSent` | Your answers were not sent. AI feedback needs your permission (Profile → Data). | Your answers were not sent. Your permission is needed for artificial intelligence feedback (Profile → Data). |  | ✓ |
| `paywallBenefitFeedbackBody` | AI feedback on every topic you practice, not just your free daily practice. | Artificial intelligence feedback in every topic you study, not only in your daily free practice. | "çalıştığın" = you study/work on | ✓ "study" for "practice"; the claim (every topic, not only the free daily practice) is unchanged. |
| `paywallBenefitWeakSpotsBody` | {count, plural, =1{Go beyond your one free daily practice.} other{Go beyond your {count} free daily practices.}} | {count, plural, =1{Go beyond your single daily free practice.} other{Go beyond your daily {count} free practice.}} | Turkish uses singular noun after a numeral: other = "your {count} daily free practices"; "tek" = single/only one | ✓ Turkish puts a singular noun after a number ("2 free practice"); not a change of meaning. |
| `paywallBenefitTopicsBody` | All {topics} topics · {lengths} questions · up to {sessions} sessions a day. | All of the {topics} topics · {lengths} questions · at most {sessions} sessions per day. | Nouns singular in Turkish after numerals ("{topics} topic", "{lengths} question", "{sessions} session"); literally "per day at most {sessions} session" | ✓ As above; "at most {sessions} sessions per day" keeps the cap. |
| `paywallPlanAnnual` | Annual | Yearly | "Yıllık" = annual/yearly | ✓ "Yearly" = annual. |
| `paywallPlanMonthly` | Monthly | Monthly |  | ✓ |
| `paywallSave` | Save {percent}% | {percent}% savings | Turkish places % before the number (%{percent}); "tasarruf" = saving(s), noun not verb | ✓ The percent sign comes first in Turkish ("%30"); the noun "savings" for the verb "save". |
| `paywallPerMonthApprox` | ≈ {price} per month | Monthly ≈ {price} | "Aylık" = monthly/per month | ✓ "Monthly ≈ {price}". |
| `paywallPricePerPeriod` | {price} per {period} | {price} / {period} |  | ✓ "{price} / {period}", the usual Turkish price notation. |
| `paywallPerPeriod` | per {period} | / {period} |  | ✓ As above. |
| `paywallTrial` | {length} free trial | {length} free trial |  | ✓ |
| `paywallBilledYearly` | Billed yearly | Billed yearly | Literally "It is invoiced yearly" | ✓ |
| `paywallBilledMonthly` | Billed monthly | Billed monthly |  | ✓ |
| `paywallBilledPerPeriod` | Billed per period | Billed per period |  | ✓ |
| `paywallBilledEvery` | Billed every {period} | Billed at {period} intervals | Literally "It is invoiced with {period} intervals"; reads as "every {period}" (e.g. "at 2-month intervals") | **Revised.** "Her {period}" with a number ("Her 3 ay") reads unnaturally; now "at {period} intervals" ("3 ay aralıklarla"). |
| `paywallStartTrial` | Start my {length} free trial | Start my {length} free trial |  | ✓ |
| `paywallContinueWith` | Continue with {plan} | Continue with {plan} |  | ✓ |
| `paywallSubscribeFor` | Subscribe for {pricePerPeriod} | Subscribe for {pricePerPeriod} | Literally "Subscribe in exchange for {pricePerPeriod}" | ✓ |
| `paywallDisclosureTrial` | {span} free, then {pricePerPeriod}, auto-renews unless cancelled. | {span} free, then {pricePerPeriod}; renews automatically unless cancelled. | Subject of "renews" implicit (subscription) | ✓ The trial span, the price after it and "renews automatically unless cancelled" are all there (App Store 3.1.2). |
| `paywallDisclosure` | {pricePerPeriod}, auto-renews unless cancelled. | {pricePerPeriod}; renews automatically unless cancelled. |  | ✓ As above. |
| `paywallPeriodDay` | {count, plural, =1{day} other{{count} days}} | {count, plural, =1{day} other{{count} day}} | Turkish singular after numerals: other = "{count} days" | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallSpanDay` | {count, plural, =1{1 day} other{{count} days}} | {count, plural, other{{count} day}} | = "{count} days" | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallTrialLengthDay` | {count}-day | {count}-day | Adjectival form ("-lük"): "of {count} days" | ✓ The adjective form ("7-day"), as in English. |
| `paywallPeriodWeek` | {count, plural, =1{week} other{{count} weeks}} | {count, plural, =1{week} other{{count} week}} | other = "{count} weeks" | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallSpanWeek` | {count, plural, =1{1 week} other{{count} weeks}} | {count, plural, other{{count} week}} | = "{count} weeks" | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallTrialLengthWeek` | {count}-week | {count}-week | Adjectival form | ✓ The adjective form ("7-day"), as in English. |
| `paywallPeriodMonth` | {count, plural, =1{month} other{{count} months}} | {count, plural, =1{month} other{{count} month}} | other = "{count} months" | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallSpanMonth` | {count, plural, =1{1 month} other{{count} months}} | {count, plural, other{{count} month}} | = "{count} months" | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallTrialLengthMonth` | {count}-month | {count}-month | Adjectival form; "aylık" also means "monthly" | ✓ The adjective form ("7-day"), as in English. |
| `paywallPeriodYear` | {count, plural, =1{year} other{{count} years}} | {count, plural, =1{year} other{{count} year}} | other = "{count} years" | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallSpanYear` | {count, plural, =1{1 year} other{{count} years}} | {count, plural, other{{count} year}} | = "{count} years" | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallTrialLengthYear` | {count}-year | {count}-year | Adjectival form; "yıllık" also means "yearly" | ✓ The adjective form ("7-day"), as in English. |
| `paywallPeriodUnknown` | period | period |  | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallSpanUnknown` | {count, plural, =1{1 period} other{{count} periods}} | {count, plural, other{{count} period}} | = "{count} periods" | ✓ Turkish keeps the noun singular after a number ("3 day" = 3 days). |
| `paywallTrialLengthUnknown` | {count}-period | {count}-period | Adjectival form | ✓ The adjective form ("7-day"), as in English. |
| `paywallRestored` | Purchases restored — full access is active. | Purchases restored; full access is active. |  | ✓ |
| `paywallNothingToRestore` | No previous purchases found to restore. | No purchase to restore was found. | Literally "A purchase to be restored could not be found" | ✓ |
| `paywallTrialStarted` | Trial started — Topic Practice is unlocked. | Trial started; Topic Practice is unlocked. | Literally "the lock of Topic Practice was opened" | Updated for the translated feature names (Günlük Test, Konu Pratiği; owner, 2026-11-02) and back-translated again, blind. ✓ |
| `paywallActive` | Premium is active — Topic Practice is unlocked. | Premium is active; Topic Practice is unlocked. | Literally "the lock of Topic Practice was opened" | Updated for the translated feature names (Günlük Test, Konu Pratiği; owner, 2026-11-02) and back-translated again, blind. ✓ |
| `paywallCancelled` | Purchase cancelled — no charge was made. | Purchase cancelled; no charge was taken. | "ücret alınmadı" = no fee was charged | ✓ "no charge was taken" = no charge was made. |
| `paywallPending` | Waiting for approval — Premium starts once the purchase is approved. No charge until then. | Approval is awaited; Premium starts when the purchase is approved. Until then no charge is taken. | "Onay" = approval/confirmation; "ücret alınmaz" aorist = you are not / will not be charged | ✓ The purchase awaits approval; Premium starts on approval; no charge until then. |
| `paywallFailed` | Something went wrong and the purchase couldn't start. Please try again. | A problem occurred and the purchase could not be started. Please try again. |  | ✓ |
| `paywallRowDailyTest` | Daily Test, refreshed every day | Daily Test, renews every day | "yenilenir" = renews/refreshes/is renewed | Updated for the translated feature names (Günlük Test, Konu Pratiği; owner, 2026-11-02) and back-translated again, blind. ✓ "renews" here means the test is refreshed daily, not a subscription renewal; the Turkish verb is the everyday "is renewed / refreshed". |
| `paywallRowTopicPractice` | Topic Practice, all five topics | Topic Practice, all of the five topics |  | Updated for the translated feature names (Günlük Test, Konu Pratiği; owner, 2026-11-02) and back-translated again, blind. ✓ |
| `paywallRowWeakSpots` | Practice your weak spots | Study your weak spots | "çalış" imperative = study/work on | ✓ "Study" = practice. |
| `paywallRowLengths` | Sessions of {lengths} questions | {lengths}-question sessions | Literally "sessions of {lengths} questions" | ✓ |
| `paywallFreePerDay` | {count} a day | {count} per day | Literally "In a day {count}" | ✓ |
| `paywallFreePerDayShort` | {count}/day | {count}/day |  | ✓ |
