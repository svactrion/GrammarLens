# GrammarLens

<p align="center">
  <img src="screenshots/1.4.0/readme/header.png" width="820" alt="The GrammarLens wordmark beside a card that corrects 'She write every day.' to 'She writes every day.'">
</p>

GrammarLens turns your English mistakes into practice. Every day you get a short grammar test. When you finish, you don't just see a score — you see why each answer was right or wrong, written in plain language. It is built for people who learned English by speaking it, not by studying it.

**Live on the App Store — 1.4.0 (7 Nov 2026): seven interface languages, question-flow improvements. First public release: 1.3.0 (2 Nov 2026).**

<p>
  <a href="https://apps.apple.com/us/app/grammarlens-ai-english-tutor/id6811477346"><img src="https://img.shields.io/badge/App_Store-Download-black?logo=apple&logoColor=white" alt="Download on the App Store"></a>
</p>

<p align="center">
  <img src="screenshots/1.4.0/readme/01-results.png" width="135" alt="Every answer explained: a Daily Test result with the answer written, its correction and the reason">
  <img src="screenshots/1.4.0/readme/04-question.png" width="135" alt="Write your own answer: a Daily Test question with its answer box">
  <img src="screenshots/1.4.0/readme/02-hint.png" width="135" alt="See the grammar pattern: the topic hint slid open on a Tense Selection question">
  <img src="screenshots/1.4.0/readme/08-multi-blank.png" width="135" alt="One box for every blank: a two-blank Articles question, one blank set to no article">
  <img src="screenshots/1.4.0/readme/03-home.png" width="135" alt="Watch your progress climb: Home with the avatar on this month's mountain">
  <img src="screenshots/1.4.0/readme/05-review.png" width="135" alt="Your weak spots, in one place: Review with saved weak spots by topic">
</p>

*Screenshots: the first six frames of the en-US 1.4.0 App Store set (build 7, live since 7 Nov 2026; [`screenshots/1.4.0/`](screenshots/1.4.0/README.md)). 1.3.0's set is under "Version history". The learner is made up ("Sam").*

## What it does

- **Daily Test** (free): a fresh set of five questions every day. Fill in the blanks, correct the errors, and get an explanation for every answer. Everyone gets the same set on a given date, and it is graded on the device.
- **Topic Practice** (Premium): focus on a specific area (Articles, Tense Selection, Modal Verbs, Modal Past Forms, Gerund vs. Infinitive) with sessions of 3, 5 or 10 questions, generated and scored by AI.
- **Plain-language feedback:** instead of "wrong", you get the reasoning: which rule applies, why your answer doesn't fit, and what to remember next time. New in 1.4.0: marks per blank on multi-blank questions, and the words that changed between your answer and the correction highlighted.
- **Review:** built from your own wrong answers. The app remembers which grammar points you keep missing and collects them as weak spots, so you always know what to work on.
- **Topic hints:** slide to see the grammar pattern for a question's topic: a reminder of the rule, never the answer.
- **Mountain of Learning** (the Monthly Climb): every Daily Test takes your character one step up this month's mountain; a month's score earns a Bronze, Silver or Gold medal.
- **Free and Premium:** free includes one Daily Test and one practice session every day. Premium unlocks Topic Practice across all five areas and more practice sessions each day, as a monthly or annual subscription; both include a free trial for new subscribers.
- **Privacy:** no account and no sign-up. Your name, your progress and your practice history stay on your device. To give feedback, the answers you type in practice sessions are sent to the AI provider, Anthropic, only with your permission, which you can withdraw at any time from the Data screen. The app sends anonymous usage and crash data, never your name; there is no in-app switch to decline it.

## Interface languages

English, plus Turkish, German, Spanish, Portuguese, Japanese, Korean and Arabic since 1.4.0. 1.3.0 was English only.

The English content is the same for everyone: questions, answers, AI feedback and topic names stay in English in every language. Only the interface is localized. The translations are AI-made and checked by a blind back-translation; no native speaker has reviewed them ([tables](docs/translations/)).

