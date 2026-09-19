# Analytics plan — Monthly Climb launch

**Status: owner decisions recorded 2026-09-19; implementation follows in
separate commits.** This file was first written the same day as a plan only.
The owner's decisions are folded in below ("Decisions" at the end lists
them). Until the implementation commits land, no analytics code exists for
the new events. Branch: `monthly-climb-v2`, the launch branch (see "Launch
scope" in `docs/roadmap.md`).

Why this file exists: the app ships to the App Store for the first time with
gamification in it, so there is no pre-gamification baseline. Whatever is not
instrumented in the first build cannot be recovered later — there is no
server-side record of what users did, only a local sqlite ledger.

---

## 1. Current state (verified against the code, 2026-09-19)

### Wrapper and initialization

- **One wrapper:** `AnalyticsService` (`lib/services/analytics_service.dart`),
  a thin layer over `FirebaseAnalytics.instance.logEvent`. Every call goes
  through `_logEvent` (`analytics_service.dart:129-137`), which swallows all
  errors, so analytics can never break a feature.
- **One instance:** created in `lib/app.dart:34` and passed down through
  constructors to `HomeScreen`, `FirstLaunchFlow`, `PracticeScreen`,
  `TopicPracticeScreen`, `ResultsScreen`, `ReviewScreen`,
  `WeakSpotDetailScreen`, `PremiumScreen` and `launchPracticeSet`
  (`lib/screens/practice_launch.dart:41`).
- **Initialization:** `_initializeFirebase()` in `lib/main.dart:39-51` calls
  `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
  and wires Crashlytics to `FlutterError.onError` and
  `PlatformDispatcher.instance.onError`, all inside a try/catch. Packages:
  `firebase_core`, `firebase_analytics`, `firebase_crashlytics`
  (`pubspec.yaml:17-19`). iOS only; Firebase project `grammarlens-18d47`.
- **Not used anywhere in `lib/`:** `setUserProperty`, `setUserId`,
  `logScreenView`, `setAnalyticsCollectionEnabled`, any consent/opt-out
  switch. Grep over `lib/` for these returns nothing.

### Events that exist today (9)

| Event | Params | Call site |
|---|---|---|
| `onboarding_completed` | none | `lib/screens/first_launch_flow.dart:71` |
| `mode_selected` | `mode` = `daily_test` / `topic` / `premium` | `lib/screens/home_screen.dart:285`, `:356`, `:405` |
| `session_completed` | `topic_id`, `question_count` | `lib/screens/results_screen.dart:45` (**Topic Practice only**) |
| `free_practice_used` | none | `lib/screens/practice_launch.dart:147` |
| `free_practice_quota_exhausted` | none | `lib/screens/practice_launch.dart:73`, `lib/screens/weak_spot_detail_screen.dart:127` |
| `paywall_viewed` | `source` = `home` / `weak_spot_quota` / `practice_launch` / `onboarding` | `lib/screens/premium_screen.dart:128` |
| `paywall_dismissed` | `source`, `method` = `close_button` / `maybe_later` / `system_back` | `premium_screen.dart:229`, `:270` |
| `purchase_started` | `plan` = `monthly` / `annual` | `premium_screen.dart:176` |
| `purchase_result` | `plan`, `outcome` = `success` / `cancelled` / `error` | `premium_screen.dart:197` |

### Gaps that matter for this plan

1. **Monthly Climb has no events at all.** Daily Test completion, the result
   CTA, the Welcome badge, medal finalization, Profile and text size are all
   uninstrumented (matches `docs/gamification-handoff.md` §8).
2. **`session_completed` is Topic Practice only.** Daily Test completion —
   the action that earns a step — is invisible today. Also, the Day-0
   first-launch flow starts its Daily Test without a `mode_selected`, so
   there is no "started" signal for it; `onboarding_completed` is the nearest
   proxy.
3. **Only "does not throw" is tested.** `test/analytics_service_test.dart`
   asserts each method completes without a Firebase project; nothing checks
   event names or parameters, because `FirebaseAnalytics.instance` is a
   static and cannot be substituted. Adding events without a test seam means
   names/params can drift unnoticed.
4. **`IS_ANALYTICS_ENABLED = false` in the plist — resolved, not a blocker
   (owner, 2026-09-19).** `ios/Runner/GoogleService-Info.plist` carries that
   value, but the owner confirmed in the Firebase console that
   `first_open` and `session_start` are arriving, i.e. Analytics collects.
   The plist field is a stale leftover from when the file was generated and
   does not gate collection for this project. Left as is; do not "fix" it
   by hand, since regenerating the plist is unnecessary churn.
5. **No token/cost logging in the proxy.** `proxy/src/` has no usage or token
   logging (grep for `usage`, `input_tokens`, `console.log` finds nothing),
   consistent with the case-study note that the proxy drops the `usage`
   object. The "free tier cost" guardrail in §5 cannot be measured from
   Firebase or from the proxy as it stands.

---

## 2. Event contract proposal

Conventions (match the existing nine): `snake_case`, no prefix, one wrapper
method per event on `AnalyticsService`, values are strings or integers only.
**Booleans are sent as `0`/`1` integers** — `firebase_analytics` accepts only
`String` and `num` parameter values, and the existing wrapper is typed
`Map<String, Object>`, where a `bool` would compile but not be a supported
value.

### E1 — `daily_test_completed` (priority: must have)

| | |
|---|---|
| Params | `correct_count`, `wrong_count`, `skipped_count` (ints; sum is 5 today, computed rather than assumed), `step_earned` (0/1: at least one non-blank answer), `day0` (0/1: completed inside the first-launch flow) |
| Fired | In `DailyTestResultScreen._saveCompletion` (`lib/screens/daily_test_result_screen.dart:67-90`), **after** `completeDailyTest` succeeds, and only when the set was not already completed. A failed save that is retried yields one event; reopening a finished result yields none. |
| Answers | Is the daily habit forming (events/user/week)? What share of tests earn no step (all-skipped)? Does a first-ever (Day-0) test behave differently from later ones? Is scoring "favoring habit over accuracy" (`prd-gamification.md` §M6.1) showing up as a real accuracy spread? |

### E2 — `results_cta_tapped` — DROPPED (owner decision, 2026-09-19)

The reasoning below is kept as the record of why. Not implemented.

| | |
|---|---|
| Params | `cta` = `see_climb` / `back_home`, `revisit` (0/1: the result was reopened from Home, not a fresh completion) |
| Fired | (not built) The result screen's single `FilledButton` (`daily_test_result_screen.dart:135-149`). |
| Answers | (not measured) Of tests that earned a step, how many leave through the "See your climb" button. |

Honest assessment: this is **one button whose label depends on state**
(`step > 0` and not already completed → "See your climb", otherwise "Back to
Home"); the user does not choose between two CTAs, and both labels just pop
the route. So `cta` is mostly a function of `step_earned` and `revisit`, and
the event mainly measures "tapped the button" versus "left another way"
(back arrow; `BrandScaffold` implies one by default — whether it renders on
this route was not verified). Recommendation: **cheap to add, low decision
value; keep only if back-navigation exits are also captured** (a `PopScope`
observer like the one `PremiumScreen` already uses), otherwise drop it and
read the climb's effect from E1 plus retention.

### E3 — `welcome_badge_earned` (priority: must have)

| | |
|---|---|
| Params | `rule_version` (int, `WelcomeBadgeRules.ruleVersion`), `day_of_month` (int 1–31), `days_in_month` (int 28–31) |
| Fired | Where `welcomeBadgeJustEarned` is true (`daily_test_result_screen.dart:75-85`) — the live earn only. |
| Answers | How many first-time users hit the badge, and how late in the month they were. Together with §3 this is the data the Welcome assumption (`prd-gamification.md` §M6.5) needs. |

**Recommendation: do not add a `source` = live/backfill parameter.** The
backfill exists only in the v17→v18 migration (`lib/services/storage_service.dart`,
the `oldVersion < 18` block near line 388). `main` was never shipped, so no
production device can hold pre-existing ledger rows; every real install
starts at the latest schema and earns the badge live. The backfill can only
run on developer devices. A `source` param would always be `live` in
production and adds a parameter (and a place to make mistakes) for nothing.
Log the live earn only, and do not log from the migration.

### E4 — `medal_month_finalized` (priority: must have)

| | |
|---|---|
| Params | `tier` = `none` / `bronze` / `silver` / `gold`, `score_pct` (int 0–100, score ÷ month maximum, rounded), `active_days` (int), `days_in_month` (int), `rule_version` (int, `MonthlyMedalRules.ruleVersion`), `months_ago` (int: how many months back the finalized month was when finalization ran) |
| Fired | Once per newly finalized month, from the path that calls `StorageService.finalizePastMedalMonths()` (`lib/screens/settings_screen.dart:142-151`). |
| Answers | Tier distribution; how close users land to the 25/50/75 % thresholds (validates rule v1); whether finalization is late. |

**Decision (owner, 2026-09-19): finalization runs at app launch and on
resume from background, in addition to Profile.** The first version of this
plan noted that finalization was lazy (Profile only), so E4 would miss users
who never open Profile. That is now addressed:

- `StorageService.finalizePastMedalMonths` returns the months it newly
  finalized (it returned `void`), so each one can be reported.
- It is called at launch, on `AppLifecycleState.resumed`, and still from
  Profile. It must stay idempotent: the "already finalized" check and the
  inserts happen inside one transaction, sqflite serializes transactions, so
  a second concurrent call finds nothing left to finalize. A month is
  therefore finalized once and `medal_month_finalized` fires once for it,
  whichever trigger got there first.
- `months_ago` still distinguishes late finalizations (a user who did not
  open the app for several months).

### E5 — `profile_medals_viewed` (priority: nice to have)

| | |
|---|---|
| Params | `finalized_months` (int), `medals_earned` (int: finalized months with tier ≠ `none`), `welcome_earned` (0/1) |
| Fired | When Profile's medal data finishes loading successfully (`settings_screen.dart:130`, `:138`), **at most once per app session**. Profile loads on mount *and* on every tab re-entry, so an unguarded event would count tab bouncing, not interest. |
| Answers | Do users look at the collection, and is looking associated with retention? |

Caveat: with `finalized_months = 0` (every user in their first month) this
event only says "opened Profile". Its value grows after the first month-end.

### E6 — `text_size_changed` (priority: nice to have)

| | |
|---|---|
| Params | `size` = `small` / `medium` / `large`, `previous` = same set |
| Fired | `_setTextSize` in `lib/app.dart:118`, only when the value actually changes. |
| Answers | Is Medium (1.10×) the right default? The direction of change is the signal: many Medium→Large means the default is too small; many Medium→Small means it is too big. |

### Events considered and not proposed

- **`climb_step_earned`** — redundant with E1's `step_earned`.
- **A separate "mountain viewed" / animation-played event** — the animation
  is a presentation detail; whether the climb matters shows up in E1 volume
  and retention. Revisit only if the climb looks ignored in that data.
- **A per-medal-tier "unlocked" event** — E4 already carries the tier.
- **Daily Test generation success/failure** — a reliability signal, not a
  gamification one; belongs in a separate reliability pass (Crashlytics
  already records fatal errors).
- **Renaming `session_completed` to `practice_completed`** — it is easily
  confused with `daily_test_completed`. **Decided 2026-09-19: rename it.**
  Nothing has shipped, so no dashboards or historical data are affected;
  after launch it would cost a broken time series.

### Events that already cover the guardrails (no change proposed)

`paywall_viewed` → `purchase_started` → `purchase_result` already give the
paywall funnel by `source` and `plan` (§5).

---

## 3. User properties (approved 2026-09-19)

| Property | Value | Set when |
|---|---|---|
| `first_step_dom` | Day of month (`"1"`–`"31"`) on which the user earned their first ever step | Exactly once, at the moment E3 fires (`welcomeBadgeJustEarned`) |
| `text_size` | `small` / `medium` / `large` | At startup after the stored value is loaded, and on each change (E6) |

`first_step_dom` is what makes the Welcome assumption testable: the
hypothesis is that a badge on day one helps **mid-month starters** — the
users the no-proration monthly-medal design otherwise leaves with nothing
(`prd-gamification.md` §M6.5). Without the start day, a D7 comparison cannot
separate "started on the 2nd" from "started on the 24th".

Why it cannot be recovered later:

- User properties apply to events logged **after** they are set; setting one
  later does not back-fill earlier events or earlier cohorts.
- To break a report down by it, it must be registered as a **user-scoped
  custom dimension** in the Analytics property, and registration is also not
  retroactive. Register it before launch.
- The ledger has the date locally, but there is no server, so the value can
  only reach Firebase if the app sends it.

Rules for it: set only when the Welcome badge is earned live (the badge table
already guarantees "once"); never overwrite; derived from the device's local
calendar date (the same authority the ledger uses). A reinstall creates a new
Firebase app instance and a new first step, which is correct.

`first_step_dom` lacks the month length. Late-month starts are the interest,
and E3 carries `days_in_month`, so no combined value is needed. If a single
comparable number is wanted, `first_step_dom` alone is sufficient for the
first four weeks.

---

## 4. Privacy rules

**Never sent, in any event or user property:** question text, answer text,
correct answers, the user's name, learning goal, age, occupation, avatar,
any device identifier of our own (`getOrCreateDeviceId` is the proxy's
quota key and stays out of Firebase), and free text of any kind.

**Allowed:** counts, tiers, percentages, rule versions, day-of-month, and
fixed-vocabulary strings. Every string value in §2/§3 comes from a closed
enum (`tier`, `cta`, `size`, `previous`), so nothing user-typed can leak
through a parameter. Existing `topic_id` is a topic enum name, also closed.

**Enforcement to build in when coding (after approval):** the wrapper takes
typed arguments only, never a `Map` from a caller; one unit test asserts the
exact param key set of each event, so an added parameter fails a test rather
than shipping silently. This is also the missing test seam noted in §1.3.

### Firebase limits check

Limits below are from Google Analytics help
(<https://support.google.com/analytics/answer/9267744>), fetched
2026-09-19. Proposed names were checked with a script.

| Limit | Value | This plan |
|---|---|---|
| Event name length | 40 chars | Longest is `medal_month_finalized`, 21 |
| Event name charset | Letter first; letters, digits, underscore | Pass |
| Reserved prefixes (`firebase_`, `google_`, `ga_`) and reserved names | Not allowed | None used. Note the existing `purchase_started`/`purchase_result` do not collide with GA's recommended `purchase` |
| Parameters per event | 25 | Max is 6 (E4) |
| Parameter name length | 40 chars | Pass |
| Parameter value length | 100 chars | All values are short enums/ints |
| User properties | 25 max; name ≤ 24 chars; value ≤ 36 chars | 2 properties; names 14 and 9 chars; values ≤ 6 chars |
| Distinct events per app | 500 | 9 existing + 6 proposed = 15 |

Not verified from the fetched page (check in the console before relying on
them): the number of custom dimensions and metrics allowed on a standard
property, and the exact reserved-name list. Practical consequence to plan
for: event parameters and user properties appear in Firebase/GA4 reports
**only after being registered as custom dimensions/metrics**; unregistered
ones still appear in DebugView and in a BigQuery export. Registration also
starts collecting from registration time, so do it before launch.

### Other privacy points

- The onboarding privacy note ("data stays on-device, never sent to a
  server") is already recorded as a submission blocker in `docs/roadmap.md`.
  Adding events makes that fix more important, not less, and the App Store
  "App Privacy" answers must cover Firebase Analytics (usage data and a
  device/app-instance identifier) and Crashlytics.
- `IS_ADS_ENABLED` is `false` in the plist. Whether the iOS Analytics pod
  includes IDFA support (which would trigger an ATT question) was not
  checked here; confirm before submission.
- There is no in-app analytics opt-out. Not required by anything in this
  plan; noted so it is a decision rather than an omission.

---

## 5. Measurement plan — approved 2026-09-19

**Primary metric: D7 retention**, from Firebase's own Retention report
(cohorts by first open). Note what Firebase counts: a user is "retained" if
they open the app and engage on day 7, **not** if they take a Daily Test.
That is right for a headline number and wrong for "did the climb work", which
is why E1 exists.

**Guardrail metrics:**

1. **Paywall conversion** — `paywall_viewed` → `purchase_started` →
   `purchase_result` (`outcome = success`), by `source` and `plan`; trial
   start → paid conversion from RevenueCat, which Firebase cannot see.
2. **Free-tier cost** — see below; not measurable today.

**No baseline.** The product ships with gamification from day one, so there
is no before/after. Therefore:

- **The first 4 weeks are observation only.** No thresholds, no success or
  failure calls, no rollback criteria are written now. Thresholds are set
  from that data, after it exists. (This supersedes `prd-gamification.md`
  §9.2–9.4's baseline-comparison design, which assumed a pre-gamification
  baseline; the old §9 is weekly-era text.)
- Comparisons that are possible are **internal and observational**: cohorts
  by `first_step_dom`, by whether a step was earned on day 0 (`day0`), by
  `text_size`. They are confounded by who chooses to engage; they describe,
  they do not prove.
- **The Welcome badge stays an explicit assumption**, unmeasured until then.
  A controlled test (badge on/off) would need an experiment mechanism the app
  does not have (no Remote Config / A/B dependency in `pubspec.yaml`) and
  enough traffic to detect a difference. Later option, not proposed for
  launch.

**Observation window (approved): at least 4 weeks, and at least one week past
the first month-end** — whichever is later. E4 fires only after a month
closes; if launch lands mid-month, the first month-end can fall after four
weeks, so the window must extend to include it.

Constraints to keep in mind while reading the data:
- **Small cohorts.** A first release from a solo developer will have small
  D7 cohorts; Firebase may show limited data for small cohorts. Do not read
  a percentage without its user count.
- **Cost guardrail signal (approved for launch):** the Anthropic console's
  aggregate spend plus Cloudflare's per-Worker request counts. This is a
  rough total, not a per-user or per-tier figure — the proxy does not log
  tokens (§1.5) and Firebase cannot derive cost. **Operation-level usage
  logging in the proxy is deferred to after launch.**

Measurement table (thresholds intentionally blank until the observation window ends):

| Metric | Source | Threshold |
|---|---|---|
| D7 retention (primary) | Firebase Retention | set after week 4 |
| Paywall view → purchase_started → success | Firebase events, RevenueCat | set after week 4 |
| Free-tier cost (rough total) | Anthropic console spend, Cloudflare request counts | set after week 4 |
| Welcome-badge assumption | E3, `first_step_dom`, D7 by cohort | descriptive only |

---

## 6. Verifying events on a physical iPhone with DebugView

Bundle id: `com.ahmettayfur.grammarlens`. Replace `<DEVICE>` with the name or
UDID from step 1.

**Every device command here uses `config/prod.json`.** `config/dev.json`
points `PROXY_BASE_URL` at `localhost`, which on a physical device means the
device itself, so every proxy call would fail; and `scripts/dev.sh` is
simulator-only for the same reason (README, Local setup, "Physical device").
A device run therefore talks to the real proxy and the real Firebase project:
use only your own test device, expect real (small) generation cost, and rely
on DebugView's debug flag plus a developer-traffic filter to keep test events
out of reports.

**Step 0 — Analytics is already collecting (owner, 2026-09-19).**
`first_open` and `session_start` are visible in the Firebase console
(`grammarlens-18d47`), so nothing needs enabling. The
`IS_ANALYTICS_ENABLED = false` value in `GoogleService-Info.plist` is a stale
field and does not block collection (§1.4); do not regenerate the plist for
it.

**Step 1 — find the device.**

```bash
xcrun devicectl list devices
```

**Step 2 — turn on debug mode for the app (one time).** `flutter run` cannot
pass iOS launch arguments, so pass them with `devicectl` against an installed
non-debug build (debug Flutter builds cannot be launched from the home screen
on iOS 14+):

```bash
flutter build ios --profile --dart-define-from-file=config/prod.json
```

```bash
xcrun devicectl device install app --device <DEVICE> build/ios/iphoneos/Runner.app
```

```bash
xcrun devicectl device process launch --device <DEVICE> --terminate-existing com.ahmettayfur.grammarlens -FIRAnalyticsDebugEnabled -FIRDebugEnabled
```

The two flags are both passed on purpose. The Firebase DebugView page as
fetched on 2026-09-19 names `-FIRDebugEnabled` (disable: `-FIRDebugDisabled`);
the flag long documented for Analytics debug mode is
`-FIRAnalyticsDebugEnabled` (disable: `-FIRAnalyticsDebugDisabled`). I could
not reconcile the two from the fetched text, so pass both; extra launch
arguments are harmless, and DebugView showing the device is the actual proof.
Per the same page, the setting **persists across launches** until the
disable argument is passed.

Alternative for the same one-time step: open `ios/Runner.xcworkspace`, Product
→ Scheme → Edit Scheme → Run → Arguments → add the flag(s), and run once
from Xcode on the device. Xcode runs do not pass `--dart-define` values
(README's Local setup section), so the app will not reach the proxy in that
run; that does not matter for a one-time flag-setting launch.

**Step 3 — day-to-day runs.** With the flag persisted, use the README's
physical-device command (not `scripts/dev.sh`):

```bash
flutter run --dart-define-from-file=config/prod.json -d <DEVICE>
```

**Step 4 — watch events.** Firebase console → Analytics → DebugView, pick the
device in the top-left selector. Events appear within seconds, with
parameters expanded. Walk the checklist: complete a Daily Test (E1; also check
a fresh-install first test for `day0 = 1` and E3 + the `first_step_dom` user
property), open Profile (E5), change text size (E6; also the `text_size`
user property). Launch and resume the app to see E4 trigger (below). E4 needs a past month in the ledger; use a seeded/controlled-clock
database, since a real month rollover is impractical. Confirm it fires once
per month across a launch followed by a resume.

**Step 5 — turn debug mode off when finished.**

```bash
xcrun devicectl device process launch --device <DEVICE> --terminate-existing com.ahmettayfur.grammarlens -FIRAnalyticsDebugDisabled -FIRDebugDisabled
```

Caveats: events sent in debug mode are included in the daily BigQuery export
by default, so configure a developer-traffic data filter in the Analytics
property before relying on exported data. Console log lines are not a substitute: DebugView is the authority.

---

## 7. Case study

A case-study document **exists**: `docs/Claude outputs/grammarlens-case-study-kaynak.md`
(915 lines, Turkish, titled "Case Study Ham Kaynak" — a raw source file,
extracted 2026-09-12, that lists every claim with its repo source and marks
unrecorded facts `[kayıtta yok]`). `README.md` also carries a "Personal
product case study" framing, and the public Medium write-up lives outside
the repo. It predates the Monthly Climb work, so these parts are stale or
will become stale. **Not edited in this step.**

| Location (line numbers as of this commit) | What to update |
|---|---|
| Header, lines 3-6 | Source list and extraction date (2026-09-12). Add `roadmap.md` "Launch scope", `gamification-handoff.md`, `prd-gamification.md` §M6, and this file. |
| §1.4 table, line 92 (Gamification row) | Says gamification was a Weekly Climb draft, "not approved". Now: monthly cycle, approved rule v1, implemented, and in launch scope. |
| §2.1 "Launch sıralaması tersine çevrildi", lines 136-143 | Its reasoning ("launch before unproven mechanics, to get a real retention signal") is now partly reversed: gamification launches *with* the app. Needs a dated entry that records the reversal and its reason (the branch merges to `main`; `main` was never shipped). |
| §3.3 item 9, lines 440-442 | "Gamification as a layer on Daily Test, not a third mode" still holds; add that the layer is monthly and ledger-based. |
| §5.1, lines 604-609 (gamification measurement) | Describes the weekly-era plan "against a D1/D7 baseline". Replace with the no-baseline, 4-week-observation design in §5 above, and record the Welcome badge as an unmeasured assumption. |
| §5.2, lines 611-640 | "Firebase: code scaffold exists, no project" is out of date (connected 2026-09-13); "no measured product metric" changes once launched; add that Monthly Climb events were planned before launch. |
| §7.2, lines 817-830 ("would do differently") | Item 1 ("measurement should have been set up first") is evidence for this plan; record whether the analytics batch landed before or after the first build. |
| Timeline, §6 (lines 698-766) | Nothing after 2026-09-12 (Monthly Climb, launch-scope change on 2026-09-19). |
| Appendix, lines 898+ | Test count (237) is far out of date (469 now). Add climb/medal numbers only once measured. |

If a durable, non-"raw" version is wanted, keep `docs/case-study.md` (English,
per the repo language rule) as the publishable text and leave the Turkish
`…-kaynak.md` as its evidence file; that split is a suggestion, not something
this step creates.

---

## Decisions (owner, 2026-09-19)

1. **Events approved:** E1 `daily_test_completed`, E3 `welcome_badge_earned`,
   E4 `medal_month_finalized`, E5 `profile_medals_viewed`, E6
   `text_size_changed`. **E2 `results_cta_tapped` dropped** (one state-driven
   button, low decision value; §2).
2. **User properties approved:** `first_step_dom`, `text_size` (§3).
3. **Analytics is working** — `first_open` and `session_start` are visible in
   the Firebase console; `IS_ANALYTICS_ENABLED = false` in the plist is a
   stale field, not a blocker (§1.4, §6 step 0).
4. **`session_completed` renamed to `practice_completed`** — nothing has
   shipped, so no data or dashboards are affected.
5. **Cost signal for launch:** Anthropic console spend and Cloudflare request
   counts. Proxy usage logging deferred until after launch (§5).
6. **Measurement plan approved** (§5), with an observation window of at least
   4 weeks and at least one week past the first month-end.
7. **Finalization timing:** `finalizePastMedalMonths` also runs at app launch
   and on resume, stays idempotent, so E4 counts users who never open Profile
   (§2, E4).
8. **Device commands corrected** to `config/prod.json` (§6).

Implementation status is tracked in the next batch of commits on this branch;
this section is updated when it lands.
