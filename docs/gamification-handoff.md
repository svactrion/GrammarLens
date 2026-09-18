## 1. Design as agreed

- Monthly Climb is a local, guest-first engagement layer on the existing five-question Daily Test. It must not add another test mode, LLM call, account, backend, leaderboard, or paid advantage.
- The route is one calendar month long: 28–31 daily steps. Completing a Daily Test with at least one non-blank answer earns one path step. An all-skipped test is completed but earns zero steps. Wrong answers never move the avatar backward. No catch-up tests are available.
- The original Daily Test set day is authoritative across midnight, month boundaries, and timezone changes. Reopening/retrying a completed result must not create another completion, mistake, step, or score entry.
- Medal rule v1 is approved: correct answer `+2`, wrong answer `+1`, skipped answer `+0`. Monthly maximum is `daysInMonth * 10`. Thresholds are rounded up: Bronze 25%, Silver 50%, Gold 75%. Only the highest tier is awarded.
- There is no separate minimum-day requirement: the score thresholds imply the required participation. A mid-month starter receives no prorated thresholds and no catch-up; they can earn only whatever full-month tier remains reachable.
- The current month is provisional and shown as `In progress`. A past month with at least one Daily Test ledger row is finalized once, including a frozen `No medal` result below Bronze. Empty months are not synthesized because profile/install creation time is not stored. Finalized results are versioned and never silently recalculated after rule changes or late data.
- Path milestones are step-based, not score-based: days 7/14/21/28 use campfire, tent, cabin, and viewpoint landmarks. In a 28-day month, the viewpoint and summit/flag share the finish area. Path, avatar, and landmarks must use the same geometry.
- The intended mountain geometry is broad lower turns narrowing toward a steeper, more vertical summit. Landmark offsets must be consistent; the pale viewpoint must remain visible against the snowy summit in light and dark themes.
- The approved visual starting theme is Green Slope. Mountains are intended to vary by calendar month, but the exact theme sequence/rotation beyond Green Slope is not decided or implemented. A volcano theme was discussed but not approved.
- The Profile collection has Bronze/Silver/Gold visuals. Unawarded tiers must be visibly locked and say `Not earned`; current progress and finalized month history live below them. Existing Settings functions remain accessible from the user-facing Profile tab.
- Monthly reset affects the active route/provisional score only. Raw daily ledger rows and finalized medal history are durable local history. Existing `Reset progress` still clears practice mistakes/topic counts only; it does not clear climb or medal history.

`docs/prd-gamification.md` contains an active Monthly Climb section at the top, but its large historical appendix is the old Weekly Climb proposal. The monthly design differs from that weekly appendix in every material way:

- Calendar month (28–31 steps) instead of ISO Monday–Sunday week.
- One step per answered Daily Test instead of meter-based path movement.
- `+2/+1/+0` per correct/wrong/skipped answer instead of `+10/+5` meters per correct/wrong answer.
- Monthly percentage thresholds (25/50/75%) instead of fixed 275 m mountain badge and 350 m Perfect Week thresholds.
- Bronze/Silver/Gold monthly medals instead of named mountain badges, Perfect Week, and Four Peaks.
- Day 7/14/21/28 visual landmarks instead of the weekly 40/75/125/175/225/275/325/350 m camp ladder.
- Month rollover instead of Monday reset.
- Full-month thresholds with no mid-month proration instead of the weekly partial-first-week proposal.
- Month-keyed theme intent instead of `ISO week % 4` rotation.
- Only Green Slope is approved so far; the old Green/Snow/Misty/Night four-theme rotation and named badge landmarks are not active requirements.
- No summit-above-350 behavior, weekly rotation cycle, or Four Peaks meta-goal exists in the monthly design.
- Monthly medal results are frozen locally by scoring-rule version; old weekly schema/model examples (`climb_week`, `climb_badge`, meters, camps reached) are not used.

## 2. Done