## Key decisions, and what they cost

**1. One shared Daily Test a day instead of one per device**
- **Problem:** 1.0.0 generates a set per device per day, ≈ $0.023–0.028 each (measured tokens, 10 local runs). Daily Test cost grows with every active user.
- **Decision:** 1.1.0 generates one set per date on the server and serves it to everyone; grading stays on the device; a bundled pool of 7 sets covers a failed read.
- **Cost:** a bad set now reaches every user at once (the owner found 4 of 10 questions defective in the first two published sets); a scheduled job and a fallback to maintain. 1.0.0 will never be released, so no released app generates per device: 1.3.0, the first public release, carries the shared Daily Test from the never-submitted 1.1.0.
- **Result so far:** ≈ $0.019 per set (measured, 3 runs), ≈ $0.57 a month at any user count (estimate). Not yet measured with real users.
- **Evidence:** [shared Daily Test report](docs/1.1.0-shared-daily-test.md) §0, §1; [quality report](docs/1.1.0-shared-daily-test-quality.md) §0, §16.7; [build log](docs/build-log.md) 2026-09-26.

**2. Closing a paywall gap with a free quota**
- **Problem:** Review's "Practice this" button had no subscription check, so a free user could start paid-tier practice, bounded only by the 10-a-day cap everyone shared. Found on a device on 15 September 2026; noted and deferred ten days earlier.
- **Decision:** the check moved into the one function every practice set goes through. Free: one Daily Test and one 3-question practice session a day; the session counts only when generation succeeds.
- **Cost:** a free user who uses both every day costs ≈ $1.72–1.86 a month on 1.0.0 (Daily Test part measured, practice part an estimate) and pays nothing. Since 2026-11-02 the proxy scores practice with Claude Haiku 5.5 (Sonnet 5.5 generates the questions): in an offline measurement run (2026-10-31, list prices, not real users), a 5-question practice session cost ≈ $0.009 ($0.0078 to generate, $0.0015 to score), against ≈ $0.026 with Sonnet 5.5 scoring. Haiku agreed with the owner-reviewed labels on 97.8 % of 370 answers, marked no wrong answer as correct, and marked 3.9 % of right answers as wrong. Not yet measured on real traffic. The limit is 1 to cap the cost of each free user and to point anyone who wants more practice to Premium. The quota model will be re-evaluated with four weeks of data.
- **Evidence:** [build log](docs/build-log.md) 2026-09-15; [build log](docs/build-log.md) 2026-10-04 (free practice limit: rationale recorded after the fact); [PRD v2](docs/prd-v2.md) §13.7; [roadmap](docs/roadmap.md), "Post-launch tasks"; [measurement report](docs/1.4.0-measurement-report.md) §2, §6.

