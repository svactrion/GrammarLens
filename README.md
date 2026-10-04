# GrammarLens

**An AI-powered grammar coach for people who learned English by speaking it, not by studying it.**

**Status (4 October 2026):** 1.0.0 is in App Store review (resubmitted 28 September 2026); 1.1.0 is a release candidate, not submitted ([roadmap](https://github.com/svactrion/GrammarLens/blob/1.1.0-design/docs/roadmap.md), "1.1.0 — release candidate").

<p>
  <img src="screenshots/1.1.0/01-result.png" width="200" alt="Daily Test result: every answer with a one-sentence explanation">
  <img src="screenshots/1.1.0/04-review.png" width="200" alt="Review: weak spots listed by topic">
  <img src="screenshots/1.1.0/02-home.png" width="200" alt="Home: the avatar on this month's mountain">
  <img src="screenshots/1.1.0/08-collection.png" width="200" alt="Profile: the medal collection">
</p>

*Screenshots: 1.1.0 release candidate, not yet on the App Store.*

## What it does

- **Daily Test** (free): five questions a day, graded on the device, each answer explained. From 1.1.0 everyone gets the same set on a given date.
- **Review**: wrong answers build a personal error profile, shown as weak spots by topic.
- **Topic Practice** (Premium): AI-generated sets on a chosen topic, graded by AI with plain-language feedback. Free users get one short session a day from a weak spot.
- **Monthly Climb**: each Daily Test moves the avatar one step up a monthly mountain; a month's score earns a Bronze, Silver or Gold medal.

## Three decisions, and what each one cost

**1. One shared Daily Test a day instead of one per device**
- **Problem:** 1.0.0 generates a set per device per day, ≈ $0.023–0.028 each (measured tokens, 10 local runs). Daily Test cost grows with every active user.
- **Decision:** 1.1.0 generates one set per date on the server and serves it to everyone; grading stays on the device; a bundled pool of 7 sets covers a failed read.
- **Cost:** a bad set now reaches every user at once (the owner found 4 of 10 questions defective in the first two published sets); a scheduled job and a fallback to maintain; 1.0.0 devices keep their per-device cost until they update.
- **Result so far:** ≈ $0.019 per set (measured, 3 runs), ≈ $0.57 a month at any user count (estimate). Not yet measured with real users.
- **Evidence:** [shared Daily Test report](docs/1.1.0-shared-daily-test.md) §0, §1; [quality report](docs/1.1.0-shared-daily-test-quality.md) §0, §16.7; [build log](docs/build-log.md) 2026-09-26.

**2. Closing a paywall gap with a free quota**
- **Problem:** Review's "Practice this" button had no subscription check, so a free user could start paid-tier practice, bounded only by the 10-a-day cap everyone shared. Found on a device on 15 September 2026; noted and deferred ten days earlier.
- **Decision:** the check moved into the one function every practice set goes through. Free: one Daily Test and one 3-question practice session a day; the session counts only when generation succeeds.
- **Cost:** a free user who uses both every day costs ≈ $1.72–1.86 a month on 1.0.0 (Daily Test part measured, practice part an estimate) and pays nothing. The limit is 1 to cap the cost of each free user and to point anyone who wants more practice to Premium. The quota model will be re-evaluated with four weeks of data.
- **Evidence:** [build log](docs/build-log.md) 2026-09-15; [build log](https://github.com/svactrion/GrammarLens/blob/1.1.0-design/docs/build-log.md) 2026-10-04 (free practice limit: rationale recorded after the fact); [PRD v2](docs/prd-v2.md) §13.7; [roadmap](docs/roadmap.md), "Post-launch tasks".

**3. Known flaw, not fixed: right answers graded as wrong**
- **Problem:** answers are graded by plain text matching. In the owner's review of 35 live questions, 6 had a right or defensible answer marked "Needs work", and it goes into the error profile. Contractions (`'m` / `am`) and spelling variants (`neighbourhood` / `neighborhood`) are not normalized.
- **Done so far:** the fallback pool carries 10 owner corrections. The live daily sets do not; the second-model check that would add accepted answers was deferred past 1.1.0.
- **Cost:** 1.1.0 ships with it. Fixing the live sets (P14) is the first job after 1.1.0, on the server side.
- **Evidence:** [roadmap](https://github.com/svactrion/GrammarLens/blob/1.1.0-design/docs/roadmap.md), "Known flaws shipping in 1.1.0"; [build log](https://github.com/svactrion/GrammarLens/blob/1.1.0-design/docs/build-log.md) 2026-10-04 (P12–P14).

## How it was built

I made the product decisions, set scope and acceptance criteria, and tested on device. The code was written with Claude Code in small batches. The reasoning behind each decision is in [`docs/build-log.md`](docs/build-log.md), dated.

## Case study and writing

- [Case study](https://ahmettayfur.com/products/grammarlens/case-study): the decisions behind the product and what they cost.
- [Medium](https://medium.com/@ahmet-tayfur): process write-ups.

## Version history

| Version | When | What | Status |
|---|---|---|---|
| v1 — MVP | Jul 2026 | One-week sprint, user research, two iterations | Not released |
| v2 | Aug–Sep 2026 | Free/paid split, structure and visual pass, API proxy, subscriptions | Not released |
| 1.0.0 | Sep 2026 | v2 plus Monthly Climb | In App Store review (resubmitted 28 Sep 2026) |
| 1.1.0 | Oct 2026 | Shared Daily Test; mountain themes, medals and collection; launch screen; new avatars; iPad layout | Release candidate, not submitted |

<details>
<summary><strong>1.0.0 screenshots</strong></summary>

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

## Tech & docs

- **App:** Flutter / Dart, iOS only; local storage in sqflite (no accounts).
- **AI:** Anthropic's Claude through an operation-based Cloudflare Workers proxy (`proxy/`). The proxy owns the model, prompts and token limits and enforces daily quotas; the API key is never in the client.
- **Subscriptions:** RevenueCat.
- **Analytics and crashes:** Firebase Analytics and Crashlytics.

**Local setup:** moved to [`docs/development.md`](docs/development.md).

Docs:
- [`docs/development.md`](docs/development.md): local setup, debug defines, visual previews
- [`docs/roadmap.md`](docs/roadmap.md): current status and what's next
- [`docs/build-log.md`](docs/build-log.md): dated record of decisions and bugs
- [`docs/prd.md`](docs/prd.md) (MVP), [`docs/prd-v2.md`](docs/prd-v2.md) (v2), [`docs/prd-gamification.md`](docs/prd-gamification.md) (Monthly Climb)
- [`docs/analytics-plan.md`](docs/analytics-plan.md): launch events and how to read them
- [`docs/case-study-material.md`](docs/case-study-material.md): sourced raw material behind the case study

## Credits

The avatar set is adapted from ["Cute Animal 3D Icons"](https://www.figma.com/community/file/1514963172455082116/cute-animal-3d-icons) by Tran Mau Tri Tam (Figma Community), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); adapted (PNG → WebP, resized).

## About

Built by [Ahmet Emin Tayfur](https://www.linkedin.com/in/ahmettayfur): statistics graduate moving into product management. This repo doubles as a learning-in-public log; process write-up on [Medium](https://medium.com/@ahmet-tayfur).