- Monthly mountain preview and reusable vector route: `lib/widgets/monthly_climb/monthly_mountain.dart`, `lib/preview/monthly_climb_preview.dart`, `test/monthly_climb_preview_test.dart`.
- Raw monthly ledger and safe additive migrations: `lib/services/storage_service.dart`. Schema v15 added `climb_daily_entries`; v16 added independent `text_size_settings`; v17 added `monthly_medal_results`. Existing rows are not dropped/recreated.
- Atomic Daily Test completion: result answers, mistakes, completion timestamp, and one unique daily climb row are persisted in the existing transaction. Original-day attribution and retry/idempotency are implemented in `lib/services/storage_service.dart`, `lib/models/daily_test_completion.dart`, `lib/screens/daily_test_result_screen.dart`, and their tests.
- Daily Results continuation and visible Home movement: save-aware `See your climb`/`Back to Home`, retry state, route-close timing, Home visibility gating, and one-step animation are in `lib/screens/daily_test_result_screen.dart`, `lib/screens/home_screen.dart`, `lib/app.dart`, and tests.
- Home mountain integration uses persisted monthly progress and the selected avatar. Home owns vertical scrolling while the mountain retains automatic avatar tracking. The verbose lower caption was removed and progress moved to a compact accessible heading.
- Premium fixes are implemented in `lib/screens/premium_screen.dart`: equal Annual/Monthly card frames (4a), stable weak-spot contextual copy without a taller headline (4b), and responsive opaque non-overlapping 3/5-avatar hero layout (4c). Corresponding coverage is in `test/premium_screen_test.dart`.
- Nunito Sans is bundled offline at `assets/fonts/NunitoSans-Variable.ttf` with `assets/fonts/OFL-NunitoSans.txt`; registration is in `pubspec.yaml` and theme integration in `lib/theme.dart`.
- Persisted Small/Medium/Large app text sizes are implemented through `lib/models/app_text_size.dart`, `lib/theme.dart`, `lib/services/storage_service.dart`, `lib/screens/settings_screen.dart`, and tests. Small is the original Nunito size; Medium (1.10x) is default; Large is 1.20x. System accessibility scaling remains separate.
- User-facing Settings was changed to Profile (person nav icon and Profile title) while retaining avatar, identity, appearance, data, and debug controls: `lib/app.dart`, `lib/screens/settings_screen.dart`.
- Locked medal collection shell is implemented in `lib/models/medal_tier.dart` and `lib/widgets/monthly_medal_collection.dart` with light/dark, three text-size, narrow-screen, and semantics coverage.
- Medal rule v1 and durable history are implemented in `lib/services/monthly_medal_rules.dart`, `lib/models/monthly_medal.dart`, `lib/services/storage_service.dart`, `lib/screens/settings_screen.dart`, and `lib/widgets/monthly_medal_collection.dart`. Profile loads/finalizes on mount and tab re-entry, shows current progress, and lists frozen historical tier/`No medal` rows.
- Relevant tests include `test/monthly_medal_rules_test.dart`, `test/storage_service_medal_test.dart`, `test/monthly_medal_collection_test.dart`, `test/storage_service_climb_test.dart`, `test/storage_service_migration_test.dart`, `test/settings_screen_test.dart`, and `test/theme_test.dart`.
- Last known verification before this handoff: static analysis was clean and the full Flutter suite reported 436 passing tests. Do not treat that as verification of any later change. No commit, push, PR, or merge was made.

## 3. Partial

