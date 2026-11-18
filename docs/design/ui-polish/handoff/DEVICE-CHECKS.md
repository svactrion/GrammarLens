# Device checks — `ui-polish-widgets` on the iPhone 14 Plus

One ordered checklist for the owner's phone. It covers the UI polish
(SPEC v10, fix rounds 1 and 2), the widgets and reminders, the
integration of the two (`INTEGRATE.md`), fix round 3 (`FIX3.md`, SPEC v11)
and fix round 4 (`FIX4.md`, SPEC v12), whose third pass comes first. It merges fix round 2's "Owner
device checks" (`PROGRESS.md`) and the widgets run's "Owner steps"
(`PROGRESS-widgets.md`). Nothing on this list was checked on a device; the
simulator results are in `PROGRESS.md` ("Integration").

Each item gives what to do, what you should see, and the board ID (the
boards are in `boards/`). Write down anything that differs: the item
number and what you saw is enough.

## Fix round 4 — third pass (start here)

Fix round 4 (`FIX4.md`, SPEC v12) changed what you found on the second
pass. This section is the third pass, in order; the second pass (FR3) and
the first pass (sections 1–4) below stay for reference. Nothing here was
checked on a device: the simulator and test results are in `PROGRESS.md`
("Fix round 4"). Write down anything that differs (the item number and what
you saw).

### FR4-1. Build and install

The same commands as FR3-1; **no Xcode step**. Install over the current test
build; do not delete it.

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

```bash
flutter devices
```

```bash
flutter run --release -d <iPhone ID> --dart-define-from-file=config/prod.json
```

When it says the app is running, press `q`; the app stays on the phone.
Keep the interface in Turkish and your larger text size, as on the second
pass.

### FR4-2. On this install

Do them in this order: the first one needs **today's Daily Test not yet
done**; the rest need it done.

1. **A wrong answer's sweat drop by the head** (needs today's test not done,
   or a fresh install). In the Daily Test, answer one question wrong: the
   companion shakes its head and the sweat drop starts at its temple and
   falls along its cheek, not above and to the right of it. Check it on the
   giraffe if you can (Profile → change your buddy). — SPEC §3.5, X01, V09
2. **Forward buttons are felt.** In the Daily Test: "Kontrol et" gives only
   its right or wrong feedback (one haptic); "Devam et" on the sheet gives a
   light tap. In a practice: "İleri" and "Gönder" give a light tap. —
   SPEC §3.4
