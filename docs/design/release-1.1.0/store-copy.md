# 1.1.0 store copy — draft

**Draft, 2026-10-04.** Nothing here is in App Store Connect. The final
text is Ahmet's. Written on `1.1.0-design` at `1.1.0+4`.

Character limits below are App Store Connect's as I remember them
(What's New 4,000, promotional text 170, description 4,000, keywords 100);
**not checked against Apple's current page here, so confirm them in the
form.** The counts next to each draft were measured on the text as
written in this file.

## 1. 1.0.0's store text in the repository

**Not in the repository.** The description, promotional text, keywords
and subtitle were entered in App Store Connect before the 2026-09-24
submission (build-log 2026-09-24, "listing text"), but the text itself was
never committed. The only trace is a paraphrase in `roadmap.md` (the
2026-09-24 "Daily Test explains every answer" entry): the description says
that you see why each answer was right or wrong. The proposals in §3 are
therefore written as additions and replacements to check against the live
text, not as a diff of it.

Worth copying the live 1.0.0 text into this file before editing it, so
the next release has a record.

## 2. What's New in 1.1.0

Only what ships in 1.1.0 (`roadmap.md`, "1.1.0 — release candidate").
Words avoided on purpose: no streak or daily-chain wording (the app has
no streak); no "personalized" Daily Test (it is the same set for
everyone); no medal promised every month (a tier is earned with points);
no "compete" or "together" (there is no social feature: the shared set is
the same questions, nothing is compared between users).

**When this applies:** only if 1.0.0 is approved and released first
(path 1 in `roadmap.md`, "1.0.0's state and the submission path"). If the
1.0.0 submission is withdrawn and the version becomes 1.1.0 (path 2),
1.1.0 is the app's first version and App Store Connect does not ask for
What's New text; the description (§3) carries the new features instead.

### Short (219 characters)

> Meet the Mountain of Learning: climb a new illustrated mountain each
> month, pass save points on the trail and collect medals in your
> Profile. Everyone now gets the same Daily Test each day. Plus a better
> layout on iPad.

### Longer (762 characters, line breaks counted as one)

> What's new in 1.1.0
>
> • Mountain of Learning: your monthly climb has a new look. Four
> illustrated mountains take turns, one each month, in light and dark
> mode.
> • Save points: pass First Camp, Halfway Hut, Mountain Spring and High
> Camp on your way to the Summit.
> • Medals and your collection: each month's Bronze, Silver and Gold
> medals match that month's mountain. Reach a new tier and it's
> celebrated; every medal you earn is kept in your Profile.
> • Month summary: when a new month starts, a card sums up the last one.
> • One Daily Test for everyone: each day, every learner gets the same
> five questions, still with an explanation for every answer.
> • iPad: the app now uses a centred layout on iPad.
> • Also: a new launch screen, four new avatars, and small fixes.

Notes on the claims, for checking:

- "a new illustrated mountain each month": four themes rotate (Green
  Slope, Ember Peak, Glacier Peak, Red Canyon), so the fifth month repeats
  the first. Same wording as screenshot caption 2, which Ahmet approved
  (P7). The longer draft says "four … take turns" to be exact.
- "light and dark mode": every theme has a light and a dark image
  (Batch 4).
- "every learner gets the same five questions": the shared set; if it
  cannot be read, a bundled set is shown instead, so on such a day a user
  may see different questions. The pool currently has 0 sets, which
  makes the fallback the day-0 questions (release checklist).
- "still with an explanation for every answer": shared sets carry one
  explanation per question (`proxy/src/shared_daily_test.ts`); the
  day-0 set has hand-written ones.
- "iPad": iPad was supported in 1.0.0 with a stretched layout; 1.1.0 caps
  the content at 640 pt (P1, P2).
- "small fixes": the Home greeting at 320 pt; nothing else user-visible is
  claimed.

## 3. Description and promotional text — proposed changes

### Promotional text (138 characters)

Promotional text can be changed without a new build.

> New in 1.1.0: climb a new illustrated mountain each month, pass save
> points along the way and collect medals in your Profile's collection.

### Description: a section to add

To place after the Daily Test and Topic Practice paragraphs of the live
text (I cannot see the live text's headings, so match its style):

> MOUNTAIN OF LEARNING
> Every Daily Test you finish moves your avatar one step up this month's
> mountain. Four illustrated mountains take turns, one each month. Pass
> save points on the way to the Summit, and earn a Bronze, Silver or Gold
> medal as your month's score grows. When a new month starts, a card sums
> up the last one, and every medal you earn stays in your Profile's
> collection.

### Description: lines to check in the live text

- **Anything that says the Daily Test is generated for you or made
  personally for you.** From 1.1.0 every user gets the same set on a date.
  (1.0.0's per-device set was not personalized either: the request sent
  only a device id and a count, `509f94d`
  `lib/services/claude_service.dart`. But "generated for you" would now
  be wrong on its face.) Suggested line: "Five new questions every day,
  the same for every learner, each with a short explanation."
- **"Monthly Climb"**, if the live text uses that name: on screen it is
  now "Mountain of Learning".
- **iPad**: if the text says nothing about iPad, nothing needs adding.
- Unchanged and still true: the explanation for every answer; Topic
  Practice as Premium; no account; plans and prices from the store.

### Keywords

Not proposed: the live keyword list is not in the repository, and
changing it without seeing it would be guesswork. Candidates if there is
room within the 100 characters: "medals", "monthly challenge". Not
"streak".

## 4. App Privacy answers

**Conclusion: no change to the App Privacy answers is needed for 1.1.0**,
on the code and `analytics-plan.md`. The 1.0.0 answers themselves are not
in the repository (build-log 2026-09-24: "the privacy questionnaire
(published)"), so this compares the data flows, not the answers. Ahmet
should still open the questionnaire and confirm it matches the list
below.

What I compared, between 1.0.0's build commit `509f94d` (`1.0.0+3`) and
`1.1.0-design` now:

- **SDKs:** no new runtime dependency in `pubspec.yaml`. The only new
  package is `flutter_driver`, a dev dependency for screenshot capture
  that is not in a release build. `ios/Runner/Info.plist` is unchanged.
  Firebase Analytics, Crashlytics and RevenueCat are the same packages
  as in 1.0.0.
- **Network: the Daily Test now sends less.** 1.0.0 posted the anonymous
  device id and a question count to `/v1/generate-daily-test`. 1.1.0
  reads `GET /v1/shared-daily-test/{date}` with only the date and the app
  token: no device id, nothing about the user
  (`lib/services/claude_service.dart`). Topic Practice's requests are
  unchanged.
- **Analytics: new events and parameters, same data type.** 1.1.0 adds
  `month_card_shown`, `month_card_dismissed`, `month_zoom_ended`,
  `save_point_reached`, `medal_tier_reached`, and the parameters
  `set_date`, `theme_id`, `variant`, `medal_tier`, `near_miss_shown`,
  `trigger`, `save_point`, `step`, `open_ms`. Every value is a count, a
  date, a duration or a closed enum (`analytics-plan.md` §4's rule; the
  exact key sets are tested in `test/analytics_service_test.dart`). They
  are usage data about in-app interaction, the type Firebase Analytics
  already covered in 1.0.0. No user property is added (still
  `first_step_dom` and `text_size`). No name, answer text or free text.
- **Crashlytics:** 1.1.0 buffers errors raised before Firebase is ready
  and reports them once it is (`lib/utils/early_error_reporting.dart`):
  more complete crash data of the same type, not a new type.
- **Local only:** themes, medals, save points and the month card's
  "seen" records stay in the on-device database.

Not checked here: what the published privacy policy
(https://ahmettayfur.com/products/grammarlens/privacy/) says word for
word; it is not in the repository. If it lists the Daily Test request
with the device id, it is still true as an upper bound for 1.0.0 users;
an optional edit could say the 1.1.0 Daily Test sends no device id.