- Medal engine/device acceptance: code and automated coverage are complete, but the user has not yet confirmed the new `In progress` card or finalized history UI on a physical device. The user only confirmed the earlier locked medal shell.
- Medal history detail: Profile shows month, tier/`No medal`, and score/max, but rows do not open a month-detail screen and do not expose correct/wrong/skipped breakdowns. Files: `lib/widgets/monthly_medal_collection.dart`, `lib/screens/settings_screen.dart`.
- Mountain themes/rotation: Green Slope exists; month-specific theme selection, additional palettes, and a settled rotation sequence do not. Files: `lib/widgets/monthly_climb/monthly_mountain.dart`, `lib/preview/monthly_climb_preview.dart`.
- Mountain geometry/decor: the current route and landmarks work, but the requested broad-to-narrow/steeper summit redesign, consistent landmark placement, and viewpoint/snow contrast pass are unfinished in `lib/widgets/monthly_climb/monthly_mountain.dart`.
- Home/Profile medal entry: Profile is reachable from bottom navigation, but the PRD idea of a medal icon beside the Home avatar that opens the collection is not implemented in `lib/screens/home_screen.dart`.
- Profile is user-facing, but the implementation class/file remains `SettingsScreen` in `lib/screens/settings_screen.dart`; this is naming debt, not a user-visible bug.
- Premium comparison table: a horizontal overflow at 320 px with 2x text was discovered but intentionally left outside fixes 4a–c. File: `lib/screens/premium_screen.dart`.

## 4. Not started

1. Physical-device acceptance of the medal `In progress` and history states; use seeded/debug data or a controlled clock/database fixture because a real month rollover is impractical.
2. Fix the known Premium comparison-table overflow at 320 px / 2x text without regressing the fixed footer or plan-card equality.
3. Add the optional Home avatar-adjacent medal entry that navigates to Profile/collection, if still desired.
4. Redesign mountain path geometry and landmark placement; verify 28/29/30/31 days, light/dark, Small/Medium/Large, and reduced motion.
5. Decide and implement the additional monthly mountain themes and their calendar rotation.
6. Analytics contract, baseline measurement, rollout gating, and launch work. This branch remains post-launch work and must not be merged to main or opened as a PR without new explicit instruction.

## 5. Deviations & shortcuts

- Empty calendar months are omitted rather than frozen as `No medal`; there is no reliable local profile/install creation timestamp from which to synthesize legitimate empty months.
- Medal finalization is lazy: it runs when Profile is constructed or re-entered, not in a background scheduler. The result is still deterministic and durable once Profile is opened.
- The three medal colors are hardcoded in `lib/widgets/monthly_medal_collection.dart` rather than defined as shared design tokens.
- `MonthlyMedalCollection` marks a tier earned only if a finalized result has exactly that highest tier. A Gold result does not also visually unlock Bronze and Silver specimens.
- The full Material 3 type scale is explicitly populated in `lib/theme.dart` before applying text-size factors because this Flutter version exposed null font sizes in some base styles. These numeric sizes are standard Material values but are now locally hardcoded.
- The app-wide default changed to Medium (1.10x); existing users without a stored preference receive Medium, while Small preserves the first Nunito implementation.
- Profile still uses the internal Settings screen class/file name.
- Monthly mountain theme rotation is not hardcoded because it was never approved; only Green Slope is real.

## 6. Known risks

- The v17 migration and medal engine passed automated tests, but no physical-device migration/rollover test has been performed.
- Finalization and a simultaneous late Daily Test write around month rollover were not explicitly stress-tested together. SQLite transactions serialize writes, but the exact concurrent UI scenario remains unverified.
- Finalized history intentionally ignores later ledger changes. This protects versioned history, but a legitimate late repair to a past month will not update its medal automatically.
- Local day strings and the injectable local clock define month boundaries. Real travel/timezone-change behavior has tests around original Daily Test day attribution, but medal finalization across an actual device timezone change was not device-tested.
- `SettingsScreen._loadMedals` can be triggered on mount and tab re-entry without a generation token. Rapid repeated tab changes could allow an older async read to win, although both reads should normally return equivalent local data.
- Medal history can grow indefinitely and is rendered as children inside the Profile scroll view. This is fine for the near term but may need pagination/virtualization after years of use.
- At Large app text plus OS accessibility scaling, automated component tests cover important narrow layouts, but every production screen was not visually inspected on a device.
- Existing Daily Test atomic completion was not redesigned for medals; medal scoring reads the raw ledger afterward. This deliberately reduces regression risk, but any corruption/missing row in `climb_daily_entries` also affects medals.
- `Reset progress` does not clear climb or medal history. Copy currently says it clears practice history and weak spots, so behavior is consistent, but users may expect a broader reset.
- Free-tier quota, paywall entitlement, RevenueCat pricing, and Daily Test generation were not intentionally changed. The full suite passed before handoff, but no live RevenueCat/StoreKit or backend quota verification was performed.
- The worktree is dirty with many uncommitted changes and pre-existing untracked docs. Preserve them; do not reset or replace main-derived storage/migration/completion code.

