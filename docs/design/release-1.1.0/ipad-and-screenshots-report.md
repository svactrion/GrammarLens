# 1.1.0 release preparation, step 1: the iPad check and the App Store screenshot plan

2026-10-03, branch `1.1.0-design` (`1.1.0` merged in first: already up to
date at `82eaf4a`). Read, rendered, measured; **nothing fixed, no
screenshot produced.** `lib/` and `assets/` unchanged.

Renders and numbers: [`ipad/`](ipad/) (sheets per screen,
`ipad_numbers.txt`). Reproduce:

```bash
DESIGN_MEASURE_OUT=build/design_measure/ipad flutter test tool/design_measure/release/ipad_render_test.dart
```

```bash
build/scene_art_venv/bin/python tool/scene_art/release_ipad_sheet.py
```

Every number below comes from `ipad/ipad_numbers.txt` unless marked
*computed* (a formula on the product's own constants, not a render) or
*not verified*.

---

## 1. What the app supports on iPad (from the code)

| Question | Answer | Where |
|---|---|---|
| Device families | iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`, all three build configs) | `ios/Runner.xcodeproj/project.pbxproj:390`, `:520`, `:573` |
| Orientations, iPhone | Portrait only | `ios/Runner/Info.plist:60-63` |
| Orientations, iPad | Portrait and portrait upside down; no landscape | `ios/Runner/Info.plist:64-68`; Flutter side `lib/utils/app_orientation.dart:11-14`, applied in `main()` |
| Split View / Slide Over | Not supported: `UIRequiresFullScreen = true` | `ios/Runner/Info.plist:58-59` |
| An iPad layout rule (max content width, breakpoints) | **None.** No `shortestSide`/tablet check and no max content width anywhere in `lib/`. Every screen takes the full width minus Home's padding rule, `clamp(width × 4.5 %, 16, 28)` pt (28 pt on every iPad). The only caps found: Welcome's text at 300 pt (`lib/screens/welcome_screen.dart:230`), Material 3's own 640 pt cap on modal bottom sheets (measured below), the celebration and medal detail at a fixed 288 pt group | — |
| The mountain window | Fixed 350 pt tall at any width (`ClimbCamera.windowHeight`, `lib/widgets/monthly_climb/climb_camera.dart:22`); the image is fitted to the window's **width** × 1.1 | `climb_camera.dart:13-36` |
| Native launch screen | The 125 pt logo centred, 39 pt above the centre, at any size | `ios/Runner/Base.lproj/LaunchScreen.storyboard:20-36` |

Known and still open from 1.0.0: rotation on iPad hardware never tried
(simulator only). Apple deprecated `UIRequiresFullScreen` for iPadOS 26
(build log 2026-09-24); how iPadOS 26's resizable windows treat this app
is **not verified** (question Q4).

## 2. What was rendered

`tool/design_measure/release/ipad_render_test.dart`: the real widgets
(real shell, `HomeScreen`, `MonthCardSheet`, `MedalCelebration`,
`DailyTestResultScreen`, `SettingsScreen` as Profile, `AvatarPickerScreen`,
`LaunchSplash`), real fonts and icon font, images really decoded, with
fake storage (the same fakes as the Batch 5/6 tools).

- Devices, 2x, safe areas 24 / 20 pt (*assumed* for current iPads with a
  home indicator, not read from a simulator):
  13 in 1032 × 1376 (renders are 2064 × 2752 px), 11 in 834 × 1194,
  mini 744 × 1133.
- Portrait only (the only orientation the app allows; upside-down lays
  out the same, not rendered separately).
- Light and dark; Medium (default) and Large (largest), only through
  `buildAppTheme(textSize:)`.
- 14 states × 3 devices × 2 modes × 2 sizes = 168 renders. **No
  framework exception (overflow or other) in any of them.**

Not rendered / not verified: a real iPad or the iPad simulator; the zoom's
motion (only its first frame); the Developer/Debug sections of Profile are
visible because the renders run in debug (a release build hides them); how
iOS filters the upscaled scene on a device (the softness below is judged on
the test renderer's output).

## 3. Findings per screen

Classification: **broken** (overflow, clipping, unusable), **ugly** (works,
but disproportionate, too empty or hard to read), **fine**. **Nothing is
broken.** Five findings are ugly; four of them have the same cause (no max
content width).

| # | Screen | Sheet | Class |
|---|---|---|---|
| 1 | Launch splash | `launch.jpg` | fine |
| 2 | Home, daily framing (days 1, 15, 31) | `home_day1/15/31.jpg`, `scene_1to1_*.jpg` | **ugly** |
| 3 | Home with the month card (summary, fresh start) | `card_summary.jpg`, `card_fresh.jpg` | fine |
| 4 | The zoom's first frame (K-c) | `kc.jpg` | **ugly** |
| 5 | Save point label | `label.jpg` | fine |
| 6 | Celebration (Welcome, Gold) | `cel_welcome.jpg`, `cel_gold.jpg` | fine |
| 7 | Daily Test result screen | `result.jpg` | **ugly** (13 in, 11 in) |
| 8 | Profile: shelf, bar, medal detail | `profile.jpg`, `profile_detail.jpg` | **ugly**, minor |
| 9 | Avatar picker | `avatar_picker.jpg` | **ugly** |

### 3.1 Launch splash — fine

Logo 125 pt at every size (12 % of the width at 13 in, 17 % at mini),
wordmark under it; the block is centred. The native storyboard places the
same 125 pt logo at centre − 39 pt, which matches the Flutter frame's logo
centre at every size here (13 in: logo centre y 649 = 1376 / 2 − 39). Small
on a 13 in screen, but a launch logo is meant to be.

### 3.2 Home, daily framing — ugly

| | 13 in | 11 in | mini | iPhone 430 pt (*computed*) |
|---|---|---|---|---|
| Climb card / mountain window (pt) | 976 × 350 | 778 × 350 | 688 × 350 | 391 × 350 |
| Window aspect | 2.79 : 1 | 2.22 : 1 | 1.97 : 1 | 1.12 : 1 |
| Image on screen (pt) | 1074 × 1432 | 856 × 1141 | 757 × 1009 | — |
| Image in device px vs the 1536 px asset | 2147 px, **1.40× upscaled** | 1712 px, **1.11× upscaled** | 1514 px, 0.99× | 1291 px, 0.84× |
| Share of the image the window shows | 22 % | 28 % | 32 % | — |
| Avatar tile (cap 42.3 pt) / share of window width | 42.3 pt / 4.3 % | 42.3 / 5.4 % | 42.3 / 6.1 % | 42.3 / 10.8 % (*computed*) |
| Empty screen under Home's last item (Medium) | about 640 pt | — | — | — |

- The window becomes a wide, low strip: on 13 in it shows a fifth of the
  picture, the avatar is 4 % of its width, and on days 1–15 the summit is
  out of view. Day 31 reads well (the whole summit as a panorama).
- **Sharpness:** at 13 in the scene is drawn 1.40× larger than its asset,
  at 11 in 1.11×. In the 1:1 crops (`scene_1to1_13in.jpg` against
  `scene_1to1_mini.jpg`) the 13 in image is visibly softer but not blurry
  enough to look broken. On a device: **not verified**.
- About half of the 13 in screen is empty below Home's content.
- No overlap, no clipping; chips, plaque and score bar are in place in
  every combination.

**Fix (one):** a maximum content width for the app's single-column
screens, centred (for example 600–640 pt, the width Material 3 already
gives the bottom sheet). Home's card would then be at most the cap, which
by the camera's formula (*computed*: px = cap × 1.1 × 2) keeps the image at
or under its asset size up to a 698 pt cap, brings the window to about
1.7 : 1 at 600 pt, and the avatar to about 7 % of the window. **Scope:**
small in code (one wrapper on the shell's body, or per screen; every iPhone
is narrower than the cap, so iPhones do not change), medium in checking
(all screens re-rendered on iPad, the camera and label tools re-run; the
empty space below Home grows sideways, which is the normal look of a
capped iPad app).

### 3.3 Home with the month card — fine

The sheet is capped at **640 pt** by Material 3 and centred: 62 % of the
width at 13 in, 77 % at 11 in, 86 % at mini. Height 427 / 438 pt (summary,
Medium / Large), 250 / 255 pt (fresh start); no scrolling, no overflow.
**It hides none of the mountain window on any iPad** (0 pt of 350), and
START is above it — better than on iPhones (at 430 × 932 START is under the
sheet, Batch 5 N37). Only the large grey area beside and below the sheet on
13 in is notable; not a defect.

### 3.4 The zoom's first frame (K-c) — ugly

K-c fits the whole image to the window's fixed 350 pt height, so it is
always 262.5 × 350 pt; the rest of the window is the blurred backdrop.

| | 13 in | 11 in | mini | iPhone 430 pt (*computed*) |
|---|---|---|---|---|
| Blurred side band, each side | 357 pt | 258 pt | 213 pt | 64 pt |
| Share of the window that is blur | **73 %** | 66 % | 62 % | 33 % |

The mountain is a narrow picture in the middle of a wide blur, behind the
month card and at the start of every month's zoom (and the first run's).
The zoom from it was not rendered as motion: **not verified**.

**Fix:** the same content width cap as 3.2. At a 600 pt cap the bands
become 169 pt each, 56 % of the window (*computed*: (600 − 262.5) / 2);
still more blur than on an iPhone, but no longer three quarters. Scope:
nothing beyond 3.2's fix.

### 3.5 Save point label — fine

90 × 24 pt (Medium), 97 × 26 pt (Large), text 15.4 / 16.8 pt, the same as
on an iPhone; 9–14 % of the window's width. It sits by its object and
touches nothing. Fine.

### 3.6 Celebration (Welcome, Gold) — fine

A fixed group, 288 pt wide, medal 162 pt, centred over a full-screen dim:
16 % of the width at 13 in, 22 % at mini; 29–41 % of the height. Nothing is
cut, text reads well in both modes. It looks smaller on 13 in than on a
phone, but it is a centred moment, not a layout; fine.

### 3.7 Daily Test result screen — ugly on 13 in and 11 in

Cards take the full width (976 pt at 13 in). The explanation text box is
940 pt wide at 13 in: **132–139 characters on a full line** (Large /
Medium), 103–113 at 11 in, 89–98 at mini (measured with the explanation's
own style at its box width). Lines beyond about 75–90 characters are
harder to read; at 13 in a line is nearly twice that. The short real
explanations mostly fit on one line, which leaves the cards wide and empty
on the right. No overflow.

**Fix:** the same content width cap (3.2). Scope: nothing beyond it.

### 3.8 Profile (shelf, bar, medal detail) — ugly, minor

- Shelf slots 76 × 89 pt. With the Welcome badge and 12 months (13 slots):
  **12 per row at 13 in, leaving one medal alone on the second row**;
  9 / 4 at 11 in; 8 / 5 at mini. A new user with a few medals sees one
  short row; the orphan only appears from 13 slots on.
- The "This month" bar spans 976 pt at 13 in; its labels are spread far
  apart but readable.
- The medal detail: 288 pt wide, medal 162 pt, centred; fine.
- Appearance and text size buttons stretch to the full width; fine but
  wide.

**Fix:** the same content width cap (3.2) (fewer slots per row, so rows
fill more evenly; the bar shorter). Scope: nothing beyond it.

### 3.9 Avatar picker — ugly

The carousel's page is 45 % of the screen width
(`lib/widgets/avatar_carousel.dart:76`): the centre avatar is 160 pt
(16 % of the width at 13 in) and the two neighbours (128 pt) are always
**half cut by the screen edges**, 464 pt away from the centre at 13 in. The
screen is mostly empty, and the cut neighbours far apart read as a mistake
rather than a peek. Same proportions as on an iPhone, but on an iPhone the
neighbours are close.

**Fix:** the same content width cap (3.2) applied to this screen (the
carousel then measures 45 % of the cap). Scope: nothing beyond 3.2 if the
cap is on the shell or the route; otherwise one wrapper here.

### 3.10 Summary

One cause, one fix: a centred maximum content width for iPad. It fixes the
softness of the scene on 11 in and 13 in, the strip-shaped mountain window,
most of K-c's blur, the result screen's line length, Profile's row
balance and the avatar picker's spread. Not done; decision Q1.

## 4. App Store screenshots: what exists

| | iPhone | iPad |
|---|---|---|
| Uploaded for 1.0.0 | 8 (build log 2026-09-24) | 5 (build log 2026-09-24) |
| In the repository | `screenshots/1.0.0/01–08`, **600 × 1298 resized copies** (commit `5bc61dc`, "resized to 600 px wide"); used by the README | **None** |
| Original size | Not recorded. The copies' aspect (600 / 1298 = 0.4622) matches 1284 × 2778 (6.5 in, the iPhone 14 Plus Ahmet tests on), so most likely device captures: *inferred, not verified* | Not recorded |
| How made | Device screenshots (status bar with carrier bars and battery, 02:20–02:23) placed in a device frame on a cream background with a caption above. The framing tool is **not recorded** and is not in the repository | Not recorded |
| Sources (unframed captures, frame files) | Not in the repository | Not in the repository |

The eight iPhone screenshots, and whether each can stay for 1.1.0
(based on what changed in `lib/` since build 3, `509f94d`):

| # | Caption | Screen | 1.1.0 |
|---|---|---|---|
| 01 | Every answer explained | Daily Test result, explanations | **Outdated**: `daily_test_result_screen.dart` changed substantially (282 lines); retake |
| 02 | A new test every day | Daily Test question | Can stay (only error states changed) |
| 03 | Your weak spots, tracked | Review | Can stay (unchanged) |
| 04 | Your climb, your streak | Home with the coded mountain | **Outdated**: the scene, plaque, score bar and header are new |
| 05 | Practice what you got wrong | Weak spot detail | Can stay (unchanged) |
| 06 | See your progress after every test | Result end with the "Welcome to the climb" card | **Outdated**: Welcome moved into the celebration layer (Batch 5) |
| 07 | Start in under a minute | Welcome | Can stay (only entrance timing changed) |
| 08 | Pick a buddy, set your goal | Onboarding | Can stay (the carousel now loops and has 16 avatars; the frame looks the same) |

The five iPad screenshots: their content is unknown here, so whether they
are outdated is **not verified** (Q5). Any that show Home or the result
screen are outdated.

## 5. Proposed 1.1.0 set

### 5.1 Sizes Apple asks for today

From Apple's "Screenshot specifications" page (read 2026-10-03):

- iPhone: **6.9 in** (1260 × 2736, 1290 × 2796 or 1320 × 2868) or **6.5 in**
  (1284 × 2778 or 1242 × 2688); one of the two is required, the other
  sizes are scaled from it. 1.0.0's 6.5 in set is therefore still an
  accepted size.
- iPad: **13 in** (2064 × 2752 or 2048 × 2732) is required because the app
  runs on iPad; 11 in is optional and scaled from 13 in.
- 1 to 10 screenshots per size; `.jpeg`, `.jpg` or `.png`; no alpha.

Whether App Store Connect still shows the 6.5 in slot for a new version of
this app, and whether a single size is enough in practice: **to be
verified** in App Store Connect (Q6).

Note: the render tool's 13 in images are exactly 2064 × 2752 px, an
accepted iPad size (without a status bar).

### 5.2 Order and how each frame is set up

New features first; the three first frames are what the store shows
without scrolling.

| # | Frame | Caption idea | How to set it up |
|---|---|---|---|
| 1 | Home: the illustrated mountain, a theme, the avatar on the trail near a save point | "A new mountain every month" | Debug panel (Settings → Debug): theme (Ember Peak or Green Slope) and day (for example 15); light mode |
| 2 | Daily Test result with explanations (retake of 01) | "Every answer explained" | Do a Daily Test with one wrong answer; or the render tool's `result` state |
| 3 | The celebration: "Gold medal earned" | "Earn a medal each month" | Debug panel → milestones → Gold (replays the real layer, no record written) |
| 4 | Daily Test question (keep 02) | "A new test every day" | Keep, or retake for a matching status bar |
| 5 | Month card summary | "Your month at a glance" | Debug panel → month cards → summary (`summary_near` shows "Just 5 points from Gold") |
| 6 | Profile: "Medal collection" shelf and "This month" bar | "Collect every theme" | **No way on a device without months of data**: the debug panel has no medal seeding. Options: the render tool at the target size, or a debug seed (a code change; Q3) |
| 7 | Review (keep 03) | "Your weak spots, tracked" | Keep |
| 8 | Weak spot detail (keep 05) | "Practice what you got wrong" | Keep |
| 9 | Onboarding (keep 08) | "Pick a buddy, set your goal" | Keep |
| 10 | Welcome (keep 07), optional | "Start in under a minute" | Keep, or drop to stay at 9 |

The save point label (debug panel → milestones, a save point) could replace
frame 1 if Ahmet prefers the moment over the calm view.

iPad 13 in: the same order, fewer frames is fine (1.0.0 had 5). The iPad
frames should come **after** the decision on the content width (Q1):
today's iPad Home shows the strip-shaped window and the empty lower half.
Ways to produce them: the iPad simulator (13 in) with the debug panel
(needs a profile or debug build; the debug panel is not in release); or
the render tool, which already produces 2064 × 2752 for every state
including Profile's shelf.

Debug and profile builds show the Settings' Developer/Debug rows; none of
the frames above shows Settings' lower part, so it does not matter for
the set.

## 6. Questions for Ahmet

1. **iPad content width:** add a centred maximum content width on iPad
   (proposal: 600–640 pt) before the iPad screenshots, or ship the
   stretched layout? It is the single fix for all five "ugly" findings.
2. **Screenshot production:** device/simulator captures framed the same
   way as 1.0.0 (which tool was used for the frames and captions?), or
   the render tool's output (exact sizes, no status bar, needs a framing
   step)?
3. **Profile's medal shelf frame:** the render tool, or a debug-only seed
   of finalized medals (code change), or drop the frame?
4. **iPadOS 26:** `UIRequiresFullScreen` is deprecated there. Do you have
   an iPad (or the iPadOS 26 simulator) to check whether the app is still
   full screen and portrait, and the still-open "rotation on iPad hardware"
   check?
5. **1.0.0's five iPad screenshots:** which screens do they show, and are
   the original files (and the iPhone originals at full size) anywhere we
   can keep them, e.g. `screenshots/1.0.0/source/`?
6. **Sizes:** keep 6.5 in (1284 × 2778, your iPhone 14 Plus) for iPhone,
   or move to 6.9 in (simulator)? Please confirm in App Store Connect which
   slots the new version shows.
7. **The set:** agree with the order in §5.2, and how many frames (8, 9 or
   10)? Light only, or one dark frame?
