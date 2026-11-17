# Widgets and reminders — implementation task (branch `widgets-notifications`)

The owner's task message of 2026-11-17, saved as step W0 asks. The message
was written in Turkish; this is its English rendering (docs stay in English),
with the user-facing copy kept exactly as given. Where this file and the
original differ in meaning, the original wins and the difference is a bug in
this file.

This is the GrammarLens Flutter project. Before starting, read
`docs/roadmap.md`, `docs/build-log.md`, `CLAUDE.md`, `docs/AGENTS.md`, and in
`docs/design/ui-polish/handoff/` the files `SPEC.md`, `TASK.md` and
`PROGRESS.md`.

## Context

This folder (`~/GrammarLens-widgets`) is a separate git worktree opened from
`ui-polish`; its branch is `widgets-notifications`. The owner is testing
`ui-polish` on a device in `~/GrammarLens` meanwhile. **Never touch that folder
or the `ui-polish` branch in any way: no file writes, no branch switches, no
commits.**

## Goal

Build, completely and on this branch, the two features the UI polish left out
of scope: the home-screen widgets (W01) and the daily reminder notifications
(N01, N02, N03 and the "Remind me tomorrow" switch on V24). Design sources:
`handoff/boards/` W01-Widgets.html, N01-SoftAsk.html, N02-LockScreen.html,
N03-Settings.html, V24-DayComplete.html, and the renders in `handoff/screens/`.

## Fixed decisions

1. **No new package.** The Flutter ↔ iOS bridge is our own `MethodChannel`
   (Swift, AppDelegate): App Group read/write, WidgetCenter reload,
   notification permission and scheduling (`UNUserNotificationCenter`). So
   `legal.third_parties` and `legal.data_collected` do not change; no data
   leaves the device.
2. **App Group** `group.com.ahmettayfur.grammarlens`. **Widget extension
   bundle ID** `com.ahmettayfur.grammarlens.widgets`. Entitlements files are
   written for Runner and the extension. Add the extension target to the Xcode
   project without the Xcode UI: a script with the Ruby `xcodeproj` gem, or a
   careful edit of `project.pbxproj`. Back up first, then verify with a
   simulator build. Do not touch team, signing or provisioning settings;
   device signing is the owner's step.
