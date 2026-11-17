# Widgets and reminders — progress log (branch `widgets-notifications`)

Running log of `TASK-widgets.md` (W01 home-screen widgets; N01, N02, N03
reminders; the V24 reminder switch). One section per step W0–W6: status,
commits, what was verified and how, decisions, open items. The final summary
and the "Owner steps" go at the top when W6 ends.

Rules carried over from `TASK.md`: the §1 decision rule (TASK-widgets fixed
decisions → `SPEC.md` → the board → the app's current behaviour → the
smallest choice that is easy to change), no questions and no stopping, small
commits, no new package, no deploy, no paid API, no merge into `main`, never
touch `~/GrammarLens` or the `ui-polish` branch. Nothing unverified is
marked done.

| Step | Status | Commits |
|---|---|---|
| W0 Plan | done | see W0 |
| W1 Bridge, URL scheme, routing | done | see W1 |
| W2 Widget extension + SwiftUI views | done | see W2 |
| W3 App-side payload | not started | |
| W4 Reminder engine | not started | |
| W5 UI (N01, N03, V24), captures | not started | |
| W6 Final pass, merge, docs | not started | |

## Decisions

Format: what · options · choice · why. Numbered per step (DW0-1, DW1-1, …).

- **DW0-1 TASK-widgets.md is in English.** The owner's message was Turkish
  and asked to be saved as the task file; the same message says all docs
  stay in English. · Verbatim Turkish vs. an English rendering. · **English
  rendering**, the user-facing copy kept exactly, with a note at the top that
  the original wins on any difference. · Both rules hold that way.
- **DW0-2 A third link, `grammarlens://review`.** Fixed decision 4 says a
  "Free ticket is back" tap opens the ticket on Review; fixed decision 3 only
  names `daily-test` and `home`. · Reuse `home` vs. add a link. · **Add
  `grammarlens://review`** (the Review tab, where the ticket is the top card).
  · Opening Home would not be "directly the right screen".
- **DW0-3 Links act only on the tab shell.** A link that arrives while a
  flow is pushed (a Daily Test, practice, paywall) or before onboarding is
  complete. · Pop to the root vs. drop the link vs. queue it. · **Drop it
  while a flow is pushed or onboarding is running; queue it during launch
  until the profile has loaded.** · Popping could throw away a running
  practice session; the app simply comes to the front where the user left it.
- **DW0-4 Countdown text is prepared by the app, per hour.** "Next test in
  10 h" changes over time, and `Text(date, style: .relative)` formats in the
  device language, not the app's. · iOS relative text vs. the clock time of
  the next test vs. app-prepared strings. · **The payload carries one string
  per remaining whole hour** (ICU plural from the ARB) and the timeline has
  an entry at each top of the hour until midnight. · Fixed decision 3 allows
  "text the app prepared"; it keeps the board's copy.

- **DW1-1 How the iOS app is built here.** `flutter build ios --simulator`
  fails on this machine before any of our code: Flutter 3.44.6 runs
  `lipo <framework> -verify_arch arm64 x86_64`, which Xcode 27.2's `lipo`
  rejects ("-verify_arch requires exactly one input file"), so a generic
  two-architecture simulator build always stops at "Failed to copy Flutter
  framework". · Patch the Flutter SDK vs. build for one simulator. · **Build
  for the booted simulator** (`xcodebuild … -destination 'platform=iOS
  Simulator,id=…'` with the default DerivedData, or `flutter run -d <id>`),
  which builds only the active architecture. · Touches nothing outside the
  repo; the SDK problem is the owner's to know about (listed in Owner steps).
