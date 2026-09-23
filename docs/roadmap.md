# GrammarLens — Roadmap & Status

## Launch scope — 2026-09-19

**Plan change:** `monthly-climb-v2` will be merged to `main`, and the app goes
to the App Store for the **first time** with this branch's content. `main` was
never shipped, so gamification is part of launch, not a post-launch add-on.
This branch is the launch branch. The merge (or PR) still happens only on the
owner's explicit approval; nothing here authorises it.

Status words below are literal: "implemented" means code and automated tests
exist; "device-confirmed" means the owner confirmed it on a physical phone.
Nothing is marked complete unless the record says so.

### In scope (launch)

| Item | Why it is in | Status |
|---|---|---|
| Monthly Climb: ledger, Home mountain, Results `See your climb` / `Back to Home` CTA | It is the whole engagement layer; without it the release has no gamification, and the ledger is the data every other item reads. | Implemented. CTA (package 1) and Home scrolling (package 2) device-confirmed; a full launch acceptance pass is still open. |
| Monthly medals + Profile collection (rule v1, frozen history) | Gives a month a payoff and the collection a reason to exist; rule v1 is already approved and versioned. | Implemented. Locked-shell device-confirmed; `In progress` card, finalized history and the v17 migration are **not** device-confirmed. |
| Welcome badge (first `step = 1` ledger row) | Cheap day-one reward for a first-ever user; kept as an explicit hypothesis to measure, not a proven driver. | Implemented, automated tests only. No device confirmation recorded. Since 2026-09-22 the celebration is a large card under the results, and the confetti plays when the user taps "Start my climb" (automated tests only, not device-confirmed). |
| Text size setting (Small / Medium / Large) | Medium (1.10×) is now the default for everyone, so the choice has to ship with the default. | Implemented (schema v16). Device review pending. |
| Premium fixes 4a–4c (plan-card frames, stable contextual entry, separated avatars) | The paywall is the launch's revenue surface and the first subscriptions go out with this version. | 4a–4c device-confirmed. Comparison-table overflow at 320 px / 2× text: fixed 2026-09-21 with a stacked layout (see the launch-checklist note below); automated tests only, **not device-confirmed**. |
| Analytics events for Monthly Climb | First release has no baseline; events that are not in the first build cannot be recovered afterwards. | Implemented (E1, E3–E8; E2 dropped by decision), automated tests only: `docs/analytics-plan.md` §8. Open: the physical-device DebugView run (moved to the TestFlight pre-submission checklist, "What's next" §1) and the owner's custom-dimension registration (§9). |

### Out of scope (after launch, on a separate design branch)