3. **Widgets** (minimum iOS 15; iOS 16/17 APIs behind availability checks):
   - **"Climb" widget, two sizes:**
     - **Small.** Waiting: "Step N is waiting", "5 questions · 2 min", step
       N/30; tap → Daily Test. Done: "Done today", "Step N of 30", the time
       of the next test; tap → Home.
     - **Medium A, "mountain panorama":** this month's mountain, the avatar on
       its real trail point, a status badge, Start → Daily Test. When the
       test is done: evening tone, "See you tomorrow, <name>" → Home.
   - **"Tip" widget, medium only** (B, "personal tip"): today's rule from the
     user's weak spot (from the app's topic hint data, no network call) + a
     Daily Test box → Daily Test. With no weak spot, a general topic tip.
   - No streak, no animation.
   - Every text, number and image is written to the App Group by the app.
     Texts come from the ARB files in the app's selected language; the
     extension does no translation of its own. Images (the avatar, this
     month's mountain background in light and dark) are scaled down to the
     widget's size and written to files; no app asset is copied into the
     extension. Clock times and countdowns are shown either in a
     language-independent form or with text the app prepared.
   - **Timeline:** the current state + a precomputed "waiting" state for the
     next local midnight. The app writes the payload and calls
     `reloadAllTimelines` at these moments: launch, Daily Test finished,
     practice finished, avatar or name changed, month changed, language
     changed.
   - **URL scheme for taps:** `grammarlens://daily-test` and
     `grammarlens://home`. Must work on a cold start too.
4. **Notifications:** at most 1 per day, at the time the user chose. The
   day's content is picked among the kinds that are switched on, in this
   priority:
   (a) first day of the month and the test not done → "New mountain";
   (b) test not done and 5 points or fewer to the next medal → "Close to a
   medal";
   (c) test not done → "Daily Test reminder" (as on N02: with the
   companion's name and the step goal);
   (d) test done but a free user's daily ticket not used → "Free ticket is
   back".
   If none fits, no notification that day.
   - The next 7 days' notifications are scheduled ahead, their content
     computed from the state at that moment. The plan is rebuilt at: launch,
     a test or practice finishing, a settings change. When the test finishes,
     today's notification is cancelled or turns into (d).
   - A tap opens the right screen directly (the Daily Test, or the ticket on
     Review). No notification is shown while the app is in the foreground.
   - Texts from the ARB files, in 8 languages; topic names stay English
     (SPEC §3.7).
   - N02's companion image: add it with `UNNotificationAttachment` if that
     works; if it cannot be added, record why and move on.
5. **N01 permission flow:** our own question is asked only once and comes
   before the iOS permission dialog. When: the first time the V24 rest scene
   appears, or when the second Daily Test is finished, whichever comes first.
   Time options: Morning 08:30, Lunch break 12:30, Evening 20:00, Pick a time.
   "Turn on reminders" → iOS permission → scheduling. "Not now" → never asked
   again on its own. If iOS permission is denied, the settings show the state
   and a link to iOS Settings.
6. **N03:** a "Notifications" section inside Profile → Settings. Rows: Daily
   Test reminder (with its time), Free ticket is back (shown to free users
   only), Close to a medal, New mountain. Below: "I'll never send more than
   one reminder a day." The time picker is a wheel. When the user turns
   notifications on, all four kinds start switched on.
7. **V24's "Remind me tomorrow · 20:00" switch** is a shortcut to the Daily
   Test reminder setting; if permission has not been asked yet it opens the
   N01 flow.
8. No new analytics event, no new data collection, no version change.
   Settings live on the device only, in the existing storage.

## How to work

TASK.md's rules apply: the §1 decision rule, no questions and no stopping,
small commits, the git prohibitions, no new package, no deploy, no paid API,
no merge into `main`. Additionally allowed for this task: the Xcode target,
entitlements, App Group and `Info.plist` (URL scheme) changes.

## Steps

At the end of every step: `flutter analyze` clean, the whole `flutter test`
passes, commit, push.

- **W0.** Save this message as `docs/design/ui-polish/handoff/TASK-widgets.md`.
  Open `PROGRESS-widgets.md` and write the plan into it: the file list, the
  bridge API, the payload schema, the risks. Commit, then
  `git push -u origin widgets-notifications`. Then stop; the owner starts the
  work with /goal.
- **W1.** The bridge: `MethodChannel`, App Group read/write, the URL scheme
  and routing (cold and warm start), tests.
- **W2.** The widget extension target, the SwiftUI views (small, medium A,
  medium B), the timeline provider, payload decoding. Verification: add to
  RunnerTests an XCTest that renders a PNG with `ImageRenderer` for every
  widget and state; write the images under `build/widget-snapshots/` and
  compare them with the W01 board.
- **W3.** The app side of the payload: texts (ARB, 8 languages), images
  written to files, update triggers. Tests: through a pure function that
  builds the payload from the state.
- **W4.** The notification engine. Content choice and the 7-day plan are a
  pure Dart function; unit tests cover: the priority order, at most one
  notification a day, cancel or change when the test finishes, the first day
  of the month, the 5-point limit. Swift side: scheduling, cancelling,
  permission and taps.
- **W5.** UI: the N01 page, the N03 settings, the V24 switch, ARB in 8
  languages, widget tests, simulator captures and the board comparison. Set a
  real notification 1–2 minutes ahead in the simulator and verify it with a
  screenshot.
- **W6.** Final. Dark theme, Arabic (RTL) and largest text size checks. If
  `origin/ui-polish` has new commits, merge them into this branch (no
  rebase); if a conflict cannot be resolved safely, `git merge --abort` and
  record it. Update `build-log.md` and `roadmap.md`. In `product.yaml`, update
  the widget/notification line in `planned` and add an entry to `recent`;
  `legal` does not change. At the top of `PROGRESS-widgets.md` write a summary
  and an "Owner steps" section (device signing, App Group registration,
  adding the widget and checking notifications on a device). Push; `git
  status` clean.

Code, comments, commit messages and all docs stay in English.