## 7. Open decisions

- Additional mountain themes and order: keep only Green Slope for v1, use a fixed calendar-month sequence, or revive an adapted four-theme rotation. Volcano remains unapproved.
- Whether a Gold month should visually unlock only Gold (current behavior) or also Bronze and Silver.
- Whether medal history rows should open a detailed monthly breakdown and what that screen should show.
- Whether Home should include the avatar-adjacent medal shortcut described in the PRD or rely on the Profile tab.
- Whether empty months should appear as `No medal`. Supporting this correctly would require a trustworthy profile/install start date migration.
- Whether reset actions should ever offer a separate destructive “reset climb and medals” option.
- Whether the known Premium 320 px / 2x comparison-table issue should be solved by horizontal scrolling, a stacked layout, or reduced column content.
- Release measurement remains undecided: analytics event names/properties, baseline window, D1/D7 success thresholds, rollout percentage, and rollback criteria.

## 8. Analytics

- No new analytics events were added for Monthly Climb, result CTA, mountain movement, text-size selection, Profile, medal progress, medal finalization, or medal-history viewing.
- Existing analytics calls elsewhere were preserved. No live Firebase event validation was performed.
- Before rollout, define a privacy-safe contract using counts/tier/rule version only; do not send question text, answers, profile fields, or other PII.

## 9. Next step

- First, create a deterministic debug/device preview for medal states (current progress, Bronze/Silver/Gold finalized month, and `No medal`) and have the user physically verify Profile at Small/Medium/Large and light/dark. Do not change scoring or storage until that acceptance check exposes a concrete issue.

## 10. Claude Code review — Batch 0

Read-only verification pass. No production code was touched; one throwaway
probe test was written, run, and deleted (see §10.4). Everything below is
checked against the actual repo on `monthly-climb-v2`, not re-derived from
this document's own claims.

### 10.1 "Done" claims vs. code

Every file listed in §2 exists (spot-checked with a batch existence check
across all ~26 paths — mountain/preview, storage/migrations, Daily Test
completion, Home/app.dart wiring, Premium 4a–4c, Nunito Sans assets, text
sizing, Profile rename, medal shell/rules/collection, and every test file
named). No missing file, no stale reference.

Behavior spot-checks, not just presence:
- **Atomic Daily Test completion.** `StorageService.completeDailyTest`
  ([storage_service.dart:692](lib/services/storage_service.dart:692)) does
  genuinely wrap the `daily_test_sets` update, the `error_entries` batch
  insert, and the `climb_daily_entries` insert in one `db.transaction`, and
  returns early (no-op) when the cached set is missing or already completed
  — matches the "atomic, retry-safe" claim.
- **Profile rename.** `app.dart`'s bottom-nav entry is confirmed
  `Icons.person_outline_rounded` / `Icons.person_rounded` with label
  `'Profile'` ([app.dart:297](lib/app.dart:297)), while the implementing
  class/file is still `SettingsScreen` in `settings_screen.dart` — exactly
  the "naming debt, not a user-visible bug" the doc describes.
