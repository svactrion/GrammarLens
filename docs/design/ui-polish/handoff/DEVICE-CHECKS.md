# Device checks — `ui-polish-widgets` on the iPhone 14 Plus

One ordered checklist for the owner's phone. It covers the UI polish
(SPEC v10, fix rounds 1 and 2), the widgets and reminders, and the
integration of the two (`INTEGRATE.md`). It merges fix round 2's "Owner
device checks" (`PROGRESS.md`) and the widgets run's "Owner steps"
(`PROGRESS-widgets.md`). Nothing on this list was checked on a device; the
simulator results are in `PROGRESS.md` ("Integration").

Each item gives what to do, what you should see, and the board ID (the
boards are in `boards/`). Write down anything that differs: the item
number and what you saw is enough.

## 1. Before the first device build (once)

The widget extension is a new target, `GrammarLensWidgets`, and it shares
an App Group with the app. Xcode needs your team on it once. No signing
setting was written by the runs; this is the only manual step.

### 1a. Get the branch

In Terminal:

```bash
cd ~/GrammarLens
```

```bash
git switch ui-polish-widgets
```

```bash
git pull --ff-only
```

```bash
flutter pub get
```

### 1b. Xcode: team and App Group, click by click

1. In Terminal run `open ios/Runner.xcworkspace`. Xcode opens the project
   (the **.xcworkspace**, not the .xcodeproj).
2. In the left sidebar click the folder icon at the top (Project
   navigator), then the blue **Runner** icon at the very top of the list.
3. The middle pane shows **PROJECT** and **TARGETS**. Under **TARGETS**
   click **Runner**, then the **Signing & Capabilities** tab at the top.
   Note the **Team** shown there (your team, as for every release).
4. Still in **Signing & Capabilities** for **Runner**, scroll down to
   **App Groups**. `group.com.ahmettayfur.grammarlens` should be listed
   with its box ticked.
   - If it is red or shows an error, click **Try Again** (or the small
     circular-arrow button next to it). With "Automatically manage
     signing" on, Xcode registers the group in your developer account.
   - If the box is not ticked, tick it.
5. Under **TARGETS** click **GrammarLensWidgets**, then **Signing &
   Capabilities**.
   - Tick **Automatically manage signing** if it is not ticked.
   - **Team:** choose the same team as Runner's (step 3).
   - **Bundle Identifier** must read
     `com.ahmettayfur.grammarlens.widgets`; do not change it.
   - **App Groups:** the same `group.com.ahmettayfur.grammarlens`, ticked;
     if it is red, **Try Again** as in step 4. If App Groups is missing,
     click **+ Capability** (top left of the tab), double-click **App
     Groups**, click **+** under it and type
     `group.com.ahmettayfur.grammarlens`.
6. Plug in the iPhone 14 Plus with the cable, unlock it, and tap **Trust**
   if asked. In Xcode's top bar, click the device menu (next to "Runner")
   and pick your iPhone once, so Xcode can make the provisioning profiles
   for both App IDs. Wait until both targets' Signing sections show no red
   errors (the "Signing Certificate" line shows your name).
7. Close Xcode (**Xcode → Quit Xcode**). Nothing needs to be built from
   Xcode, and nothing needs to be committed: Xcode writes the team into the
   project file, which `git status` will then show as changed — leave it, or
   commit it yourself if you want it kept.

If Xcode cannot register the group: in the Apple Developer site,
**Certificates, IDs & Profiles → Identifiers → App Groups → +**, register
`group.com.ahmettayfur.grammarlens`; then under **Identifiers** open
`com.ahmettayfur.grammarlens` and `com.ahmettayfur.grammarlens.widgets`
(create the second as an App ID if it is missing), tick **App Groups**,
**Configure**, choose the group, **Save**; then repeat step 6. Push
Notifications are **not** needed (the reminders are local).

### 1c. Build and install on the phone, in release mode

With the phone plugged in and unlocked, find its ID:

```bash
flutter devices
```

