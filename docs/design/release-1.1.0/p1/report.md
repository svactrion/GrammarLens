# P1: a maximum content width on iPad — build and renders

2026-10-03, branch `1.1.0-design`. Decision P1 (`roadmap.md`, "1.1.0 side
tracks"; build log 2026-10-03). Follows
[`../ipad-and-screenshots-report.md`](../ipad-and-screenshots-report.md).
**Not seen on an iPad or the iPad simulator.**

Reproduce:

```bash
DESIGN_MEASURE_OUT=build/design_measure/ipad_p1 flutter test tool/design_measure/release/ipad_render_test.dart
```

```bash
for c in 560 640 720; do DESIGN_MEASURE_OUT=build/design_measure/ipad_p1/caps IPAD_CAP=$c IPAD_CASES=home_day15,home_day31,kc IPAD_DEVICES=13in,11in flutter test tool/design_measure/release/ipad_render_test.dart; done
```

```bash
IPAD_IN=build/design_measure/ipad_p1 IPAD_OUT=docs/design/release-1.1.0/p1/ipad build/scene_art_venv/bin/python tool/scene_art/release_ipad_sheet.py p1
```

## 1. The rule

`lib/utils/content_width.dart`, `ContentWidth`: when the screen's shortest
side is **600 pt or more**, the content column is centred and at most
**`ContentWidth.maxContentWidth` = 640 pt** wide; below 600 pt nothing
changes (the widest iPhone is 440 pt). Backgrounds, the top band, the nav
bar's pill and dimming layers stay full width; their content moves in.

Where it is applied:

| Place | How |
|---|---|
| `BrandScaffold` (every screen built from `children`: Home, Review, Profile/Settings, Data, Credits, the debug panel, the topic list, the weak spot detail, practice results, Daily Test results) | The list's side padding goes through the rule; the band (title, back, actions, `bandBottom`) is moved in with a full-width band colour behind it. Not wrapped at all below 600 pt |

Not from that one place, and why:

| Screen / element | Why not through `BrandScaffold` | What it does |
|---|---|---|
| Onboarding, Daily Test question, Practice question, Premium, AI consent, avatar picker (their own `body`) | They lay out their own body, with footers whose surface and top border must stay full width; wrapping the body in `BrandScaffold` would have narrowed those surfaces | Their existing side-padding line now calls `ContentWidth.sidePaddingOf` (it was a raw copy of the padding formula) |
| Daily Test results' fixed footer (`bottomBar`) | The footer's surface and border stay full width | Same, through its existing padding line |
| Avatar picker's carousel | The carousel is centred, not padded | An inset of `ContentWidth.insetOf` (0 on an iPhone), so its pages are fractions of the column |
| Welcome | Its own `Scaffold` (D1's full-orange exception) | Its padding line through `ContentWidth.sidePadding` with its own base |
| Floating nav bar (`FloatingNavShell`, not a scaffold) | The pill is the bar's surface and stays full width (as decided) | Its tab row is inset to the column |
| `ResultScoreBand` | Sits inside the band, which `BrandScaffold` already moves in | Only its base padding, now `ContentWidth.basePadding` |
| Loading screens of Topic Practice and the weak spot detail (plain `Scaffold` + `LoadingView`) | Not on `BrandScaffold` since 1.0 | Unchanged: a centred spinner and line. Not rendered |
| Modal sheets (month card, practice length picker), dialogs, the celebration, the medal detail | Material 3 already caps a modal sheet at 640 pt; dialogs have their own width; the celebration and medal detail are a fixed 288 pt group | Unchanged. The practice length picker and the dialogs were not rendered |
| Launch splash | Full screen by design | Unchanged |

A tool-only hook, `ContentWidth.debugMaxContentWidthOverride` (null in the
app), drives the 560 / 640 / 720 pt comparison.

## 2. The iPhone proof

Every render at 320 × 568, 375 × 667, 375 × 812 and 430 × 932 before the
change (`1b6d130`) and after it, compared pixel by pixel
(`tool/scene_art/release_p1_compare.py`):
**590 images, 590 identical, 0 different**
([`iphone_before_after.txt`](iphone_before_after.txt)). The set: all 25
screen states of `release/ipad_render_test.dart` × 4 iPhones × light/dark ×
Medium/Large (400), and the existing tools' renders: Batch 6's real month
card at the four screens (48), Batch 5's celebration (90) and Profile
shelf (34), Scene Art's Home card at 320 / 375 / 430 (18).

One deviation on the way: the first comparison showed 15 onboarding
images differing. Rendering the same code twice differed the same way:
onboarding starts on a random avatar (PRD v2 §13.5). The tool now jumps
the carousel to a fixed page; onboarding's "before" images were re-made
in a worktree at `1b6d130` with that tool, and the result above is after
that fix (onboarding run twice on the same code: 16 of 16 identical).

## 3. iPad renders

25 screen states × 1032 × 1376 / 834 × 1194 / 744 × 1133 × light/dark ×
Medium/Large = 300 renders, **no framework exception in any** (light and
dark). Sheets per screen in [`ipad/`](ipad/), numbers in
[`ipad/ipad_numbers.txt`](ipad/ipad_numbers.txt).

| Screen | Sheet | Class | Note |
|---|---|---|---|
| Launch splash | `launch.jpg` | fine | Unchanged, full screen |
| Welcome | `welcome.jpg` | fine | Button and text in the column; the orange stays full screen |
| Onboarding | `onboarding.jpg` | fine | Column 640 pt; the carousel's neighbours peek at the column's edges |
| Home, days 1 / 15 / 31 | `home_day*.jpg` | fine | Card 640 pt, window 640 × 350; empty space below the content on 13 in, as before (Home is short) |
| Month card, summary and fresh start | `card_*.jpg` | fine | Sheet 640 pt, now the same width as the card above it; hides none of the window |
| K-c (the zoom's first frame) | `kc.jpg` | **ugly** | 59 % of the window is blur (was 73 % at 13 in); see §4 |
| Save point label | `label.jpg` | fine | 14 % of the window |
| Celebration (Welcome, Gold) | `cel_*.jpg` | fine | Unchanged (fixed 288 pt group over a full-screen dim) |
| Daily Test question | `daily_test.jpg` | fine | Column 640 pt; the answer field and buttons too |
| Daily Test results | `result.jpg` | fine | Cards 640 pt; the score in the band lines up with them; the footer's surface full width |
| Topic list | `topic_list.jpg` | fine | Cards 640 pt |
| Practice question | `practice.jpg` | fine | Column 640 pt |
| Practice results (with the offer card) | `practice_results.jpg` | fine | Cards 640 pt |
| Review | `review.jpg` | fine | Cards 640 pt |
| Weak spot detail | `weak_spot.jpg` | fine | Column 640 pt (seen on the sheet; the tool's reference widget was not found, so no number) |
| Profile (shelf, bar) | `profile.jpg` | fine | Shelf 8 / 5 with 13 slots |
| Medal detail | `profile_detail.jpg` | fine | Unchanged, 288 pt |
| Profile / Settings, lower part | `profile_bottom.jpg` | fine | Appearance, text size, Data, Credits in the column (the Developer section shows because the renders are a debug build) |
| Avatar picker | `avatar_picker.jpg` | fine | Neighbours peek at the column's edges, as on an iPhone |
| Premium | `premium.jpg` | fine | Table and plans in the column (seen on the sheet, no number); a large gap above the fixed footer on 13 in and 11 in, which is the footer pinned to the bottom of a tall screen |
| AI consent | `ai_consent.jpg` | fine | Column 640 pt; footer surface full width |

Nothing is **broken**. One state stays **ugly**: K-c.

The nav bar: the pill is still full width (as decided), with its three
tabs over the 640 pt column; on 13 in that leaves 180 pt of empty
pill on each side (Q1 below).

## 4. The five findings of the iPad report

| Finding | Before (13 in / 11 in / mini) | After P1 (every iPad) | iPhone 430 pt (*computed*) | Status |
|---|---|---|---|---|
| Mountain window's proportion | 2.79 / 2.22 / 1.97 : 1 | **1.83 : 1** (640 × 350) | 1.12 : 1 | Much better; still wider than a phone |
| Scene image against its 1536 px asset | 1.40× / 1.11× / 0.99× | **0.92×** (1408 px), not enlarged | 0.84× | **Fixed** |
| K-c side bands (blur) | 73 / 66 / 62 % | **59 %** (189 pt each side) | 33 % | Better, **still ugly**: K-c is always 262.5 pt wide (fitted to the fixed 350 pt height) |
| Result screen, characters on a full line (Medium / Large) | 139–132 / 113–103 / 98–89 | **93 / 80** | not measured | **Fixed** (near the usual 75–90 character range) |
| Profile shelf per row; avatar picker | 12 / 1, 9 / 4, 8 / 5; neighbours half off the screen, 464 pt from the centre | **8 / 5** everywhere; neighbours at the column's edges | — | **Fixed** |

## 5. 560 / 640 / 720 pt for Home (13 in and 11 in)

Sheets: [`ipad/caps_home_day15.jpg`](ipad/caps_home_day15.jpg),
`caps_home_day31.jpg`, `caps_kc.jpg`; numbers in
`ipad/ipad_numbers_cap{560,640,720}.txt`. The same on both iPads, since
the cap is narrower than both screens.

| Cap | Window | Image vs asset | K-c blur | Avatar / window width (day 15) |
|---|---|---|---|---|
| 560 pt | 560 × 350, 1.60 : 1 | 0.80× | 53 % | 7.6 % |
| **640 pt** (chosen default) | 640 × 350, 1.83 : 1 | 0.92× | 59 % | 6.6 % |
| 720 pt | 720 × 350, 2.06 : 1 | **1.03× (enlarged)** | 64 % | 5.9 % |

720 pt enlarges the scene again; 560 pt is closer to a phone's proportion
and leaves more empty space on each side. 640 pt is the widest cap that
keeps the image at or under its asset size (the limit is 698 pt).

## 6. Simulator checklist (for Ahmet)

On the iPad simulator (13 in, and the mini if possible), a debug or
profile build so the debug panel is there:

1. Portrait and upside-down portrait: the app does not rotate to
   landscape; on iPadOS 26, whether the app opens full screen or in a
   resizable window (`UIRequiresFullScreen` is deprecated there). If it
   opens in a window narrower than 600 pt, it shows the iPhone layout:
   say whether that happens.
2. Home: the 640 pt column centred; the band's title, the greeting and
   the cards aligned; the nav pill full width with its three tabs over the
   column (does the wide pill look right?).
3. The mountain on days 1, 15 and the last day (debug panel: day, theme):
   sharpness of the scene; the hop and the save point label.
4. A month card (debug panel: month cards → summary, fresh) and the zoom
   from K-c: how the blurred sides look in motion.
5. The celebrations (debug panel: milestones → Welcome, Gold).
6. Daily Test: question with the keyboard up (the field and buttons stay
   in the column and above the keyboard), then results.
7. Topic Practice: list, the length picker sheet (not rendered), a
   question, results with the offer card.
8. Review → a weak spot → "Practice this".
9. Profile: the shelf, the bar, a medal's detail; Settings' lower part;
   Data and Credits.
10. Premium (from Home's Premium row): table, plans, the footer's surface
    full width.
11. Dialogs (leaving a test, the debug panel's reset): not rendered.
12. Onboarding and Welcome: debug panel → "Reset local data".
13. Dark mode and Large text on a few of the above.