- **Medal finalize-on-mount/re-entry.** `SettingsScreen._loadMedals` is
  called from `initState` and from `didUpdateWidget` when the tab flips
  from inactive to active or the storage service instance changes
  ([settings_screen.dart:119](lib/screens/settings_screen.dart:119),
  [:123](lib/screens/settings_screen.dart:123)) — matches §2's "loads/
  finalizes on mount and tab re-entry."
- **v17 migration.** Purely additive: `_createMonthlyMedalResultsTable` is
  `CREATE TABLE IF NOT EXISTS`
  ([storage_service.dart:227](lib/services/storage_service.dart:227)), and
  `onUpgrade`'s `if (oldVersion < 17)` step
  ([storage_service.dart:368](lib/services/storage_service.dart:368)) only
  runs it — no `ALTER TABLE`, no drop/recreate, consistent with every other
  step in that method and with the "existing rows are not dropped/
  recreated" claim.

No discrepancy found between what §2 claims and what the code actually
does.

### 10.2 `flutter analyze` and full test suite

Both run clean on current `HEAD` (`054ab33`):
- `flutter analyze`: **No issues found!**
- `flutter test`: **436 passing, 0 failing** — matches the handoff's "436
  passing tests" exactly. (One `pub get` version-resolution notice printed
  first, unrelated to this branch: 44 transitive packages have newer
  versions available under current constraints — not new to this batch,
  not acted on here.)

### 10.3 Known risks — assessed

**`SettingsScreen._loadMedals` race, no generation token.** Real, but
low-severity. `initState` and `didUpdateWidget` can both fire `_loadMedals`
without cancelling a prior in-flight call
([settings_screen.dart:131](lib/screens/settings_screen.dart:131)); if two
overlapping calls resolve out of order, the one that finishes last wins the
`setState`, regardless of which one started last. In practice both reads
hit the same local SQLite file milliseconds apart with no write in
between in the ordinary case (mount, or a plain tab re-entry with no month
rollover in between), so they return identical data and the race is inert.
It stops being inert only in the narrow window where `finalizePastMedalMonths`
changes what a read returns *between* two overlapping `_loadMedals` calls —
rare, but not impossible (e.g., a fast double tab-switch exactly at a
month boundary). **Fix recommended, but not urgent**: a simple monotonic
generation counter (increment at the start of `_loadMedals`, capture it in
the closure, discard the result in the `setState` if a newer call has since
started) is a small, self-contained change with no scoring/storage
impact — reasonable to bundle with the next batch that touches this file,
not a reason to block device acceptance on its own.

