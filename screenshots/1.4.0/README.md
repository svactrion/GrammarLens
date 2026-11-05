# 1.4.0 App Store screenshot assets

Checkpoint 1: the owner selected **Canlı fade** on 2026-11-04 and authorized
its rollout to all eight languages and both device families. The localized
sets below await checkpoint review; nothing uploaded or pushed.

Captured from build 7's source, detached commit `c37757a` (`1.4.0+7`),
in `/private/tmp/grammarlens-140-build7`. The owner's checkout remains on
`main`. Rig changes are committed on main and imported before every run
with `git checkout main -- tool/`. Every run refuses to capture unless
`git diff --stat c37757a -- lib ios assets pubspec.yaml` prints nothing.
No application, iOS, proxy or test sources were edited.

The existing `tool/marketing/store_130/` rig supplies the capture flow,
native screenshots and English copy. The current composition uses the
owner-approved vivid fade, double ribbon and floating native components. Only
`tool/screenshots/seed.dart` is reused from the older screenshot pipeline.
The real app widgets run with a capture-only database and no Firebase or
RevenueCat initialization. Every launch creates a fresh capture database;
existing databases and owner devices are retained. The simulator binary
is reused only when its capture-source fingerprint matches.

Sam, Fox, exam prep, Glacier Peak, light mode, 9:41, full signal and
battery. The deterministic capture clock is 2026-11-04 at 9:41. The same
bundled Daily Test begins with “Yesterday I ___ a great film.”, the wrong
answer “have seen” and correction “saw”. The Tense Selection hint is
opened with a real held drag, then released and its closure verified. Its
content contains neither “see” nor “saw”. Frame 08 uses the same local
two-blank Articles fixture and production PracticeScreen as the 1.3.0 rig.
English learning content and topic titles remain English by design.

Dedicated simulators created for this job, iOS/iPadOS 27.2:

| Device | UDID | Native size |
|---|---|---|
| GrammarLens 1.4 Store iPhone, iPhone 18 Pro Max | `4B3BE06E-07D8-4449-8FCB-DA1F2794FC02` | 1320 × 2868 |
| GrammarLens 1.4 Store iPad, iPad Pro 13-inch (M5) (16GB) | `790AEE6E-7212-4829-A190-C96C31826B75` | 2064 × 2752 |

The dedicated iPad is set to **Full Screen Apps** in Settings →
Multitasking & Gestures. Only these two simulators are restarted. Before
each language run, AppleLanguages and AppleLocale are set and the
simulator restarted. The app stays on **System default**. The driver
checks the resolved locale and localized UI before continuing; locale
and hint interaction audits remain outside the repository with the raws.
Arabic uses the app's real RTL layout and right-to-left hint drag, with
English learning content left to right. No screenshot is mirrored by hand.

| Language | AppleLanguages / AppleLocale | Font | Tag / title / subtitle weights | Review |
|---|---|---|---|---|
| en | en-US / en_US | Fredoka / Caveat / Nunito Sans | see font report | [iPhone](en/overview-iphone.png), [iPad](en/overview-ipad.png), [copy](en/copy.en.json), [source-language note](en/back-translation.md) |
| tr | tr / tr_TR | Fredoka / Caveat / Nunito Sans | see font report | [iPhone](tr/overview-iphone.png), [iPad](tr/overview-ipad.png), [copy](tr/copy.tr.json), [blind table](tr/back-translation.md) |
| de | de / de_DE | Fredoka / Caveat / Nunito Sans | see font report | [iPhone](de/overview-iphone.png), [iPad](de/overview-ipad.png), [copy](de/copy.de.json), [blind table](de/back-translation.md) |
| es | es-MX / es_MX | Fredoka / Caveat / Nunito Sans | see font report | [iPhone](es/overview-iphone.png), [iPad](es/overview-ipad.png), [copy](es/copy.es.json), [blind table](es/back-translation.md) |
| pt-BR | pt-BR / pt_BR | Fredoka / Caveat / Nunito Sans | see font report | [iPhone](pt-BR/overview-iphone.png), [iPad](pt-BR/overview-ipad.png), [copy](pt-BR/copy.pt-BR.json), [blind table](pt-BR/back-translation.md) |
| ja | ja / ja_JP | Noto Sans JP | 700 / 600–800 / 650 | [iPhone](ja/overview-iphone.png), [iPad](ja/overview-ipad.png), [copy](ja/copy.ja.json), [blind table](ja/back-translation.md) |
| ko | ko / ko_KR | Noto Sans KR | 700 / 600–800 / 650 | [iPhone](ko/overview-iphone.png), [iPad](ko/overview-ipad.png), [copy](ko/copy.ko.json), [blind table](ko/back-translation.md) |
| ar | ar / ar_SA | Noto Sans Arabic | 700 / 600–800 / 650 | [iPhone](ar/overview-iphone.png), [iPad](ar/overview-ipad.png), [copy](ar/copy.ar.json), [blind table](ar/back-translation.md) |