**3. Known flaw, not fixed: right answers graded as wrong**
- **Problem:** answers are graded by plain text matching. In the owner's review of 35 live questions, 6 had a right or defensible answer marked "Needs work", and it goes into the error profile. Contractions (`'m` / `am`) and spelling variants (`neighbourhood` / `neighborhood`) are not normalized.
- **Done so far:** the fallback pool carries 10 owner corrections. Since 2026-11-02 (P14, server side) each new live set goes through one review call (Claude Opus 5.5) that may add other accepted answers to it. In the offline measurement, all 27 answers it wrote were right, but it found 28 of the 71 known right alternatives (39.4 %), so most right alternatives are still graded as wrong.
- **Cost:** 1.3.0, the first public release, ships with it (it carries the never-submitted 1.1.0's shared Daily Test). The review call costs ≈ $0.04 per set (measured offline), and its findings go to a weekly owner review.
- **Evidence:** [roadmap](docs/roadmap.md), "Known flaws shipping in 1.1.0"; [build log](docs/build-log.md) 2026-10-04 (P12–P14), 2026-11-02 (proxy deployed); [measurement report](docs/1.4.0-measurement-report.md) §5.

**4. The scoring model, chosen by measurement**
- **Decision:** Claude Haiku 5.5 scores practice answers; a 5-question session costs about a third of the same session scored by Sonnet 5.5 (≈ $0.0093 against ≈ $0.0264), and Haiku agreed with the labelled sets at least as well (97.8 % against 95.4 %, about 370 answers each).
- **Limit:** an offline run at list prices, not real users. The labels were written by Claude and reviewed by the owner, so they share a model family with the models measured.
- **Evidence:** [measurement report](docs/1.4.0-measurement-report.md) §0, §2, §6, §7.

**5. Topic names stay in English in every interface language**
- **Decision:** topic names (Gerund vs. Infinitive, Modal Verbs, …) name English grammar points and match the questions, so they are not translated. Feature names are translated, one word each; only the brand stays (GrammarLens, Premium).
- **Evidence:** [build log](docs/build-log.md) 2026-11-02 (B5, the owner's decisions from the Turkish device pass).

## How it was built

I made the product decisions, set scope and acceptance criteria, and tested on device. The code was written with Claude Code in small batches; Codex made the 1.4.0 App Store screenshots and uploaded them through the App Store Connect API. The reasoning behind each decision is in [`docs/build-log.md`](docs/build-log.md), dated.

## Case study and writing

- [Case study](https://ahmettayfur.com/products/grammarlens/case-study): the decisions behind the product and what they cost.
- [Medium](https://medium.com/@ahmet-tayfur): process write-ups.
  - [Sıfır maliyetli dediğim ilk gün, maliyetin başladığı yerdi](https://ahmet-tayfur.medium.com/s%C4%B1f%C4%B1r-maliyetli-dedi%C4%9Fim-ilk-g%C3%BCn-maliyetin-ba%C5%9Flad%C4%B1%C4%9F%C4%B1-yerdi-42f94d7fa634) (in Turkish): where cost leaks in an AI app, from a "free" Daily Test to one shared set a day.

## Version history

| Version | When | What | Status |
|---|---|---|---|
| v1 — MVP | Jul 2026 | One-week sprint, user research, two iterations | Not released |
| v2 | Aug–Sep 2026 | Free/paid split, structure and visual pass, API proxy, subscriptions | Not released |
| 1.0.0 | Sep 2026 | v2 plus Monthly Climb | Submitted to App Store review; never released |
| 1.1.0 | Oct 2026 | Shared Daily Test; mountain themes, medals and collection; launch screen; new avatars; iPad layout | Skipped, never submitted; its content ships in 1.2.0 |
| 1.2.0 | Oct 2026 | Redesigned Home, Review and Profile; two-step onboarding with a learning goal; new paywall with trial eligibility; multiline answers | Never submitted; its content ships in 1.3.0 |
| 1.3.0 | Released 2 Nov 2026 | 1.2.0's redesign plus a new question screen: the topic on each question, a slide-to-reveal topic hint, one answer box per blank (with a "no article" button for articles), tap a blank to answer it, and Skip that really skips | Released 2026-11-02 (build 6); the first public release; replaced by 1.4.0 on 2026-11-07 |
| 1.4.0 | Released 7 Nov 2026 | Seven more interface languages; multi-blank questions accept a blank left empty and mark each blank; long feedback split into paragraphs; the words that changed highlighted; hints that no longer give the answer away | **Live since 2026-11-07** (build 7); submitted 5 Nov 2026, approved and released 7 Nov 2026 |

**Research:** four short interviews (one a self-interview) and a 3-participant usability test on the MVP ([PRD](docs/prd.md) §2.1, §2.2); fewer testers than the original target of five, a deliberate call.

**Not done yet:** Medium article 2; the home-screen widget (planned for 1.5.0).

<details>
<summary><strong>Previous version: 1.3.0 screenshots</strong> (the App Store set, build 6)</summary>

<p align="center">
  <img src="screenshots/1.3.0/readme/hero.png" width="820" alt="Three App Store frames: Every answer explained (Daily Test results); See the grammar pattern (the topic hint); Watch your progress climb (Home with this month's mountain)">
</p>

<p align="center">
  <img src="screenshots/1.3.0/readme/04-question.png" width="160" alt="Write your own answer: a Daily Test question with its answer box">
  <img src="screenshots/1.3.0/readme/05-review.png" width="160" alt="Your weak spots, in one place: Review with saved weak spots by topic">
  <img src="screenshots/1.3.0/readme/06-collection.png" width="160" alt="Build your mountain collection: Profile's medal collection">
  <img src="screenshots/1.3.0/readme/07-onboarding.png" width="160" alt="Pick your learning companion: onboarding's avatar choice">
  <img src="screenshots/1.3.0/readme/08-multi-blank.png" width="160" alt="One box for every blank: a two-blank Articles question">
</p>

</details>

<details>
<summary><strong>Previous version: 1.2.0 screenshots</strong> (never submitted; its content ships in 1.3.0)</summary>

<p align="center">
  <img src="screenshots/1.2.0/readme/hero.png" width="820" alt="Three iPhones: Home with this month's mountain, a Daily Test result with every answer explained, and a Daily Test question">
</p>

<p align="center">
  <img src="screenshots/1.2.0/readme/04-review.png" width="190" alt="Review: saved weak spots by topic, with today's free practice">
  <img src="screenshots/1.2.0/readme/05-weak-spot.png" width="190" alt="A weak spot's detail: the saved mistake, its correction and a free practice">
  <img src="screenshots/1.2.0/readme/07-collection.png" width="190" alt="Profile: the medal collection and this month's progress">
  <img src="screenshots/1.2.0/readme/08-goal.png" width="190" alt="Onboarding: choosing a learning goal">
</p>

</details>

<details>
<summary><strong>Previous version: 1.1.0 screenshots</strong> (skipped, never released)</summary>

| Result | Home | Review | Medal collection |
|---|---|---|---|
| ![Daily Test result: every answer with a one-sentence explanation](screenshots/1.1.0/01-result.png) | ![Home: the avatar on this month's mountain](screenshots/1.1.0/02-home.png) | ![Review: weak spots listed by topic](screenshots/1.1.0/04-review.png) | ![Profile: the medal collection](screenshots/1.1.0/08-collection.png) |

</details>

<details>
<summary><strong>Previous version: 1.0.0 screenshots</strong> (submitted to the App Store, September 2026; never released)</summary>

| Results | Question | Review | Home |
|---|---|---|---|
| ![Daily Test results: each answer comes with a one-sentence explanation](screenshots/1.0.0/01-results-explained.png) | ![A Daily Test question: fill in the blank with the correct verb form](screenshots/1.0.0/02-daily-test.png) | ![Review: weak spots listed by topic](screenshots/1.0.0/03-review.png) | ![Home: the Monthly Climb with the avatar on the trail](screenshots/1.0.0/04-home.png) |

| Practice this | Practice results | Welcome badge | Onboarding |
|---|---|---|---|
| ![A weak spot's detail screen with a Practice this button](screenshots/1.0.0/05-practice-this.png) | ![Practice results with the Premium offer card](screenshots/1.0.0/06-results-end.png) | ![The Welcome badge earned after the first Daily Test](screenshots/1.0.0/07-welcome.png) | ![Onboarding: name and learning goal](screenshots/1.0.0/08-onboarding.png) |

</details>

<details>
<summary><strong>v2 screenshots</strong></summary>

| Onboarding | Home (empty) | Daily Test question |
|---|---|---|
| ![Onboarding screen with name and learning goal](screenshots/v2/onboarding.png) | ![Home screen, empty state](screenshots/v2/home_empty.png) | ![Daily Test question](screenshots/v2/daily_test_question.png) |

| Daily Test results | Daily Test results (continued) | Home after use |
|---|---|---|
| ![Daily Test results, correct and skipped answers](screenshots/v2/daily_test_results.png) | ![Daily Test results, continued, showing a needs-work answer](screenshots/v2/daily_test_results_continued.png) | ![Home screen after use, with today's Daily Test result and Topic Practice locked behind Premium](screenshots/v2/home_after_use.png) |

| Premium | Review | Weak spot detail |
|---|---|---|
| ![Premium paywall with feature comparison and pricing](screenshots/v2/premium.png) | ![Review list of weak spots](screenshots/v2/review.png) | ![Weak spot detail for Articles](screenshots/v2/weak_spot_detail.png) |

| Settings | Change avatar | Home (dark) |
|---|---|---|
| ![Settings screen with appearance and profile options](screenshots/v2/settings.png) | ![Change avatar screen, reached from Settings](screenshots/v2/change_avatar.png) | ![Home screen after use, dark mode](screenshots/v2/home_dark.png) |

</details>

<details>
<summary><strong>v1 (MVP) screenshots</strong></summary>

| Home | Length selection | Practice |
|---|---|---|
| ![Home screen](screenshots/v1/mainscr.png) | ![Length selection](screenshots/v1/length.png) | ![Practice question](screenshots/v1/questions.png) |

| Correct answer | Incorrect answer | Skipped answer |
|---|---|---|
| ![Correct result](screenshots/v1/trueanswer.png) | ![Incorrect result](screenshots/v1/falseanswer.png) | ![Skipped result](screenshots/v1/blankanswer.png) |

| Loading state | Review | Weak spot detail |
|---|---|---|
| ![Loading](screenshots/v1/loadscreen.png) | ![Review list](screenshots/v1/reviews.png) | ![Weak spot detail](screenshots/v1/inspectrev.png) |

</details>

## Stack

- **App:** Flutter / Dart, iOS only (iPhone and iPad); local storage in sqflite; no accounts.
- **Server:** a Cloudflare Worker proxy in TypeScript, with KV, in [`proxy/`](proxy/). It owns the models, prompts and token limits and enforces daily quotas; the API key is never in the client.
- **AI:** the Anthropic API. Haiku 5.5 scores answers, with Sonnet 5.5 as the fallback (one constant to swap by hand, not an automatic failover). Sonnet 5.5 generates practice sets and the Daily Test. Opus 5.5 checks each shared set. Evidence for the choice: [measurement report](docs/1.4.0-measurement-report.md).
- **Subscriptions:** RevenueCat.
- **Analytics and crashes:** Firebase Analytics and Crashlytics.

## Docs

- [`docs/roadmap.md`](docs/roadmap.md): current status and what's next
- [`docs/prd.md`](docs/prd.md) (MVP), [`docs/prd-v2.md`](docs/prd-v2.md) (v2), [`docs/prd-gamification.md`](docs/prd-gamification.md) (Monthly Climb)
- [`docs/build-log.md`](docs/build-log.md): dated record of decisions and bugs
- [`docs/1.4.0-plan.md`](docs/1.4.0-plan.md): the 1.4.0 decisions and work list
- [`docs/1.4.0-measurement-report.md`](docs/1.4.0-measurement-report.md): the model measurement
- [`docs/translations/`](docs/translations/): the back-translation reviews, one table per language
- [`docs/analytics-plan.md`](docs/analytics-plan.md): launch events and how to read them
- [`docs/case-study-material.md`](docs/case-study-material.md): sourced raw material behind the case study
- [`docs/development.md`](docs/development.md): local setup, debug defines, visual previews

## Credits

The avatar set is adapted from ["Cute Animal 3D Icons"](https://www.figma.com/community/file/1514963172455082116/cute-animal-3d-icons) by Tran Mau Tri Tam (Figma Community), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); adapted (PNG → WebP, resized).

## About

Built by [Ahmet Emin Tayfur](https://www.linkedin.com/in/ahmettayfur): statistics graduate moving into product management. This repo doubles as a learning-in-public log; process write-up on [Medium](https://medium.com/@ahmet-tayfur).