3. **V20 centred, the last item waiting** (needs the free ticket on a
   practice: Review → a weak spot → use today's ticket, answer, submit).
   While the AI checks: the content is centred on the screen (not at the
   top with the lower half empty); "Cevapların okunuyor" and the second
   item tick, "Geri bildirimin yazılıyor" keeps a pulsing dot until the results are
   ready, then ticks just before the results open; the lens stays inside
   its window over the answers. — V20
4. **V24f on one screen with the fire by the companion** (the practice from
   item 3 done; back on Home). The rest scene and its sheet fit the screen
   without scrolling: the header ("Bugünlük her şey tamam", two small
   ticks, the countdown on the right), the Premium card (the title and the
   PREMIUM chip on one row, the tickets, "Tilki uyansın · …"), then
   "Yarın hatırlat" with the time and the switch, all above the floating
   bar. The camp sits under the dream bubble; the campfire stands at the
   companion's front right on the same ground: small logs, a two-coloured
   flame about 40 % of the companion's height, a warm glow on the ground.
   Scrolling does nothing (or only bounces back). — V24f
5. **The paywall footer** ("Tilki uyansın" opens it, or Profile →
   Premium). The pinned footer is compact: the orange button, the full
   price line under it, "Geri yükle · Koşullar · Gizlilik" on one row, and
   **no "Belki sonra"**. "Compare plans" ("Planları karşılaştır") with its
   arrow is visible above the footer on the first view. The X at the top
   left closes; the first time this session it shows the reminder pop-up
   (V13b). — V13, V13c, V13a, V13r
6. **The Turkish capitals.** "TİLKİ RÜYASINDA…" in the dream bubble (item 4,
   when a weak spot is saved) and "GERİ BİLDİRİMİN YOLDA" on V20 (item 3):
   a dotted İ, never "GERI" or "TILKI". — SPEC §3.7
7. **Profile's progress card.** Profile → under the medal shelf: "Kasım
   ilerlemesi" and "<mountain> · N aktif gün" on the left, the score capsule
   (ring, star, points, "Bronz için N") at the top right, a bar of ten
   segments filled by this month's points, "Bronz 75 · Gümüş 150 · Altın
   225" under the bar at their places, and the monthly total. Check it in
   dark mode too. — V23
8. **The widgets in light and dark.** Remove the GrammarLens widgets from
   the Home Screen and add them again once (iOS keeps the old layouts until
   then). The medium tip widget shows your latest weak spot: its topic, a
   short rule with a green pill, your own sentence with the wrong words
   struck through (red) and the corrected one (green), "Zayıf noktan · her
   gün bir yenisi"; tap the sentences → that weak spot opens in Review; tap
   the right box → the Daily Test (or Home once done, where it says
   "Tamam" and the hours to the next test with the companion asleep). Switch
   the phone to dark mode: every widget has its own dark look (a dark plum
   card, the small waiting widget a deeper orange with cream text, the done
   box dark navy), none of them system grey; the medium mountain widget is
   unchanged. — W01

## Fix round 3 — second pass

Fix round 3 (`FIX3.md`, SPEC v11) changed what you found on the first
device test. This section is the second pass, in order; sections 1–4 below
are the first pass and stay for reference. Nothing here was checked on a
device: the simulator and test results are in `PROGRESS.md` ("Fix round
3"). Write down anything that differs (the item number and what you saw).

### FR3-1. Build and install

The same commands as section 1a and 1c. **No Xcode step is needed now:**
your team is set on the widget target (your change, committed as round 3's
E1). Install over the current test build; do not delete it.

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

```bash
flutter devices
```

```bash
flutter run --release -d <iPhone ID> --dart-define-from-file=config/prod.json
```

When it says the app is running, press `q`; the app stays on the phone.

### FR3-2. On this install

Do them in this order: the first two need **today's Daily Test not yet
done**; the rest need it done.

1. **A wrong answer's "oops"** (needs today's test not done). In the Daily
   Test, answer one question wrong: the companion shakes its head and a
   sweat drop falls beside "Oops! So close." — V09, B8.
2. **The dark mode walk, part 1** (needs today's test not done). Switch the
   phone to dark mode (Control Centre or Settings → Display). In the Daily
   Test: the right answer's green chip and the wrong answer's red "Almost!"
   read clearly; the results' rows ("Correct", "Needs work") too. — SY03, D
3. **V18 from Review** (needs today's test done and the free ticket not
   used). Review → a weak spot → "Use today's ticket": the loading screen
   has no big title at the top, the companion thinks over three dots,
   "Writing 3 questions on <topic>…", two skeleton cards and a **blue**
   "Did you know?" card, all the same width. — V18, B7
4. **N01 right after the practice** (the practice from item 3 done). Back
   on Home: the rest scene shows and the reminder question (N01) opens at
   once, without switching tabs. Answer it either way. — §5.10, A2
5. **V24f's layout** (today's test done, the ticket used, a free account):
   the scene runs to the top of the screen behind the status bar, the night
   sheet is attached under it (no separate rounded card), the tent,
   companion and fire are whole above the sheet, and "Wake <Hero> up" is
   above the floating bar on the first view. — V24f, B1
6. **The switches**: Profile → Notifications (N03), and V24f's "Remind me
   tomorrow": white thumbs in both states, the track navy (N03) or green
   (V24f) when on. — N03, B5
7. **Profile**: the navy ribbon is the screen's width minus 60 pt, tails
   included, and no longer looks thick; the name and "Climbing with … ·
   since …" each on one line. Tap the companion: it changes to the wave
   with a soft cross-fade, not a jump. — V23, C5, C6
8. **The paywall** (a topic card on Home or a locked practice): the first
   view says "Compare plans"; it scrolls to Free vs Premium, then "Choose
   your plan" leads to the plans and the trial timeline at the end. The
   orange button and its price line stay at the bottom all the way, and
   the button already says the yearly trial before you reach the plans.
   — V13, V13c, V13a, C4
9. **The dark mode walk, part 2**: Home, Review, a weak spot, the paywall,
   Profile, Notifications, Settings in dark mode: no navy text on dark
   (links, eyebrows, icons are a light blue), soft cards are dark tints,
   nothing hard to read. — SY03, D

### FR3-3. Before today's test (the next day)

1. **Home's first view**: the pawn and the gold ring on the next step are
   above the floating nav bar. — V14, V15
2. **The Daily Test card's companion** hops while it waits. — X05
3. **The widgets' "before the test" state**: "Step N is waiting" / "one
   test away", your mountain at your step; a tap opens the Daily Test.
   — W01

### FR3-4. Delete the app and install again (the first run)

Delete GrammarLens from the home screen, then run the `flutter run
--release …` command of FR3-1 again.

1. **Splash**: about 2.2 s; the small lens scans the word slowly (about a
   second). Open the app again later: the short splash only. — V01, C1
2. **The name screen**: the companion is large in the middle with a warm
   glow. Empty field: it waves and asks "Hi! What should I call you?".
   Typing: it looks at the field through its lens, three dots in the
   bubble. Stop typing: after a moment it cheers, hops once, three
   sparkles, "Nice to meet you, <name>!" with the name in orange, a green
   tick in the field and **one light haptic**. Type again: it listens;
   clear the field: it asks again. — V04, V04s, C2
3. **The goals**: the cards tilt right, left, right, left. — V05, B3
4. **The shine** on the goal screen's Continue (once a goal is picked) is
   a tall diagonal band across the whole button, not a small square. — B4
5. **Getting ready**: the bar is a warm track with light stripes that
   move, round stops that pop into green ticks, and the flag's pole
   standing on the last stop. — V05b, B2
6. **The mountain intro**: the flag stands on the very top of this
   month's mountain. — V06, B6
7. **Day 0**: the results come first, then "Climb my first step" opens the
   Welcome badge, then the first climb. — V10, V11, V12, A1
8. **The first climb**: "First step done! 29 to the summit." opens just
   above your companion, its tail pointing at it. — V12, C3
9. **The paywall** after the climb: the same order as FR3-2 item 8. — C4
10. **N01 after the first practice**: Review → use the free ticket on a
    weak spot → finish the practice → back on Home, the rest scene and N01
    at once. — A2

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
