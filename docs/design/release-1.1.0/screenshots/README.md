# 1.1.0 App Store screenshots

**Approved by Ahmet (2026-10-04)**: the set of P4–P9, nine frames each
for iPhone 6.9" and iPad 13". Not uploaded to App Store Connect yet
(Ahmet's step).

Decisions: P4 (nine frames), P5 (the real app in the simulator, light
mode, status bar 9:41 with full battery and signal), P6 (the debug panel's
sample collection), P7 (the order and captions), P8 (Nunito Sans 800; raw
captures not kept) — `docs/roadmap.md`, under P1.

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
   the app and saves frames 01–08 with `xcrun simctl io … screenshot` to
   `build/screenshots/raw/<device>/` (git-ignored: P8);
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
- Answers `first_correct` (the first question's right answer, typed in
  frame 06) and `answers` (today's five, the first wrong) for the driver.

### Every frame is automatic

P7's order. File names follow it (`01-result.png` … `09-welcome.png`).

| # | Frame | Caption | How the driver gets there |
|---|---|---|---|
| 01 | Daily Test result with explanations | Every answer explained | Answers today's test live (the first answer wrong, the other four right), then the result screen |
| 02 | Home, the mountain | Climb a new mountain each month | After the live test the avatar is on Halfway Hut (Green Slope, step 15 of 31). Home is measured at rest, and the smallest scroll is chosen at which the screen's bottom edge falls in a gap between items with the whole mountain card in view; the hop onto Halfway Hut is then replayed from the debug panel and the frame taken while its "Halfway Hut" label shows, at that scroll |
| 03 | Last month's Gold celebration (P9) | Earn medals as you climb | Debug panel → "Celebrate last month" on → Milestones → gold: "Gold medal earned · September", the month and theme of the month card's summary |
| 04 | Review | Your weak spots, tracked | The Review tab |
| 05 | Weak spot detail | Practice what you got wrong | Review → the first weak spot (today's wrong answer) |
| 06 | A question | A new test every day | Today's first question with its right answer ("eating") typed and the on-screen keyboard up (see below) |
| 07 | Month card, summary, Gold | Your month at a glance | Debug panel → Month card → summary_gold |
| 08 | Medal collection | Collect every mountain | Debug panel → Sample collection on → Profile, scrolled to "Medal collection" where the screen is too short for all of Profile |
| 09 | Welcome | Start in under a minute | A fresh install, no data |

No frame needs a manual step.

**The keyboard (06).** `flutter_driver` types through its own text-entry
emulation, which stands in for iOS's text input, so no keyboard opens
while it types. The driver types the answer, unfocuses the field (the
capture app's `unfocus` request), turns the emulation off and taps the
field again: the field opens a new input connection, now to iOS, and the
real keyboard comes up on the typed text. `capture.sh` marks iOS's
one-time "slide to type" introduction as already shown on the simulator
(`DidShowContinuousPathIntroduction`), or it would cover the keyboard.

**Frames that agree.** One source, the month card's `summary_gold`
sample (`ClimbDebugMonthCard`), gives last month to three frames: the
replayed celebration (03, with the panel's "Celebrate last month", P9),
the month card (07) and the sample collection's last month (08), so all
three show the same September, theme and Gold medal. The sample
collection's running month is the stored one, so 08's "This month" shows
the same days and points as Home in 02.

## Review of the set (2026-10-04, after P9)

Checked on the captures of the last run, both devices:

- **Frames 2, 3, 7 and 8 agree.**

  | | Month | Theme | Tier | Steps | Points |
  |---|---|---|---|---|---|
  | 02 Home | October | Green Slope | — (Bronze reached) | 15 of 31 | — |
  | 03 celebration | September | Green Slope | Gold | — | — |
  | 07 month card | September (next: October, Green Slope) | Green Slope | Gold | 26 of 30 | 237 |
  | 08 shelf, last month | September | Green Slope | Gold | 26 (its detail) | 237 (its detail) |
  | 08 "This month" | October | Green Slope | (Bronze) | 15 active days | 149 |

  September and October are both Green Slope by the app's own rotation:
  October 2026 is its first month, and every month before it is Green
  Slope (`ClimbThemeRotation`).
- **Also agree:** Review (04) and the weak spot (05), "1 time · last seen
  today" for today's wrong answer; the question (06) is that same first
  question, with its right answer typed.
- **The shelf's earlier months** (February–August) carry the four themes
  and every tier, as P6 asked for the sample; by the rotation above a real
  user could only have Green Slope before October 2026. Illustrative, not
  changed.
- **Cut text:** none at a frame's bottom edge in 02 (the edge falls in a
  gap: iPhone scrolled 3.4 pt, iPad not at all). In 01 the last visible
  explanation runs under the result screen's fixed footer (accepted, P9).
  Items behind the frosted nav bar (02, 04, 08) show through it,
  softened, as in the app.
- **Shelf rows:** ten slots, 5 + 5 on the iPhone, 8 + 2 on the iPad.
- **Profile on the iPad (08):** the whole of Profile fits the screen, so
  there is nothing to scroll (accepted, P9).
- **Developer-only items:** none on any frame.
- **Personal data:** none; the learner is the fictional "Sam".
- **Status bar:** 9:41, full battery, full signal on every frame; the
  iPad's date reads "Sun Oct 4", the day of the run.

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
app's Nunito Sans is in the repository, used at weight 800 (kept by
P8).

## Captions

P7 (Ahmet, 2026-10-04), in `tool/screenshots/captions.json`; see the table
above. The eight 1.0.0 captions, for the record: "Every answer
explained", "A new test every day", "Your weak spots, tracked", "Your
climb, your streak", "Practice what you got wrong", "See your progress
after every test", "Start in under a minute", "Pick a buddy, set your
goal".

## Folders

- `iphone/`, `ipad/`: the framed set, at the App Store's size.
- The simulator's own screenshots are not kept here (P8):
  `tool/screenshots/capture.sh` writes them to `build/screenshots/raw/`.
- `overview.jpg`: every frame, reduced.