| Item | Why it waits |
|---|---|
| Mountain geometry redesign (broad-to-narrow, steeper summit, landmark placement, viewpoint contrast) | Current route and landmarks work; this is a visual improvement and needs its own 28/29/30/31-day, theme and text-size verification. |
| Mountain themes and calendar rotation | Only Green Slope is approved; the sequence was never decided, and a volcano theme was never approved. |
| Final medal artwork | The tier visuals work as they are; final art is polish, and swapping it later does not change stored data. |
| Medal shortcut on Home | Profile is reachable from the tab bar, and the shortcut is still an open product decision. |
| v3 Home redesign | No scope is written yet; redesigning Home right before first release adds risk without a measured problem. |
| Shared Daily Test: the daily question set is generated once per day and shown identically to every user, instead of once per user | **Why it is worth considering:** as users grow, Daily Test generation cost stops scaling with them (one generation per day, not one per device per day), and opening the test gets faster (no per-user generation wait). **Trade-offs to accept:** (1) personalization is lost: a shared set cannot be chosen by an error profile (the per-device set was biased toward the device's own weak spots, PRD v2 §12.8, until 2026-09-21, when that was removed ahead of this change, §13.12); (2) the proxy needs scheduled generation and storage of the day's set, which is a new source of failure, so a fallback is mandatory (for example, a last good set or on-device generation when the shared set is missing); (3) a time-zone rule must be decided (one global "day", or per region), since "today" is a local calendar day in the app now. **Why not before launch:** there are no users today, so there is no saving to capture; and it is better decided after the proxy token-log data (PRD v2 §13.10) shows what a Daily Test really costs. |
| Turkish UI copy (localization) | Recorded 2026-09-23 while adding the practice results Premium prompt, whose copy was wanted in both English and Turkish. The app has no localization setup (no `flutter_localizations`, `intl` or l10n files); every string is English in the widget code. Adding Turkish means setting that up and moving all copy into it, a separate project, not a string edit. Nothing is scheduled. |
| Theme setting as a single toggle button (instead of the System / Light / Dark segmented control) | Not planned, idea only (recorded 2026-09-21). The three-way control is shipped, tested and device-reviewed; a toggle would drop the explicit "System" choice or need a long-press or cycle to keep it, which is a product decision, not a polish item. Nothing is scheduled. |

### Post-launch tasks

- **Delete `~/GrammarLens-backup.git` one week after launch.** It is the
  full mirror taken before the 2026-09-17 history rewrite and still contains
  personal data (it also holds the deleted `codex/monthly-climb`). Never push
  it anywhere.
- **Premium comparison table does not show the daily session limit
  difference**, while the results-screen offer card promises "more daily
  sessions". Adding a row pushes plan cards below the fold at 375x667
  (measured 2026-09-23). Fix by shortening or restructuring the table, not by
  appending a row.
- **Daily Test sets repeat the same topics and scenarios across days and
  users** (observed 2026-09-24 across 5 sampled generations: 'admit',
  'needn't have looked', 'train had already left' recurred). Same prompt for
  everyone is the cause. Revisit together with shared Daily Test generation,
  where day-to-day variety becomes the main concern.

Launch blockers unrelated to gamification (false onboarding privacy note,
App Review assets for the subscription products, expiry/restore and non-USD
checks) stay in "What's next" §1, Pre-launch checklist.

**Launch checklist, code items — 2026-09-21.** Progress is recorded per item
as each one lands, with literal status words (see above):

- **Session cap 10 → 5 — implemented, automated tests only.**
  `StorageService.dailySessionLimit` is 5. This is a margin decision: at
  ~$0.034/session (an unmeasured estimate, PRD v2 §13.7), 10 sessions/day is
  ~$10.20/month against ~$3.54/month of net annual-plan revenue. It also
  closes the proxy-headroom conflict: 5 sessions = 10 proxy units + 1 Daily
  Test unit, inside `DEVICE_DAILY_LIMIT` = 15, which is unchanged. The only
  user-facing quota text is the "That's all for today" dialog, which reads the
  constant. Premium's comparison table states no session quota, and no string
  in `lib/` says "unlimited" (a test asserts this on the Premium screen).
  The App Store Connect subscription descriptions are outside this repo and
  were not re-checked here.
- **Developer/debug tools out of release builds — implemented, automated
  tests plus a release web-build check; not verified on an iOS release
  build.** Scan result: four tools in Settings' "Developer" section
  (entitlement override, first-launch reset, pricing fixture toggle, theme
  preview), the raw error text on Daily Test's load-failure screen, the
  launch-time load of the stored override in `app.dart`, and two standalone
  preview entry points in `lib/preview/` (Monthly Climb, medals; run only with
  `flutter run -t`, imported by no app code, each throws outside debug).
  All UI was already behind `kDebugMode`. Gaps closed: the subscription
  service's gate was a mutable static, not a compile-time constant; and
  `StorageService.resetOnboarding()` (deletes the profile) plus the override
  read/write had no guard of their own. Everything now goes through one
  switch, `DebugTools` (`kDebugMode && DebugTools.enabledForTesting` at each
  gate, so a release build folds it to `false`); tests simulate release with
  it, and one flag turns every tool off. Text size is a real feature and was
  not touched. Checked by building `flutter build web --release`: none of the
  tool strings appear in the compiled output. Not removable without a schema
  change: the empty `debug_settings` table is still created (nothing reads it
  in release). The iOS release build was broken on this machine by the Xcode
  27 `lipo` issue at the time, so the AOT binary itself was not inspected.
  *(Update 2026-09-23: the `lipo` blocker is resolved and a release IPA now
  builds; the AOT binary has still not been inspected for tool strings.)*
- **Profile: age and occupation removed — implemented, automated tests
  only.** Scan before removal: the two fields were used only by the Profile
  form, `UserProfile` and the `user_profile` table; not by prompt generation,
  any request body to the proxy, analytics, Home or Premium, so no
  personalization was lost. Removed from UI, model, storage and tests. Schema
  v19 rebuilds `user_profile` without the columns (not `DROP COLUMN`, which
  needs SQLite 3.35+) and deletes every stored value; name, learning goal and
  avatar survive, and a replayed migration is a no-op. Onboarding never asked
  for them, its privacy note does not mention them, and the published privacy
  policy never listed them (its only age wording is the 13+ audience
  statement). PRD v2 §13.11.
- **Onboarding privacy note — corrected, automated tests only.** *(Reworded
  2026-09-22 to name "Anthropic (Claude)" and say the user is asked first; see
  the AI permission item below. The text quoted here is the earlier version.)* The old
  line ("Stored only on this device — never sent to a server") was false.
  It now reads: "Your name and goal stay on this device. Practice answers
  are sent to our AI provider to give you feedback, and usage and crash data
  is collected." Checked against the code: name and goal are sent neither to
  the proxy nor to analytics; answers go via the proxy to Anthropic;
  Firebase gets usage and crash data. It agrees with the published policy
  (https://ahmettayfur.com/products/grammarlens/privacy/), which also lists
  the anonymous device ID (usage limits only), RevenueCat and Cloudflare.
  The note carries no link, so the policy's other recipients are not named
  in the app text. No other claim of this kind exists in `lib/` (searched
  for on-device / never sent / stored only / no server wording); the
  Premium screen links the policy itself. Still open before submission: the
  App Store privacy nutrition label must match the same facts (outside this
  repo).
- **Proxy token logging — implemented, tested and deployed; data is
  accumulating in Workers Logs.** Each successful Anthropic call logs `kind` (daily_test /
  topic_practice), operation, question count and real input/output tokens
  with `console.log` (Workers Logs). Nothing user-related is logged; a test
  plants secrets to prove it. Purpose: after a few weeks of traffic, measure
  the real cost of a Daily Test and of a practice session — all unit
  economics (PRD v2 §13.7, the session cap, the margin numbers above) are
  still unmeasured estimates until then. Persistent-storage options are
  proposed in PRD v2 §13.10 (recommended: Workers Analytics Engine) and none
  is built. Two pre-existing proxy `console.error` calls (Anthropic's raw
  error body on a non-200, and the JSON parse exception on unusable
  content) could echo response text; **fixed 2026-09-21** (see the failure-log
  entry below).
- **Proxy `duration_ms` — implemented, tested and deployed.**
  Usage and failure log lines carry the wall time of the call to Anthropic, so
  the real generation time of a Daily Test (and any hang) can be read from
  Workers Logs. Numbers only; the privacy contract is unchanged.
- **Proxy failure logging — content-free, implemented, tested and
  deployed.** A failed Anthropic call now logs one JSON line: operation, kind
  (daily_test / topic_practice), failure category, HTTP status and Anthropic's
  error `type` restricted to its documented values (anything else is
  `unknown`). The upstream error body and every exception message are no
  longer logged, and a body that is not JSON is now handled instead of
  reaching the catch-all. Tests plant secrets in the body, the model text and
  the network error. *(Update 2026-09-21, later: the catch-all `Unhandled error` in
  `proxy/src/index.ts`, first left as is, was narrowed too. It now logs only
  the operation, kind and an error category, never the message or stack.
  Every `console` call in `proxy/src/` writes a fixed-field line with no user
  content; tests plant secrets to prove it. Deployed. The trade-off: an
  unexpected bug now shows up as a category, so diagnosing it needs a
  reproduction rather than a stack trace.)*
- **Trial-length wording — corrected in current-state text.** Truth: annual
  = 7 days, monthly = 3 days; both are set in App Store Connect and read live
  from RevenueCat, and no day count is written in `lib/` app copy (checked).
  README no longer implies a single trial length (its old sentence named no
  duration, and also wrongly said no App Store Connect product was connected;
  both fixed). Older dated entries in this file and in the build log keep
  their original wording as history, with pointers where they would mislead.
- **Premium legal links in the fixed footer — implemented, automated tests
  only; not device-confirmed.** Terms and Privacy now sit in the footer above
  "Maybe later" (33% of a 375x667 screen at Medium/Large), the avatar hero is
  dropped on screens under 700 pt, and the disclosure sentence is never
  truncated (it was cut at Large text with a 1.6x system scale). Above about 1.6x
  (375x667) the links fall back to the end of the scrolling body so the footer
  cannot take over the screen. Restore Purchases stays in the body. On an
  iPhone SE the comparison table is now fully in view and the top of the plan
  cards shows above the footer (about 56 pt at Medium, 11 pt at Large; before,
  10 pt and none).
- **Premium comparison-table overflow — implemented (stacked layout),
  automated tests only; not device-confirmed.** Decision: when the three
  columns do not fit, rows stack (label on top, Free and Premium chips
  below); no horizontal scroll and no content removed. The table falls back
  when its label column would drop under the existing 96 pt minimum even
  with the short "1/day" phrasing. Measured with the bundled Nunito Sans:
  320x667 @2x and 375x667 @3x text stack cleanly with no overflow (light,
  dark, pricing loaded and unavailable); 320-430 pt wide at up to 1.3x text
  keep the three-column table unchanged. The "pricing unavailable" card had
  its own overflow (icon + sentence + retry in one row) and now drops the
  retry below the sentence when the row cannot fit. Two side effects to
  know: the table's width measurements now use the app font it is drawn in
  (they used the platform default font, a latent mismatch since the
  Nunito Sans change), so column widths can differ from before by a few
  points; and tests load the real font, since `flutter test` otherwise
  measures in a font about twice as wide. **Update 2026-09-21 (owner
  decision):** a sales table must not clip, so the table now also stacks
  whenever any label would not fit in its two lines (measured as drawn: same
  style, text scale and label-cell width). Sizes where nothing was clipped keep
  the three-column table unchanged. With the real font: table at 360-430 pt
  wide at 1x and 1.1x, 375-430 pt at 1.15x, 414-430 pt at 1.3x; stacked at
  320 pt from 1x up, and at 393 pt from 1.3x up (the previously reported
  cases), and everywhere at 1.5x and above. Every size that was already
  unclipped kept its table; every size that changed had a clipped label
  before (checked by running old and new logic over a width x scale grid).
  Automated tests only; not device-confirmed.
- **Resume refresh (day rollover, greeting) — already implemented; now covered
  end to end.** The premise that no `AppLifecycleState` hook exists was stale
  (see the closed entry under "What's next"). No third hook was added. Two
  observers exist with disjoint jobs: the app-level one (analytics, medal
  finalization) and Home's (Daily Test day, greeting, climb month, weak
  spots). `test/app_resume_test.dart` drives an overnight background through
  the real app with an injected clock. Automated tests only.
- **Avatar attribution (CC BY 4.0) + Profile layout rework — implemented,
  automated tests only; device check pending.** The avatar set is adapted from
  "Cute Animal 3D Icons" by Tran Mau Tri Tam (Figma Community), CC BY 4.0; the
  owner confirmed all twelve avatars, Crab (`avatar_07`) included, come from
  that set. No separate licence item existed in this file, so this entry is the
  record and closes it: Profile has a Credits row that opens a Credits screen
  with the attribution sentence word for word and two link buttons (the Figma
  file, the licence). The links open exactly as the Premium legal links do:
  `_LegalLink` was made the public `LegalLink` widget (external browser, the
  same "Could not open …" message), with no behaviour change. Profile now reads
  Avatar, Name (+ Save), Monthly medals, Appearance (theme, text size), Data,
  Credits, and the debug-only Developer section last (still gated by
  `DebugTools`). The avatar row is unchanged, only moved. "Reset progress data"
  left Profile: a Data row opens a Data screen holding the explanation, the
  button and the unchanged confirmation dialog, so the destructive option
  needs two taps. Link taps are not tested (no `url_launcher` fake, no new
  dependency); tests assert the buttons exist with live https URLs. Age and
  occupation stay removed.

- **Day-0 climb animation — implemented, automated tests only; device check
  pending.** The first-launch Daily Test now ends on a Home that mounts the
  pawn at its earlier position and animates the step, like the normal flow.
  `FirstLaunchFlow` hands `pendingClimb: (day, step)` to `app.dart`, which gives
  it once to the new Home; the result screen's one button is disabled until the
  result is saved (this also closes a stale-Home race; it was two buttons until
  2026-09-22). Covered end to end through the
  real app (`test/first_launch_climb_test.dart`). Not device-confirmed.

- **Daily Test sends no weak spots — implemented and tested (Flutter and
  proxy); proxy deployed.** `generate_daily_test` no longer receives the
  error profile: client (`DailyTestService`, `ClaudeService`) and proxy
  (`validateGenerateDailyTest`, the prompt's bias branch) drop `weakSpots`, and
  the proxy rejects the field with a 400, so the Daily Test sends no user data
  to Anthropic. The "no practice history yet" prompt sentence became a plain
  general-mix instruction. Personalization moves to Premium features later.
  PRD v2 §13.12. The proxy side is deployed (it already returns 400 for a
  request that still carries `weakSpots`), so the app must ship with the
  client change.

- **AI permission before Topic Practice — implemented, automated tests only;
  device check pending.** A full-screen permission screen ("Feedback on your
  answers") appears inside `launchPracticeSet` before the length picker, until
  the user agrees. Stored in a new single-row `ai_consent` table (schema v20,
  versioned, fails closed, survives "Reset progress"). Declining costs nothing
  and the Daily Test is unaffected. Profile → Data has an "AI feedback" switch
  (switching on re-shows the screen, switching off is immediate), the onboarding
  note now names "Anthropic (Claude)" and says we ask first, and
  `ai_consent_result` reports granted / declined / revoked (analytics plan E7;
  register `consent_version` as a custom dimension). Outside this repo and still
  open before submission: the privacy policy must name Anthropic and this flow,
  the App Store privacy label must list user content shared with a third party,
  and the App Review notes should say how to reach the screen (Topic Practice,
  first session). No claim about the provider's retention or training is made
  anywhere in the app. PRD v2 §13.13.

- **First Daily Test preload — superseded 2026-09-22 (see the fixed first-day
  test below).** The "Get started" preload is removed (an AI set would have
  replaced the fixed one). What stays: single-flight per day in `DailyTestService`,
  the 40 s proxy request timeout (check it against the proxy's `duration_ms` once
  deployed), and the `getOrCreateDeviceId` race fix.

- **Tomorrow's Daily Test prepared in the background — implemented, automated
  tests only; device check pending.** Completing a day's Daily Test (the fixed first
  test's day included) generates the next day's set in the background and stores it
  under the next day's key, so that day's test opens from the cache with no wait. Silent
  on failure (the next day then generates on open as before), free when the set already
  exists or is already being generated. Home now shares one `DailyTestService`. Cost:
  one generation per active day, moved earlier, one wasted for a skipped day; the
  proxy's per-device daily unit count stays within 15 (12 in a full day) and the proxy
  was not touched. Not device-confirmed: needs a day to pass (or a device clock change)
  to see the next morning open with no wait.

- **Fixed first-day Daily Test — implemented, automated tests only; device check
  pending.** New users get the same five hand-written questions
  (`kDayZeroQuestions`, a Dart constant), seeded into today's set before the
  profile is saved, so the test opens at once, offline and free of generation
  cost, and also when the user closes the app mid-test and opens it from Home.
  Later days are unchanged. Schema v21 adds `daily_test_sets.source`, and
  `daily_test_completed` reports `set_source` (`bundled` / `generated`; register it
  as a custom dimension, analytics plan §9). Curly quotes and apostrophes now match
  in answers, and the Daily Test and Topic Practice answer fields turn off
  autocorrect, suggestions and smart punctuation. Not device-confirmed: how the five
  questions read and feel on a phone, and what a real iOS keyboard does with the
  no-correction flags. The content's difficulty is a hypothesis to read from data.

- **Welcome celebration confetti — implemented, automated tests only; device
  check pending; reworked 2026-09-22 (see below).** A package-free
  `CustomPainter` burst (about 1.8 s, the theme's colors) into an overlay, never
  under reduced motion, removed if the user leaves. It no longer fires when the
  badge is earned: it plays when the user taps "Start my climb" (next item).

- **Result screen: one fixed button, badge card below, confetti on tap —
  implemented, automated tests only; device check pending.** The Daily Test result
  screen has one primary button in a fixed footer (`BrandScaffold.bottomBar`, so a
  SnackBar floats above it): "Saving your results…", a retry after a failed save,
  "Start my climb" (with a small badge icon) when the Welcome badge was just earned,
  otherwise "Continue" (Day-0) or "See your climb" / "Back to Home" (from Home). The
  large Welcome card is the last item under the results and moves nothing when it
  arrives. Tapping "Start my climb" disables the button, plays the confetti on the
  results for its whole run and only then goes on to Home (a 2.5 s timer goes on
  anyway; no confetti under reduced motion). The same holds for a badge earned from a
  test opened on Home. The Day-0 paywall card is removed; the paywall moves to Home
  (next item). Not device-confirmed: how the burst reads from the button on a
  phone, and the 2.5 s ceiling.

- **First-day paywall on Home — implemented, automated tests only; device check
  pending.** Home opens the Premium screen by itself, once per install, about 600 ms
  after the pawn finishes its first climb (or as soon as Home loads, with no step
  to climb), only for a user who finished the Day-0 test, never with full access,
  never while Home is covered or in the background (it waits). One-time via a stored
  flag (schema v22, `one_time_flags`; claimed just before the push, so a paywall the
  app was closed on counts as shown; an unreadable flag means no paywall).
  `paywall_viewed` / `paywall_dismissed` use the source `day0_after_climb` (the old
  `onboarding` source is gone) and the automatic opening sends no `mode_selected`.
  Debug "reset onboarding" clears the flag. Not device-confirmed: the 600 ms pause
  and how the Premium screen arrives over the just-finished climb.

- **Submission prep — implemented; launch screen not device-confirmed.**
  `pubspec.yaml` version `1.0.0+1`. `ITSAppUsesNonExemptEncryption = false` in
  Info.plist: the app uses no encryption beyond HTTPS and the OS's own (no
  crypto package in `lib/`; the `crypto` package is only a build-hook
  dependency). Launch screen: it was Flutter's template, a fixed white
  background, so a dark-mode user saw white until the first frame (which also
  waits for Firebase and RevenueCat to start). It now uses a
  `LaunchBackground` color asset, `#FAF3EC` / dark `#1C1B1F` (the theme's
  `surfaceContainerLow`), and the app's first frame, the profile-loading view,
  paints that same color itself (it painted nothing before). A test keeps the
  asset, the storyboard and the theme in sync. Known limit: the launch screen
  follows the system appearance, so a user who chose Dark in the app on a
  Light system still starts on the light color.

- **Premium offer card on the practice results screen — implemented, automated
  tests only; device check pending.** After the last result card, a free user
  whose daily free practice is used up sees a plain app card (the theme's
  `surfaceContainerHigh`, radius 20, 18 pt padding): a "PREMIUM" chip
  (`secondaryContainer`, as on the Premium screen's PREMIUM column, not the
  orange band color), "Keep practicing", the shared `freePracticeUsedMessage`
  ("You've used today's free practice. Unlock Topic Practice and more daily
  sessions with Premium.", also on the weak-spot screen's locked row), two
  text-only benefits (Topic Practice; More Daily Sessions, side by side on
  wide screens, stacked on narrow ones or large text) and a "See Premium"
  FilledButton (paywall source `practice_result`). "Back to topics" sits under
  the card as an OutlinedButton, and stays the FilledButton when there is no
  card; its behavior is unchanged. Benefit icons (2026-09-23): a fixed 24 pt
  PNG per benefit from `assets/icons/` (light and dark variants, 1x/2x/3x),
  decorative for screen readers; the SVG sources in `assets/icons/_source/`
  are not bundled. Hidden for premium, for a free user with
  practice left, and when either read throws. Events unchanged:
  `practice_result_upsell_viewed` is exposure and the tapped/viewed ratio is
  the signal (analytics plan E8). Replaced the first version (2026-09-23, a
  line and an outlined button under a filled "Back to topics"). Known limit: `hasFullAccess` swallows a RevenueCat
  failure and returns false, so a paying user during such a failure reads as
  free; the card still needs a used-up free count, which a premium user does
  not accumulate. Not device-confirmed.

- **Daily Test explains every answer — implemented, automated tests only
  (Flutter and proxy); proxy NOT deployed; device check pending.** Recorded
  2026-09-24. The App Store description says "you see why each answer was
  right or wrong", but a Daily Test card only explained a wrong answer that
  matched a predicted common mistake; a correct or skipped card had no text,
  and an unpredicted wrong answer only got "Not quite — here's the correct
  answer." (Topic Practice already explains every card.) Each Daily Test
  question now carries a one-sentence `explanation` of why the answer is
  right, generated in the same single call as the rest of the set (option B
  of the 2026-09-24 diagnosis; estimated +150–250 output tokens per set,
  roughly $0.002–0.004 per device per day on Sonnet 4.6, unmeasured). Shown
  on correct, skipped and unpredicted-wrong cards; a predicted mistake keeps
  its own comment; a keyboard-variant match shows its note, then the
  explanation. The five hand-written first-day questions have hand-written
  explanations. A set cached before this has none and behaves exactly as
  before. **Deploy order:** the app tolerates a proxy without the field (old
  behavior), and the old app ignores the new field, so the proxy can be
  deployed on the owner's approval at any time; until then, generated sets
  still have no explanation. Measured locally before deploy (2026-09-24,
  `wrangler dev`, 5 sets each round): with the first prompt a 5-item set used
  1470–1632 output tokens, only ~20% under the shared 2048 limit, so the
  Daily Test got its own budget (3072 for 5 items, scaled with count) and the
  explanation a "fewer than 25 words" limit; the second round used
  1319–1496 tokens (≥51% headroom), every response parsed, all 25
  explanations present, 5 of 25 still at 25–27 words. Not device-confirmed.

- **Weak-spot detail no longer repeats the topic name — implemented,
  automated tests only; device check pending.** Recorded 2026-09-24. For a
  Daily Test weak spot the detail screen said "You've had trouble with Modal
  Past Forms in Modal Past Forms." (and showed the name again under the
  frequency pill), because a Daily Test record stores its topic id as the
  error type. When the rule title equals the topic title, the sentence now
  names it once and the line under the pill is hidden, the same rule
  `WeakSpotCard` has used since 2026-09-05. Not device-confirmed.

**Monthly Climb branch update — 2026-09-18:** On `monthly-climb-v2`, Stage 1
preview and Stage 2 persistence are present. The approved first Stage 3 slice
now displays persisted monthly progress and the selected avatar on Home, with
local refresh on completion/return/resume and explicit progress-read retry.
Main's storage, migration and atomic Daily Test completion remain the base.
Home device acceptance, the remaining Home redesign/access decisions, medals,
Profile and rollout are pending. As of 2026-09-19 this is the launch branch: it
merges to `main` (on the owner's approval) and ships as the first App Store
release; see "Launch scope" above. Older statements below that no gamification
exists describe the earlier v2 checkpoint. See `prd-gamification.md` M1–M5 for the active monthly direction.

**Device-feedback package 1 — 2026-09-18:** Results now end with a save-aware
`See your climb` / `Back to Home` action. Persisted progress waits for Home to
be visible before animating; the mountain is brought into view first. Both
CTA/back returns, delayed saves and reduced motion are covered. No new paywall
route; Day-0 retains its existing CTA. Implementation and automated/widget
visual checks are complete; the user confirmed successful behavior on their
phone. Home scrolling follows in package 2, per `monthly-climb-revision-plan.md`.

**Device-feedback package 2 — 2026-09-18:** User confirmed package 1 works on
their phone. Home's mountain now passes vertical drags to the page while its
automatic pawn tracking remains. The long caption below the mountain is
removed; a compact accessible monthly counter sits in the heading area.
Standalone preview exploration remains enabled. Package 2 device review is
complete: user confirmed it works. Typography/Premium follow next.

**Premium 4a — equal plan-card frames:** The two pricing cards now stretch to
the taller natural content height; total border/padding insets remain stable
when switching selection. No pricing or purchase logic changes. Static
analysis clean and all 67 Premium tests pass, including equality/selection
stability at 320px/1× and 375px/2× in light/dark. User device review passed.
Typography and 4b/4c remain open. Separately observed comparison-table overflow
at 320px/2× is recorded for the broader Premium layout pass.

**Premium 4b — stable contextual entry:** The headline is identical across
entry points. Weak-spot context replaces the existing supporting sentence
instead of lengthening the headline. Empty context uses the generic copy;
long context remains untruncated and may scroll at large text sizes. All 70
Premium tests pass, including light/dark geometry comparisons against normal
entry. User device review passed.

**Premium 4c — separated, opaque avatars:** The selected avatar remains larger
and centered, with two or four smaller companions according to available width.
Removed overlapping offsets and side-avatar opacity; preserved 90pt hero height,
deterministic selection, legacy fallback and one semantic announcement. Static
analysis clean; all 74 Premium tests pass, including light/dark geometry at
320/390px. User device review passed; typography remains open.

**App typography — Nunito Sans:** User selected Nunito Sans. The variable font
and its OFL license are bundled locally (~558KB), so rendering has no runtime
network dependency. The shared light/dark theme now applies it across Material
text, app bars and controls. Static analysis clean; 120 focused Home/Premium/
theme tests and all 412 app tests pass, including a Turkish-character render
check. Physical-device typography acceptance remains pending.

**Profile + user text sizing:** The Settings tab is now user-facing `Profile`
with a person icon and Profile page title; all prior settings/profile functions
remain available. Appearance adds persisted Small/Medium/Large choices. The
original Nunito size is Small; readable Medium (1.10×) is the default and Large
is 1.20×. Schema v16 adds only `text_size_settings`, preserving the existing
v15 climb ledger and every prior table. System accessibility scaling remains
independent. Static analysis clean; all 416 tests pass. Device review pending.

**Profile medal collection shell:** Added a responsive Bronze/Silver/Gold row
to Profile with distinct subdued tier colors, mountain marks, lock badges and
explicit `Not earned` copy. Production supplies no earned tiers while scoring,
minimum participation and partial-month rules remain undecided, so the UI
cannot imply an award. Semantics announce tier plus locked/earned state. Static
analysis clean; all 424 tests pass, including 320px light/dark across all three
app text sizes. Physical-device visual acceptance remains pending.
User subsequently confirmed the medal collection on their phone.

**Monthly medal rules + durable history:** Approved rule v1 scores correct +2,
wrong +1 and skipped +0. Bronze/Silver/Gold are ceil(25/50/75% of the full
calendar month's 10-points-per-day maximum); there is no separate minimum-day
gate and partial months are not prorated. Schema v17 adds only frozen monthly
results after main's raw v15 ledger and the independent v16 text preference.
Past months with at least one ledger row finalize once (including `No medal`),
never recompute, and empty months create no fake history. Profile shows current
score/max/active days as `In progress` plus finalized month history. Static
analysis clean; all 436 tests pass. Physical-device acceptance pending.

**Purpose of this file:** single source of truth for where the project stands.
Read this first in any new working session (chat or Claude Code) to get context
without re-explaining history.

**Last updated:** 2026-09-16 (docs sync: defined the v2/v3 boundary — v2
is this build, frozen as-is for a visible before/after; v3 is a
gamification layer plus a Home redesign, neither built. Corrected a
stale Paid Apps Agreement status left in the "Pre-launch checklist"
narrative below "Current wiring" moved past it on 2026-09-15. Replaced
the old 2026-09-02 gamification heads-up with a dated entry under "Later
phases" reflecting the actual current state — no gamification code
exists anywhere in this repo; `docs/prd-gamification.md` is a draft, and
direction has since moved from weekly to monthly. See "Later phases
(post-v2)" below.). Previous update, same day (iOS minimum deployment
target raised to 15.0 — the installed Xcode toolchain rejects a simulator
build below it; pure build-setting change, no dependency versions moved.
See "Premium screen redesign, underway" below and this file's own
2026-09-16 entries for detail, and "What's next" §1 for a separate,
unrelated toolchain bug found while verifying the build). Previous
update, same day (Premium
screen redesign: on-device review fixes): the redesign's four batches
were checked on-device and two follow-up commits fixed what didn't hold
up — an ad-copy headline with no real source, a row-overlap bug ordinary
overflow tests can't catch, and a density/color-language pass; one known
debt left open (375×667 still needs a scroll). Previous update 2026-09-15
(Premium screen redesign closed out — Batch 4 shipped four new paywall
analytics events (`paywall_viewed`,
`paywall_dismissed`, `purchase_started`, `purchase_result`), tagged by
the four real entry points Batch 0 confirmed. The dismissal event needed
a genuinely designed solution, not just a call per button: a system back
gesture reaches a pop without going through any of this screen's own
`onPressed` handlers, solved with an observing `PopScope` plus an
`_exitHandled` flag so it never double-logs. See "Premium screen
redesign, underway" below and `docs/build-log.md`'s same-date entries
for the full four-batch arc. Previous update, same day (Batch 3, hero
avatar group): a hero avatar group at the top (the user's own avatar
front-and-center,
four others deterministically picked, layered behind it), no `Hero`
wrapper on any of them since this screen has no push/pop flight partner
and wrapping would risk colliding with Home's/Settings' own avatar Hero
tags. Found and fixed a real accessibility gap while building it, not
just in review: a bare `AvatarTile` carries no semantic label on its
own. Previous update, same day
(Batch 2, structure): the CTA is now genuinely pinned in a fixed footer
instead of just
happening to fit on one common screen size, the comparison table merged
two wrong/overlapping rows into one correct one, and the Premium column
is now a real highlighted strip using a contrast-checked color pairing
instead of the one Batch 0 found failing in dark mode. A real
`IntrinsicHeight`/`Expanded` reliability bug was found and fixed along
the way, not hypothetical — it caused an actual overflow at 2.0× text
scale during this batch's own testing. Previous
update, same day (Batch 1, pricing fixture): a debug-only pricing
fixture shipped so the paywall's loaded state is finally previewable
with no App Store Connect product connected yet, and Batch 0's own
diagnosis found a real factual error in the comparison table beforehand.
Previous update, same day (Home avatar Hero): Home's avatar tap now
opens Settings' avatar
picker via a real route push, with a genuine `Hero` flight to the
carousel's centered avatar — checked first that the old tab-switch
mechanism couldn't support a Hero at all, since it has no push/pop
transition; stopped and presented options before picking one. Found and
fixed a real flicker risk along the way, in the *shared* picker widget
(so it also closes the same latent risk in Settings' own existing flow):
the pending-avatar-change flush used to happen only in `dispose()`, too
late for the destination Hero to already show the new avatar before the
flight starts. See "Home avatar → Settings' avatar picker: a real
transition" below and `docs/build-log.md`'s same-date entry. Previous
update, same day (bigger picker avatar): Settings' avatar picker screen
got a bigger
center avatar, a second look now that the colored ring is gone — center
avatar 128pt → 160pt diameter, with the neighbor peek still measured at
exactly half-visible at both 320pt and 375pt. Corrected a belief in the
previous ring-removal batch's own reasoning along the way: the ring, not
the peek-visibility rule itself, was the real reason radius used to be
capped low. See "Settings' avatar picker: bigger center avatar, second
look after the ring's removal" below and `docs/build-log.md`'s same-date
entry. Previous update, same day (ring removed): the avatar carousel's
colored selection
ring is gone — background is transparent now, with a soft theme-aware
ground shadow under the illustration instead, applied everywhere an
avatar renders: the carousel, Home's greeting, Settings' preview row.
The ring-color palette this section's own history carried forward twice
before is deleted outright this time, not renamed or expanded again —
see `docs/design-audit.md`'s avatar section for the closing status note.
Also fixed along the way: a real zero-size rendering bug in `AvatarTile`
introduced while building this, caught by a widget test before it ever
reached a device. See "Avatar presentation: dropped the colored ring,
transparent background + ground shadow" below and `docs/build-log.md`'s
same-date entry. Previous update, same day (Avatar asset fix): a
vertical-line rendering bug reported on
the onboarding carousel's Dinosaur avatar, diagnosed to a corrupted pixel
stripe baked into `avatar_07.webp` itself — not a render or layout bug.
Dinosaur was retired and replaced with a new Crab illustration in that
slot; that batch closed out the asset swap properly — resized/
re-encoded to match the pipeline, a new regression test that decodes
every avatar's real bytes and checks its edges, and two much smaller
pre-existing edge artifacts on unrelated avatars fixed along the way. See
"Avatar asset fix: the vertical-line bug, Dinosaur → Crab" below and
`docs/build-log.md`'s 2026-09-15 "Avatar asset fix" entry.
**Note on dates:** this and the next three "previous update" entries
below were all originally logged with sequentially incremented dates
(2026-09-16 through 2026-09-19); `git log` shows all four batches were
actually committed on 2026-09-15, so their dates are corrected here to
match — see `docs/build-log.md`'s own 2026-09-15 entries for the
detailed, now-consistent record. Previous update, same day (Avatar
picker screen): the
avatar picker screen — Settings' full-screen "Change avatar" — gained a
"Done" button, warmer/plainer heading copy, and a bigger center avatar
with neighbors still peeking at the edges; onboarding's embedded carousel
is untouched. See "Avatar picker screen: Done button, copy, bigger
avatars" below and `docs/build-log.md`'s 2026-09-15 "Avatar picker
screen" entry. Previous update, same day (Home greeting):
Home's greeting is time-of-day now, not a fixed "Welcome back", and its
avatar is bigger — see "Home: time-of-day greeting + bigger avatar"
below and `docs/build-log.md`'s 2026-09-15 "Home: time-of-day greeting"
entry. Also confirmed, not
fixed: the avatar ring palette's 10-into-12 cycling is intentional, from
the previous batch's own explicit instruction, not an oversight.
Previous update, same day (Avatar carousel): replaced the
avatar picker: a real layout bug in the old tap-a-grid-tile picker —
selecting a tile changed its own footprint and broke the grid — is fixed
by moving to a swipeable carousel over twelve illustrated avatars, never
a grid again. See "Avatar carousel" below and `docs/build-log.md`'s
2026-09-15 "avatar picker: layout-bug diagnosis, carousel replacement"
entry. Previous update 2026-09-15: closed the free-tier "Practice this" leak —
`launchPracticeSet` now checks entitlement and a new per-day free-practice
quota itself, instead of relying on each screen to gate it. See "Free tier
practice quota" below and `docs/build-log.md`'s 2026-09-15 entry. Previous
update 2026-09-14: Firebase and RevenueCat now actually configured; legal
pages written and live; first run on a physical iPhone; App Store Connect
bank account submitted and the banking/tax sequencing decision reversed — see
"Current wiring" immediately below, and the 2026-09-14 entries in §1's blocker
status. Previous update 2026-09-10: v2.2 B-structure batch shipped; B-polish
visual-polish tour — D1 hybrid theme and D2 single blue both closed, remaining
contrast/states and consistency findings (D5) plus D1's own test gap closed;
app icon generated from a real source image, replacing Flutter's placeholder)

---

## Why this project exists

Personal product case study — building product management capability by
actually shipping something, and creating a portfolio piece that demonstrates
end-to-end product thinking (research → definition → build → iteration → learning),
not just a finished app.

Originally started during a job application process. That process ended, the
product continues.

---

## Where we are now

**Status: MVP complete, tested with real users, closed. V2 built; the launch
branch `monthly-climb-v2` is pending its merge to `main` and the first App
Store submission — see "Launch scope" at the top of this file and
`docs/prd-v2.md`.**

### Current wiring — verified against the repo, 2026-09-14

Earlier entries in this file describe Firebase and RevenueCat as unconfigured
scaffolds. That was true when each was written and is no longer true. Those
entries stay as the record of when the batches landed; **this block is what is
actually wired today.** Checked against the filesystem, not from memory.

- **Firebase — connected.** Project `grammarlens-18d47`.
  `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist` and
  `firebase.json` present since 2026-09-13. Analytics and Crashlytics collect
  for real; `AnalyticsService` is no longer a no-op. **iOS only** — there is
  no `android/app/google-services.json`.
- **RevenueCat — configured.** `REVENUECAT_API_KEY` populated in both
  `config/dev.json` and `config/prod.json` (both gitignored). Entitlement id
  `premium`.
- **App Store Connect app record — created**, bundle id
  `com.ahmettayfur.grammarlens`.
- **Paid Apps Agreement — Active as of 2026-09-15.** The bank account
  ("USD account", Türkiye, USD, royalty currency USD) went Active one
  day after submission — verification took ~1 day, not the "multi-day"
  re-verification this file previously assumed. Tax forms Active since 7 Sep.
  **The banking blocker is closed; the whole store/billing chain is open.**
- **Subscription products — created, Ready to Submit, 2026-09-17.**
  Subscription group "GrammarLens Premium": `grammarlens_premium_annual`
  (level 1, 1 year, $49.99, 1-week free introductory offer) and
  `grammarlens_premium_monthly` (level 2, 1 month, $5.99, 3-day free
  introductory offer — see PRD v2 §13.2's own 2026-09-17 note on the
  asymmetric trial). **Not yet submitted for review** — first subscriptions must go
  out together with a new app version, not on their own.
  **ASC metadata:** subscription group display name "GrammarLens Premium";
  product description "Daily topic practice with personalized feedback" —
  replaced an earlier "Unlimited topic practice…" description, which was
  false: premium is capped at `dailySessionLimit` (5 sessions/day since
  2026-09-21; it was 10 when this was written), never unlimited.
  **Review assets are placeholders, not launch-ready.** Both products'
  App Review screenshot is a simulator capture of the debug fixture
  offering, not a real device/real price screenshot, and their review
  notes state US prices and describe the path to the paywall. Both must
  be replaced or re-checked before submission — added to the Pre-launch
  checklist (§1 below) rather than assumed done here.
  **RevenueCat:** both App Store products created and attached to the
  `premium` entitlement; the `default` offering is current, with
  `$rc_monthly`/`$rc_annual` packages each now holding the real App Store
  product (the existing Test Store products stay attached alongside, not
  removed). An App Store Connect API key is added to the RevenueCat
  project, so its dashboard shows live product status instead of pending.
  **Verified on a physical iPhone, 2026-09-17,** built against
  `config/prod.json`: live prices and the per-plan trial lengths (PRD v2
  §13.2) both load correctly on `PremiumScreen`.
  **Sandbox purchase completed, same device, same day.** A sandbox tester
  bought the annual plan's free trial; the `premium` entitlement was
  granted and Home's locked cards unlocked. After deleting and
  reinstalling the app (wiping local data and restarting onboarding),
  premium came back **without tapping Restore Purchases** — StoreKit
  syncs transactions on launch, which confirms entitlement is actually
  read from RevenueCat/StoreKit, not reconstructed from anything stored
  locally.
  **Not yet done:** an *explicit* Restore Purchases tap has not been
  exercised in a scenario that actually needs it (a second device, or a
  signed-out/re-signed-in sandbox account) — added to the TestFlight
  pre-submission pass, since the reinstall test above happens not to
  require it. Also still open: expiry/cancellation behavior (locks
  returning once a subscription actually lapses), and a non-USD
  storefront check (e.g. Türkiye / TRY) of prices and the savings badge.
  **Decided against:** Apple's "Monthly with a 12-Month Commitment"
  billing option is not being configured — it was never part of the
  pricing decision (PRD v2 §13.3) and `PremiumScreen`'s disclosure block doesn't
  support disclosing a commitment term. Left as a post-launch idea only,
  worth revisiting if annual conversion turns out low.
- **EU DSA — trader verification Active, 2026-09-22** (Apple case
  102955281512). EU availability is no longer gated. The history below is
  the 2026-09-16 record, kept as written: it was In Review then, resubmitted
  2026-09-16. The first submission was rejected because the declared trader address was
  incomplete and misspelled, so it couldn't match the proof document — the
  translation was not the cause. The corrected address was resubmitted with
  the same invoice PDF (English translation included), now matching it
  exactly. The DSA trader address is independent of the developer-membership
  address; the membership address-change case (102963244071) was
  deliberately dropped — do not reopen without a new reason. Not on the
  launch critical path: gates EU availability only, and Türkiye is not in
  the EU. Full story: `docs/build-log.md`, 2026-09-16.
- **Legal pages — written and live**, no longer placeholder:
  `/products/grammarlens/privacy/`, `/terms/` and `/support/` on
  ahmettayfur.com.
- **GDPR Art. 27 EU representative — not appointed. Deliberate, documented
  gap.** Reasoning: sole developer established in Türkiye, no EU
  establishment; the app does not target the EU as a primary market (initial
  launch is aimed at Turkish speakers); processing is limited to pseudonymous
  analytics and crash diagnostics with no special-category data. Revisit
  trigger: appoint a representative if EU users become a material share of
  the user base, or if EU-targeted marketing begins.

**Open consequence (fixed 2026-09-21 — see "Launch scope"):** the onboarding
privacy note — "data stays on-device, never sent to a server" — was wrong
twice over: answers go through the proxy *and* telemetry goes to Firebase. A
false privacy claim is a real App Review rejection reason. The note now
matches the privacy policy; automated tests only.

### Shipped

**Core product**
- Topic selection → session length (Quick 3 / Standard 5 / Extended 10)
- One-question-at-a-time flow with progress bar, Back / Skip-Next, exit confirmation
- Mixed question types: sentence writing, error correction, fill-in-the-blank
- LLM-generated question sets (Claude Sonnet, structured JSON)
- Batch evaluation at the end → Results screen
- Plain-language feedback with grammar rule as secondary caption
- Deterministic skipped-answer handling (empty ≠ wrong)
- Error profile stored locally (sqflite), fed by every session
- Review tab: weak spots with frequency/recency stats, sortable
- Weak-spot detail screen → summary of past mistakes → targeted fresh practice

**Design**
- Material 3, custom identity: orange primary / deep blue accent
- Light mode (orange background) + dark mode (neutral dark, orange accents)
- Animated bottom nav, full-screen loading states, semantic result colors
- Per-topic icons, home cards showing personal progress stats
- Responsive sizing, no hardcoded pixel values
- Empty states: shared `EmptyState` widget (icon + title/description + optional
  CTA); Review's no-weak-spots state now has a "Start practicing" CTA, and
  weak-spot detail's empty mistake list uses the same icon+text pattern
- Keyboard-aware bottom button on practice questions: the primary
  Skip/Next/Submit button now stays pinned above the on-screen keyboard on
  every free-text question type (fill-in-the-blank, error correction,
  sentence writing), instead of sitting behind it. Answers the T1 finding in
  `docs/prd.md` §2.2 Theme 2. Two follow-up fixes from testing this on a real
  device: the question header (context/instruction/hint) now lives in its
  own scroll region, separate from the answer field, so it no longer gets
  dragged half off screen by the keyboard's "scroll the focused field into
  view" behavior; and tapping anywhere outside the field dismisses the
  keyboard, not just its own "Done" key

**Documentation**
- `docs/prd.md` — MVP: problem, personas, interview findings (§2.1), usability
  testing findings (§2.2), scope decisions
- `docs/prd-v2.md` — v2 scope, evidence-vs-bet labeling, screen architecture,
  open decisions
- `docs/build-log.md` — chronological record of decisions and bugs
- `README.md` — product overview, screenshots, key product decisions
- Public write-up on Medium

**User research**
- 3-participant usability testing (T1–T3), full core loop, think-aloud +
  structured questions. Below the original 5+ target — proceeding with 3 was
  a deliberate call, not an oversight; findings weighted accordingly (see
  `docs/prd.md` §2.2 for the sample-size note and per-theme evidence
  strength). Headline results: plain-language feedback strongly reconfirmed
  (3/3, consistent with §2.1 Theme 2); multiple-choice question format
  rejected outright (3/3, consistent with §2.1 Theme 3) — closes the
  MC-based word-form category as a candidate

**V2 Phase 1 — Onboarding + Home + Settings** (`docs/prd-v2.md` §4, §5, §10)
- First-launch flow: one-sentence Welcome/value intro → two-field onboarding
  (name + learning goal only — age/occupation deliberately deferred, see the
  onboarding screen's doc comment). Guest-first, no signup: the profile
  saves straight to the existing local sqlite store, and its presence is
  what "onboarding complete" means — returning launches skip straight to
  Home
- Home replaced: was the topic list, now mode selection with a personalized
  greeting ("Welcome back, {name}") and three mode cards — Topic Practice
  (active, opens the unchanged MVP loop, now its own TopicPracticeScreen),
  Streak Mode and AI Practice Partner (not built yet; tapping either is
  informative rather than a dead disabled card)
- Settings screen, new: theme (proper light/dark/system, replacing the old
  quick toggle), name edit, optional age/occupation fields (removed
  2026-09-21), and a "reset
  progress" action — scoped to practice history only, keeps the guest
  identity intact
- Bottom nav: three tabs now (Home / Review / Settings)

**V2 Phase 1 — revision round**, three fixes found testing the above on a
real device:
- Onboarding: centered text/labels (was left-aligned); the learning-goal
  option cards were unreadable in light mode (transparent fill on the vivid
  orange page, faint border) — now use an explicit surface color and a
  stronger border, light mode only, dark mode left untouched
- Streak/Voice "coming soon" messaging moved off the app-wide SnackBar
  (which queued on repeat taps and kept showing after navigating away,
  since it lives above the Navigator) onto a proper modal `showDialog`,
  matching the app's existing confirm-dialog look
- Home's mode cards: vertical list → 2-column grid, room to grow into more
  modes without a layout rethink

**V2 Phase 2 — Premium / early-access screen** (`docs/prd-v2.md` §6, §10 item 2)
- New `PremiumScreen`, reached from a fourth Home mode card ("Early
  Access", fills out the 2×2 grid alongside Topic Practice / Streak Mode /
  AI Practice Partner). Informational only, per §6: no payment flow, no
  price, no buy button anywhere on it
- Content: the required framing line ("You're one of our first users —
  everything is free while we're in early access") plus a short list of
  what premium will include — unlimited Streak Mode, AI Practice Partner —
  each tagged "Coming soon" since neither feature exists yet either.
  Deliberately did not say "free forever" or unqualified "free" (§6:
  becomes a constraint once real pricing ships)
- Verified in both themes on the iOS simulator via a temporary,
  untracked debug-harness entry point (same technique as Phase 1 — direct
  render, no tap automation), deleted after use

**V2 Phase 2 continued — pre-launch checklist progress, Home polish,
avatar picker** (`docs/prd-v2.md` §10.1, §11), five independent commits:
- **Daily session cap.** Client-side cost guardrail (§10.1): `StorageService`
  tracks practice sessions started per local calendar day (schema v7);
  `launchPracticeSet` checks it before even opening the length picker and
  shows a "That's all for today" dialog instead of triggering generation
  once the limit (10/day at the time, a placeholder default — see §7.2;
  lowered to 5 on 2026-09-21, see PRD v2 §13.8) is reached. A
  session only counts once generation actually succeeds; both the check and
  the write fail open on a storage error
- **Onboarding privacy note.** One line under the goal options: data stays
  on-device, never sent to a server (§10.1's privacy-note item, closed —
  the claim was false and was replaced on 2026-09-21, see PRD v2 §13.9)
- **Firebase Analytics + Crashlytics — code scaffold only, no project
  connected.** `AnalyticsService` wraps three custom events
  (`onboarding_completed`, `mode_selected`, `session_completed`) plus
  Crashlytics's global error hooks in `main.dart`. Connecting an actual
  Firebase project needs an interactive `flutterfire configure` run against
  a real account, which isn't something that can be done inside a coding
  session — so `Firebase.initializeApp()` is wrapped in try/catch and every
  `AnalyticsService` call is a safe no-op until that happens. Verified the
  app still builds and runs normally on iOS with the packages present but
  unconfigured. *(Superseded 2026-09-13 — the Firebase project is now
  connected. See "Current wiring" near the top of this file.)*
- **Early Access given a distinct look on Home.** As a fourth grid tile it
  read identically to the three practice-mode cards, implying it was one.
  Pulled into its own full-width outlined/tinted banner below the grid —
  commercial framing, not a mode, now reads that way on sight
- **Avatar picker (§11), promoted from the parking lot.** Eight local stock
  emoji avatars, no upload pipeline. Picker lives in Settings (not
  onboarding, consistent with onboarding's "every field costs completions"
  stance); the chosen avatar shows next to Home's personalized greeting.
  `UserProfile` gains a nullable `avatar` field (schema v8)

**Home + nav bar revision round**, referencing Kick/Instagram's nav design,
four independent commits:
- **Floating, frosted-glass nav bar.** Replaced the flush, flat-background
  bottom bar with a pill: margins from all three screen edges, fully
  rounded corners, translucent `BackdropFilter`-blurred container. Existing
  active-tab styling (icon+label, selected pill) untouched — only the bar's
  own surface changed. Deliberately not `extendBody: true` (letting screen
  content draw behind the bar): a first attempt at that hid Home's mode
  grid's last row underneath the bar on an unscrolled screen instead of
  stopping above it — a real regression for a cosmetic "blur reveals
  scrolled content" nicety. Scaffold's default behavior (reserving the
  bar's height above `body`) avoids that risk entirely and still delivers
  the floating/rounded/translucent look
- **Early Access banner contrast.** The outlined/tinted treatment (10%
  secondary fill, thin border) read as washed out against the vivid orange
  page — too close to the page color to register as its own surface.
  Switched to a solid `colorScheme.secondary` fill with `onSecondary` text,
  the same pairing `FilledButton` already uses — reads clearly against both
  the orange page and the cream/white mode cards
- **Avatar moved to the trailing edge.** Was leading the greeting text;
  swapped order (greeting first, avatar last) with a `spaceBetween` Row so
  the avatar sits flush against the screen's trailing edge instead of
  floating near the center-left
- **Avatar tap → Settings.** The avatar is the user's own identity marker
  and Settings is where it's actually edited, so tapping it jumps there
  directly — wired the same way `ReviewScreen`'s `onGoToPractice` already
  switches tabs, a nullable callback set by `app.dart`

**Nav bar revision round 2 + avatar shape**, three independent commits —
the first revision round's nav bar didn't actually hit the target:
- **Genuinely floating nav bar.** The previous pill still used Scaffold's
  `bottomNavigationBar` slot, which wraps its child in an opaque `Material`
  spanning the full width of the screen's bottom regardless of what's
  inside it — so a solid strip was painted behind the pill and across its
  margins on every screen, most visibly on scrollable Settings where
  content (the Save button) stacked ugly against an invisible boundary.
  Replaced with a `Stack`: tab content fills the whole body, the pill is a
  `Positioned` overlay near the bottom — nothing paints anything outside
  the pill's own rounded bounds, so content now genuinely scrolls behind
  it, Instagram-style. Each tab screen's scrollable content gets extra
  bottom padding (`navBarClearance`) so an important control can be
  scrolled fully clear of the bar rather than staying stuck under it. This
  also reverses the previous round's "don't use extendBody" call — that
  call was avoiding the *symptom* (content hidden behind an opaque
  boundary) without addressing the actual cause (the slot itself), which
  this round fixes properly
- **Active tab: translucent highlight, not a solid block.** Was a solid
  `colorScheme.secondary` fill with white text; switched to a soft 30%-
  alpha tint with the accent color carried by the icon/text instead — GNav
  already only renders the tab background for whichever tab is selected,
  so this reads as a gentle "you're here" marker rather than a filled pill
- **Avatar shape: circle → rounded square.** Both Home's greeting avatar
  and Settings' picker grid. `AvatarCircle` renamed to `AvatarTile`
  (the old name would be actively misleading now); corner radius scales
  with size instead of being fixed. Selection ring and the avatar's tap
  ripple both updated to match the new shape

**Nav bar revision round 3: drop the active-tab indicator entirely.** Two
prior rounds tried to fix the active tab's `tabBackgroundColor` block —
first a solid fill, then a translucent tint — and neither ever sat flush
against the floating pill's edges; the block is painted by `GNav`'s own
internal animated icon+label layout, which has no seam to fix that
geometry from outside. Rather than a third attempt at re-geometrying it,
removed the block outright and replaced `GNav`/`google_nav_bar` with a
small custom row widget (`_FloatingNavBar` in `app.dart`) so the active
tab is communicated purely by icon + color + a small dot: outline icon
swaps to filled, icon/label recolor to the accent blue, label goes bold,
and a 4px accent dot appears centered beneath — no background shape at
all, Instagram-style. `google_nav_bar` is no longer a dependency.

**Removed Streak Mode and AI Practice Partner from Home.** Both were
"coming soon"/"premium" tiles in Home's mode grid leading only to an
informational dialog — neither is actually built. Per `docs/prd-v2.md`
§12.6, that's an Apple App Review completeness risk (tiles for
core-looking features that don't do anything) and pure duplication
besides, since the Premium screen (reached via the Early Access banner)
already lists "unlimited Streak Mode" and "AI Practice Partner" as
coming-soon premium features. Removed
the tiles, their tap dialogs, and the now-dead `_showComingSoonDialog`
machinery; Topic Practice — the only real mode — is now a single
full-width card instead of a lone tile in an otherwise-empty 2-column
grid.

**RevenueCat integration scaffold — code only, no product connected yet.**
Added `SubscriptionService` (`lib/services/subscription_service.dart`),
wrapping `purchases_flutter`'s SDK configuration, entitlement check
(`hasFullAccess`), `purchasePackage`, and `restorePurchases`, initialized
in main.dart the same "safe no-op until configured" way Firebase already
is: no RevenueCat public SDK key set at build time (or `Purchases.configure`
throwing) means every method degrades to its safe default
(`false`/`PurchaseOutcome.failure`) instead of crashing, matching
`AnalyticsService`'s pattern for an unconnected Firebase project. Same
caveat as that Firebase entry: **no RevenueCat account or App Store
Connect product exists yet** — entitlement id `premium` and product id
`grammarlens_premium_monthly` are just the identifiers reserved for when
one is created. *(Superseded 2026-09-14 — the RevenueCat key is now set and
the app record exists; products still do not. See "Current wiring" near the
top of this file.)* This batch is the service layer only: no paywall UI, no
gating of Topic Practice, nothing wired to a purchase button — later
batches consume this.

**Daily Test — data/logic layer only, not reachable from any screen yet.**
The free tier's fixed daily set (PRD v2 §12.2, §12.5, §12.8): 5
fill-in-the-blank/error-correction questions (no multiple-choice —
conclusively rejected in user research, `docs/prd.md` §2.2 Theme 1),
generated once per calendar day per device and graded entirely offline.
Added `DailyTestQuestion`/`DailyTestSet` (`lib/models/`), a local schema
v9 cache table in `StorageService` (`daily_test_sets` — a separate
per-day cache from Topic Practice's session-cap table, deliberately not
sharing or touching it), `ClaudeService.generateDailyTestQuestions`
(structured JSON: each question's correct answer plus 2-3 predicted
common wrong answers with pre-written comments, generated up front so no
second LLM call is needed to grade), and `answer_matching.dart`'s
deterministic checker (normalize → exact match → common-wrong match →
generic fallback). Personalizes by biasing topic selection toward the
device's local error profile (`StorageService.getWeakSpots`) when one
exists, general/varied mix otherwise — same single generation call
either way. `DailyTestService` ties it together (get-cached-or-generate,
mark-completed) for a future screen to call. No UI, no Home/onboarding
wiring, no paywall/entitlement checks — next batch.

**Daily Test — screens built, still not reachable from Home/onboarding.**
`DailyTestScreen` (`lib/screens/daily_test_screen.dart`) and
`DailyTestResultScreen` (`daily_test_result_screen.dart`) on top of the
previous batch's data layer. The question flow deliberately mirrors
PracticeScreen's layout — same progress bar, same keyboard-aware bottom
button, same header/answer split into separate scroll regions (the
hard-won fix for the keyboard dragging the question off screen, not
worth regressing here) — but simpler: fixed 5-question count, no length
picker, no submit-time API call (grading is instant and local via
`checkDailyTestAnswer`). The result screen reuses `SemanticColors` and
`MistakeBreakdown` for the same correct/incorrect/skipped card treatment
Topic Practice's ResultsScreen already uses, plus an optional
`bottomBuilder` extension point (deliberately no hardcoded "Back to
Home") for the next batch's trial/paywall pitch. Verified via a
temporary debug harness (both screens, both themes) — no real entry
point exists yet; wiring into Home is the next batch. Also: gave
`StorageService` an injectable `dbName` so the growing set of
ffi-backed test files (this batch added a third) stop racing on the
same real db path under `flutter test`'s default concurrency.

**Daily Test is now reachable from Home.** A second full-width card,
stacked above Topic Practice (Daily Test leads since it's the always-
free entry point — Topic Practice becomes trial/paid-gated once the
paywall exists), wired to the existing `DailyTestScreen` →
`DailyTestResultScreen` flow via `DailyTestService`; no new generation/
caching/checking logic, just the entry point and an analytics identifier
(`AnalyticsService.modeDailyTest`) to match. No entitlement/paywall
gating yet on either card — anyone can open both, same as before; that
depends on the paywall screen, which doesn't exist yet. The first-launch
Day-0 flow (PRD v2 §12.3's "Welcome → Onboarding → Daily Test → Results
→ paywall pitch" sequence) is also still pending — this batch only
covers Daily Test's placement inside the existing Home, not onboarding.
Verified on the real running app (not a debug harness) for Home itself;
the flow screens (unchanged from the previous batch) were re-confirmed
via the same temporary harness technique, since there's no way to script
a real tap in this environment — a unit test asserts the Daily Test
card's tap handler is wired distinctly from Topic Practice/Early Access
as a deterministic proxy for that gap.

**Paywall screen built and reachable from Premium — not yet gating Topic
Practice or wired into onboarding.** New `PaywallScreen`
(`lib/screens/paywall_screen.dart`), on top of the RevenueCat scaffold
service layer from the batch above. Leads with the personalized-feedback
pitch (docs/prd.md §2.1 Theme 2 / §2.2 Theme 7 — the thing every one of
the three usability testers praised unprompted), then price/trial terms
read live from `SubscriptionService.getOfferings` (new method added this
batch) rather than hardcoded, a Restore Purchases action, and Privacy
Policy/Terms links wired to a new `AppLinks` constant
(`lib/utils/app_links.dart`) that is **still empty** — no hosted pages
exist yet, confirmed, not an oversight. **This is a real pre-launch
blocker**: the App Store requires a working Privacy Policy link for any
app that collects data, and a Terms link specifically for auto-renewable
subscriptions (PRD v2 §10.1, §12.6). PremiumScreen's copy is revised to
match: it no longer claims "everything is free while we're in early
access" (PRD v2 §12.2's real split — Daily Test free, Topic Practice
3-day-trial-then-paid, Streak/Voice paid once built), and gained a "Start
free trial" button navigating to `PaywallScreen`.

Neither screen is wired to anything else yet: Topic Practice still opens
directly with no entitlement check, and the Day-0 onboarding flow (PRD v2
§12.3's "Daily Test result → paywall pitch" step, `DailyTestResultScreen`'s
`bottomBuilder` extension point from the previous batch) still isn't
connected to this screen. Both are later batches.

**A real bug found and fixed while verifying this on the iOS simulator:**
calling any `Purchases.*` method before `Purchases.configure()` succeeds
throws a *native* Swift `fatalError` (`Purchases has not been
configured`), not a catchable Dart exception — it crashed the app outright
the first time `PaywallScreen` actually called `getOfferings()` on-device,
despite `SubscriptionService`'s existing try/catch blocks (which cannot
catch a native fatal error). Since no RevenueCat API key is set at build
time, the app never calls `Purchases.configure()`, so this was live in
`hasFullAccess`/`purchasePackage`/`restorePurchases` since the RevenueCat
scaffold batch too — nothing had exercised them from the UI until this
batch's paywall screen did. Fixed with an explicit `_configured` flag,
set only after `Purchases.configure` actually succeeds; every method now
checks it and returns its safe default *before* touching the SDK, instead
of trusting a try/catch that structurally can't contain this failure.
Re-verified on-device after the fix: the paywall now shows its
"pricing unavailable" state, not a crash — this is also the state real
testing hits today, since no RevenueCat/App Store Connect product exists
yet either. Screenshotted in both light and dark mode (PremiumScreen and
PaywallScreen); `flutter analyze` and the full test suite (including new
`paywall_screen_test.dart` and updated `premium_screen_test.dart`,
against a faked `SubscriptionService` — the real one hangs indefinitely
against RevenueCat's platform channel with no engine to answer it in a
plain widget test) are clean.

**Paywall follow-up: fixed an invisible Restore Purchases button in light
mode.** A quick correction on the batch above. Restore Purchases and the
Privacy Policy/Terms links were already there, but an unstyled
`TextButton` defaults to Material 3's `colorScheme.primary` — which in
this app's light theme *is* the page's own vivid-orange background (the
exact clash `theme.dart`'s `filledButtonTheme` comment already documents
working around for `FilledButton`). Result: Restore Purchases rendered
orange-on-orange and was completely invisible in light mode, never caught
before because earlier verification only screenshotted the top of the
scrollable screen. Fixed with an explicit `foregroundColor:
colorScheme.secondary` on both that button and the legal links. The legal
links also changed from a tap-triggers-a-SnackBar pattern to a properly
disabled (`onPressed: null`) button while `AppLinks`' URLs are still
empty — simpler, and reads correctly as "not yet available" rather than
a live-looking link that does something unexpected. Also tried, then
reverted, pinning Restore Purchases/the legal links to the true bottom of
the screen via an `Expanded` split (matching `practice_screen.dart`'s
pinned-button pattern) to address a reported empty-space gap — that
actually made it worse, turning a short gap into a large deliberate-
looking void; reverted to a single flowing list, which keeps these
elements tightly grouped right after whatever pricing content precedes
them. Re-verified on-device in both themes; `flutter analyze` and the
full test suite are clean.

**The v2.1 free/trial/paid flow is now wired end-to-end (PRD v2 §12.3).**
Everything built across the RevenueCat scaffold, Daily Test, and paywall
batches above is now actually connected — routing and gating logic only,
no new screens:

- **Topic Practice gated by entitlement on Home**, live. `HomeScreen` now
  checks `SubscriptionService.hasFullAccess` on load and subscribes to a
  new `SubscriptionService.addAccessListener`/`removeAccessListener` pair
  (wrapping `Purchases.addCustomerInfoUpdateListener`, which — unlike
  every other `Purchases.*` call — is a local, SDK-config-independent
  operation, so it's safe to register even before/without a configured
  project). A trial starting or expiring updates the card without an app
  restart. Locked state reuses the old Voice Practice tile's lock-icon
  visual language (muted icon-avatar fill + a small lock glyph next to
  the title) adapted to the current full-width card layout; tapping a
  locked card opens `PaywallScreen` instead of `TopicPracticeScreen`.
- **`PaywallScreen` gained a "Maybe later" skip**, below Restore
  Purchases/the legal links, plus an `onDone` callback so where it leads
  depends on how the screen was reached: null (Home's locked card,
  Premium's CTA) just pops; the Day-0 flow below passes a real callback.
  The primary button also now repurposes itself to "Continue" once a
  trial has actually started, instead of adding a second button.
- **The Day-0 first-launch flow** (Welcome → Onboarding → Daily Test →
  Result-with-paywall-pitch → Home) is real. `FirstLaunchFlow` gained
  `dailyTest`/`dailyTestResult` steps to its existing widget-swap state
  machine — deliberately *not* routed via `Navigator.push`: this flow has
  no nested Navigator, so a `pushReplacement` (which is what
  `DailyTestScreen` normally uses to reach results) would replace the
  app's root route entirely and break the reactive `home:`-swap
  app.dart's onboarding-complete transition depends on. `DailyTestScreen`
  gained optional `onFinished`/`onExit` callbacks (null keeps its
  existing pushReplacement/pop behavior for Home's own entry point)
  specifically so the Day-0 case can reach results and handle "leave"
  through plain state changes instead. The result screen's `bottomBuilder`
  slot (built but left empty in the Daily Test screens batch) now shows a
  short pitch + "Start free trial"/"Maybe later" — tapping "Start free
  trial" pushes the real `PaywallScreen` (a genuine, poppable excursion on
  top of the still-intact root route); either skip path calls
  `FirstLaunchFlow`'s own finish, which hands the already-saved profile to
  `onComplete` exactly like plain onboarding-complete always has. Onboarding
  completing a *second* time (returning launches) is unaffected — that
  distinction was already fully carried by "does a profile exist," no new
  flag needed.
- **The daily session cap is untouched** — confirmed by diff, not just
  assumption: `practice_launch.dart`/`storage_service.dart`'s cap logic
  has zero coupling to `SubscriptionService`, so it applies the same way
  to trial and paid users as it always has, independent of Daily Test's
  own separate once-a-day generation.

Also fixed along the way: a `testWidgets()`-only hang discovered while
building `first_launch_flow_test.dart` — genuine `sqflite_common_ffi` I/O
(which works fine in a plain `test()`, per the existing ffi-backed test
files) stalls indefinitely inside `flutter_test`'s fake-async test
binding. Worked around with an in-memory fake `StorageService` for that
one test file rather than real ffi.

Verified on-device in both themes (locked Topic Practice card, Day-0
result-with-paywall screen); `flutter analyze` and the full test suite
(85 tests, including a new `first_launch_flow_test.dart` driving the
entire Day-0 flow through both exit paths) are clean.

**v2.2 B-structure batch — shipped** (`docs/prd-v2.md` §13,
`docs/design-audit.md` §5 D1–D4). Closes every item in the B-structure list
under "What's next" §2 below:
- Early Access and Paywall merged into one `PremiumScreen`; 3-day trial
  replaced by a 7-day trial from a single `SubscriptionService.trialLengthDays`
  source; two-plan (monthly/annual) pricing with a computed "Save N%" badge;
  the required App Store disclosure block; unbuilt features ("Unlimited
  Streak Mode", "AI Practice Partner") removed from the purchase surface.
- Home rebuilt from a mode-selection menu into a "today" screen: today's
  Daily Test state, Topic Practice, the 2-3 most frequent weak spots
  (locked for a free user, naming the specific weak spot via
  `PremiumScreen.sourceContext`), and a quiet Premium row — replacing the
  half-empty 3-item list left after Streak Mode/AI Practice Partner were
  removed.
- Daily Test now feeds the error profile (previously Topic Practice-only),
  tagged by source (`ErrorSource.topicPractice` / `.dailyTest`) so both
  flows aggregate into one unified weak-spot view.
- Design-audit fixes: the nav bar overlapping scrollable content (S4, fixed
  via a measured `NavBarClearance` instead of a guessed constant), the
  duplicated topic label and wrong-field card title on weak-spot cards, and
  Skip demoted from the primary button on question screens (D3).

Also shipped alongside this batch, closing the "API key safety" pre-launch
blocker: the Anthropic API key moved out of the client entirely, behind an
operation-based Cloudflare Workers proxy (`proxy/`) now on a permanent
custom domain (`api.ahmettayfur.com`); `AppLinks`' Privacy Policy/Terms/
Support URLs are real and permanent (the pages themselves still carry
placeholder copy — see the pre-launch checklist below); Turkish-keyboard
letter variants (ı/i, ş/s, ğ/g, ç/c, ö/o, ü/u) are no longer scored as
grammar mistakes. Full detail for all of the above: `docs/build-log.md`,
2026-09-05 through 2026-09-07.

**v2.2 B-polish — visual-polish tour, in progress** (`docs/design-audit.md`
§5). Started 2026-09-08, after the structure batch above per D4's own
sequencing ("polishing screens whose structure is about to change is wasted
work"). See `docs/build-log.md`, 2026-09-08 for full reasoning on each item:
- **D2 (one blue) closed.** The violet-blue `secondaryContainer` pair
  replaced with a light tint of the existing navy (`#D7E1FA` on `#0A2E70`,
  ~9.8:1 contrast) — `secondaryContainer` is now part of the same navy
  family everywhere, not a second hue. D1 (the hybrid theme / orange header
  band) is still open — no screen has it yet, and dark mode's version of
  the band (deep orange vs. neutral) isn't decided either.
- **A named spacing scale exists** (`lib/spacing.dart`, 4/8/12/16/24/32/48)
  but is a foundation only — used in the screens touched this round
  (Welcome, the session-length picker, the debug-only Theme Preview screen),
  not migrated across the rest of the app yet.
- **Brand mark replaced**: the placeholder sparkle icon
  (`Icons.auto_awesome_rounded`) is gone from the whole app, replaced by a
  hand-drawn `BrandMark` (a loupe), animated into Welcome's entrance —
  closes the design audit's "brand mark reused as a feature icon" finding.
  Meant to become the source app-icon generation draws from later.
- **Session-length picker rebuilt**: the `AlertDialog` of three tappable
  cards is now a draggable modal bottom sheet built around a single slider,
  with a custom drag-affordant thumb and the selection card's number
  redrawn as a fill-ratio dial (question count only — no duration is shown,
  since no per-session timing is measured anywhere). Closes the audit's
  "muddy scrim" finding as a side effect of the redesign.
- **Premium screen**: the "Everything in Free, plus" benefit list replaced
  with a Free/Premium comparison table; the screen was then reordered
  (measured reason: the old layout needed 1357px of scrolling past an
  844px viewport to reach "Start free trial") so price is reachable without
  scrolling; the price-card slot gained explicit loading/loaded/unavailable
  states instead of silently showing nothing when no product is connected
  (a real App Review rejection risk, not just a nicety).
- **Question screens** (`DailyTestScreen`, `PracticeScreen`): Back and
  Close moved from the bottom footer into the app bar (40x40 bordered
  circles, top-left/top-right); Skip moved beside the primary button as a
  narrower `OutlinedButton` instead of a text link below it, still demoted
  per D3. Back's slot is preserved as an invisible placeholder on question 1
  (no valid Back destination) so the centered title never shifts between
  questions — verified by a widget test.

Known debts opened by this round, not yet fixed (`docs/build-log.md`,
2026-09-08 for detail): the comparison table's `FittedBox(scaleDown)`
header fix works against Dynamic Type; light theme's disabled
`FilledButton` (onboarding's "Continue" is the concrete case) is still hard
to read on the orange scaffold, expected to be resolved by D1 rather than
patched individually; the widget-test suite has no coverage of Welcome's or
the length picker's real (non-reduced-motion) animation path, since every
test that reaches them has to force reduced motion to avoid `pumpAndSettle`
hanging against their infinite ambient animations.

**2026-09-10 — App icon generated; the remaining B-polish findings (D5)
closed; D1's test gap closed.** Three independent pieces of work:

- **App icon.** A real 1024px source image (a loupe/magnifying glass on
  navy, matching `BrandMark`'s identity) replaced Flutter's placeholder
  icon and its stale `Contents.json` (still referencing default filenames).
  Generated every iOS size from the one source via `flutter_launcher_icons`
  (iOS only — no Android release track) rather than hand-maintained sizes;
  `remove_alpha_ios: true` matches the source's own lack of an alpha channel
  and baked-in corner rounding. Verified with a clean build: the real icon,
  not the Flutter default, shows on the simulator's home screen.
- **D5 — the remaining contrast/states and consistency findings, closed in
  one round.** See `docs/design-audit.md` D5 and the B-polish checklist
  above for the full list (nine items, four batches): the skipped-answer
  "CORRECTED" box now reads neutral; the avatar palette gives all eight a
  real, distinguishable hue; locked cards get a shared pill instead of a
  near-invisible lock glyph; Onboarding's disabled-button tracking closed
  with no further code; one back-button treatment app-wide (plain chevron,
  chosen after an on-device two-direction comparison); Daily Test's
  progress bar dropped in favor of the counter it duplicated; Settings'
  Profile/Data lost their `Card` wrap; the topic list's icon alignment
  fixed.
- **D1's own test gap closed.** Seven screens moved onto `BrandScaffold`
  during D1, `ResultScoreBand` was written from scratch, and none of it had
  a test — the count stayed at 227 throughout. Added `brand_scaffold_test.dart`
  (both constructor asserts actually throw; `isTabRoot` correctly chooses its
  padding source), `results_screen_test.dart` (Topic Practice's own results
  screen had no test file before this), a `ResultScoreBand` check added to
  `daily_test_result_screen_test.dart`, and `mistake_breakdown_test.dart`
  (the skipped-answer regression). 237 tests passing, up from 227.

Every code change this round was verified on-device in both themes via a
temporary, untracked debug harness, deleted before each commit — same
technique D1's own batches used. `flutter analyze` and the full test suite
are clean throughout.

**2026-09-15 — Free tier practice quota: closed the "Practice this" leak.**
A diagnosis batch (`docs/build-log.md`, same date) found that
`launchPracticeSet` — the one function every real practice-set generation
goes through — checked only the blanket `dailySessionLimit` cost guardrail,
never entitlement. Entitlement was only ever checked as a navigation guard
inside `HomeScreen`'s own tap handlers, so `ReviewScreen`'s weak-spot →
`WeakSpotDetailScreen` → "Practice this" path reached real, billed
generation with no gate at all — already noted and deferred in this file's
2026-09-05 entry, closed now:

- **The gate moved into `launchPracticeSet` itself**, as required,
  non-optional logic — both real callers (`TopicPracticeScreen`,
  `WeakSpotDetailScreen`) now pass a `subscriptionService` the function
  always consults, no boolean any caller can use to skip it.
- **New policy:** `hasFullAccess == true` → unchanged, only
  `dailySessionLimit` applies. `hasFullAccess == false` → checked against a
  new, independent daily counter, `StorageService.freeDailyPracticeLimit`
  (`1`/day) — the free tier's one real "Practice this" session, separate
  from `dailySessionLimit` and from Daily Test's own cache, matching PRD v2
  §12.2's tiers. Limit reached → the same `PremiumScreen` Home's locked
  card already opens, not a new dialog.
- **A free session skips the length picker and always generates the
  shortest set** (`PracticeLength.quick`, 3 questions) — the previous
  behavior let a free session pick the most expensive length for free.
  Premium's picker is unchanged.
- **Storage:** a new `free_practice_usage(day, session_count)` table,
  deliberately not sharing `daily_session_usage` or `daily_test_sets` —
  same local-calendar-day reset convention as both (`StorageService`'s
  `_todayKey()`, now backed by an injectable test clock,
  `clockForTesting`, added in this batch for exactly this kind of
  day-rollover test).
- **Quota is consumed on generation success**, at the same moment
  `recordSessionStarted()` already fires — a failed generation never burns
  the day's one free session.
- **Onboarding is unaffected by design**: the Day-0 Daily Test never reads
  or writes `free_practice_usage` — verified by a new test asserting
  neither method is ever called during that flow, not just assumed from
  reading the code.
- **Review's weak-spot list stays visually unlocked** (`WeakSpotCard.locked`
  still defaults to `false` there) — reading your own past mistakes is
  genuinely free; only the practice action on the detail screen is gated.
  `WeakSpotDetailScreen`'s bottom action now has two states: an enabled
  button with a caption naming the remaining free count when quota is
  available, or — when it's exhausted — a locked row in the exact visual
  language `HomeScreen`'s locked Topic Practice card already uses (reusing
  `LockedPremiumPill` directly, not a new treatment), tapping through to
  `PremiumScreen` with `sourceContext` naming the weak spot.
- **Checked, not found:** no existing UI copy (`PremiumScreen`/paywall
  included) claims "unlimited" anywhere — grepped across `lib/` to confirm
  before writing this batch's own copy, which also avoids the word, since
  premium is actually bounded by `dailySessionLimit` (10/day then, 5/day
  since 2026-09-21), not unlimited.
- **Analytics:** two new events, `free_practice_used` and
  `free_practice_quota_exhausted`, so post-launch data can actually say
  whether `freeDailyPracticeLimit = 1` is the right number, not just
  whether the gate exists.
- Full test suite: 251 tests passing (up from 237), including new coverage
  of the choke point through both real entry points, the exhausted-quota UI
  state, the day-rollover seam, and the onboarding-independence invariant
  above. `flutter analyze` clean.

**Open decision, found while implementing the above, not resolved —
proxy quota headroom for premium.** A full premium Topic Practice session
costs **2** proxy quota units (`generate_practice_set` + `score_answers`,
`proxy/src/index.ts`), and `dailySessionLimit` allows **10** sessions/day —
up to 20 units against a `DEVICE_DAILY_LIMIT` of **15**
(`proxy/wrangler.jsonc`). A premium user practicing normally can hit the
proxy's per-device wall (a generic "come back tomorrow" message, not
anything premium-aware) before ever reaching their own local cap. Needs a
decision before launch: raise `DEVICE_DAILY_LIMIT` to ~25, or lower
`dailySessionLimit` to 7. Not resolved here — recorded so it isn't lost.
**Resolved 2026-09-21:** `dailySessionLimit` is now 5 and
`DEVICE_DAILY_LIMIT` stays 15 — see the 2026-09-21 launch-checklist note in
"Launch scope" above.

**2026-09-15 — Avatar carousel: fixed the layout bug, replaced the picker
and the avatar set.** Diagnosed first, confirmed, then fixed
(`docs/build-log.md`, same date): `AvatarTile`'s `selected` state used to
wrap the same fixed-size box in an extra border+padding container,
growing the tile by 5px only while selected — enough to make Settings'
avatar `Wrap` recompute its line breaks and visibly reflow everything
below it whenever the last tile in a row was tapped. The fix is
structural, not cosmetic: selection state now never changes any widget's
layout footprint, anywhere in this app's avatar UI.

- **The picker is a `PageView` carousel now** (`AvatarCarousel`,
  `lib/widgets/avatar_carousel.dart`), not a grid — the center avatar is
  the selection, no separate confirm button. Neighbors peek from the
  edges at reduced scale/opacity, continuously tracking drag position.
  Settling (not mid-drag) fires a haptic, a brief pop on the center tile,
  and reports the change — the same widget embedded inline in
  `OnboardingScreen` (above the name field, not a new step) and pushed
  as `AvatarPickerScreen` from Settings (autosaves, debounced, no Save
  button of its own).
- **Selection itself is a single ring layer behind the `PageView`**
  (`AnimatedContainer`, recolored on settle, never resized) — the actual
  fix, not just a different picker shape. `AvatarTile` lost its
  `selected` parameter entirely rather than keeping a fixed-but-unused
  knob that caused a real bug once already.
- **The avatar set is illustrated now**, twelve assets
  (`assets/avatars/avatar_01.webp`–`avatar_12.webp`, registered as a
  folder), replacing the previous eight emoji-on-flat-color avatars.
  `Avatar` (`lib/models/avatar.dart`) is a plain indexed class generated
  from a single `count` constant, not an enum — adding avatar_13 is
  "drop the file, add its label, bump the constant," not a new case
  touching every switch. Ids persist as `avatar_NN`; an unrecognized or
  legacy id (`Avatar.fromJson`) falls back to `null` — no avatar set,
  never a crash — which is exactly what happens to a real device's
  pre-existing profile carrying an old, now-meaningless id like `fox`.
- **The ring color palette carried forward, renamed and expanded** — see
  `docs/design-audit.md`'s own updated status note on the "named
  exception" section for the full reasoning; ten colors now
  (`avatarRingColor1`–`10`), cycling across the twelve avatars, verified
  by a regression test that none of the three green-illustrated avatars
  (Frog, Dinosaur, Turtle) ever lands on a green-ish ring.
- **`Hero`** ties the picker's centered avatar to Settings' own preview
  row for the return flight; onboarding's inline carousel has no such
  transition (no push/pop boundary to animate across).
- Verified on-device in both themes (Settings' preview row, the picker
  carousel, onboarding's embedded carousel) via a temporary, untracked
  debug harness, deleted before commit — same technique earlier batches
  used. `flutter analyze` and the full test suite (277 tests, up from
  251) are clean.

**2026-09-15 — Home: time-of-day greeting + bigger avatar.**

- **The greeting is time-of-day now, three slices, local device clock:**
  "Good morning" (05:00–11:59), "Good afternoon" (12:00–17:59), "Good
  evening" (18:00–04:59) — replacing the fixed "Welcome back" copy.
  Deliberately three slices, not four: no "Good night," since that's an
  English farewell, not a greeting, on an app that teaches English.
  `timeOfDayGreeting` (`lib/utils/greeting.dart`) is a pure function over
  a concrete `DateTime`, and `HomeScreen` gained an injectable `clock`
  (`DateTime Function()`, defaulting to `DateTime.now`) so the boundary
  tests don't depend on when the suite happens to run. The "$word, $name"
  shape is exactly the old "Welcome back, $name" pattern, generalized —
  plus one case that copy never needed: an empty name (the field itself
  is a non-nullable `String`, but nothing enforces non-empty) now renders
  the greeting word alone, no dangling comma.
- **Not refreshed purely by time passing while the app sits open** —
  checked first, not built around blindly: `HomeScreen` (and the rest of
  the app) has no `AppLifecycleState` hook to attach a refresh to today,
  and per this batch's own instruction, none was added for this alone
  (no new lifecycle observer, no polling `Timer`). The greeting still
  recomputes on every rebuild Home already does for other reasons (Daily
  Test/weak-spot loads, entitlement changes), so it's rarely stale in
  practice, but a user who opens the app at 11:58 and leaves it
  foregrounded with nothing else happening won't see it flip at 12:00 on
  its own. **Found and flagged as a separate, more important gap while
  checking this:** Daily Test's own day-rollover likely has the exact
  same non-issue — `_loadTodaysDailyTest` only runs from `initState`,
  so a device open across local midnight wouldn't show a new day's test
  as available until the next natural rebuild either. Not fixed here —
  recorded in "What's next" below since it's a real product gap, not a
  copy nicety.
- **The avatar next to the greeting is bigger:** radius 22 → 30 (44pt →
  60pt tile). Measured before changing it, per this batch's own
  instruction: 44pt was already exactly at the ≥44pt touch-target
  minimum, so this only grows that margin, never puts it at risk.
  Confirmed by reading `BrandScaffold` itself (not assumed) that this row
  lives in Home's scrollable body (`children`), not its app bar/band —
  so the band's own height is untouched by the avatar's size, nothing to
  report there. Confirmed by inspection that Settings' own avatar row
  (which does carry the `Hero` to `AvatarPickerScreen`) is a separate
  call site at its own radius, untouched by this change. Verified at 2.2×
  text scale with a deliberately long name: the existing `Flexible` +
  `maxLines: 1` + `ellipsis` treatment (already there before this batch)
  handles it correctly — the greeting truncates, the avatar keeps its own
  fixed size, nothing overflows or clips vertically.
- **Checked, left as-is (from the previous batch's own explicit
  instruction, not an oversight): the avatar ring palette is 10 colors
  cycling across 12 avatars, not 10 distinct-per-avatar or 12 colors.**
  `avatarRingColor` computes `(avatar.index - 1) % 10`, so avatar 11
  (Giraffe) reuses avatar 1's color (orange) and avatar 12 (Hedgehog)
  reuses avatar 2's color (yellow-green) — confirmed intentional
  cycling, not a bug, from the prior batch's own instruction to expand
  the palette "to 10," not to 12. Left unchanged per this batch's own
  "if intentional, leave it" instruction.
- Verified on-device in both themes via a temporary, untracked debug
  harness (also checked large Dynamic Type there), deleted before
  commit. `flutter analyze` and the full test suite (285 tests, up from
  277) are clean.

**2026-09-15 — Avatar picker screen: Done button, copy, bigger
avatars.** Scoped to Settings' full-screen "Change avatar" picker only —
`AvatarCarousel`'s shared physics, pop, haptic, ring-color transition,
`Hero`, and onboarding's own embedded use are untouched by design (the
task's own explicit boundary), and are verified untouched, not just
assumed.

- **A "Done" button, pinned at the bottom** (the app's own default
  `FilledButton` style, no new one invented — its theme-wide
  `minimumSize: Size.fromHeight(52)` already clears the 44pt touch-target
  minimum with no extra work). It only pops the screen — no new
  persistence logic. The autosave-on-settle behavior (debounced) and
  `dispose()`'s existing "flush a pending debounce before leaving"
  safeguard were already exactly what's needed for this: since Done and
  the back button both just trigger the same pop → dispose() path, they
  were already equivalent exit paths by construction the moment Done's
  handler is nothing but `Navigator.pop()`. No double-write risk to guard
  against separately.
- **Copy changed, no box to remove:** "Swipe to choose your avatar" →
  "Pick your study buddy". Checked first, per the task's own instruction:
  there was no card/container around the old text to remove — it was
  already plain `Text`. The "robotic" complaint was really about
  typography, not a phantom box: it's now `titleMedium`/w700 off the
  theme (the same role Onboarding's own prompts already use), no new
  color value or font.
- **The picker's center avatar is bigger — but less than a first attempt,
  and the reduction was deliberate, not a compromise:** radius 56 → 64,
  `viewportFraction` 0.45 → 0.5 (`AvatarCarousel` gained these as
  optional constructor parameters, defaulting to the original values so
  `OnboardingScreen`'s call site is untouched). A first pass tried 80/0.6
  — visibly bigger — but growing `viewportFraction` alongside the radius
  actually *shrank* how much of each neighbor peeks in (a wider page slot
  leaves less of the next page's own width exposed at the screen edge);
  worked out numerically before landing on 64/0.5, which keeps a neighbor
  at least half-visible at both 375pt (iPhone SE) and 320pt width with
  its ring still strictly narrower than its own page at either size — the
  actual constraint (neighbors must keep signaling "there's more to
  swipe to"), not "as big as will fit." Verified on a real 375pt
  simulator; 320pt is calculation-only — Xcode's current iOS runtime no
  longer supports creating a 1st-generation iPhone SE (320pt) simulator
  at all, confirmed by trying.
- Tests added: Done pops and keeps the swiped avatar saved (including
  mid-debounce, via the same flush `dispose()` already provided); tapping
  Done after the autosave already fired doesn't write a second time; Done
  and the back button produce the identical saved result; onboarding's
  embedded carousel has no Done button.
- Verified on-device in both themes, on both a 375pt (iPhone SE) and a
  larger (iPhone 17) simulator, plus a direct re-check that onboarding's
  own screen is pixel-identical to before. `flutter analyze` and the full
  test suite (289 tests, up from 285) are clean.

**2026-09-15 — Avatar asset fix: the vertical-line bug, Dinosaur → Crab.**
A thin vertical line reported inside the onboarding carousel's selection
ring, on the Dinosaur avatar specifically. Diagnosed first, against real
pixel data rather than the widget tree: `avatar_07.webp`'s columns 1–3
carried a translucent stray stripe running the asset's full height,
present in every other render site too (Home's greeting, Settings'
preview row) since it's in the shipped file's own pixels — the colored
selection ring some render sites lack was never the cause. Full
diagnosis, including the render- and layout-level hypotheses ruled out
along the way: `docs/build-log.md`, same date.

- Dinosaur was retired and replaced with a new Crab illustration in the
  same avatar_07 slot (a manual asset swap, verified clean on-device
  before this batch); `Avatar`'s numbering is by asset slot, not
  identity, so no index/count change was needed, only the semantic label
  VoiceOver/TalkBack reads.
- The replacement asset didn't match this project's own avatar pipeline
  (1024×1024 and ~4× the file size other avatars run at) — resized to
  508×508 and re-encoded lossy quality 90, this set's own established
  convention, landing back at a normal ~33KB.
- **New regression test, `avatar_asset_edges_test.dart`, decodes every
  bundled avatar's real bytes and checks its outermost edge for stray
  alpha** — the only path that could actually have caught the original
  bug, since it lived in the shipped pixels, not in any widget's
  behavior. Writing it surfaced two further, much smaller pre-existing
  defects (a couple of imperceptible alpha=1/255 pixels each on
  `avatar_01.webp`/`avatar_03.webp`, unrelated to Dinosaur/Crab) — fixed
  rather than carved out as exceptions to the new test. First fixed via
  the same lossy quality-90 re-encode as avatar_07, then corrected on
  review to a lossless re-save from each file's own pre-fix original
  that changes only those exact pixels (verified by diffing decoded
  pixel arrays) — the lossy pass re-compressed every pixel for a 1px
  fix, the wrong tool even though no visible difference resulted. Both
  files are now noticeably larger than the lossy set's usual range as a
  result (avatar_01: 31.5KB → 84.1KB; avatar_03: 42.7KB → 84.9KB),
  accepted deliberately for pixel-exact correctness. See
  `docs/build-log.md`'s same-date entry for the full detail.
- `docs/build-log.md`'s own 2026-09-15 "avatar picker: layout-bug
  diagnosis, carousel replacement" entry (and this file's matching
  passage above) still say "Dinosaur" — left alone deliberately, same
  don't-rewrite-history call already made for the "AI Voice Practice" →
  "AI Practice Partner" rename (2026-09-05): they correctly describe the
  app as it was named at the time.
- `flutter analyze` and the full test suite (290 tests, up from 289) are
  clean.

**2026-09-15 — Avatar presentation: dropped the colored ring, transparent
background + ground shadow.** `docs/design-audit.md`'s avatar
named-exception section is now closed (status block added, not
rewritten): the ring-color palette that section carried forward twice
before is deleted outright, not renamed or expanded a third time.

- **Inventory confirmed the colored circle was drawn in exactly one
  place** — `AvatarCarousel`'s own selection-ring layer — before touching
  anything: `AvatarTile` (Home's greeting, Settings' preview row) already
  had no background circle at all.
- **Ring and `avatarRingColor1`–`10` deleted**, along with
  `avatar_ring_color_test.dart`. Selection now reads purely from the
  carousel's existing paint-only scale/opacity differential (full
  size/opacity centered, ~0.8 scale/~0.5 opacity faded either side,
  continuously interpolated by drag position) — already implemented, not
  new work, just no longer backed by the ring as the more obvious cue.
  `radius`/`viewportFraction` untouched on both call sites, so the
  previous batch's measured neighbor-peek geometry at 375pt/320pt still
  holds.
- **Semantics gained an explicit `selected` flag** on the carousel's
  per-page `Semantics` node — checked first, not assumed to already
  exist; nothing previously marked the centered avatar as selected for a
  screen reader.
- **Ground shadow lives inside `AvatarTile` itself**, so the carousel,
  Home (60pt), and Settings' preview row all get it from one change: a
  blurred ellipse sized as a formula of `radius` (width `×1.3`, height
  `×0.32`, blur `×0.16`), not four hand-tuned constants. Skipped for the
  null-avatar placeholder, which already reads as a filled UI element,
  not a floating illustration.
- **Theme-aware color, measured not guessed:** a black shadow works in
  light mode (~1.6–1.8 contrast at 20–25% alpha against `#FAF3EC`) but is
  nearly invisible in dark mode (~1.16 contrast even at 65% alpha against
  the near-black `#1C1B1F`) — dark mode uses white at 11% alpha instead,
  landing both themes at a comparable ~1.4–1.6 contrast.
- **A real bug found while building this, not by inspection:** wrapping
  `Image.asset` in a `Stack` (for the shadow layer) made it loosely
  constrained instead of tightly sized by the tile's own `SizedBox`,
  which collapsed it to zero size for any frame before the asset decodes
  — invisible in normal use but caught by a widget test's hit-test
  warning at one specific viewport size. Fixed with explicit
  `width`/`height` on the `Image.asset`; new regression test asserts the
  illustration's own rect, not just the tile's outer box.
- Legacy/unknown avatar ids unaffected, confirmed by the existing test
  suite passing unchanged.
- `flutter analyze` and the full test suite (291 tests, up from 290) are
  clean. Full detail: `docs/build-log.md`, same date.

**2026-09-15 — Settings' avatar picker: bigger center avatar, second look
after the ring's removal.** Measured first: the tile's own box has no
layout slack to reclaim (a square asset in a square box, no
letterboxing) — what reads as empty space is padding baked into each
illustration, and it varies too much (63%–99% fill ratio across the set,
Snail at near-zero margin) to safely crop/zoom uniformly. Grew the slot
instead.

- **The previous batch's "64/0.5 is the largest radius that keeps the
  neighbor half-visible" turned out to be wrong, corrected by measuring
  the real widget tree**: the neighbor's visible fraction depends only on
  `viewportFraction`, not `centerRadius` at all (exactly 50% at vf 0.5,
  any radius, both 320pt and 375pt). The real limit is the settled tile's
  own diameter fitting its own page slot at 320pt, giving `centerRadius
  <= 80`.
- **Center avatar: 128pt → 160pt diameter (+25%)**, `viewportFraction`
  unchanged at 0.5. Neighbor's own peek width: 51.2pt → 64pt, identical
  at both 320pt and 375pt (it depends on radius and `neighborScale`
  alone, not screen width — no longer needing separately-recomputed
  numbers per width now that the ring's own extra constraint is gone).
  `neighborScale` (0.8) untouched — unnecessary once the real constraint
  was corrected.
- Scoped to exactly `avatar_picker_screen.dart`'s own constant —
  `AvatarCarousel`'s defaults (what onboarding's embedded carousel uses)
  untouched, confirmed by diff.
- New regression test group asserts ≥50% neighbor visibility at both
  widths against the real `AvatarPickerScreen`, re-measured rather than
  pinned to today's constants.
- `flutter analyze` and the full test suite (293 tests, up from 291) are
  clean. Full detail: `docs/build-log.md`, same date.

**2026-09-15 — Home avatar → Settings' avatar picker: a real transition.**
Checked first: Home's avatar tap was an `IndexedStack` tab swap, not a
`Navigator` route change — `Hero` cannot animate across that at all,
having no push/pop transition to run during. Stopped and presented
options rather than assuming an answer; landed on a third path beyond
the two originally offered.

- Home's avatar now pushes the *existing* `AvatarPickerScreen` route
  directly (the same screen Settings' "Change avatar" already opens),
  instead of switching tabs — a real `Hero` flight to the carousel's
  centered avatar, with the tab model itself untouched everywhere else.
- `AvatarPickerScreen` gained a required `heroTag` — `avatarHeroTag`
  (Settings', unchanged) and a new `homeAvatarHeroTag`, kept deliberately
  distinct: Home and Settings are both permanently mounted inside
  `app.dart`'s `IndexedStack`, so sharing one tag would mount two Heroes
  with the same tag simultaneously the instant either entry point pushed
  this screen — a Flutter crash, not just an edge case. New test confirms
  exactly one tagged Hero exists at a time, including mid-drag.
- **A real flicker risk found and fixed, not assumed away:** the pending-
  debounced-change flush used to live only in `dispose()`, which doesn't
  run until *after* a pop's transition finishes — too late for a Hero
  flight, whose destination needs the new avatar showing *before* the
  flight starts. Fixed with `PopScope` routing every exit path (Done,
  back chevron, system back gesture) through one flush-then-pop method.
  This is a fix to the *shared* `AvatarPickerScreen` widget, so it also
  closes the same latent risk in Settings' own existing flow — Settings'
  entry point and destination are otherwise unchanged, confirmed by diff.
- The ground shadow needed no special handling for the flight: it's
  painted inside `AvatarTile`, which is what `Hero` wraps on both ends,
  so it scales with the illustration automatically.
- `MediaQuery.disableAnimationsOf` branches the push itself (a
  zero-duration `PageRouteBuilder` vs. the normal `MaterialPageRoute`) —
  Flutter route transitions don't respect this setting on their own.
- `flutter analyze` and the full test suite (299 tests, up from 293) are
  clean. Full detail: `docs/build-log.md`, same date.

**2026-09-15 — Premium screen redesign, underway.** Moving the Premium
screen from a text-heavy list toward a visually stronger layout (hero
avatar visual, a highlighted Premium column, a fixed bottom CTA) —
Duolingo Super's *pattern*, not its look, over several small batches
each verified and committed separately. Full diagnosis and every
measurement below: `docs/build-log.md`, same date.

- **Batch 0 (diagnosis, no code):** found a real factual error in the
  comparison table (free users actually get 1 targeted weak-spot
  practice/day, the table said "—"); measured the compliant highlighted-
  strip color (`onSecondaryContainer` on `secondaryContainer` — 9.79:1
  light, 7.13:1 dark) and caught that the *current* premium checkmark
  color would fail at only 2.53:1 in dark mode; confirmed a debug-only
  pricing fixture is buildable from `purchases_flutter`'s own `const`
  constructors, no platform channel needed; found the CTA isn't actually
  pinned today (a real structural gap, not cosmetic); confirmed the
  paywall's own analytics surface is empty today (no internal events
  exist yet) so nothing existing is at risk.
- **Batch 1 (debug-only pricing fixture) — shipped.**
  `SubscriptionService.getOfferings()` now checks a `debugFixtureOffering`
  first, the same `kDebugMode`-gated/tree-shaken-in-release shape as the
  existing entitlement override. `buildDebugFixtureOffering()` builds PRD
  v2 §13.2's stated prices ($5.99/month, $49.99/year, 7-day trial — the fixture
  models the annual offer) with
  only the raw numbers fixed — the annual plan's per-month figure is a
  real `49.99 / 12` computed in code, so `PremiumScreen`'s existing
  "Save %" math actually runs against it. Settings > Developer gained a
  session-only "Preview paywall pricing" toggle (never written to
  storage, unlike the entitlement override next to it). 312 tests
  passing (up from 299), `flutter analyze` clean.
- **Batch 2 (structure, comparison rows, the Premium strip) — shipped.**
  Replaced `BrandScaffold`'s implicit `ListView` with a scrollable middle
  + a genuinely fixed footer (`AvatarPickerScreen`'s own shape) — the
  actual fix for Batch 0's "the CTA isn't really pinned" finding. Footer
  content varies correctly by state (loading/loaded/pricing-unavailable/
  purchase-error), measured at all four required size×textScale
  combinations (worst case 320×568 @1.3×: 174.0pt, 30.6% of viewport —
  well clear of the 40% stop threshold). Comparison table merged from
  five rows to four (the two overlapping "—" rows became one, correctly
  showing free = "1 a day" from the real quota constant). The Premium
  column is now one continuous highlighted strip
  (`secondaryContainer`/`onSecondaryContainer`, not `secondary` — which
  measured only 2.53:1 in dark mode); confirmed the selected plan card
  still reads as selected next to it via its own border width, not
  assumed. `FittedBox(scaleDown)` removed from "PREMIUM", replaced by an
  actually-measured column width. Found and fixed a real `IntrinsicHeight`
  + `Expanded` reliability bug along the way (a genuine overflow at 2.0×
  text scale, not hypothetical) by switching to pre-measured fixed row
  heights. 322 tests passing (up from 312), `flutter analyze` clean.
- **Batch 3 (hero avatar group, sub-headline) — shipped.** `PremiumScreen`
  gained a required `StorageService` to read the real user's avatar
  itself (all four call sites already held one for other reasons, so
  this is one added argument each, not a new dependency) instead of
  threading `Avatar?` by hand through two plain-function call sites that
  don't carry profile state. `_AvatarHero`: the user's own avatar
  front-and-center, four others layered behind it (picked deterministically
  by a fixed index offset, not `Avatar.random`), no `Hero` wrapper at all
  (no push/pop partner here, and wrapping would risk colliding with
  Home's/Settings' own avatar Hero tags). A real accessibility gap was
  found and fixed while building it, not just caught in review: a bare
  `AvatarTile` carries no semantic label on its own, unlike
  `AvatarCarousel`'s pages — fixed by wrapping the whole decorative group
  in one clear `Semantics` node instead of exposing five separate,
  mostly-noisy ones. Sub-headline "Practice the mistakes you actually
  make." added below the existing contextual headline. 327 tests passing
  (up from 322), `flutter analyze` clean.
- **Batch 4 (paywall analytics) — shipped, closes this redesign.** Four
  new PII-free events on `AnalyticsService` — `paywall_viewed {source}`,
  `paywall_dismissed {source, method}`, `purchase_started {plan}`,
  `purchase_result {plan, outcome}` — `source` matching the four real
  push call sites Batch 0 confirmed (home, weak_spot_quota,
  practice_launch, onboarding). The dismissal event needed real design
  work: a system back gesture reaches a pop without going through either
  of the screen's own buttons, solved with an observing (not blocking)
  `PopScope` plus an `_exitHandled` flag so it never double-logs whatever
  a button's own `onPressed` already tagged, and a completed purchase's
  "Continue" logs no dismissal at all (already covered by
  `purchase_result`). `modeSelected`/`freePracticeQuotaExhausted`
  untouched, confirmed by diff. 340 tests passing (up from 327),
  `flutter analyze` clean.

**2026-09-16 — Premium screen: on-device review fixes, two commits.**
The four-batch redesign above (eee79c2–1a1291e) was checked on-device and
not visually accepted — overlap and density problems, not caught by the
batches' own tests. Full detail: `docs/build-log.md`, same date.
- **Fixes (`dc5a955`):** the fallback headline ("Personalized feedback,
  not a feature list") traced to no spec doc — `git log -S` shows it was
  written directly as ad copy in `4d327b7`, the commit that first added
  the standalone Paywall screen, despite that commit's own message citing
  `docs/prd.md`. Removed, replaced by a plain "Unlock personalized
  feedback[, on `<topic>`]". Also fixed: the weak-spot row's free-quota
  text ("1 a day") shared a flex factor with the row label, which let it
  silently overflow its row's own fixed height — the root cause is that
  ordinary overflow tests only catch a *horizontal* `RenderFlex`
  overflow, never a vertical one, so this shipped undetected; new
  geometry tests (checking rendered rects directly, not just absence of
  an exception) now guard it. The FREE header and the checkmarks/dividers
  below it now share one measured column, hence one x-center.
- **Visual pass (`7e54966`):** hero avatar group shrunk (120pt → 90pt)
  and spacing tightened so the loaded state's plan cards clear the fixed
  footer without scrolling at 393×852; the selected plan card no longer
  fills with the same `secondaryContainer` the comparison table's Premium
  strip uses (fill stays plain surface, selection reads from the border +
  a check mark instead); the dark-mode Premium strip fill changed from
  the saturated `secondaryContainer` navy to the calmer
  `surfaceContainerHighest` (9.34:1 contrast for the existing
  `onSecondaryContainer` text, up from 7.13:1 — light mode untouched);
  "What's free, trial, and paid" moved below the table, centered, small;
  the pricing-unavailable footer's top border no longer shows when
  "Maybe later" is the only thing in it.
- **Known debt, not fixed:** at 375×667, the plan cards still extend
  below the fixed footer's own top edge (measured: footer top at 507pt,
  cards' own bottom at ~706–710pt) — a scroll is still needed there. Only
  393×852 was brought fully above the fold this round.
- 355 tests passing, `flutter analyze` clean.

**2026-09-16 — iOS minimum deployment target: 13.0 → 15.0.** The
installed Xcode toolchain rejects a simulator build below iOS 15
outright. Pure build-setting change (`9ac79d9`) — this project has no
`ios/Podfile` (Swift Package Manager, not CocoaPods), so the fix is the
three `IPHONEOS_DEPLOYMENT_TARGET` occurrences in
`Runner.xcodeproj/project.pbxproj`; no dependency versions moved
(`pubspec.lock` diff is empty). Every native plugin's own minimum is
well under 15.0. Full reasoning and the separate toolchain bug found
while verifying it: `docs/build-log.md`, same date (`9ac79d9`, `9f04956`).

---

## What's next

**MVP is closed. Work continues in v2 — see `docs/prd-v2.md`.**

### Decision: "make the MVP try-able" dropped (2026-08-24)
The previous next-item was distributing the MVP build so people could try it.
Dropped in favor of going public with v2 instead: seven people have already
used the core loop in person, and another small private round would mostly
repeat what we know. A public launch is the more useful test, and it needs
what a bare practice loop lacks — a reason to return, an identity, a
commercial frame. Recorded as a deliberate reversal, not silent drift.

**Decision (2026-08-24): lean launch.** Public launch now comes *before*
streak mode, not after — see `docs/prd-v2.md` §10 for the reasoning
(launching exists to get real retention signal on the validated core loop;
building a zero-evidence bet before measuring that defeats the point).

### 1. Pre-launch checklist
See `docs/prd-v2.md` §10.1. Done: daily session cap, privacy note, minimal
analytics (a real Firebase project has been connected since 2026-09-13 —
see "Current wiring" above; this line used to read "code scaffold — no
Firebase project connected yet, needs an interactive `flutterfire
configure` run against a real account", which is stale now), and now
the full v2.1 free/trial/paid flow (previous section) — functionally
complete, but not launch-ready. Still open: distribution channel
decision, device coverage, feedback channel (API key safety is closed, see
below) —
several of these are open decisions, not just tasks. **Blocker status, reconciled 2026-09-05** (previous
entries here were partly stale and partly optimistic — corrected against what
actually exists):
- **RevenueCat / App Store Connect: in progress since 2026-09-07** (this
  bullet previously read "nothing done"). What is actually true now:
  - **Legal entity** completed in App Store Connect — registered as an
    individual (gerçek kişi), which fixes the US tax form as **W-8BEN**.
  - **Paid Apps Agreement (Schedule 2)** accepted; Contact Info and Tax Forms
    submitted and **awaiting Apple's approval**.
  - **Bank account: the one open item.** Deliberately not submitted yet — see
    the tax note below. Until it clears, the agreement cannot go Active and no
    subscription product can be sold.
  - **EU DSA trader status** declared and contact details submitted. Trader
    contact info is displayed publicly on the EU product pages, so the support
    address is `support@ahmettayfur.com` rather than a personal inbox.
  - **`support@ahmettayfur.com` now works** — Cloudflare Email Routing on the
    existing zone, forwarding to a personal inbox. Receive-only: replies still
    leave from the personal address until an SMTP sender is added. Not urgent,
    but it is a real gap for a public support address.
  - **Updated 2026-09-14** (this bullet previously read "Still nothing done:
    no RevenueCat account, no App Store Connect app record, no products"):
    the RevenueCat key is set in `config/*.json`, the App Store Connect app
    record exists, and Firebase is connected. **Subscription products still do
    not exist** — they cannot be created until Paid Apps is Active.
  - **Bank account submitted 2026-09-14** — a personal USD account at Ziraat,
    pending Apple's verification; Paid Apps stays *Pending User Info* until it
    clears. This reverses the "deliberately not submitted yet" line above; the
    reasoning is in the reversal note below. **Update 2026-09-15: cleared.**
    Paid Apps Agreement went Active the day after submission — see "Current
    wiring" near the top of this file. Subscription products still do not
    exist (unblocked now, not yet created).
  - **Subscription products created and Ready to Submit — 2026-09-17.** Full
    detail in "Current wiring" above. **Pre-submission to-do, not yet
    done:** both products' App Review screenshot and review notes are
    still placeholders (a simulator capture of the debug fixture offering,
    and notes stating US prices) — replace or re-check both before the
    first submission that includes them.
  - *(Resolved: Active 2026-09-22, see "Current wiring".)*
    **EU DSA trader verification — In Review** (Apple case 102955281512). The
    Turkish utility bill submitted as address proof was rejected **for
    language only**, not content: Apple's document review reads nine
    languages, Turkish not among them. A signed, self-certified English
    translation was uploaded with the Turkish original attached, translation
    first, page 1 only — the page Apple already had; adding unseen pages would
    have restarted content review. While preparing it the declared trader
    address turned out to be incomplete (street name plus an unverifiable site
    name, no neighbourhood, building or apartment number). A membership
    information change request was filed to match the invoice exactly, using
    the corrected address — and the correction was disclosed to Apple in the
    reply on the case rather than left for the reviewer to find. This address
    is published publicly on EU product pages. **Superseded 2026-09-16 — see
    "Current wiring" above and `docs/build-log.md`'s 2026-09-16 entry**: this
    correction alone did not resolve the case; it was rejected and a
    different, careless-form-entry cause diagnosed and fixed.

- **Bank account is a tax decision, not a banking preference (2026-09-07).**
  Turkey's GVK Mükerrer 20/B exemption covers mobile app development income
  sold through app stores: the bank withholds 15% as final tax and no return
  is filed, under the 2026 threshold. Its binding condition is that **all
  revenue is collected exclusively through one dedicated bank account** — an
  everyday personal account does not qualify. A new dedicated account is
  therefore being opened before anything is submitted to Apple, since changing
  the bank account in App Store Connect later re-triggers Apple's multi-day
  verification. Currency (TRY vs USD) is being settled with an accountant at
  the same time, because the withholding mechanics differ. Not tax advice —
  recorded here as the reason this step is deliberately paused.

  **Reversed 2026-09-14.** The dedicated-account-first order was dropped once
  it became clear what the 20/B application actually triggers: confirming the
  istisna belgesi dilekçesi files an *işe başlama bildirimi* with SGK and
  starts **4/b (Bağ-Kur)** — roughly 10,157 TL/month in 2026, running from
  that date whether or not there is any revenue. The key realisation is that
  **Bağ-Kur is the price of monetizing, not the price of 20/B**: any
  commercial income creates mükellefiyet, which creates 4/b, so skipping 20/B
  would keep the premium and merely forfeit the flat-15%-final treatment while
  adding beyanname, geçici vergi, defter and an accountant. The order was
  therefore inverted: a personal USD account goes in now to unblock Paid Apps
  so that products and RevenueCat can proceed, and the 20/B dilekçe — saved as
  a draft in Dijital Vergi Dairesi — is confirmed later. Apple pays ~45 days
  after the fiscal month closes and the certificate plus branch account takes
  ~2 weeks, so the dilekçe gets confirmed about **3 weeks before the expected
  first payout**, then the App Store Connect bank account is switched.
  **The trigger is a date, not a revenue level:** the exemption never applies
  retroactively, so it is the first payout landing in a non-dedicated account
  that would cost it, however small that payout is.

  A free launch was weighed as the alternative that avoids the premium
  entirely — the Free Apps Agreement is already Active and needs no bank
  account — and was **explicitly rejected**: working on funnel-flow
  optimization is one of the goals of this project, and shipping free defers
  exactly that. Recorded so the option is not re-opened without new reasons.

- **Bundle ID: fixed, closed 2026-09-13** (was: "still Flutter's placeholder —
  launch blocker found 2026-09-07"). `ios/Runner.xcodeproj/project.pbxproj`
  carried `com.example.grammarLens` (six occurrences, three of them the
  `.RunnerTests` target); Apple rejects any identifier under `com.example.*`,
  so no App ID could be registered and no app record created until this
  changed. Chosen then, applied now: `com.ahmettayfur.grammarlens` —
  reverse-DNS of a domain actually owned, all lowercase — deliberately,
  since **a bundle ID cannot be changed once it is attached to an App Store
  Connect app record**. Verified directly against the file (commit
  `e289cbb`): all six occurrences now read `com.ahmettayfur.grammarlens` /
  `com.ahmettayfur.grammarlens.RunnerTests`. The same commit also closed the
  related item decided alongside it: `CFBundleDisplayName` had drifted to
  "Grammar Lens" (with a space) instead of matching the product name
  "GrammarLens" — verified directly against `ios/Runner/Info.plist`, now
  reads `GrammarLens`.

- **Product identifiers are already reserved in code and must be matched
  exactly in App Store Connect** (these are permanent once created and cannot
  be renamed or reused, even after deletion): entitlement `premium`, products
  `grammarlens_premium_monthly` and `grammarlens_premium_annual`, all three in
  `lib/services/subscription_service.dart`. One subscription group holds both
  products, so Apple's one-introductory-offer-per-group-per-customer rule
  means a user who takes the monthly trial cannot take a second one on
  annual — intended, but the paywall copy is written knowing it. (Written
  when both trials were 7 days; since 2026-09-17 the annual plan's trial is
  7 days and the monthly plan's is 3 — read live, never hard-coded.)

- **Apple Small Business Program: enroll.** 15% commission instead of 30%,
  which roughly doubles net revenue at this scale and is what every margin
  figure in `docs/prd-v2.md` §13.7 assumes. Requires Schedule 2 accepted
  (done). Adjusted proceeds only take effect 15 days after the end of the
  fiscal month in which enrollment is approved, so enrolling early is worth
  real money. **Not yet done.**
- *(Superseded: the pages are written and live, see "Current wiring".
  The text below is the 2026-09-08 record.)*
  **Privacy Policy / Terms: URLs are real, page content is not — updated
  2026-09-08, corrected from a stale "still do not exist" note.** Checked
  directly against `lib/utils/app_links.dart`: `privacyPolicyUrl`, `termsUrl`,
  and `supportUrl` are no longer empty — all three point at permanent pages
  under `ahmettayfur.com/products/grammarlens/`, live since 2026-09-07, and
  the Premium screen's legal links actually open them (`url_launcher`). What
  remains open is narrower than before: the pages themselves still carry
  placeholder/drafting copy (confirmed by opening the live Privacy Policy
  page), not the real Privacy Policy/Terms text. Writing that real text is
  the actual remaining launch blocker here, not a domain or architecture
  dependency — both of those are resolved.
- **API key safety: done, closed 2026-09-06/07.** The key is no longer
  compiled into the client at all. Moved behind an operation-based
  Cloudflare Workers proxy (`proxy/`) that owns the model, every system
  prompt, and `max_tokens` server-side, validates each request against a
  fixed per-operation schema, and rate-limits per device and globally in
  Workers KV. Deployed on a permanent custom domain (`api.ahmettayfur.com`)
  as of 2026-09-07, replacing the initial `workers.dev` address. Full design
  reasoning (why operation-based rather than a forwarding proxy) and the
  on-device verification: `docs/build-log.md`, 2026-09-06 and 2026-09-07.
- **Visual polish: audited, now underway.** A screen-by-screen review was
  done on 2026-09-05 and written up in `docs/design-audit.md`. The
  B-structure half of the resulting work is shipped and the B-polish half is
  in progress as of 2026-09-08 — see "Where we are now" above and the split
  status in the v2.2 section below.
- **README overhaul: confirmed applied** (verified against the repo
  2026-09-05). Closed.
- **Open decision, found 2026-09-15, not yet resolved: proxy quota headroom
  for a premium user.** A full Topic Practice session costs 2 proxy quota
  units (generate + score); `dailySessionLimit` allows 10/day = up to 20
  units against `DEVICE_DAILY_LIMIT`'s 15. A premium user practicing
  normally can hit the proxy's generic per-device wall before their own
  local cap ever kicks in. Needs a decision before launch: raise
  `DEVICE_DAILY_LIMIT` to ~25, or lower `dailySessionLimit` to 7. See the
  2026-09-15 "Free tier practice quota" entry above for how this was found.
  **Resolved 2026-09-21:** `dailySessionLimit` lowered to 5 (a margin
  decision, PRD v2 §13.8); 5 sessions = 10 proxy units + 1 Daily Test unit,
  inside `DEVICE_DAILY_LIMIT` = 15, which is unchanged.
- **Closed (recorded 2026-09-21; the bug text below is the 2026-09-15
  original, kept as history): Home didn't refresh Daily Test's day-rollover
  (or its own greeting) on resume, because nothing in this app hooked
  `AppLifecycleState` at all.** Found stale during the launch-checklist pass:
  `HomeScreen` has had a resume observer since the Monthly Climb preview
  commit `0cf7eaa` (refreshes the Daily Test day, greeting, climb month and
  weak spots, with a Home-level midnight test), and `GrammarLensApp` has one
  for analytics and medal finalization (`60b799b`). Two observers, disjoint
  jobs, no shared work. New `test/app_resume_test.dart` proves the whole
  overnight scenario through the real app with an injected clock (new
  test-only `GrammarLensApp.clock`): after resume the new day and greeting
  show, and one resume triggers finalization, Daily Test read and climb read
  exactly once each. Automated tests only; no device confirmation recorded.
  Original entry: **Home doesn't refresh Daily
  Test's day-rollover (or its own greeting) on resume, because nothing in
  this app hooks `AppLifecycleState` at all.** `HomeScreen._loadTodaysDailyTest`
  only runs from `initState`; a device left open across local midnight
  (or a time-of-day boundary, for the greeting — the smaller half of this)
  keeps showing yesterday's Daily Test state until the next full rebuild,
  not automatically at midnight. Needs a `WidgetsBindingObserver` on
  `AppLifecycleState.resumed` — real fix, not a `Timer`. Found while
  checking whether the greeting had something to attach a refresh to; see
  the 2026-09-15 "Home: time-of-day greeting + bigger avatar" entry above.
- **Resolved 2026-09-23: a release IPA builds without problems.** The
  entry below is the 2026-09-16 record, kept as written.
  **Open blocker, found 2026-09-16, not project-caused: the local iOS
  simulator build is broken by an Xcode 27 / Flutter toolchain
  incompatibility.** This Xcode's `lipo -verify_arch` now rejects being
  passed more than one architecture at once, which breaks Flutter
  3.44.6's own framework-thinning step
  (`flutter_tools/lib/src/build_system/targets/darwin.dart`) even though
  the framework binary genuinely contains both `arm64` and `x86_64`
  (verified directly with `lipo -info`/`-verify_arch` on the actual
  file). Tracked upstream as flutter/flutter#188461. Waiting on a Flutter
  release that fixes it (or a different Xcode); not something this repo
  can work around. See the 2026-09-16 "iOS minimum deployment target"
  entry above for how this was found and confirmed unrelated to that
  change.
- **Open debt, found 2026-09-16, not yet fixed: the Premium screen's
  plan cards don't clear the fixed footer at 375×667 without scrolling.**
  The density pass that fixed this at 393×852 didn't close the gap at
  the smaller iPhone SE size (measured: footer top at 507pt, cards'
  own bottom at ~706–710pt). See the 2026-09-16 "Premium screen: on-
  device review fixes" entry above. **Still open (2026-09-23):** the
  2026-09-21 footer work shows the top of the plan cards above the footer
  (about 56 pt at Medium), not the whole cards; to be checked on TestFlight
  (checklist below).

#### TestFlight pre-submission checklist

Open items to run on a TestFlight build before submitting for review
(build it only after `./scripts/preflight.sh` passes; README "Local setup",
step 5):

- [ ] **Firebase DebugView on a physical device** for the launch analytics
  events: not done yet. Procedure: `docs/analytics-plan.md` §6.
- [ ] **Premium screen at 375×667 (iPhone SE):** do the plan cards clear the
  fixed footer, or is scrolling acceptable? (Open debt above.)
- [ ] **An explicit Restore Purchases tap** in a scenario that needs it (a
  second device, or a signed-out/re-signed-in sandbox account). See
  "Current wiring".

### 2. v2.2 — structure, then finish
Decisions in `docs/prd-v2.md` §13 and `docs/design-audit.md` §5.

**B-structure** (do first — polishing screens whose structure is about to
change is wasted work) — **all shipped**, see "Where we are now" above:
- [x] Merge Early Access and Paywall into one Premium screen; retire the "Early
  Access" name
- [x] Replace the 3-day trial with the 7-day card-up-front model everywhere; trial
  length and prices from a single source, never hardcoded copy *(superseded
  2026-09-17: annual 7 days, monthly 3 days, both read from RevenueCat; no day
  count is written in app copy)*
- [x] Add the required App Store disclosure block to the purchase point
- [x] Remove unbuilt features from the purchase surface
- [x] Rebuild Home as a "today" screen (Daily Test state, Topic Practice, weak
  spots, quiet premium row) — explicitly *not* by restoring coming-soon cards
- [x] Demote Skip from primary on Daily Test questions
- [x] Fix the nav bar overlapping scrollable content
- [x] Fix the duplicated topic label in Review

**B-polish** (after the above) — **in progress as of 2026-09-08**, split by
what's actually done, per `docs/build-log.md`'s 2026-09-08 entry (no item
below is marked done unless verified directly against the current code):
- [x] Collapse to a single blue (D2) — closed. `secondaryContainer` is a
  light tint of the existing navy, not a second hue.
- [x] Apply the hybrid theme rule (D1) across screens — **closed
  2026-09-09.** Dark mode's band is neutral, not deep orange — orange never
  becomes a surface color in dark mode; only light mode keeps the orange
  band, decided in Batch 1 and confirmed on-device in every batch since.
  `BrandScaffold` (`lib/widgets/brand_scaffold.dart`) is the shared
  band+body shell, and every screen now uses it except Welcome — D1's one
  deliberate exception, staying full orange. Migrated across four batches:
  **Home** (Batch 1), **Topic list, Review, Weak-spot detail, Settings**
  (Batch 2), **Daily Test question, Topic Practice question, Onboarding,
  Loading** (Batch 3), **Daily Test Results, Topic Practice Results,
  Premium** (Batch 4). Batch 4 also gave the two results screens a shared
  `ResultScoreBand` widget (`lib/widgets/result_score_band.dart`) so the
  score sits in the band the same way on both, by construction, rather than
  each screen independently choosing to agree.
  - **Batch 3 needed `BrandScaffold` to support a fully custom app bar**
    (`appBar`, mutually exclusive with `title` — enforced by assertion,
    same pattern as `children`/`body`): the question screens' own
    `QuestionAppBar` (Back/Close/progress row) has nothing in common with
    a plain title bar, so it's passed through as-is rather than forced
    into the title/leading/actions shape. `QuestionAppBar` sets its own
    `scrolledUnderElevation: 0` for the same reason `BrandScaffold`'s
    built-in app bar does.
  - **Keyboard-open layout verified on-device for both question screens,
    in both themes** (this batch's actual risk — `BrandScaffold` now owns
    padding/scroll for every migrated screen, question screens included):
    answer field stays pinned directly above the keyboard, the band stays
    in place, Skip/Next stay reachable, and the layout correctly resets
    once the keyboard closes. Confirmed by screenshot, not assumed.
  - **Onboarding's disabled "Continue" button — the audit's worst-rated
    contrast finding, and D1 does resolve the actual problem, measured.**
    Before: dark orange text on the vivid orange page background — the
    button was effectively invisible. After migrating onto `BrandScaffold`
    (neutral body instead of the orange page), the same unstyled disabled
    `FilledButton` measures **~2.24:1 (light) / ~2.78:1 (dark)** between
    its own label and background (pixel-sampled on-device, not estimated).
    Both are below WCAG AA's 4.5:1 body-text threshold — but WCAG 1.4.3
    explicitly exempts inactive/disabled controls from that requirement,
    and this is Material 3's own standard disabled-button convention
    (`onSurface` at reduced opacity), not a residual defect. The thing the
    audit actually flagged — a button that reads as blank/invisible
    because label and background shared the same hue — is what's fixed;
    no follow-up button-level patch is needed.
  - **Loading moved onto `BrandScaffold`, scope held exactly where asked:
    no progress signal added.** `LoadingView` no longer paints its own
    background (previously `theme.scaffoldBackgroundColor`, which would
    have silently redrawn the old band color under it inside a neutral
    body) — every `Scaffold` it sits in, migrated or not, already paints
    its own background, so this was redundant even before and became
    actively wrong once the two colors diverged. Purely a background-
    painting fix; the "no real progress signal" finding from the audit is
    still explicitly out of scope, untouched.
  - **A scoped-override exit plan is committed now, before more screens
    migrate onto it** (`docs/design-audit.md` S3's own complaint —
    two card colors in the app at once — is otherwise exactly what this
    would become permanently). Today: a `BrandScaffold` body uses
    `surfaceContainerHigh` for cards via a local `Theme` override scoped to
    its own subtree; every screen still on the old scaffold keeps the
    app-wide `surfaceContainerLow` card color, unchanged. This was correct
    *during* the rollout (screens migrate one batch at a time, so two
    coexisting treatments are unavoidable mid-migration) but was never
    meant as an acceptable end state.
  - **Done, end of Batch 4 (2026-09-09).** The local override is deleted;
    `lib/theme.dart`'s app-wide `cardTheme` now owns color/elevation/border
    directly (`surfaceContainerHigh`, `elevation: 1`, an `outline`-colored
    1px border — `docs/build-log.md`, 2026-09-09, carries the measurements
    behind each of the three). Every card-bearing screen from all four
    batches (Home, Topic list, Review, Weak-spot detail, Settings, Daily
    Test Results, Topic Practice Results) was re-verified on-device in
    both themes against the shared default — none regressed. Closes this
    file's own reference to `docs/design-audit.md` S3's "two color
    languages" pattern, which is exactly what a permanently-scoped
    override would have become.
  - **Deferred, not decided (Contrast and states / Consistency details,
    2026-09-09): Settings' two user-facing section-container cards**
    (Profile form, Data/reset — the three Developer cards are debug-only,
    out of scope for this question) **look identical to Home's tappable
    cards.** The same visual treatment implies tappability, which can
    invite an empty tap on a card that isn't actually a single tap
    target — this doesn't fit either of the kart kuralı's two "keep"
    reasons (not a single tappable object, not carrying semantic color),
    so it's a third, not-yet-named justification (control grouping) that
    the rule isn't being extended to cover yet. Kept as-is for now,
    revisit once every screen has migrated onto the neutral body: look at
    both themes and decide then between a quieter treatment (no border,
    no shadow, a flat tonal block) or removing the container entirely.
  - **Still open, not part of D1's own scope: Onboarding's disabled
    "Continue" button's label readability.** D1 fixed the bug this audit
    actually described — label and background sharing one orange hue, so
    the button read as blank — but didn't make the label AA-compliant, and
    was never meant to: ~2.24:1 (light) / ~2.78:1 (dark), pixel-measured,
    both still under WCAG AA's 4.5:1 body-text threshold even though WCAG
    1.4.3 exempts disabled controls from it and this matches Material 3's
    own disabled-button convention. Whether the label should be more
    readable regardless is a separate design question this batch wasn't
    scoped to answer, and D1's closure above does not close it.
- [ ] Introduce a spacing scale — **partial.** `lib/spacing.dart` exists and
  is used in the screens touched this round (Welcome, the session-length
  picker, the debug-only Theme Preview screen); the rest of the app (Home,
  Review, Settings, Premium, question screens) is not migrated onto it.
- [x] Fix the contrast failures listed in the audit — **closed 2026-09-09.**
  Every `TextButton` now reads through a centralized `textButtonTheme`
  (fixes the orange-on-orange class of bug across the app, including the
  Premium screen's legal links and "Maybe later"); the session-length
  dialog's muddy scrim is gone (replaced by a tinted-scrim bottom sheet).
  Onboarding's disabled "Continue" button — the audit's worst-rated
  contrast failure — is fixed exactly as predicted: migrating onto
  `BrandScaffold`'s neutral body (D1) resolved it without a button-level
  patch, measured on-device at ~2.24:1 (light) / ~2.78:1 (dark) — see the
  D1 entry above for the full measurement and why that's a real fix
  despite sitting below WCAG's normal-text threshold (disabled controls
  are exempt from it). That fix closes the audit's own finding; whether
  the label should be more readable than that regardless was tracked as a
  still-open item under D1 above — **closed 2026-09-10** (see below), not
  pursued further.
- [~] Verify every batch on-device in dark mode — several of this round's
  batches record their own on-device dark-mode verification in their commit
  messages (the fill-ratio dial, the Theme Preview screen, Welcome's
  animated entrance); not exhaustively re-confirmed across every batch as
  part of this documentation pass.
- [x] Close the remaining contrast/states and consistency findings —
  **closed 2026-09-10** (`docs/design-audit.md` D5, `docs/build-log.md` for
  implementation detail), nine items decided together before coding, four
  batches, each verified on-device in both themes:
  - The skipped-answer "CORRECTED" box now reads neutral, labeled "CORRECT
    ANSWER" — skippedness derived from the answer already being empty
    (`MistakeBreakdown`'s own `hasAnswer` check), not a caller-supplied
    flag, specifically so a result screen can't silently forget to pass it
    and reintroduce the bug. Regression-tested
    (`test/mistake_breakdown_test.dart`).
  - Avatar palette redesigned to eight evenly-spaced hues at one fixed
    saturation/lightness (two identical-hue pairs before — fox/lion,
    panda/koala — meant only 6 of 8 were actually distinguishable),
    documented as a named, theme-independent exception in `theme.dart`
    rather than raw hex.
  - Locked Home cards (Topic Practice, a weak-spot row) get a shared
    `LockedPremiumPill` instead of a near-invisible 16px lock glyph;
    today's tap behavior (opens `PremiumScreen`) was confirmed unchanged
    first, and the pill carries its own forward chevron so that signal
    isn't lost along with the old plain one.
  - Onboarding's disabled "Continue" button: no code change, re-verified
    on-device, the "still open" tracking above closed.
  - S5 (two back-button treatments) closed: plain chevron everywhere,
    chosen over spreading the bordered circle after reviewing both
    directions on-device, in both themes, on a question screen and a
    normal screen. `HeaderCircleIconButton` renamed to `HeaderIconButton`.
  - S3 (icon circles) closed with no code change — Premium's blue circles
    were already gone from earlier polish work; confirmed by grep.
  - Daily Test's progress bar (redundant with the "N / total" counter next
    to it) removed; the counter stays and the header gets shorter.
  - Settings' Profile/Data lost their `Card` wrap — flush now, matching
    Appearance's existing layout, since neither was a single tap target.
  - Topic list's three-line cards top-align the leading icon against the
    title instead of centering it against the whole text block.
  - D1's own test gap (BrandScaffold's two asserts, `isTabRoot`'s padding
    source, both result screens sharing `ResultScoreBand`) closed
    alongside this round: 237 tests passing, up from 227.

Also newly identified while working through this list, not yet fixed: the
comparison table's `FittedBox(scaleDown)` header text works against Dynamic
Type (shrinks back down under a larger accessibility text size instead of
growing with it) — see `docs/build-log.md`, 2026-09-08.

### 3. Public launch
Topic mode + onboarding + premium teaser only. No streak mode yet.

### 4. Streak mode (post-launch fast-follow)
Built after real D1/D7 data exists, not before. Carries the open cost
decision (`docs/prd-v2.md` §7.1). Instrument per-session token usage while
building it.

### 5. Rewarded video gate on streak (free tier)

### 6. Cost measurement, resolve open decisions §7.1 / §7.2

### Later phases (post-v2)
Accounts + backend → social / competition → AI Practice Partner.

**v3 — superseded 2026-09-19 (was: planned, status draft, not scoped or built).**
The gamification layer below is no longer post-launch: Monthly Climb is in
launch scope (see "Launch scope" at the top of this file) and has code on
`monthly-climb-v2`. The Home redesign remains post-launch, unscoped. The
entry that follows is the 2026-09-18 record, kept for history and out of
date on "not scoped for merge into `main`" and its test count. (The
2026-09-17 GUARD note on `codex/monthly-climb` was removed on 2026-09-18:
that branch is deleted, see `docs/build-log.md`, 2026-09-17.)

**v3 — planned, status draft, not scoped or built in `main` (updated
2026-09-18).** Two directions:
- **Gamification layer ("Monthly Climb").** Lives on branch
  `monthly-climb-v2`, not merged into `main`. Transplanted onto the
  rebuilt `main` (post-2026-09-17 history rewrite) on 2026-09-17, from
  scratch against clean history — not a rebase of the old
  `codex/monthly-climb` branch, which sat on pre-rewrite history and a
  stale base and has since been deleted. 381 tests passing on
  `monthly-climb-v2`. `docs/prd-gamification.md`'s original weekly-cycle
  draft ("Weekly Climb") is superseded by this monthly-cycle build. Not
  scoped for merge into `main` — v3, after launch.
- **Home screen redesign.** No scope written yet.

This replaces the 2026-09-02 "heads-up, not yet decided" note below, which
described the same thing before either direction had a name.

~~**Heads-up, not yet decided (2026-09-02):** Ahmet has flagged a possible
v3/v4 gamification iteration further out, which would likely bring another
visual design pass. Recorded here only so it isn't lost — no scope, no
screens, no commitment yet. Needs its own decision pass when we get
there.~~

### Carried over from MVP Iteration 3 (unscheduled, absorbed into v2 work)
- Review tab icon visibility — single-participant, low priority; the new Home
  and post-results navigation in v2 may make this moot
- Positive micro-feedback on answering — single-participant; overlaps with
  streak mode's feedback design
- Placement/diagnostic test — partially addressed by v2's onboarding
  "learning goal" question feeding topic suggestions
- Partial-answer submission for error-correction on mobile — still tension
  with "graded on the fix, not the format" (build-log, 2026-07-24); needs its
  own product decision
- ~~**Typos misgraded as grammar errors — reopened 2026-09-06.**~~ **Fixed
  2026-09-07** (stale here since; corrected 2026-09-08). Was: using the app
  on a Turkish keyboard, an answer typed as "cookıng" (dotless ı) against the
  expected "cooking" was marked "Needs work" with no explanation, and — since
  Daily Test feeds the error profile — wrote a grammar weak spot the user
  didn't actually have. Fixed on both scoring paths: Daily Test's
  deterministic checker folds a closed, named set of seven Turkish-keyboard
  letter pairs (ı/i, İ/I, ş/s, ğ/g, ç/c, ö/o, ü/u — confirmed in
  `lib/utils/answer_matching.dart`'s `foldKeyboardVariants`) before comparing,
  and still surfaces a short note naming the differing letter(s) rather than
  going silent; Topic Practice's LLM-based scoring got the same instruction
  added to its system prompt (`proxy/src/anthropic.ts`). Deliberately not a
  general fuzzy-match/edit-distance rule — this product's question mix
  depends on single-character differences ("stay" vs. "stays") actually being
  graded wrong; only this specific, closed letter set is folded. See
  `docs/build-log.md`, 2026-09-07, for the full reasoning.

---

## Backlog (not scheduled)

- Per-question instant feedback instead of batch evaluation (costs ~5x more
  LLM calls — evaluate against value before doing it)
- Word-form / inflection question type — MC version rejected (5 of 7 tested
  users across both research rounds reject multiple-choice, see `docs/prd.md`
  §2.2 Theme 1); if revisited, must use existing production-based question
  types
- Spaced repetition scheduling for weak spots (currently recency/frequency only)
- More topics beyond the initial five
- Accounts + cloud sync (out of scope for MVP by design)
- Custom loading animations
- Turkish UI option (currently English-only interface)

---

## Working principles (carried forward)

- **No fake it.** Nothing in the repo, README, or write-ups claims work that
  wasn't done. Unfinished items stay unchecked.
- **Decisions before code.** Every meaningful change is written down with its
  reason — that record is the actual portfolio value, more than the code.
- **Small commits.** One coherent change per commit so problems stay isolated.
- **User feedback beats taste.** Changes driven by what users did, not what
  looked nicer in the moment.
- **Deterministic where possible.** Don't ask the model for things the code
  can know for certain.

---

## Session workflow

To resume work in a new session:
1. Read this file + `docs/build-log.md`
2. Pick the next item from "What's next"
3. Work in small batches, test on the iOS simulator, commit each batch
4. Update this file when a section is completed
