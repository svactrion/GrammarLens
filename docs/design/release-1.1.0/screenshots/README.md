# 1.1.0 App Store screenshots — draft

**Draft, waiting for Ahmet's approval** (captions, typeface, the frames).
Not uploaded anywhere.

Decisions: P4 (nine frames, their order), P5 (the real app in the
simulator, light mode, status bar 9:41 with full battery and signal), P6
(the debug panel's sample collection) — `docs/roadmap.md`, under P1.

## Make the whole set again

```bash
tool/screenshots/capture.sh
```

One command, about 45 minutes (two debug builds per device). For the
iPhone and then the iPad simulator it:

1. boots the simulator, sets it to English (US) and restarts it (the
   iPad's status bar shows the date), light mode, and the status bar
   override (9:41, full battery not charging, full Wi-Fi and cellular);
2. removes the app, so each run starts from a fresh install;
3. runs `flutter drive` (a debug build) with
   `tool/screenshots/capture_app.dart` on the simulator and
   `tool/screenshots/capture_driver.dart` on the Mac, which taps through
   the app and saves frames 01–08 with `xcrun simctl io … screenshot`;
4. removes the app again and runs a second, unseeded `flutter drive`
   (`--dart-define=CAPTURE_WELCOME=true`) for frame 09, Welcome;
5. frames everything with `tool/screenshots/frame.py`.

`tool/screenshots/capture.sh iphone` (or `ipad`) does one device;
`build/scene_art_venv/bin/python tool/screenshots/frame.py` re-frames the
raw captures after a caption change (`tool/screenshots/captions.json`).

| Device | Simulator | Runtime | Capture size | App Store slot |
|---|---|---|---|---|
| iPhone | iPhone 17 Pro Max | iOS 26.5 | 1320 × 2868 | 6.9" (an accepted size) |
| iPad | iPad Pro 13-inch (M5) | iOS 26.5 | 2064 × 2752 | 13" (an accepted size) |

### What the capture app does (`capture_app.dart`)

- **Seeds** a fictional learner, "Sam" (Crab avatar, exam prep): this
  month's Daily Tests done up to one step before Halfway Hut (so today's
  test, taken live, lands the avatar on it: frame 02 shows step 15 of 31
  in October); today's Daily Test stored but not taken (the bundled
  first-day questions, so no network is used); two older mistakes
  (Modal Verbs, Tense Selection) for Review; the first-day paywall and
  first-run zoom records claimed so neither opens.
- **Starts the real app** without Firebase or RevenueCat, with an
  analytics sink that drops every event: a capture run sends nothing to
  the production Firebase project and makes no purchase call. No proxy
  call either (no config is passed, today's set is local).
- Gives Home a clock at **today, 9:41**, so it greets "Good morning" like
  the status bar's time; the date is the real one.
- Before frame 08, turns the debug tools off and rebuilds the screen
  (`release_look`): Profile then shows what a release build shows (no
  Developer section), while keeping the sample shelf.

### Every frame is automatic

| # | Frame | How the driver gets there |
|---|---|---|
| 01 | Daily Test result with explanations | Answers today's test live (the first answer wrong, the other four right), then the result screen |
| 02 | Home, the mountain | "See your climb": the avatar hops onto Halfway Hut (Green Slope, mid-month); Home scrolled back to the top |
| 03 | A question | Opens today's Daily Test (first question, empty answer) |
| 04 | Gold celebration | Debug panel → Milestones → gold |
| 05 | Review | The Review tab |
| 06 | Weak spot detail | Review → the first weak spot (today's wrong answer) |
| 07 | Month card, summary, Gold | Debug panel → Month card → summary_gold |
| 08 | Medal collection | Debug panel → Sample collection on → Profile, scrolled to "Medal collection" |
| 09 | Welcome | A fresh install, no data |

No frame needs a manual step.

## The frame style

The 1.0.0 set's own framing tool was **not found**. Searched: the
repository (tracked, untracked and ignored files), and around the project
folder by file name (home, Desktop, Downloads, Documents, Projects, the
two other GrammarLens folders). Found, in
`~/Documents/Codex/2026-09-24/`, two Codex work folders from the night
the set was made, each with a script (`build.sh`, `build_assets.sh`) and
outputs. Neither produced the committed set: one draws blue two-line
titles in Arial Rounded on an AI-generated phone image, the other cream
titles on an orange band; the committed images have dark one-line titles
in a rounded face and a different frame (mean pixel difference to the
closest output 27–36 of 255). Both scripts also depend on files outside
the repository (an AI-generated image in `~/.codex`, captures in
`~/Downloads/ssler`). They were not copied in.

So `tool/screenshots/frame.py` rebuilds the style from measurements of the
eight committed images (its docstring lists every number): the cream
gradient, the orange dash, the dark title (one line, or two when long),
the phone with its bezel, rim, side buttons, Dynamic Island and shadow.
**Difference:** the 1.0.0 titles look like Nunito (rounded); only the
app's Nunito Sans is in the repository, used at weight 800 (question 1).

## Captions

The eight 1.0.0 captions, exactly:

1. Every answer explained
2. A new test every day
3. Your weak spots, tracked
4. Your climb, your streak
5. Practice what you got wrong
6. See your progress after every test
7. Start in under a minute
8. Pick a buddy, set your goal

In this draft (`tool/screenshots/captions.json`): kept for unchanged
screens — 01 "Every answer explained", 03 "A new test every day",
05 "Your weak spots, tracked", 06 "Practice what you got wrong",
09 "Start in under a minute". **Proposed** for the new frames (drafts;
the final words are Ahmet's):

| Frame | Proposal | Alternatives |
|---|---|---|
| 02 Home, the mountain | A new mountain every month | Climb a little every day |
| 04 Gold celebration | Earn a medal every month | Go for Gold |
| 07 Month card | Your month at a glance | See how your month went |
| 08 Medal collection | Collect every mountain | A medal for every month |

"Your climb, your streak" (1.0.0's Home) is not reused: the app has no
streak. "See your progress after every test" and "Pick a buddy, set your
goal" belonged to frames P4 dropped.

## Folders

- `raw/iphone/`, `raw/ipad/`: the simulator's own screenshots, unchanged.
- `iphone/`, `ipad/`: the framed draft set, at the App Store's size.
- `overview.jpg`: every frame, reduced.