Then build and install the release build with the production config (put
your phone's ID from the list in place of `<iPhone ID>`):

```bash
flutter run --release -d <iPhone ID> --dart-define-from-file=config/prod.json
```

When it says the app is running, press `q` in Terminal; the app stays on
the phone. Expected: the build ends without a signing error. This machine's
check (`flutter build ios --release --no-codesign`, `INTEGRATE.md` 3e)
built `Runner.app` with the widget extension inside, for arm64, version
1.4.0 (7); the known Flutter 3.44.6 / Xcode 27.2 `lipo` problem only hits
`flutter build ios --simulator`, not device builds.

## 2. Install over the current 1.4.0 app (do not delete it first)

Step 1c installs over the App Store 1.4.0 and keeps its data. The new build
moves the database from schema 26 to 27 in one step (tested on the
simulator with a 1.4.0-shaped database). First, Settings → Accessibility →
Motion: note whether **Reduce Motion** is on (with it on, every companion
loop stops by design; that was the likely reason the companions looked
still at the first test).

1. **Your data survived.** Same name, same goal; this month's steps on
   Home; Profile's medals and "since" line; Review's weak spots; your
   language and text size. If your 1.4.0 hero was one of the seven
   retired ones, it is Fox now (expected). — V15, V23, PF02
2. **Home's first view.** The greeting is one line with your name in
   bold; the pawn and the gold ring on the next step are fully above the
   floating nav bar (the 6.7" phone keeps the full mountain window).
   — V14, V15
3. **The companions move** (if Reduce Motion is off): Welcome's sides
   float and Fox sways (you see this in part 3); Home's card companion
   hops; Profile's companion breathes and floats, and waves when tapped;
   the paywall's side companions float and the middle one hops; the rest
   scene breathes (Premium, with a rising Zzz) or shows the floating dream
   bubble (free). — V02, X05, V23, V13, V24, V24f
4. **Daily Test.** Each question has its own Check with right/wrong
   feedback and a haptic; the progress, the results and the points count
   up. — V07, V08, Q04, Q05, V10
5. **The free ticket, Review and practice.** The ticket on Review
   (free / used), a weak spot's detail, a practice session and its results.
   — X04, V16, V16b, V17–V21
6. **Profile.** The navy ribbon with its V-cut tails, your name on one
   line. Edit name with the **real keyboard**: the sheet sits right on the
   keyboard with the companion visible above, the counter reads n/40.
   **All medals:** newest first, the Welcome badge at the month you earned
   it, the counters on top. — V23, PF04, PF02
7. **The paywall** (as a free user: Home's topic cards, or a locked
   practice on Review): the trio moves,
   the button shines and pulses, the arrow nudges; scroll to the Free vs
   Premium table (it reads well at your text size); close with X: the
   exit pop-up once. — V13, V13c, V13b
8. **The free rest scene → Premium** (as a free user, with today's Daily
   Test done and the free ticket used; a sandbox account):
   - V24f: the dream bubble names today's weak spot; "Wake Fox up · 7 days
     free" is on the first view (the trial days come from the store);
   - under the Premium card, **"Remind me tomorrow"** with its time and
     switch (scroll a little if it is below the bar) — INTEGRATE 3a;
   - Wake: the companion wakes, then the paywall rises from the bottom
     (V13r); X → the exit pop-up once → back at the camp, asleep;
   - start the **sandbox trial**: PW05r, and "Practise <weak spot>" opens
     that practice. — V24f, V24s, V13r, PW05r
9. **Widgets** (long-press the home screen → Edit → Add Widget →
   GrammarLens). Open the app once first (it writes the widget data).
   - Add all three: **Climb** small, **Climb** medium, **Tip**.
   - Before today's test: "Step N is waiting" / "one test away", your
     mountain at your step; a tap opens the Daily Test.
   - After the test: "Done today", the hours to the next test, the evening
     mountain; a tap opens Home.
   - The text is in **Nunito Sans** (the app's typeface; rounded, heavy
     titles), nothing cut off; dark mode; Arabic if you switch the app to
     it (the Arabic letters use the system font). — W01
10. **Reminders.**
    - N01 opens by itself once: on the first rest scene (V24 or V24f), or
      when you finish a Daily Test on a second day. "Turn on reminders" →
      iOS's dialog → Allow. — N01
    - Profile → Notifications: the four kinds and the time wheel; set the
      time 2–3 minutes ahead and leave the app: one reminder arrives, with
      the companion's picture; tapping it opens the Daily Test (or Review
      for "Free ticket is back"). — N02, N03
    - "Don't Allow" (or turn it off in iOS Settings): Profile →
      Notifications shows "Notifications are off" and **Open Settings**
      works. — N03
11. **Haptics:** Wake (medium) and the wake hop (light); Save name and the
    pencil (light); See all (light); the paywall button (medium); the goal
    cards (selection); each Daily Test answer.

## 3. Then delete the app and install again (the first run)

Delete GrammarLens from the home screen (this removes its data and the
widgets), then run the command of step 1c again.

1. **Splash** then **Welcome**: the companions float and sway. — V01, V02
2. **Pick a buddy** on the turntable; drag it; **"Try my luck"** spins and
   never lands on the current buddy or the previous result. — V03, V03b
3. **Your name**, then **four goals** (Exam prep, Work, School &
   university, General); each card gives a selection haptic. — V04, V05
4. **Getting ready** lasts about 4 seconds, never stalls, the companion
   thinks then hops. — V05b
5. **The mountain intro:** the flag stands **on the summit**. — V06
6. **Day 0 test** → **results** → **the Welcome badge** → **the first
   climb** (the pawn walks to step 1) → **the paywall** → **Home**.
   — V07–V12, V13
7. N01 should **not** open after this first test (it waits for a second
   day or the first rest scene).

## 4. Performance (release build)

1. The turntable drag and the wheel spin are smooth. — V03, V03b
2. Scrolling Home up and down (mountain, ticket, topics) is smooth, and the
   companions keep moving. — V14, V15
3. Opening the paywall and scrolling it is smooth. — V13

## Going back to the App Store version

To return to 1.4.0 from the App Store, delete the app and install it from
the App Store (this build's data does not carry over; Premium comes back
with "Restore Purchases" on the paywall). Do not install 1.4.0 over this build.