**Finalization vs. a late-arriving Daily Test write, at month rollover.**
Real, and already accepted as a deliberate trade-off elsewhere in this
document (§5 "Finalized history intentionally ignores later ledger
changes", §6 same point). Traced the actual mechanism: `completeDailyTest`
writes `climb_daily_entries` keyed by the **original** test day
([storage_service.dart:724](lib/services/storage_service.dart:724)), fully
decoupled from `finalizePastMedalMonths`
([storage_service.dart:782](lib/services/storage_service.dart:782)), which
freezes a month by `INSERT OR IGNORE` and — critically — its own `SELECT
DISTINCT` query excludes any month already present in
`monthly_medal_results` going forward
([storage_service.dart:791](lib/services/storage_service.dart:791)). So the
concrete failure case is: a user starts (but doesn't finish) the last
day's Daily Test before midnight, the app is reopened after rollover
(Profile mount finalizes the now-past month with that day missing), then
the user finally submits the pending test — `climb_daily_entries` accepts
the late write, but the month's medal row is already frozen and will never
be recomputed, silently dropping that day's contribution. SQLite
transactions do serialize the actual writes (no corruption/partial-row
risk, confirming that half of the doc's own risk note), but the
product-level staleness is real, not hypothetical. Given how narrow the
window is (must start-but-not-finish before midnight, then the app must be
reopened before finishing), and that it can only ever cost a user one
day's worth of points in the edge month rather than corrupt anything,
**no fix is needed before device acceptance** — worth a one-line mention in
the app (or just accepting it as documented behavior) rather than new
logic.

**v17 migration safety.** No corruption or data-loss risk found by code
inspection — see §10.1: it is an `IF NOT EXISTS` table creation, gated the
same way as v15/v16, run unconditionally-once via the standard
`oldVersion <` ladder. What genuinely remains unverified is only what the
doc already says: no physical-device upgrade path (an install actually
carrying rows through v14/v15/v16 → v17) has been exercised, only tests
against a fresh in-memory/ffi schema. Code-level risk: none found. Real
open item: still needs one on-device upgrade check before shipping, same
as the doc already flags.

### 10.4 Main's Premium comparison-table overflow at 320px/2x — confirmed, not branch-specific

Compared `git show main:lib/screens/premium_screen.dart` against this
branch's copy. The `_ComparisonTable`/`_ComparisonRowLine`/
`_UnavailableCard` layout code is byte-for-byte identical between main and
this branch (the only diffs anywhere in the file are Premium 4a–4c's own
scoped changes: `_headline`/`_supportingText`, and the hero avatar-group
layout — none of them touch the comparison table). So this is a
**pre-existing main bug**, not something introduced on `monthly-climb-v2`.

Confirmed empirically, not just by reading: wrote a throwaway widget test
pumping the real `PremiumScreen` at 320×667, device pixel ratio 2.0, text
scale 2.0 (both no-offering and default-fake-subscription paths), ran it
once, then deleted it — nothing was committed. It reproduced two real
`RenderFlex` overflows, not one:
- `_ComparisonRowLine`'s row at `premium_screen.dart:1033` — 52px overflow,
  the comparison-table row itself (label + free-value cell + Premium
  strip cell), confirming the exact issue the handoff names.
- A second, previously-undocumented overflow in `_UnavailableCard`'s row at
  `premium_screen.dart:1512` — 51px, in the "pricing unavailable" state
  block (the state real local testing already hits, since no RevenueCat
  product is configured in dev). Worth folding into the same fix pass
  since it's the same width/scale combination, not a new investigation.

Cross-checked against the existing test suite to see why neither was
caught: `premium_screen_test.dart`'s "no overflow anywhere at 320pt or
375pt width" test only runs at text scale 1.0
([premium_screen_test.dart:1114](test/premium_screen_test.dart:1114)), and
its "PREMIUM header doesn't overflow at 1.3x/2.0x" test only runs at width
375 ([premium_screen_test.dart:1097](test/premium_screen_test.dart:1097)).
The 320×2.0x combination — where both constraints bind at once — is a real
gap in coverage, not an oversight caught and dismissed.

### 10.5 Plan for the "Next step": deterministic medal-state debug preview

Goal (per §9): let the user physically see In progress / Bronze / Silver /
Gold / No medal on Profile's medal UI at Small/Medium/Large and light/dark,
without a real month rollover and without touching scoring or storage.

**The cheapest correct approach uses an existing seam, not a new one.**
`MonthlyMedalCollection` ([monthly_medal_collection.dart](lib/widgets/monthly_medal_collection.dart))
is already a pure, stateless, presentation-only widget — it takes
`currentProgress` (`MonthlyMedalProgress?`) and `results`
(`List<MonthlyMedalResult>`) as plain constructor arguments and renders
from them directly, with zero dependency on `StorageService` or real
scoring. Every medal state the user needs to see is just a different pair
of fixture values passed to this same widget — no database, no clock
mocking, no finalize-then-read round trip required at all.

**Concretely, replicate the project's own existing pattern** — this repo
already has exactly this kind of thing for the mountain:
`lib/preview/monthly_climb_preview.dart` is a standalone, committed,
debug-only entry point (own `main()`, `if (!kDebugMode) throw
StateError(...)` guard, its own `MaterialApp`, launched via `flutter run -t
lib/preview/monthly_climb_preview.dart`, never referenced from
`lib/main.dart` or any real navigation), with its own structural test
(`test/monthly_climb_preview_test.dart`).

Plan:
1. Add `lib/preview/monthly_medal_preview.dart`, same shape as
   `monthly_climb_preview.dart`: its own `main()` behind the same
   `kDebugMode` guard, its own minimal `MaterialApp` using
   `buildAppTheme`/`AppTextSize` the same way the app does, a dark-mode
   toggle, and a text-size segmented control (Small/Medium/Large) reusing
   the app's real `AppTextSize` scaling so what the user sees matches
   production typography exactly.
2. Give it a state selector (a `SegmentedButton` or dropdown) cycling
   through five fixed, hand-built fixtures — no storage read, no clock:
   - **In progress**: a `MonthlyMedalProgress` with a mid-range
     score/maxScore and `results: const []`.
   - **Bronze / Silver / Gold finalized**: a `results` list with one
     `MonthlyMedalResult` at that tier, `currentProgress: null` (mirrors
     what Profile actually shows once a month is frozen and the *new*
     current month hasn't started yet, and also with `currentProgress`
     non-null to preview the "past medal + present progress together"
     case, since both are real production states).
   - **No medal**: a finalized `MonthlyMedalResult` with `tier: null`
     (below Bronze) — the frozen-but-unawarded row the doc's §1/§9 both
     call out explicitly.
   Each fixture is a literal, deterministic value constructed in the
   preview file itself — never read from or written to the real
   `climb_daily_entries`/`monthly_medal_results` tables, so it cannot
   drift with scoring-rule changes and cannot leak into real user data.
3. Render `MonthlyMedalCollection(currentProgress: ..., results: ...)`
   directly inside a `BrandScaffold`, matching how `Profile` embeds it
   today, so spacing/typography context matches what the user will
   actually see, not an isolated widget in a blank page.
4. Add `test/monthly_medal_preview_test.dart` mirroring
   `monthly_climb_preview_test.dart`'s own scope: the widget builds under
   each of the five fixtures with no exception, in both themes.

**How this stays out of production code:**
- Same `if (!kDebugMode) throw StateError(...)` guard the mountain preview
  already uses — this makes the file's own `main()` refuse to run in a
  release build, the same compile-time-adjacent safety net
  `SubscriptionService.debugModeForTesting`'s doc comment describes
  elsewhere in this codebase.
- It is launched with its **own** `main()`/entry point
  (`flutter run -t lib/preview/monthly_medal_preview.dart`), never wired
  into `lib/main.dart`, `app.dart`'s routes, or the real `SettingsScreen` —
  there is no code path in the shipped app that can reach it, not even a
  debug-only button, exactly like the existing mountain preview.
- It imports nothing from `StorageService`, so it cannot accidentally read
  or mutate a real device's `grammar_lens.db` — the fixtures are
  self-contained Dart object literals, not queries.
- Physical-device use is `flutter run -t
  lib/preview/monthly_medal_preview.dart -d <device>` exactly the way this
  project already runs the mountain preview on-device, no new tooling.

This does not touch scoring or storage, per §9's own instruction to hold
off on that until device acceptance surfaces a concrete issue — it only
adds a new, isolated preview file and its test.

Everything above is a report; no code changes beyond the deleted throwaway
probe test in §10.4 were made in this batch, per the task's own
instruction to stop after reporting.

## 11. Batch 1

Three items, approved from §10, each its own commit. Medal scoring rules
and the storage schema were not touched.

1. **Medal debug preview** (`bcc58dd`). Added
   `lib/preview/monthly_medal_preview.dart`, following §10.5's plan and the
   existing `monthly_climb_preview.dart` pattern exactly: its own
   `kDebugMode`-guarded `main()`, no dependency on `StorageService` or the
   real clock. Six selectable states (In progress, Bronze/Silver/Gold
   finalized, No medal, and a "Multiple months" scenario showing four
   finalized months at once), each a hand-built `MonthlyMedalProgress`/
   `MonthlyMedalResult` fixture whose score/tier is derived by *reading*
   (never modifying) `MonthlyMedalRules`, so a fixture can't silently drift
   from what the real rule would actually award. In-preview toggles for
   dark mode and Small/Medium/Large text size. Added
   `scripts/preview_monthly_medal.sh` (thin `flutter run -t` wrapper) and a
   new README "Visual previews" section covering both preview files,
   including the physical-device command
   (`./scripts/preview_monthly_medal.sh -d <device-id>`) — terminal-only,
   no VS Code config added. `test/monthly_medal_preview_test.dart` covers
   all six states with no exception in both themes, checks each scenario's
   rendered medal outcome text, and checks the busiest scenario at 320pt
   width across all three text sizes. One real bug found and fixed while
   building this (not a pre-existing production bug): the scenario
   dropdown's own longest label overflowed its field at 320pt width —
   fixed with `isExpanded: true`, confirmed by the same test.
2. **`SettingsScreen._loadMedals` race** (`f03549b`), the risk flagged in
   §6/§10.3. Added a monotonic generation counter: incremented at the
   start of every `_loadMedals` call, re-checked after both awaits finish,
   so a call whose generation is no longer current discards its own
   result instead of applying it — the most-recently-*started* call always
   wins, regardless of which one finishes last. New regression test in
   `test/settings_screen_test.dart` uses a `Completer`-backed fake
   `StorageService` to resolve two overlapping reads out of order (the
   older one finishing last) and asserts the newer one's data survives.
   Verified the test actually catches the bug, not just passes vacuously:
   temporarily reverted the fix, confirmed the test failed exactly as
   expected (the stale value won), then restored the fix.
3. **Report-only items, no code changed:**
   - **iOS minimum deployment target: 15.0.** Confirmed via
     `ios/Runner.xcodeproj/project.pbxproj` —
     `IPHONEOS_DEPLOYMENT_TARGET = 15.0;` appears identically in all three
     build configurations (Debug/Release/Profile). Matches
     `docs/roadmap.md`'s own 2026-09-16 note that this was deliberately
     raised. `ios/Podfile` sets no separate `platform :ios` override, so
     the Xcode project setting is authoritative.
   - **Premium comparison table / "pricing unavailable" state at 375×667,
     largest accessibility text scale: confirmed overflowing.** Measured
     with a throwaway widget test (written, run, then deleted — nothing
     committed), reusing `premium_screen_test.dart`'s own `pumpAt`-style
     setup. At 375×667 and 2.0x text scale (already covered by
     `premium_screen_test.dart`'s existing "PREMIUM header" test): **no
     overflow**, confirming existing coverage is accurate as far as it
     goes. At 3.0x — a real Dynamic Type accessibility size beyond what
     any existing test in this repo exercises, chosen here as the actual
     "largest" stress level rather than reusing the already-tested 2.0x —
     **both surfaces overflow**: four comparison-table rows at
     `premium_screen.dart:1033` (`_ComparisonRowLine`, 116–143px each:
     "Daily Test", "Topic Practice", "Practice your weak spots",
     "Sessions of 3, 5 or 10 questions"), and the "pricing unavailable"
     card's own row at `premium_screen.dart:1512` (116px) — the same two
     locations §10.4 already found overflowing at 320×2.0x, now also
     confirmed overflowing at the larger 375×667 size once text scale is
     pushed to a genuinely maximal accessibility setting rather than 2.0x.
     This is unchanged, pre-existing behavior inherited from `main` (see
     §10.4) — not something this batch's work touched or introduced.

**Final verification for this batch:** `flutter analyze` — no issues.
`flutter test` — **442 passing** (436 baseline + 5 new in
`monthly_medal_preview_test.dart` + 1 new regression test in
`settings_screen_test.dart`), 0 failing.