- **DW1-2 Links arrive through a Flutter scene delegate.** The app uses
  the scene lifecycle (`FlutterSceneDelegate`, implicit engine). ·
  Override `SceneDelegate` methods (the superclass does not declare them in
  its header, so overriding would bypass Flutter's own forwarding) vs.
  Flutter's plugin hook. · **`GrammarLensBridge` registers itself with
  `registrar.addSceneDelegate`** and gets `willConnectTo` (cold start) and
  `openURLContexts` (warm). A link that arrives before Dart asks is kept
  (latest wins) and handed over by `links.initial`.
- **DW1-3 The seeded app for simulator checks.** `tool/widgets/seeded_app.dart`
  runs the real app with the App Store screenshot learner (`Sam`, from
  `tool/screenshots/seed.dart`), no Firebase or RevenueCat, analytics
  dropped; nothing in `lib/` imports it (the existing import guard test).

- **DW2-1 System rounded type in the widgets.** The boards use Nunito
  Sans, an app asset; fixed decision 3 says no app asset is copied into the
  extension. · Copy the font vs. the system font. · **SF Pro Rounded at
  heavy/bold weights** (`WidgetFont`). · Keeps the rule; the look stays close
  (rounded, heavy).
- **DW2-2 The tip's key words are a highlight inside the rule line.** W01
  shows "Use **the** with superlatives." with "the" in a green chip and an
  example line. The app's hint data (`kTopicHints`) has one line per hint,
  "key: explanation", and no examples. · Invent example lines vs. use the
  line as it is. · **The part before ": " is the green highlight, the rest
  follows in the same sentence** (an `AttributedString` background, iOS 15);
  a line without ": " is shown plain. No example line. · The hint text stays
  the owner's verbatim (SPEC §3.7: hints stay English).
- **DW2-3 Runner compiles the widget views too.** The snapshot tests run
  in RunnerTests (`@testable import Runner`). · Compile the view files into
  RunnerTests vs. into Runner. · **Runner** (the extension's `@main` bundle
  stays in the extension only): one copy of each type, so the tests' App
  Group override reaches the same `AppGroupStore` the views read. The app
  never shows these views; the cost is a few kilobytes.
- **DW2-4 Before the first payload** (a fresh install, the widget gallery):
  the widget shows the brand only ("GrammarLens" and the lens symbol, on
  orange) and opens Home; it has no text to translate. The gallery's own
  names ("Climb", "Tip") and descriptions are fixed English in the extension
  (the extension cannot read the app's language before the app has run).

## Blocked / not verified

- **Disk full (2026-11-17, W1).** The Mac's data volume reached 308 MB
  free during the first simulator build; a `flutter run` failed with "No
  space left on device" and the simulator shut down. Freed by deleting only
  this run's own build folder (`build/xc-dd`, a custom DerivedData path);
  about 8 GB free afterwards. Builds in this run stay on the default
  DerivedData folder and `build/`. The owner may want to free space.

## W0 — Plan

Status: **done**.

Read: `docs/roadmap.md` (1.5.0 row, the UI polish split-out note),
`docs/build-log.md` (head), `docs/1.4.0-plan.md` D5 (widget: avatar, this
month's step, done or not, no streak), `CLAUDE.md`, `docs/AGENTS.md`,
`SPEC.md`, `TASK.md`, `PROGRESS.md` (summary, B0, B5), the boards W01, N01,
N02, N03, V24 and their renders; the app's `main.dart`, `app.dart`,
`storage_service.dart` (sqflite, single-row settings tables, DB version 26),
`settings_screen.dart`, `home_screen.dart`, `review_screen.dart`,
`rest_scene.dart`, `data/topic_hints.dart`, `monthly_medal_rules.dart`,
`widgets/monthly_climb/climb_trail_table.dart`; `ios/` (Runner, RunnerTests,
`project.pbxproj`, scheme, `Info.plist`).

Facts the plan rests on (checked, not guessed):

- iOS project: Swift Package Manager for plugins (no Podfile), `objectVersion
  54`, deployment target 15.0, Swift 5.0, two targets (Runner, RunnerTests),
  the Runner scheme already tests RunnerTests. Scene-based lifecycle:
  `AppDelegate` is a `FlutterImplicitEngineDelegate` and `SceneDelegate` a
  `FlutterSceneDelegate`, so URLs arrive through the scene
  (`willConnectTo` options on a cold start, `openURLContexts` warm). No
  entitlements file exists yet; no `CFBundleURLTypes` yet.
- Tooling here: Xcode 27.2, Ruby 4.0.6 with the `xcodeproj` gem 1.28.1, the
  iPhone 18 Pro simulator (iOS 27.2).
- App data the widgets and reminders need already exists locally:
  climb progress and steps per month (`getClimbProgress`, steps = days in
  the month), the month's theme (`resolveClimbMonthTheme`, trail points in
  `climbTrail`, the same for every theme), medal thresholds and "points to
  next tier" (`MonthlyMedalRules.nextTier`, `nearMissPoints = 5`), the free
  ticket (`getFreePracticeCountForToday`, `freeDailyPracticeLimit = 1`),
  Premium (`SubscriptionService`), weak spots with `topicId`
  (`getWeakSpots`), topic hint lines (`kTopicHints`, English, four per
  topic), save point and theme names (ARB: `savePointFirstCamp`,
  `themeEmberPeak`, …), the avatar and name (`UserProfile`).

### File list

New unless marked (edit).

Dart (`lib/`):

| File | What |
|---|---|
| `services/native_bridge.dart` | `NativeBridge` interface + `MethodChannelNativeBridge` (the one channel, below); a fake lives in `test/helpers/` |
| `services/app_link.dart` | `AppLink` (`dailyTest`, `home`, `review`) parsed from `grammarlens://…`; `AppLinkRouter`: the cold-start link, the warm stream, the DW0-3 rules |
| `models/reminder_settings.dart` | `ReminderSettings` (four kinds on/off, time in minutes, `askState`: `notAsked` / `declined` / `accepted`) |
| `services/reminder_plan.dart` | **pure**: `planReminders(now, settings, ReminderState) → List<PlannedReminder>` (7 days, ≤ 1 a day, priority a–d) |
| `services/reminder_sync.dart` | reads the state, fills texts from `AppLocalizations`, calls the bridge; the triggers call this |
| `services/widget_payload.dart` | **pure**: `buildWidgetPayload(WidgetState, AppLocalizations, now) → Map` (schema below) |
| `services/widget_images.dart` | avatar and mountain crops as PNG bytes (`dart:ui`), crop rect math as a pure function |
| `services/widget_sync.dart` | reads the state, builds payload + images, writes them through the bridge, reloads timelines |
| `screens/reminder_soft_ask.dart` | N01 sheet (four time options, "Turn on reminders", "Not now") |
| `screens/notification_settings_screen.dart` | N03 |
| `widgets/time_wheel_picker.dart` | the wheel time picker (`CupertinoPicker`-based, SDK only) used by N01 "Pick a time", N03 and V24 |
| `services/storage_service.dart` (edit) | `reminder_settings` single-row table, DB version 26 → 27 with migration |
| `app.dart` (edit) | link router, launch/language triggers for widget + reminder sync |
| `screens/home_screen.dart` (edit) | open the Daily Test from a link; triggers after the Daily Test, practice and the month change; N01 after the second Daily Test |
| `widgets/rest_scene.dart` (edit) | V24 "Remind me tomorrow" row (switch + time chip); N01 on first rest scene |
| `screens/settings_screen.dart` (edit) | "Notifications" row → N03; avatar/name change triggers |
| `screens/review_screen.dart` (edit) | nothing expected (the Review tab is the target); practice-finished trigger if it lives here |
| `l10n/app_*.arb` (edit, 8) | widget, reminder, N01, N03, V24 strings |

iOS (`ios/`):

| File | What |
|---|---|
| `Runner/AppDelegate.swift` (edit) | registers `GrammarLensBridge` with the implicit engine's registrar; sets the notification center delegate early |
| `Runner/SceneDelegate.swift` (edit) | hands URLs (cold `connectionOptions.urlContexts`, warm `openURLContexts`) to the bridge, then `super` |
| `Runner/GrammarLensBridge.swift` | the `MethodChannel` handler; pending cold-start link |
| `Runner/ReminderScheduler.swift` | `UNUserNotificationCenter`: status, request, schedule (calendar triggers), cancel, attachment, foreground suppression, tap → link |
| `Shared/AppGroupStore.swift` | App Group container paths, safe names, atomic write/read; compiled into Runner **and** the extension |
| `Shared/WidgetPayload.swift` | `Codable` payload model; Runner (tests) + extension |
| `Runner/Runner.entitlements` | `com.apple.security.application-groups` |
| `Runner/Info.plist` (edit) | `CFBundleURLTypes` with the `grammarlens` scheme |
| `GrammarLensWidgets/GrammarLensWidgets.swift` | `@main` `WidgetBundle`: `ClimbWidget` (small, medium), `TipWidget` (medium) |
| `GrammarLensWidgets/PayloadTimeline.swift` | `TimelineProvider`: entries from the payload (now, each hour to midnight, midnight) |
| `GrammarLensWidgets/ClimbSmallView.swift`, `ClimbMediumView.swift`, `TipMediumView.swift`, `WidgetStyle.swift` | the SwiftUI views (W01) |
| `GrammarLensWidgets/Info.plist`, `GrammarLensWidgets.entitlements` | `com.apple.widgetkit-extension`; the App Group |
| `RunnerTests/WidgetSnapshotTests.swift` | `ImageRenderer` PNGs for every widget × state (iOS 16+) into `build/widget-snapshots/` |
| `RunnerTests/WidgetPayloadTests.swift`, `ReminderSchedulerTests.swift` | decoding, timeline entries, request building |
| `Runner.xcodeproj/project.pbxproj` (edit, by script) | the extension target, embed phase, dependency, entitlements setting, the shared files' memberships |

Tooling and docs: `tool/ios/add_widget_target.rb` (idempotent; backs up
`project.pbxproj` to `build/pbxproj-backup/` first), this file,
`TASK-widgets.md`; at W6 `docs/build-log.md`, `docs/roadmap.md`,
`product.yaml`.

Dart tests (`test/`): `native_bridge_test`, `app_link_test` (parsing, cold,
warm, DW0-3), `widget_payload_test`, `widget_images_test` (crop math),
`reminder_plan_test`, `reminder_settings_storage_test` (migration 26 → 27),
`reminder_soft_ask_test`, `notification_settings_screen_test`, rest scene
switch tests, the trigger tests on Home / app.

### Bridge API

One channel, `com.ahmettayfur.grammarlens/bridge`, registered from the
implicit engine's plugin registry (`registrar(forPlugin: "GrammarLensBridge")`).
Arguments are maps; errors are `FlutterError` with a code; every Dart call is
best effort (a failure never breaks the app, like analytics).

Dart → iOS:

| Method | Arguments | Returns |
|---|---|---|
| `appGroup.write` | `name` (`[a-z0-9_.-]+`, no `/`), `bytes` (`Uint8List`) | `true`; atomic write into `<group>/widget/<name>` |
| `appGroup.read` | `name` | `Uint8List?` |
| `appGroup.delete` | `name` | `true` |
| `widgets.reload` | — | `true`; `WidgetCenter.shared.reloadAllTimelines()` |
| `links.initial` | — | `String?`: the cold-start URL (scene or notification tap), cleared once read |
| `notifications.status` | — | `notDetermined` / `denied` / `authorized` / `provisional` / `ephemeral` |
| `notifications.request` | — | `bool` granted (alert, sound, badge off) |
| `notifications.schedule` | `items`: list of `{id, year, month, day, hour, minute, title, body, link, image?}` | `int` scheduled; removes every pending `gl.reminder.*` first, then adds one `UNCalendarNotificationTrigger` (local date components, non-repeating) per item |
| `notifications.cancelAll` | — | `true` (pending `gl.reminder.*` and delivered ones) |
| `notifications.pending` | — | list of ids (tests, debug) |
| `settings.openNotifications` | — | `bool`; iOS 16+ `openNotificationSettingsURLString`, else `openSettingsURLString` |

iOS → Dart: `links.open` with `{url}` for warm opens (widget tap, notification
tap while running). The router (DW0-3) decides what happens.

Notification details: ids `gl.reminder.YYYY-MM-DD`; `userInfo.link` holds the
URL; `willPresent` returns no options (nothing shown in the foreground);
`didReceive` hands the link to the bridge (or keeps it as the initial link on
a cold start). `image` names a file in the App Group (`avatar.png`); each
request gets its own copy in the temporary folder, because iOS moves an
attachment's file into its store when the request is added.

### Payload schema (`<group>/widget/payload.json`, version 1)

All strings final and in the app's language; the extension formats nothing.

```json
{
  "schema": 1,
  "writtenAt": 1795504320,
  "rtl": false,
  "entries": [
    {
      "validFrom": 1795504320,
      "climb": {
        "state": "waiting",
        "url": "grammarlens://daily-test",
        "step": 2, "steps": 30,
        "label": "DAILY TEST",
        "title": "Step 2 is waiting",
        "subtitle": "5 questions · 2 min",
        "stepBadge": "1/30",
        "points": "18",
        "mediumTitle": "Step 2 is one test away",
        "mediumSubtitle": "Ember Peak · November · 1/30",
        "chip": "Test waiting",
        "button": "Start",
        "countdown": {},
        "countdownMedium": {},
        "images": {
          "avatar": "avatar.png",
          "mountainLight": "mountain_2026-11_light.png",
          "mountainDark": "mountain_2026-11_dark.png"
        },
        "avatarPoint": [0.42, 0.61]
      },
      "tip": {
        "url": "grammarlens://daily-test",
        "label": "TIP FOR YOU · ARTICLES",
        "rule": "the",
        "example": "specific, known, or the only one",
        "footer": "From your weak spots · new tip daily",
        "boxLabel": "DAILY TEST",
        "button": "Start",
        "done": false
      }
    },
    { "validFrom": 1795554000, "climb": { "…": "waiting" }, "tip": { "…": "tomorrow's tip" } }
  ]
}
```

- `entries[0]` is now; `entries[1]` starts at the next local midnight
  (always the waiting state, with the next day's tip; if midnight starts a
  new month it points at that month's images and step 1).
- Times are seconds since 1970 (no date strings to parse).
- In the done state `climb.countdown` maps whole hours left, rounded up,
  1…24, to the small widget's line (`{"10": "Next test in 10 h", …}`) and
  `countdownMedium` to the medium one (`"Next test in 10 h · 1/30"`), DW0-4;
  the provider adds an entry at each top of the hour until `entries[1]`.
- `avatarPoint` is the avatar's trail point inside the cropped mountain
  image (0–1, from `climbTrail` and the crop), so the extension only places
  it. Waiting uses the light image in light mode and the dark one in dark
  mode; done uses the dark one ("evening tone").
- Images: PNG, sized for a medium widget at 3× (about 1100 × 520 px for the
  mountain crop, 240 px for the avatar); old month files are deleted by the
  app after each write.
- Tip: the weak spot with the highest frequency → its topic → one of its
  `kTopicHints` lines picked by the day number; the line is split at its
  first ": " into `rule` and `example` (no colon → all `rule`). No weak spot
  → a general topic by the day number and the label without "From your weak
  spots". Hint lines and topic names stay English (SPEC §3.7); labels are
  translated.

### Reminder plan (pure function, W4)

`planReminders` input: `now`, `ReminderSettings`, and `ReminderState`
(today's Daily Test done, free ticket used today, Premium, this month's
points and next tier threshold, current step, companion name, place name,
first day of next months in range). For each of the next 7 local days whose
chosen time is still ahead: pick (a) → (b) → (c) → (d) among enabled kinds;
future days assume "test not done that day" (so (d) only ever applies to
today, after the test, until the ticket is used); no fit → no item. Rebuilt at
launch, Daily Test finished, practice finished, settings changed, language
changed. Copy, N02: "<Buddy> is waiting at <place>" / "Today's 5 questions take
about 2 minutes. Step N is one test away.", "Your free ticket is back" /
"Practise “<Topic>” with AI feedback.", "So close to <Tier>" / "Just N points
to go this month.", plus a "New mountain" pair.

### Risks

- **Xcode project surgery.** A scripted target can break the Runner build
  (Flutter's "Thin Binary" and Crashlytics run-script phases are known to
  form a build cycle with an "Embed Foundation Extensions" phase placed after
  them). Mitigation: back up `project.pbxproj`, an idempotent script that
  puts the embed phase before the script phases, a clean simulator build
  after every change; the script is kept so it can be re-run.
- **Signing.** The new target gets no team and no provisioning settings
  (owner's step); simulator builds sign ad hoc, device builds will fail until
  the owner picks the team and registers the App Group — written into
  "Owner steps".
- **App Group on the simulator** works with ad-hoc signing; if
  `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil, record
  it under Blocked and test the store through a temporary-folder fallback.
- **Notification delegate.** Another SDK could replace the
  `UNUserNotificationCenter` delegate (none of Firebase Analytics,
  Crashlytics or RevenueCat does today); we set ours in
  `didFinishLaunching`, before the first frame, so cold-start taps are seen.
- **Cold-start links** with the scene lifecycle and the implicit engine: the
  URL can arrive before the channel exists, so the bridge keeps it until
  Dart asks (`links.initial`).
- **Widget limits.** No animation, a memory limit of a few tens of MB, no
  custom fonts unless bundled (assumption to verify in W2: system rounded
  font instead of Nunito Sans, recorded as a decision if so); images kept
  small.
- **Timeline staleness.** If the app is not opened for days, the widget keeps
  showing the precomputed midnight state; acceptable (it is still "waiting").
- **ImageRenderer snapshots** need iOS 16+ (the simulator is 27.2) and
  render the views outside WidgetKit (no system container background); the
  comparison with the board is by eye and recorded per state. Writing to the
  host's `build/widget-snapshots/` from the simulator test process may be
  blocked; fallback: write into the test's temporary folder and copy it out
  with `xcrun simctl`.
- **Simulator notifications.** The permission dialog must be tapped in the
  simulator; foreground suppression means the capture is taken with the app
  in the background or on the lock screen.
- **DB migration 26 → 27** for the reminder settings table: covered by a
  migration test like the existing ones.
- **Tests that pin today's layout** (V24 has a "no switch" test from B5,
  settings rows): updated where the design intentionally adds the switch and
  the row, and the commit says so.
- **Merging `origin/ui-polish`** at W6 may conflict on shared files
  (`home_screen.dart`, `rest_scene.dart`, ARB files, `product.yaml`); merge,
  never rebase; `git merge --abort` and record if it cannot be resolved
  safely.

### Verification plan

- Dart: unit tests for the pure functions, widget tests for N01, N03, V24,
  bridge tests over a mocked channel; `flutter analyze` and `flutter test`
  at every step.
- iOS: `xcodebuild build` and `xcodebuild test` (RunnerTests) on the
  iPhone 18 Pro simulator; snapshots in `build/widget-snapshots/`; the widget
  added to the simulator home screen and captured; a real reminder scheduled
  1–2 minutes ahead and captured on the simulator.
- Not possible here: anything on a physical device (signing, App Group
  provisioning, the real lock screen); those go to "Owner steps".

Verified in W0 (docs only, no code changed): `flutter analyze` → no issues;
`flutter test` → 2493 passed.

`product.yaml`: the widget/reminder line in `planned` now points at this
task and plan (CLAUDE.md: a plan was added); nothing else changed there.

## W1 — Bridge, URL scheme, routing

Status: **done**.

What was built:
- `ios/Runner/GrammarLensBridge.swift`: the one channel
  (`com.ahmettayfur.grammarlens/bridge`): `appGroup.write / read / delete /
  list / available`, `widgets.reload`, `links.initial`; iOS → Dart
  `links.open`. Registered from `AppDelegate.didInitializeImplicitFlutterEngine`
  and as a scene delegate (DW1-2).
- `ios/Shared/AppGroupStore.swift`: `<group>/widget/<name>`, names limited
  to `[a-z0-9_.-]`, atomic writes; shared with the extension in W2.
- `ios/Runner/Runner.entitlements` (App Group
  `group.com.ahmettayfur.grammarlens`), `CODE_SIGN_ENTITLEMENTS` on Runner's
  three configurations; `Info.plist` `CFBundleURLTypes` with `grammarlens`.
- `tool/ios/configure_xcode_project.rb`: idempotent project edits with the
  `xcodeproj` gem, a backup of `project.pbxproj` in `build/pbxproj-backup/`
  before each save, and the Flutter package reference comment restored
  after the gem's save (Flutter's migrations match it). No team, signing
  style or provisioning setting is written.
- Dart: `lib/services/native_bridge.dart` (`NativeBridge`, best effort:
  without the native side every call is a no-op), `lib/services/app_link.dart`
  (`AppLink` daily-test / home / review, `AppLinkRouter`: cold-start link
  waits for the shell, warm links go straight through, dropped during
  onboarding); `app.dart` attaches the router once the tab shell exists and
  drops a link while anything is pushed on the root navigator (DW0-3);
  Home opens the Daily Test for a `daily-test` link after reading today's
  set again (stays on Home when it is done).

Verified:
- `flutter analyze`: no issues; full `flutter test`: 2516 passed.
- New Dart tests: `app_link_test` (parsing, router, the channel's calls and
  file-name guard, errors swallowed), `app_link_routing_test` (cold review /
  daily-test, warm tab switches, dropped while the Daily Test is open,
  dropped during onboarding), three Home tests in `home_screen_test`
  ("Daily Test link").
- Swift: `RunnerTests/BridgeTests.swift` (`AppGroupStoreTests`, 5 cases:
  write/read/list/delete, the folder, unsafe names, the bridge's cold-start
  link kept until Dart asks, the channel's write/read shape): `xcodebuild
  test` on the iPhone 18 Pro simulator, TEST SUCCEEDED.
- Simulator (seeded app, Debug): the built app's simulated entitlements
  carry the App Group; `xcrun simctl openurl booted grammarlens://review`
  with the app running switched to Review (after iOS's own "Open in
  GrammarLens?" confirmation, which `simctl openurl` triggers); with the
  app terminated, `grammarlens://daily-test` cold-started it straight into
  the Daily Test's first question. Captures: `build/widgets-captures/
  w1-warm-review.png`, `w1-cold-daily-test.png` (not committed).

Not verified: on a device (signing with the App Group is the owner's step).

## W2 — Widget extension and SwiftUI views

Status: **done**.

What was built:
- Target `GrammarLensWidgets` (app extension, bundle ID
  `com.ahmettayfur.grammarlens.widgets`, iOS 15.0, Flutter's xcconfigs so
  its version follows the app's, entitlements with the App Group), embedded
  in Runner by an "Embed Foundation Extensions" phase placed right after
  "Embed Frameworks", before Flutter's "Thin Binary" and the Crashlytics
  script (no build cycle). Added by `tool/ios/configure_xcode_project.rb`
  (now idempotent for array settings too); no team, signing style or
  provisioning setting on the new target, so it inherits the project's.
- `ios/Shared/WidgetPayload.swift` (Codable schema 1, `entry(at:)`,
  countdown lines), `GrammarLensWidgets/WidgetTimeline.swift` (provider:
  current entry, hourly countdown entries when done, the midnight waiting
  entry; policy `.never`, the app reloads), `WidgetViews.swift` (small
  waiting/done, medium A waiting/done, medium B tip, the empty state,
  RTL from the payload), `WidgetStyle.swift` (W01 palette, light and dark),
  `GrammarLensWidgets.swift` (`@main` bundle: "Climb" small + medium, "Tip"
  medium; content margins off on iOS 17 so the mountain fills the widget).

Verified:
- `xcodebuild build` (Runner + extension, Debug, iPhone 18 Pro simulator):
  BUILD SUCCEEDED; the `.appex` is in `Runner.app/PlugIns/` with version
  1.4.0 and `com.apple.widgetkit-extension`; its simulated entitlements
  carry the App Group.
- `xcodebuild test` (RunnerTests: `AppGroupStoreTests` 5,
  `WidgetTimelineTests` 6, `WidgetSnapshotTests` 4 + 1 skipped until W3's
  Dart fixtures exist): TEST SUCCEEDED.
- Snapshots in `build/widget-snapshots/` (not committed): small, medium A
  and the tip, waiting and done, light and dark, the general tip and the
  empty state, from a hand-written sample payload in the board's data and
  the app's own avatar and Ember Peak images.
- Comparison with W01 (by eye, sample data): small waiting — match (orange,
  label, two-line title, subtitle, "1/30" chip, avatar bottom right);
  small done — match (check + "Done today", "Step 2 of 30", countdown, gold
  points chip); medium A waiting — match (title, subtitle, "Test waiting"
  chip, avatar on the trail, white "Start" button), medium A done — match
  (evening image, "See you tomorrow, Ada", countdown · 1/30, green chip,
  no button); medium B — layout match, the rule line differs by DW2-2;
  type is the system rounded face (DW2-1).

- Flutter gate: `flutter analyze` no issues; `flutter test` 2516 passed.

Not verified here: the widgets on a real home screen (W5 adds them on the
simulator), on a device (owner).
