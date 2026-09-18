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
