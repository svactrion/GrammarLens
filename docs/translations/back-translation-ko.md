# Back-translation check: Korean (`app_ko.arb`)

1.4.0 B5, D6 ([`../1.4.0-b5-batch0-report.md`](../1.4.0-b5-batch0-report.md) §2, §8 Q3). The 83 keys with legal or App Review weight, or that complete those screens (the AI permission screen, onboarding's "Your data & AI", the Data screen's AI card, the paywall), translated back into English **blind**: a separate subagent was given only the Korean strings and their keys, never the English, and asked for a literal rendering. Its notes on ambiguity are kept in the fourth column.

**Limit:** the back-translation was made by the same model family that wrote the Korean, so it is a consistency check (a dropped clause, a changed number, a trial that became a discount, a lost "auto-renews", a changed recipient), not an independent review. D6 has no native-speaker review.

**Layout:** `test/l10n_layout_test.dart` measures Latin-script text only; it cannot judge a Korean line's width or wrapping (no word spaces to break on, different glyph widths), so it does not run for Korean. The 320 pt and Large-text check for Korean is the owner's device pass.

**Result:** 76 of 83 matched on the first pass. Seven rows were revised (six strings changed) and back-translated again, blind, all matching. The real error: the object particle after {what} read "문제을" (the inserted text ends in a vowel); `dataAiWhat` now ends in a consonant, which also makes "you entered" cover only the answers. "{period}마다" broke on one-unit periods ("월마다", "년마다"), so the line is a label now. The table shows each row's latest pass; the Δ column says what changed. **Owner sign-off: done 2026-11-03.** All rows approved as they stand; every revised row matched on its blind second pass; the same-model-family limit above stays.