Fredoka, Caveat and Noto font licences are retained under
`tool/marketing/store_130/fonts/`; Nunito Sans stays under `assets/fonts/`.
Latin headlines use Fredoka 500–600, Caveat 650–700 and Nunito Sans 600–950;
Latin tags use Nunito Sans 800 and subtitles 650. Japanese, Korean and
Arabic use their respective Noto families: headline weights 600–800,
tags 700 and subtitles 650. The brand and counters retain Nunito Sans.
[Exact per-caption fonts, weights and sizes](font-weights.md) are recorded
for both device families, along with each locale's `composition-audit.json`.
Arabic captions are right-aligned and RTL; the real UI pixels are not mirrored.
Long headings and subtitles are fitted without changing their wording.

Each language contains eight opaque RGB iPhone 6.9-inch PNGs and six
opaque RGB iPad 13-inch PNGs. There is no 6.3-inch set.

The approved **display sequence** is below. Source filenames retain the
brief's original slot IDs; upload ordering must follow `order` in each
`composition-audit.json` / `verification.json`, not filename sorting.

| Display position | iPhone file | iPad file |
|---|---|---|
| 01 | `01-results.png` | `01-results.png` |
| 02 | `04-question.png` | `04-question.png` |
| 03 | `02-hint.png` | `02-hint.png` |
| 04 | `08-multi-blank.png` | `03-home.png` |
| 05 | `03-home.png` | `05-review.png` |
| 06 | `05-review.png` | `06-collection.png` |
| 07 | `06-collection.png` | — |
| 08 | `07-onboarding.png` | — |

Files live under `<lang>/store/iphone-6.9/` and `<lang>/store/ipad-13/`.
`overview-iphone.png` and `overview-ipad.png` are contact sheets.
`copy.json` and `copy.<lang>.json` contain identical approved-for-review
caption inputs and font weights. Each non-English back-translation table
includes all 24 caption fields, comparison notes, and any second blind pass.
The reviewer saw only localized text; this remains a same-model-family
consistency check, with no native-speaker review.

At the owner’s request (2026-11-04), the unframed native originals are
retained permanently outside Git under
`/Users/ahmet/Pictures/GrammarLens/1.4.0-raw/<lang>/<iphone|ipad>/`,
with locale/hint audits and a checksum manifest, for future design experiments.
Temporary working captures, composition audits, font proofs and logs remain
under `/private/tmp/grammarlens-140-*`. Only final frames, overview sheets,
copy, back-translation tables and verification records are delivered here.

From the detached worktree, capture one set with:

```sh
zsh tool/marketing/store_130/capture.sh iphone tr
```

From main, compose and verify each language:

```sh
node tool/marketing/store_130/compose_vivid_140.cjs tr iphone
node tool/marketing/store_130/compose_vivid_140.cjs tr ipad
node tool/marketing/store_130/verify.cjs --140 tr
```

## Checkpoint 1 verification

All eight languages passed `verify.cjs --140 <lang>`: 8 iPhone + 6 iPad
frames each, correct slot order and dimensions, opaque RGB PNGs, final
checksums, native sizes, expected interface locale, System default and
held/released hint behavior. 112 store PNGs and 16 overview sheets in all.
All sixteen source guards passed. `capture-provenance.json` records every
run and its locale check. Build 7 remains detached at c37757a; its final
protected-source diff is empty. Main remains on main, with changes only
under tool/ and screenshots/1.4.0/.

All 112 original PNGs in the permanent raw archive match the native
checksums recorded in each language's verification.json. The archive's
manifest.json is complete. Every copy.json matches copy.<lang>.json. Caption wording matches
the corresponding blind-reviewed rig input; only design/font metadata changed. All seven non-English blind tables contain
24 caption fields. English retains all 24 source fields word for word.
The capture rig's Dart analysis passed with no issues.

