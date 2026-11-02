# Back-translation check: Japanese (`app_ja.arb`)

1.4.0 B5, D6 ([`../1.4.0-b5-batch0-report.md`](../1.4.0-b5-batch0-report.md) §2, §8 Q3). The 83 keys with legal or App Review weight, or that complete those screens (the AI permission screen, onboarding's "Your data & AI", the Data screen's AI card, the paywall), translated back into English **blind**: a separate subagent was given only the Japanese strings and their keys, never the English, and asked for a literal rendering. Its notes on ambiguity are kept in the fourth column.

**Limit:** the back-translation was made by the same model family that wrote the Japanese, so it is a consistency check (a dropped clause, a changed number, a trial that became a discount, a lost "auto-renews", a changed recipient), not an independent review. D6 has no native-speaker review.

**Layout:** `test/l10n_layout_test.dart` measures Latin-script text only; it cannot judge a Japanese line's width or wrapping (no word spaces to break on, different glyph widths), so it does not run for Japanese. The 320 pt and Large-text check for Japanese is the owner's device pass.

**Result:** 71 of 83 matched the English meaning on the first pass. Twelve were revised in `app_ja.arb` and back-translated again, blind, all matching: "you entered" now covers only the answers; the withdrawal note and the onboarding AI line now say the app asks (not a request to the learner); "what to improve" now says "in the app"; the never-sent line and two others became full です・ます sentences; three labels made plainer. The table shows each row's latest pass; the Δ column says what changed. **Owner sign-off:** open.

