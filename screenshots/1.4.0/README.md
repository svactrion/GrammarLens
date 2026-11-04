# 1.4.0 App Store screenshot assets

Checkpoint 1 draft. Owner approval pending; nothing uploaded or pushed.

Captured from build 7's source, detached commit `c37757a` (`1.4.0+7`),
in `/private/tmp/grammarlens-140-build7`. The owner's checkout remains on
`main`. Rig changes are committed on main and imported before every run
with `git checkout main -- tool/`. Every run refuses to capture unless
`git diff --stat c37757a -- lib ios assets pubspec.yaml` prints nothing.
No application, iOS, proxy or test sources were edited.

The existing `tool/marketing/store_130/` rig supplies the capture flow,
original device frames, cream gradient and English copy. Only
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
| en | en-US / en_US | Nunito Sans | 800 / 900 / 600 | [iPhone](en/overview-iphone.png), [iPad](en/overview-ipad.png), [copy](en/copy.en.json), [source-language note](en/back-translation.md) |
| tr | tr / tr_TR | Nunito Sans | 800 / 900 / 600 | [iPhone](tr/overview-iphone.png), [iPad](tr/overview-ipad.png), [copy](tr/copy.tr.json), [blind table](tr/back-translation.md) |
| de | de / de_DE | Nunito Sans | 800 / 900 / 600 | [iPhone](de/overview-iphone.png), [iPad](de/overview-ipad.png), [copy](de/copy.de.json), [blind table](de/back-translation.md) |
| es | es-MX / es_MX | Nunito Sans | 800 / 900 / 600 | [iPhone](es/overview-iphone.png), [iPad](es/overview-ipad.png), [copy](es/copy.es.json), [blind table](es/back-translation.md) |
| pt-BR | pt-BR / pt_BR | Nunito Sans | 800 / 900 / 600 | [iPhone](pt-BR/overview-iphone.png), [iPad](pt-BR/overview-ipad.png), [copy](pt-BR/copy.pt-BR.json), [blind table](pt-BR/back-translation.md) |
| ja | ja / ja_JP | Noto Sans JP | 700 / 800 / 500 | [iPhone](ja/overview-iphone.png), [iPad](ja/overview-ipad.png), [copy](ja/copy.ja.json), [blind table](ja/back-translation.md) |
| ko | ko / ko_KR | Noto Sans KR | 700 / 800 / 500 | [iPhone](ko/overview-iphone.png), [iPad](ko/overview-ipad.png), [copy](ko/copy.ko.json), [blind table](ko/back-translation.md) |
| ar | ar / ar_SA | Noto Sans Arabic | 700 / 800 / 500 | [iPhone](ar/overview-iphone.png), [iPad](ar/overview-ipad.png), [copy](ar/copy.ar.json), [blind table](ar/back-translation.md) |

Noto fonts and their SIL OFL licences are kept under
`tool/marketing/store_130/fonts/`. Nunito Sans and its licence remain
under `assets/fonts/`. Noto tag, title and subtitle weights were compared visually with the
approved Nunito design and checked on composed frame 01 in each language.
The brand and Latin-digit counters retain Nunito Sans and the original
positioning. Arabic captions are right-aligned and RTL; tags in scripts
without case are not uppercased. Titles may wrap to three lines. The
composer rejects overflow and caption/device overlap; it never reduces
text below the original subtitle size (27 px iPhone / 36 px iPad).

Each language contains eight opaque RGB iPhone 6.9-inch PNGs and six
opaque RGB iPad 13-inch PNGs. There is no 6.3-inch set.

| # | File | iPhone | iPad |
|---|---|---|---|
| 01 | `01-results.png` | ✓ | ✓ |
| 02 | `02-hint.png` | ✓ | ✓ |
| 03 | `03-home.png` | ✓ | ✓ |
| 04 | `04-question.png` | ✓ | ✓ |
| 05 | `05-review.png` | ✓ | ✓ |
| 06 | `06-collection.png` | ✓ | ✓ |
| 07 | `07-onboarding.png` | ✓ | — |
| 08 | `08-multi-blank.png` | ✓ | — |

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
node tool/marketing/store_130/compose_140.cjs tr
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
manifest.json is complete. Every copy.json matches copy.<lang>.json and
the corresponding rig input. All seven non-English blind tables contain
24 caption fields. English retains all 24 source fields word for word.
The capture rig's Dart analysis passed with no issues.

No App Store Connect upload or other write has been made. No push has
been made. Checkpoint 1 awaits owner approval before Phase 4 continues.

## Turkish iPhone design exploration (owner request, 2026-11-04)

The owner requested a warmer, more colorful direction with varied type,
a connected sequence for results/question/hint/multi-blank, multiple
perspective devices, and enlarged native UI components floating in front
of a device. Approval of this Turkish iPhone concept comes before applying
the direction to other languages or iPad. The earlier checkpoint set above
is retained. No App Store Connect write or push has been made.

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