| Key | English (original) | Back-translation | Subagent note | Δ |
|---|---|---|---|---|
| `dataAiCardTitle` | AI feedback | AI feedback |  | ✓ |
| `dataAiExplanation` | Practice sessions send your {what} to {provider} to create feedback. | Practice sessions send {what} to {provider} in order to make feedback. | With {what} = dataAiWhat ("문제와 입력한 답변", ends in 변 with a final consonant), 을 is now correct. {provider}에 is fine for any value. "Practice sessions" as the subject of "send" is slightly personified but acceptable. | **Revised** (through `dataAiWhat`): the particle 을 was wrong after the old text; it is right after the new one. |
| `dataAiWhat` | typed answers and the questions | the questions and the answers (you) entered | Ends in a final consonant (답변), so 을 in dataAiExplanation fits. 문제 can be singular or plural. | **Revised.** "입력한 답변과 문제" → "문제와 입력한 답변": ends in a consonant, and "you entered" covers only the answers. |
| `dataAiSwitch` | Allow AI feedback | Allow AI feedback |  | ✓ |
| `dataAiOn` | On · Required for practice sessions | On · needed for practice sessions | Status noun (켜짐) followed by 해요체 clause; normal for a switch subtitle. Subject (what is needed) is implicit. | ✓ |
| `dataAiOff` | Off · Practice sessions need permission | Off · practice sessions need the permission | 허용 as a noun ("the allowing") is a little unnatural; 동의 (consent) would read more naturally, but it is understandable. | ✓ |
| `dataAiDailyTestNote` | Daily Test works without this permission. | Even if (you) don't allow (it), (you) can use the Daily Test. | Natural. Object of 허용하지 않아도 (AI feedback) is implicit from the screen. 데일리 테스트 is a transliteration of "Daily Test". | **Revised.** "이 허용 없이도" was awkward; now "허용하지 않아도". |
| `dataAiWithdrawn` | Practice sessions will ask again. | We will ask again in practice sessions. | Lit. "in the practice session(s)"; implies the question comes back when a practice session starts. No subject; fine. | ✓ |
| `dataAiChangeFailed` | Could not change this setting: {error} | Couldn't change this setting: {error} |  | ✓ |
| `aiConsentTitle` | AI feedback | AI feedback |  | ✓ |
| `aiConsentHeading` | Feedback on your answers | Feedback on (your) answers |  | ✓ |
| `aiConsentIntro` | Practice sessions use an AI service to check your answers and explain what to fix. This covers Topic Practice and practicing a weak spot. | Practice sessions use an AI service to check answers and explain points to fix. Topic practice and weak spot practice fall under this. | "여기에 해당해요" = "correspond to this / are included here"; natural. | ✓ |
| `aiConsentSentHeading` | What is sent | Information (we) send |  | ✓ |
| `aiConsentSentBody` | The answers you type, together with the question each one responds to. This happens when you finish a practice session. | It is the answers (you) entered and the question that each answer belongs to. (We) send them when (you) finish a practice session. | First sentence uses copula 예요 with an implied subject (the heading); natural for a heading/body pair. | ✓ |
| `aiConsentRecipientHeading` | Who receives it | Receiving place (where it goes) | Lit. "the place that receives"; natural as a heading. | ✓ |
| `aiConsentRecipientBody` | Anthropic, the company that makes Claude. Your answers go through GrammarLens's server to Anthropic's Claude model, which writes your feedback. | It is Anthropic, the company that makes Claude. Answers pass through the GrammarLens server and are delivered to Anthropic's Claude model, and this model writes the feedback. |  | ✓ |
| `aiConsentNeverHeading` | What is never sent | Information (we) never send | 절대 is emphatic ("absolutely never"); fine. | ✓ |
| `aiConsentNeverBody` | Your name or your avatar. Daily Test answers stay on your device. | (We) don't send name and avatar. Daily Test answers stay only on the device. | No possessive ("your"); natural in Korean. | ✓ |
| `aiConsentPersonalDetails` | Please don't type personal details such as full names, addresses or contact information into your answers. | Do not enter personal information such as real name, address, or contact details in answers. | Polite negative imperative 하지 마세요; consistent with 해요체. | ✓ |
| `aiConsentChangeLater` | You can change this any time in Profile → Data. | (You) can change (it) any time in Profile → Data. | Object omitted (the setting); fine. | ✓ |
| `aiConsentAgree` | Agree and continue | Agree and continue |  | ✓ |
| `aiConsentNotNow` | Not now | Later | Lit. "later", not "not now"; normal Korean button wording. | ✓ "나중에" (later) is the usual Korean button. |
| `aiConsentNotNowNote` | Not now: you can still take the Daily Test. | Even if (you) decide later, (you) can still take the Daily Test. | Clear now; 결정해도 makes it the decision that is postponed. 풀다 = "solve" (a test); natural. | **Revised.** "나중에 해도" left what is postponed vague; now "나중에 결정해도" (even if you decide later). |
| `onboardingPrivacyNote` | Your name stays on this device. Your goal is sent with app usage data, never with your name. Usage and crash data is collected. | Name stays only on this device. The goal is sent together with app usage data, and is not sent together with the name. (We) collect usage data and error data. | -며 connective (전송되며) is written/formal style inside a 해요체 sentence; acceptable but a touch stiff. "함께 전송" repeated twice reads a little repetitive. | ✓ |
| `onboardingDataLink` | How AI feedback uses your answers | How AI feedback uses answers |  | ✓ |
| `onboardingDataTitle` | Your data & AI | My data and AI |  | ✓ |
| `onboardingDataDeviceHeading` | On this device | On this device |  | ✓ |
| `onboardingDataDeviceBody` | Your name stays on this device. | Name stays only on this device. |  | ✓ |
| `onboardingDataGoalHeading` | Your learning goal | Learning goal |  | ✓ |
| `onboardingDataGoalBody` | Sent with app usage data, never with your name, to help us decide what to improve. It does not personalize your lessons. | (It) is sent together with app usage data, to be used as a reference in deciding what to improve in the app, and is not sent together with the name. Lessons do not change to fit the goal. | 앱에서 removes the earlier ambiguity: it is clearly about improving the app. Who decides is still unstated but reads as the app makers. Subject (the goal) comes only from the heading. -며 connective is slightly formal inside 해요체, and "함께 전송" repeats; acceptable. | **Revised.** Added "앱에서" (in the app) to "what to improve"; the onboarding subtitle got the same fix. |
| `onboardingDataAiHeading` | AI feedback | AI feedback |  | ✓ |
| `onboardingDataAiBody` | In practice sessions (Topic Practice or a weak spot), your answers are sent to Anthropic (Claude) to give you feedback. We ask for your permission first. | In practice sessions (topic practice or weak spot practice), (we) send answers to Anthropic (Claude) for feedback. Before sending, (we) first ask for permission. |  | ✓ |
| `onboardingDataDiagnosticsHeading` | App diagnostics | App diagnostics |  | ✓ |
| `onboardingDataDiagnosticsBody` | Usage and crash data is collected. | (We) collect usage data and error data. |  | ✓ |
| `onboardingDataGotIt` | Got it | OK (Confirm) | 확인 = "OK/confirm", not literally "got it"; standard Korean dismiss button. | ✓ "확인" is the usual Korean dismiss button. |
| `practiceNotSent` | Your answers were not sent. AI feedback needs your permission (Profile → Data). | (We) did not send the answers. AI feedback needs permission (Profile → Data). |  | ✓ |
| `paywallBenefitFeedbackBody` | AI feedback on every topic you practice, not just your free daily practice. | Get AI feedback on every topic (you) practice, not just the daily free practice. | 매일의 ("of every day") is slightly literary but fine. | ✓ |
| `paywallBenefitWeakSpotsBody` | {count, plural, =1{Go beyond your one free daily practice.} other{Go beyond your {count} free daily practices.}} | {count, plural, =1{Practice more, beyond the 1 free practice a day.} other{Practice more, beyond the {count} free practices a day.}} | Natural; ~을 넘어 (going beyond) avoids the earlier repetition. Korean needs no plural split; the two cases are harmless. | **Revised.** "연습보다 더 많이 연습해요" repeated itself; now "…을 넘어 더 연습해요" (go beyond). |
| `paywallBenefitTopicsBody` | All {topics} topics · {lengths} questions · up to {sessions} sessions a day. | All {topics} topics · {lengths} questions · up to {sessions} sessions a day. | {lengths}문제 depends on what {lengths} expands to (e.g. "10, 20" works; a list with a Korean conjunction also works). Period after a fragment list is fine. | ✓ |
| `paywallPlanAnnual` | Annual | Annual |  | ✓ |
| `paywallPlanMonthly` | Monthly | Monthly |  | ✓ |
| `paywallSave` | Save {percent}% | {percent}% discount | 할인 = "discount/off", not "save". If the badge compares annual against monthly pricing, 할인 suggests a price reduction rather than savings (절약); common in Korean paywalls, so acceptable. | ✓ "할인" (discount) is the usual Korean paywall badge for the annual saving. |
| `paywallPerMonthApprox` | ≈ {price} per month | About {price} a month |  | ✓ |
| `paywallPricePerPeriod` | {price} per {period} | {price}/{period} | Works with the =1 period words (/일, /주, /월, /년). With paywallPeriodUnknown it becomes "{price}/기간", which is odd. | ✓ |
| `paywallPerPeriod` | per {period} | /{period} |  | ✓ |
| `paywallTrial` | {length} free trial | {length} free trial |  | ✓ |
| `paywallBilledYearly` | Billed yearly | Billed every year |  | ✓ |
| `paywallBilledMonthly` | Billed monthly | Billed every month |  | ✓ |
| `paywallBilledPerPeriod` | Billed per period | Billed every period | 기간마다 (every period) is vague; acceptable only as a fallback. | ✓ |
| `paywallBilledEvery` | Billed every {period} | Billing cycle: {period} | Label style avoids the 마다 particle problem. Readable with "2주", "3개월", "주", "월", "년" ("결제 주기: 년" is a little bare but acceptable). Bare "일" is still ambiguous (day / work / one), and the fallback "결제 주기: 기간" (billing cycle: period) says nothing. | **Revised.** "{period}마다" breaks on "월", "년", "일"; now "결제 주기: {period}" (billing cycle). A one-day period still reads as bare "일"; no store plan has one. |
| `paywallStartTrial` | Start my {length} free trial | Start {length} free trial |  | ✓ |
| `paywallContinueWith` | Continue with {plan} | Continue with the {plan} plan | 으로 after 플랜 is correct whatever {plan} is. | ✓ |
| `paywallSubscribeFor` | Subscribe for {pricePerPeriod} | Subscribe for {pricePerPeriod} | Becomes e.g. "₩9,900/월에 구독하기"; 에 after the slash notation is readable. | ✓ |
| `paywallDisclosureTrial` | {span} free, then {pricePerPeriod}, auto-renews unless cancelled. | {span} free, then {pricePerPeriod}. Renews automatically unless (you) cancel. |  | ✓ |
| `paywallDisclosure` | {pricePerPeriod}, auto-renews unless cancelled. | {pricePerPeriod}. Renews automatically unless (you) cancel. |  | ✓ |
| `paywallPeriodDay` | {count, plural, =1{day} other{{count} days}} | {count, plural, =1{day} other{{count} days}} | Bare 일 is ambiguous (day / work / the number one); fine after a slash, odd elsewhere (see paywallBilledEvery). | ✓ |
| `paywallSpanDay` | {count, plural, =1{1 day} other{{count} days}} | {count, plural, other{{count} days}} |  | ✓ |
| `paywallTrialLengthDay` | {count}-day | {count} days |  | ✓ |
| `paywallPeriodWeek` | {count, plural, =1{week} other{{count} weeks}} | {count, plural, =1{week} other{{count} weeks}} |  | ✓ |
| `paywallSpanWeek` | {count, plural, =1{1 week} other{{count} weeks}} | {count, plural, other{{count} weeks}} |  | ✓ |
| `paywallTrialLengthWeek` | {count}-week | {count} weeks |  | ✓ |
| `paywallPeriodMonth` | {count, plural, =1{month} other{{count} months}} | {count, plural, =1{month} other{{count} months}} | Bare 월 also reads as "Monday" (abbreviation) or the calendar-month prefix; fine after a slash, awkward in "월마다". | ✓ |
| `paywallSpanMonth` | {count, plural, =1{1 month} other{{count} months}} | {count, plural, other{{count} months}} |  | ✓ |
| `paywallTrialLengthMonth` | {count}-month | {count} months |  | ✓ |
| `paywallPeriodYear` | {count, plural, =1{year} other{{count} years}} | {count, plural, =1{year} other{{count} years}} | Bare 년 is a bound noun; fine after a slash (/년), awkward in "년마다". | ✓ |
| `paywallSpanYear` | {count, plural, =1{1 year} other{{count} years}} | {count, plural, other{{count} years}} |  | ✓ |
| `paywallTrialLengthYear` | {count}-year | {count} years |  | ✓ |
| `paywallPeriodUnknown` | period | period |  | ✓ |
| `paywallSpanUnknown` | {count, plural, =1{1 period} other{{count} periods}} | {count, plural, other{{count} periods}} | 기간 is not a Korean counter; "{count}기간" sounds odd. A fallback only. | ✓ A fallback for a unit the store does not name. |
| `paywallTrialLengthUnknown` | {count}-period | {count} periods | Same as paywallSpanUnknown: "{count}기간" is not natural Korean. | ✓ As `paywallSpanUnknown`. |
| `paywallRestored` | Purchases restored — full access is active. | (We) restored the purchase. (You) can use all features. |  | ✓ |
| `paywallNothingToRestore` | No previous purchases found to restore. | There is no previous purchase history to restore. |  | ✓ |
| `paywallTrialStarted` | Trial started — Topic Practice is unlocked. | The free trial has started. (You) can use topic practice. |  | ✓ |
| `paywallActive` | Premium is active — Topic Practice is unlocked. | Premium has been activated. (You) can use topic practice. | Premium left in Latin script. | ✓ |
| `paywallCancelled` | Purchase cancelled — no charge was made. | (You/We) cancelled the purchase. (You) were not charged. | Subject of 취소했어요 is unstated; it can read as the user cancelling or the app cancelling. In context (user backed out) it is understood as the user. | ✓ |
| `paywallPending` | Waiting for approval — Premium starts once the purchase is approved. No charge until then. | Waiting for approval. When the purchase is approved, Premium starts. Until then, (you) are not charged. |  | ✓ |
| `paywallFailed` | Something went wrong and the purchase couldn't start. Please try again. | A problem occurred and (we) couldn't start the purchase. Please try again. |  | ✓ |
| `paywallRowDailyTest` | Daily Test, refreshed every day | Daily Test, newly opens every day | Noun-form ending 열림 is normal for a list row. | ✓ |
| `paywallRowTopicPractice` | Topic Practice, all five topics | Topic practice, all 5 topics | The number 5 is hard-coded here while paywallBenefitTopicsBody uses {topics}. | ✓ |
| `paywallRowWeakSpots` | Practice your weak spots | Weak spot practice |  | ✓ |
| `paywallRowLengths` | Sessions of {lengths} questions | {lengths}-question sessions |  | ✓ |
| `paywallFreePerDay` | {count} a day | {count} times a day |  | ✓ |
| `paywallFreePerDayShort` | {count}/day | {count} times/day |  | ✓ |