| Key | English (original) | Back-translation | Subagent note | Δ |
|---|---|---|---|---|
| `dataAiCardTitle` | AI feedback | AI feedback |  | ✓ |
| `dataAiExplanation` | Practice sessions send your {what} to {provider} to create feedback. | In practice sessions, (we) send {what} to {provider} in order to create feedback. | Subject omitted (reads as 'we/the app sends'); natural in Japanese. | ✓ |
| `dataAiWhat` | typed answers and the questions | the questions and the answers (you) entered | Unambiguous now: 入力した modifies only 解答. | **Revised.** "入力した解答と問題" let "you entered" cover the questions too; now "問題と、入力した解答". |
| `dataAiSwitch` | Allow AI feedback | Allow AI feedback |  | ✓ |
| `dataAiOn` | On · Required for practice sessions | On · Required for practice sessions |  | ✓ |
| `dataAiOff` | Off · Practice sessions need permission | Off · Practice sessions require permission |  | ✓ |
| `dataAiDailyTestNote` | Daily Test works without this permission. | The Daily Test can be used even without this permission. |  | ✓ |
| `dataAiWithdrawn` | Practice sessions will ask again. | At a practice session, (we) will ask for (your) permission again. | Clear; polite お尋ねします. | **Revised.** "再度確認します" could read "we will check again"; now "we will ask for your permission again". |
| `dataAiChangeFailed` | Could not change this setting: {error} | Could not change this setting: {error} | Full-width colon; fine. | ✓ |
| `aiConsentTitle` | AI feedback | AI feedback |  | ✓ |
| `aiConsentHeading` | Feedback on your answers | Feedback on (your) answers |  | ✓ |
| `aiConsentIntro` | Practice sessions use an AI service to check your answers and explain what to fix. This covers Topic Practice and practicing a weak spot. | In practice sessions, (we) use an AI service to check (your) answers and explain the points that should be fixed. The target is topic practice and weak-spot practice. | 対象は...です is a little stiff but correct. | ✓ |
| `aiConsentSentHeading` | What is sent | What is sent |  | ✓ |
| `aiConsentSentBody` | The answers you type, together with the question each one responds to. This happens when you finish a practice session. | The answers (you) entered and the question that corresponds to each answer. They are sent when (you) finish the practice session. | First sentence is a noun phrase + です answering the heading; acceptable. | ✓ |
| `aiConsentRecipientHeading` | Who receives it | Destination (where it is sent) | Neutral heading; fine. | **Revised.** "受け取る相手" was personal for a company; now "送信先" (destination). |
| `aiConsentRecipientBody` | Anthropic, the company that makes Claude. Your answers go through GrammarLens's server to Anthropic's Claude model, which writes your feedback. | Anthropic, the company that develops Claude. (Your) answers reach Anthropic's Claude model via GrammarLens's servers, and this model creates the feedback. |  | ✓ |
| `aiConsentNeverHeading` | What is never sent | What is not sent |  | ✓ |
| `aiConsentNeverBody` | Your name or your avatar. Daily Test answers stay on your device. | Your name and avatar are not sent. Daily Test answers stay within the device. | Both sentences です・ます; consistent. や implies 'such as name or avatar' (non-exhaustive), which is slightly softer than 'and'. | **Revised.** A bare noun list; now a full sentence ("…は送信されません"). |
| `aiConsentPersonalDetails` | Please don't type personal details such as full names, addresses or contact information into your answers. | Please do not enter personal information such as (your) full name, address, or contact details in (your) answers. |  | ✓ |
| `aiConsentChangeLater` | You can change this any time in Profile → Data. | This setting can be changed at any time in “Profile → Data”. |  | ✓ |
| `aiConsentAgree` | Agree and continue | Agree and continue |  | ✓ |
| `aiConsentNotNow` | Not now | Later | Natural button label. | **Revised.** "今はしない" was blunt; now "あとで" (later), the usual button. |
| `aiConsentNotNowNote` | Not now: you can still take the Daily Test. | Even if (you) don't allow (it) now, (you) can take the Daily Test. |  | **Revised.** Reused the button as a verb; now "今は許可しなくても" (even if you don't allow it now). |
| `onboardingPrivacyNote` | Your name stays on this device. Your goal is sent with app usage data, never with your name. Usage and crash data is collected. | (Your) name stays within this device. (Your) goal is sent together with app usage data, and is never sent together with (your) name. (We) collect usage data and crash data. | Subject of 収集します omitted (we/the app). Fine. | ✓ |
| `onboardingDataLink` | How AI feedback uses your answers | How (your) answers are used in AI feedback | Noun phrase ending in 使われ方; fine as a link. | ✓ |
| `onboardingDataTitle` | Your data & AI | Your data and AI |  | ✓ |
| `onboardingDataDeviceHeading` | On this device | Within this device | Literally 'inside this device'; as a heading it means 'on this device'. | ✓ |
| `onboardingDataDeviceBody` | Your name stays on this device. | (Your) name stays within this device. |  | ✓ |
| `onboardingDataGoalHeading` | Your learning goal | Learning goal |  | ✓ |
| `onboardingDataGoalBody` | Sent with app usage data, never with your name, to help us decide what to improve. It does not personalize your lessons. | It is sent together with app usage data in order to decide what to improve in the app. It is never sent together with (your) name. The lesson content does not change according to (your) goal. | アプリの is repeated twice in the first sentence (アプリの何を... アプリの利用データ); slightly repetitive but clear. | **Revised.** "what to improve" could mean the learner's English; now "アプリの何を" (what in the app). The onboarding subtitle got the same fix. |
| `onboardingDataAiHeading` | AI feedback | AI feedback |  | ✓ |
| `onboardingDataAiBody` | In practice sessions (Topic Practice or a weak spot), your answers are sent to Anthropic (Claude) to give you feedback. We ask for your permission first. | In practice sessions (topic practice or weak-spot practice), (we) send (your) answers to Anthropic (Claude) for feedback. Before sending, (we) ask for your permission. | Clear; no longer reads as a request to the user. | **Revised.** "許可をお願いします" could read as a request to the learner; now "we ask for your permission". |
| `onboardingDataDiagnosticsHeading` | App diagnostics | App diagnostics |  | ✓ |
| `onboardingDataDiagnosticsBody` | Usage and crash data is collected. | (We) collect usage data and crash data. |  | ✓ |
| `onboardingDataGotIt` | Got it | Understood | わかりました = 'I understand / Got it'; polite form, fine for a button. | ✓ |
| `practiceNotSent` | Your answers were not sent. AI feedback needs your permission (Profile → Data). | (Your) answers were not sent. AI feedback requires permission (Profile → Data). |  | ✓ |
| `paywallBenefitFeedbackBody` | AI feedback on every topic you practice, not just your free daily practice. | Not only the daily free practice: (you) can receive AI feedback on every topic (you) practice. | Full sentence in です・ます (受けられます); fine. | **Revised.** Ended on a noun; now "…を受けられます". |
| `paywallBenefitWeakSpotsBody` | {count, plural, =1{Go beyond your one free daily practice.} other{Go beyond your {count} free daily practices.}} | {count, plural, =1{(You) can practice beyond the 1 free practice per day.} other{(You) can practice beyond the {count} free practices per day.}} | 超えて ('exceeding/beyond') is literal and slightly stiff; understandable. 1日 here is 'per day' (could in isolation read as 'the 1st of the month', but context makes it clear). | ✓ |
| `paywallBenefitTopicsBody` | All {topics} topics · {lengths} questions · up to {sessions} sessions a day. | All {topics} topics · {lengths} questions · up to {sessions} sessions per day. | {lengths}問 reads as a single number of questions; if {lengths} is a list (e.g. 5, 10) it becomes '5、10問', which is understandable. | ✓ |
| `paywallPlanAnnual` | Annual | Annual (amount) | 年額 = 'yearly price/amount'; standard on Japanese paywalls. | ✓ |
| `paywallPlanMonthly` | Monthly | Monthly (amount) | 月額 = 'monthly price/amount'; standard. | ✓ |
| `paywallSave` | Save {percent}% | {percent}% good deal / {percent}% savings | お得 is an idiomatic 'good value' label; natural on Japanese paywalls. | ✓ "お得" (good value) is the usual Japanese paywall badge. |
| `paywallPerMonthApprox` | ≈ {price} per month | Approx. {price} per month |  | ✓ |
| `paywallPricePerPeriod` | {price} per {period} | {price}/{period} |  | ✓ |
| `paywallPerPeriod` | per {period} | /{period} |  | ✓ |
| `paywallTrial` | {length} free trial | {length} free trial |  | ✓ |
| `paywallBilledYearly` | Billed yearly | Billed every year | Noun phrase, natural label. | **Revised.** "年ごとに請求" → "毎年請求", the usual form. |
| `paywallBilledMonthly` | Billed monthly | Billed every month | Noun phrase, natural label. | **Revised.** "月ごとに請求" → "毎月請求". |
| `paywallBilledPerPeriod` | Billed per period | Billed per period | Vague by nature (fallback). | ✓ |
| `paywallBilledEvery` | Billed every {period} | Billed every {period} | Works with the period forms (日/週/月/年, 3か月 etc.): 'Xごとに請求'. | ✓ |
| `paywallStartTrial` | Start my {length} free trial | Start (the) {length} free trial | Uses hiragana はじめる, while other strings use the kanji 始まります (paywallPending) and 開始 (paywallTrialStarted). Minor script inconsistency; 始める would match. | ✓ |
| `paywallContinueWith` | Continue with {plan} | Continue with {plan} |  | ✓ |
| `paywallSubscribeFor` | Subscribe for {pricePerPeriod} | Register (subscribe) at {pricePerPeriod} | 登録する literally 'register'; commonly used for subscribing, fine. | ✓ |
| `paywallDisclosureTrial` | {span} free, then {pricePerPeriod}, auto-renews unless cancelled. | {span} free, after that {pricePerPeriod}. It renews automatically unless (you) cancel. |  | ✓ |
| `paywallDisclosure` | {pricePerPeriod}, auto-renews unless cancelled. | {pricePerPeriod}. It renews automatically unless (you) cancel. |  | ✓ |
| `paywallPeriodDay` | {count, plural, =1{day} other{{count} days}} | {count, plural, =1{day} other{{count} days}} |  | ✓ |
| `paywallSpanDay` | {count, plural, =1{1 day} other{{count} days}} | {count, plural, other{(a span of) {count} days}} |  | ✓ |
| `paywallTrialLengthDay` | {count}-day | {count} days (duration) |  | ✓ |
| `paywallPeriodWeek` | {count, plural, =1{week} other{{count} weeks}} | {count, plural, =1{week} other{{count} weeks}} |  | ✓ |
| `paywallSpanWeek` | {count, plural, =1{1 week} other{{count} weeks}} | {count, plural, other{{count} weeks}} |  | ✓ |
| `paywallTrialLengthWeek` | {count}-week | {count} weeks |  | ✓ |
| `paywallPeriodMonth` | {count, plural, =1{month} other{{count} months}} | {count, plural, =1{month} other{{count} months}} | =1 is 月 (bare kanji); fine after a slash or before ごとに. | ✓ |
| `paywallSpanMonth` | {count, plural, =1{1 month} other{{count} months}} | {count, plural, other{(a span of) {count} months}} |  | ✓ |
| `paywallTrialLengthMonth` | {count}-month | {count} months (duration) |  | ✓ |
| `paywallPeriodYear` | {count, plural, =1{year} other{{count} years}} | {count, plural, =1{year} other{{count} years}} |  | ✓ |
| `paywallSpanYear` | {count, plural, =1{1 year} other{{count} years}} | {count, plural, other{(a span of) {count} years}} |  | ✓ |
| `paywallTrialLengthYear` | {count}-year | {count} years (duration) |  | ✓ |
| `paywallPeriodUnknown` | period | period |  | ✓ |
| `paywallSpanUnknown` | {count, plural, =1{1 period} other{{count} periods}} | {count, plural, other{{count} periods}} | {count}期間 is unusual Japanese ('3 periods'); acceptable only as a fallback. | ✓ A fallback for a unit the store does not name; unusual but clear. |
| `paywallTrialLengthUnknown` | {count}-period | {count} periods | Same as above: unusual but understandable fallback. | ✓ As `paywallSpanUnknown`. |
| `paywallRestored` | Purchases restored — full access is active. | (I/We) restored (your) purchase. All features can be used. |  | ✓ |
| `paywallNothingToRestore` | No previous purchases found to restore. | No past purchases that can be restored were found. |  | ✓ |
| `paywallTrialStarted` | Trial started — Topic Practice is unlocked. | The free trial has started. Topic practice is now available. | Literally '(you/we) started the free trial'; 開始しました without a subject is natural. | ✓ |
| `paywallActive` | Premium is active — Topic Practice is unlocked. | Premium is active. Topic practice is now available. |  | ✓ |
| `paywallCancelled` | Purchase cancelled — no charge was made. | (You) cancelled the purchase. No charge has been incurred. | キャンセルしました has no subject; it can read as 'the purchase was cancelled' or 'we cancelled the purchase'. Context makes the user's cancel clear enough. | ✓ |
| `paywallPending` | Waiting for approval — Premium starts once the purchase is approved. No charge until then. | Waiting for approval. Premium will start when the purchase is approved. Until then, no charge will be incurred. |  | ✓ |
| `paywallFailed` | Something went wrong and the purchase couldn't start. Please try again. | Because a problem occurred, (we) could not start the purchase. Please try again. |  | ✓ |
| `paywallRowDailyTest` | Daily Test, refreshed every day | Daily Test, updated every day |  | ✓ |
| `paywallRowTopicPractice` | Topic Practice, all five topics | Topic practice, all 5 topics |  | ✓ |
| `paywallRowWeakSpots` | Practice your weak spots | Weak-spot practice | Noun phrase; matches neighbouring rows. | **Revised.** A verb phrase among noun rows; now "弱点の練習". |
| `paywallRowLengths` | Sessions of {lengths} questions | {lengths}-question sessions |  | ✓ |
| `paywallFreePerDay` | {count} a day | {count} times per day | 1日 = 'per day' here; in isolation it could read 'the 1st (of the month)', but next to 回 it is clear. | ✓ |
| `paywallFreePerDayShort` | {count}/day | {count} times/day |  | ✓ |