No App Store Connect upload or other write has been made. No push has
been made. Checkpoint 1 awaits owner approval before Phase 4 continues.

## Turkish iPhone design exploration (owner request, 2026-11-04)

The owner requested a warmer, more colorful direction with varied type,
a connected sequence for results/question/hint/multi-blank, multiple
perspective devices, and enlarged native UI components floating in front
of a device. These historical experiments led to the approved vivid direction now
applied above. Earlier checkpoint artwork remains in Git history, and all
exploratory variants remain outside Git. No App Store Connect write or push has been made.

Source: `tool/marketing/store_130/explore_cozy_tr.cjs`.
Concept PNGs and review sheets are outside Git at
`/Users/ahmet/Pictures/GrammarLens/design-explorations/tr-iphone/cozy-v1/`.
There are eight 1320 × 2868 opaque RGB PNGs, plus an overview and continuous
flow sheets. Input pixels come from the retained build-7 native originals;
the floating components are crops of those exact images. Fredoka and Caveat
are licensed under the SIL OFL, retained with their licence files under the
rig's fonts/ folder. Existing Turkish caption claims are retained.

### Design exploration v2 (owner feedback)

05-home, 07-collection and 08-onboarding are copied byte for byte from v1,
as requested. 06-review retains the same device composition and headings;
its two floating cards now use native interior crops inside complete,
padded rounded shells. 01–04 use calmer device angles and the same complete
component shells; short dotted arrows connect the pages instead of the
broad background ribbon. Native content and caption claims are retained.

Source: `tool/marketing/store_130/explore_cozy_tr_v2.cjs`.
Review outputs: `/Users/ahmet/Pictures/GrammarLens/design-explorations/tr-iphone/cozy-v2/`.
`revised-four.png` focuses on the first four pages; `06-review.png` shows
the corrected review cards. `verification.json` records PNG checks and the
exact preservation of 05/07/08. v2 awaits owner design feedback.

### Design exploration v3 (owner feedback)

02-question's “yaz.” and 03-hint's “gör.” now use Fredoka 600, matching
the other emphasized words. The first four pages have no decorative
underlines or isolated dotted arrows. A single continuous curve spans
their shared canvas, joining each page boundary and ending with one arrowhead.
03-hint additionally lifts the real “İpucu için kaydır” slider above the
existing open hint card. The labeled control is cropped from the closed
04-question state; the phone and explanation remain the actual held-open
02-hint state. No interface pixels or claims were invented.

05-home, 06-review, 07-collection and 08-onboarding are copied byte for byte
from v2. All original native screenshots and earlier concepts are retained.

Source: `tool/marketing/store_130/explore_cozy_tr_v3.cjs`.
Review outputs: `/Users/ahmet/Pictures/GrammarLens/design-explorations/tr-iphone/cozy-v3/`.
`test-story.png` shows the continuous first-four sequence; `03-hint.png`
shows the lifted control and explanation. `verification.json` records all
eight PNG checks, typography and preserved-page checks. v3 awaits owner
design approval; no other language, iPad or App Store Connect write is included.

### Design exploration v4 (owner feedback)

The original v1 double ribbon is restored across all eight pages. 01–04
have varied headline styles, weights and alignment, with colored underlines.
01 now lifts the complete native red error card, including its question,
wrong answer, correction and explanation. 03's foreground slider and hint
card are lowered so the question on the phone is fully visible.

05 and 08 retain their composition; their heading cedillas are centered
under the s body to remove the apparent hook beneath the following i/ı.
The actual captions remain “yükselişini” and “arkadaşını”. 06 and 07 are
copied byte for byte from v3. All raw captures and prior designs are retained.

Source: `tool/marketing/store_130/explore_cozy_tr_v4.cjs`.
Review outputs: `/Users/ahmet/Pictures/GrammarLens/design-explorations/tr-iphone/cozy-v4/`.
`overview.png` shows all eight pages; `01-results.png` and `03-hint.png`
show the revised foreground composition. `verification.json` records PNG,
preservation and unchanged lower-composition checks. v4 awaits owner design
approval. No other language, iPad, App Store Connect write or push is included.

### Design exploration v5 (general polish requested by owner)

V4's complete error card, visible hint question, varied headings, corrected
Turkish cedillas and continuous double ribbon remain. The eight pages now
use small topic illustration badges, the existing translated caption tags
in contrasting pills, soft light behind the devices and refined layered
card shadows. Brand and sequence markers share a softer capsule treatment.
No new caption claims were introduced; native build-7 sources are unchanged.

Source: `tool/marketing/store_130/explore_cozy_tr_v5.cjs`.
Outputs: `/Users/ahmet/Pictures/GrammarLens/design-explorations/tr-iphone/cozy-v5/`.
`overview.png` shows all eight pages. `comparison-v4-v5.png` compares the
first page, V4 left and V5 right. All eight PNG checks, text fit and caption
comparisons passed (`verification.json`). Turkish iPhone design review
continues; no other locales, iPad, ASC uploads or push are included.

### Two fade background alternatives (owner request)

`tool/marketing/store_130/explore_fade_tr.cjs` renders the V5 foreground
with `FADE_THEME=vivid` (coral, mango, turquoise and lilac) or
`FADE_THEME=mist` (cool blue, lavender and mint). Only the background
gradient, glow and ribbon tones change. All caption text and measured
caption positions match V5; native build-7 checksums pass.

Outputs are outside Git under
`/Users/ahmet/Pictures/GrammarLens/design-explorations/tr-iphone/fade-vivid/`
and `fade-mist/`. Each contains eight composed PNGs, overview sheets,
eight separate blank PNGs in `backgrounds/`, `background-flow.png`, a
manifest and verification. All 32 PNGs are opaque RGB at 1320 × 2868.
Both alternatives await owner selection; no ASC write or push was made.

## Approved vivid rollout (2026-11-04)

The owner selected **Canlı fade** and authorized all languages and devices.
All 112 store frames and 16 overview sheets now use that direction. The
eight Turkish iPhone frames match the selected reference byte for byte.
iPad uses a dedicated tablet composition with the same colors, double
ribbon, varied headlines and enlarged native components. Native interface
crops retain their complete localized controls, including the hint slider.

All eight final verification runs passed. All 112 permanent originals
match the recorded capture hashes. Copy wording and the existing blind
back-translations are unchanged. Caption fit and overlap checks passed;
all localized iPhone and iPad sheets were visually reviewed. No recapture,
App Store Connect operation or push was performed for this rollout.
Checkpoint 1 is ready for owner review; checkpoint 2 has not started.

## iPad layout revision (2026-11-05)

Owner feedback applied to all eight iPad localizations: the three medals
in display position 06 now share the same size and baseline, with equal
close spacing. Foreground components in positions 01–03 are centered on
the page. Position 03 no longer centers its first title line independently;
both lines share the locale’s alignment. The second headline lines in
positions 02 and 06 are enlarged, with more vertical room for their
underlines and subtitles. All eight iPad sheets were visually reviewed;
all locale verification checks pass. iPhone images, native captures and
caption wording are unchanged. Checkpoint 1 still awaits owner approval.

### iPad device-centered follow-up (2026-11-05)

The owner clarified that foreground cards must align with the device
screen, not the page. Results, question/input, hint/control and review
cards now align to the rendered primary tablet screen’s horizontal center.
Their widths are adjusted to preserve the full cards inside the canvas.
Measured centers and bounds are retained in `foregroundAlignment` for
each composition record; verification requires less than one pixel of
center deviation. The collection medals form a compact arch over the
tablet: the central gold medal is larger and higher, with the two side
medals angled inward as a balanced group. This supersedes the previous
straight row. All eight iPad languages use the revision.

### iPad hint states and connected pages (2026-11-05)

Owner feedback: position 02 now lifts three native pieces—question,
unmoved hint slider and answer input. Position 03 lifts one contiguous
crop from the held-open `02-hint.png`, containing both the slider with
its knob at the end and the revealed hint card; it no longer combines
a closed slider with an open card. `nativeGeometry.ipad.openHint` records
that exact crop. Arabic retains its native right-to-left slider state.

The secondary results iPad in position 05 continues into position 06
behind the collection tablet. Both halves use the same image, size,
vertical position, perspective and rotation; the second half is offset
by exactly one canvas width (2064 px). The medal group is raised by
150 px, exposing the native companion and avatar-change control beneath.
Caption wording and typography, iPhone outputs and raw captures remain
unchanged. Checkpoint 1 awaits owner review; nothing has been uploaded.
